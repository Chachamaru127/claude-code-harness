#!/usr/bin/env bash
# redact-by-ner.sh
# Phase 65.3.3 - Layer 2b NER (Named Entity Recognition) redaction
#
# Purpose:
#   Accept text, perform morphological analysis with a Japanese tokenizer
#   (fugashi + UniDic-lite), and replace tokens tagged pos2="固有名詞" (proper noun)
#   with [Entity]. Adjacent proper-noun tokens are merged into a single [Entity]
#   (e.g., 田中 + 太郎 → [Entity]).
#
# Usage:
#   redact-by-ner.sh --input <text>
#   echo "text" | redact-by-ner.sh --stdin
#
# Options:
#   --input <text>         Text to redact
#   --stdin                Read from stdin
#   -h | --help            Help
#
# Environment:
#   CCH_NER_DISABLE_TOKENIZER=1   Force-disable tokenizer (fail-open for tests)
#
# Exit code:
#   0 = success (includes NER success and fail-open path)
#   2 = usage error
#
# Output:
#   stdout: redacted text (original text unchanged if 0 proper nouns)
#   stderr: "redacted: <count> entities" on hits
#           "WARNING: tokenizer unavailable, fail-open" when tokenizer is absent
#
# Fail-open spec (Plans.md DoD d):
#   tokenizer (fugashi) absent / import failed → exit 0, original text unchanged,
#   1 warning line to stderr. Does not redact but does not stop processing.
#
# Double-replacement guard (D43 decision 4):
#   Existing sentinel marks ([REDACTED_*] / [Entity] / [Client_*] /
#   [Person_*] / [Domain_*]) are protected via a 3-stage stash → NER → restore
#   cycle so they are not re-redacted.

set -euo pipefail

usage() {
  cat <<'USAGE' >&2
Usage:
  redact-by-ner.sh --input <text>
  echo "text" | redact-by-ner.sh --stdin

Required (one of):
  --input <text>          Text to redact
  --stdin                 Read from stdin

Options:
  -h | --help             Help

Environment:
  CCH_NER_DISABLE_TOKENIZER=1   Force-disable tokenizer (for tests)

Exit code: 0=success / 2=usage error
USAGE
  exit 2
}

INPUT=""
USE_STDIN="false"
INPUT_PROVIDED="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input)  INPUT="${2:-}"; INPUT_PROVIDED="true"; shift 2 ;;
    --stdin)  USE_STDIN="true"; shift 1 ;;
    -h|--help) usage ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage ;;
  esac
done

if [[ "$USE_STDIN" == "true" && "$INPUT_PROVIDED" == "true" ]]; then
  echo "ERROR: --input and --stdin are mutually exclusive" >&2
  exit 2
fi

if [[ "$USE_STDIN" == "false" && "$INPUT_PROVIDED" == "false" ]]; then
  echo "ERROR: one of --input or --stdin is required" >&2
  usage
fi

if ! command -v python3 >/dev/null 2>&1; then
  # python3 absent also triggers fail-open
  if [[ "$USE_STDIN" == "true" ]]; then
    cat
  else
    printf '%s' "$INPUT"
  fi
  echo "WARNING: python3 unavailable, fail-open (NER skipped)" >&2
  exit 0
fi

# Read from stdin
if [[ "$USE_STDIN" == "true" ]]; then
  INPUT="$(cat)"
fi

export INPUT_TEXT_PY="$INPUT"
export CCH_NER_DISABLE_TOKENIZER_PY="${CCH_NER_DISABLE_TOKENIZER:-}"

exec python3 - <<'PYEOF'
import os
import sys
import re

INPUT_TEXT = os.environ.get("INPUT_TEXT_PY", "")
DISABLE_TOKENIZER = os.environ.get("CCH_NER_DISABLE_TOKENIZER_PY", "") == "1"

# Sentinel patterns (D43 decision 4: double-replacement guard)
SENTINEL_PATTERNS = [
    re.compile(r"\[REDACTED_[A-Za-z0-9_]+\]"),
    re.compile(r"\[Entity\]"),
    re.compile(r"\[Client_[A-Za-z0-9_]+\]"),
    re.compile(r"\[Person_[A-Za-z0-9_]+\]"),
    re.compile(r"\[Domain_[A-Za-z0-9_]+\]"),
]

def fail_open(reason):
    """When tokenizer is absent or import fails: pass through original text + stderr warning"""
    sys.stdout.write(INPUT_TEXT)
    print(f"WARNING: tokenizer unavailable, fail-open ({reason})", file=sys.stderr)
    sys.exit(0)

if DISABLE_TOKENIZER:
    fail_open("CCH_NER_DISABLE_TOKENIZER=1")

try:
    from fugashi import Tagger
except ImportError as e:
    fail_open(f"fugashi import failed: {e}")

try:
    tagger = Tagger()
except Exception as e:
    # dict absent etc.
    fail_open(f"tokenizer init failed: {e}")

# ---- Double-replacement guard: stash sentinels ----
text = INPUT_TEXT
sentinel_storage = []

def stash_sentinels(t):
    out = t
    for pat in SENTINEL_PATTERNS:
        def replace(m):
            idx = len(sentinel_storage)
            sentinel_storage.append(m.group(0))
            return f" CCH_SENT_{idx} "
        out = pat.sub(replace, out)
    return out

text = stash_sentinels(text)

# ---- NER: morphological analysis → proper-noun extraction → adjacent merge ----
# Analyse text with fugashi → obtain token list
# Consecutive proper-noun tokens are collapsed into a single [Entity]
# Other tokens (including sentinel placeholders) are kept as-is

try:
    tokens = list(tagger(text))
except Exception as e:
    # tokenization failure (rare) also triggers fail-open
    sys.stdout.write(INPUT_TEXT)
    print(f"WARNING: tokenization failed, fail-open ({e})", file=sys.stderr)
    sys.exit(0)

# Build output: process tokens in order, collapsing each proper-noun run into a single [Entity]
output_parts = []
hit_count = 0
in_proper_noun_run = False

for tok in tokens:
    surface = tok.surface
    feature = tok.feature
    pos2 = getattr(feature, "pos2", "") if feature is not None else ""
    is_proper_noun = (pos2 == "固有名詞")  # "固有名詞" = proper noun in UniDic
    white_space = getattr(tok, "white_space", "") or ""

    if is_proper_noun:
        if not in_proper_noun_run:
            output_parts.append(white_space + "[Entity]")
            hit_count += 1
            in_proper_noun_run = True
        # else: continuation of the same run → append nothing ([Entity] already emitted)
    else:
        output_parts.append(white_space + surface)
        in_proper_noun_run = False

result = "".join(output_parts)

# ---- Restore sentinels ----
for idx, original in enumerate(sentinel_storage):
    placeholder_core = f"CCH_SENT_{idx}"
    result = result.replace(f" {placeholder_core} ", original)
    result = result.replace(placeholder_core, original)

# ---- Output ----
sys.stdout.write(result)

if hit_count > 0:
    print(f"redacted: {hit_count} entities", file=sys.stderr)

sys.exit(0)
PYEOF
