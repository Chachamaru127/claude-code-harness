#!/usr/bin/env bash
# redact-by-dictionary.sh
# Phase 65.3.2 - Layer 2a dictionary-based named-entity redaction (D43 decisions 3 + 4)
#
# Purpose:
#   Accept text and replace named entities (clients / people / domains) with
#   redact_with tokens according to the dict in client-redaction.yaml.
#   Record hit count to stderr; output redacted text to stdout.
#
# Usage:
#   redact-by-dictionary.sh --input <text> [--dict <yaml-path>]
#   echo "text" | redact-by-dictionary.sh --stdin [--dict <yaml-path>]
#
# Options:
#   --input <text>          Text to redact (literal)
#   --stdin                 Read redact target from stdin
#   --dict <yaml-path>      Dict file (default: .claude/rules/client-redaction.yaml)
#   -h | --help             Help
#
# Exit code:
#   0 = success (normal exit regardless of 0 or 1+ hits)
#   1 = dict file not found / dict schema invalid / runtime error
#   2 = usage error
#
# Output:
#   stdout: redacted text (original text unchanged if 0 hits)
#   stderr: single line "redacted: <count> tokens" only when hits > 0
#
# Double-replacement guard (D43 decision 4):
#   Locations already containing [REDACTED_*] [Entity] [Client_*] [Person_*] [Domain_*]
#   are not re-replaced (boundary detection via sentinel pattern).
#
# Schema: client-redaction.v1 (PiiRule compatible)
#   {schema_version, clients[], people[], domains[]}
#   Each entry: {rule_id, name, aliases[]?, replace_with}

set -euo pipefail

usage() {
  cat <<'USAGE' >&2
Usage:
  redact-by-dictionary.sh --input <text> [--dict <yaml-path>]
  echo "text" | redact-by-dictionary.sh --stdin [--dict <yaml-path>]

Required (one of):
  --input <text>          Text to redact
  --stdin                 Read from stdin

Optional:
  --dict <yaml-path>      Dict file (default: .claude/rules/client-redaction.yaml)
  -h | --help             Help

Exit code: 0=success / 1=runtime error / 2=usage error
USAGE
  exit 2
}

INPUT=""
USE_STDIN="false"
DICT_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input)  INPUT="${2:-}";  USE_STDIN="false"; shift 2 ;;
    --stdin)  USE_STDIN="true"; shift 1 ;;
    --dict)   DICT_PATH="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage ;;
  esac
done

if [[ "$USE_STDIN" == "true" && -n "$INPUT" ]]; then
  echo "ERROR: --input and --stdin are mutually exclusive" >&2
  exit 2
fi

if [[ "$USE_STDIN" == "false" && -z "$INPUT" ]]; then
  # Empty-string --input outputs the original text with 0 hits (normal)
  # However, having neither specified is an error
  if [[ $# -eq 0 ]] && [[ -z "${INPUT+x}" || "$INPUT" == "__UNSET_SENTINEL__" ]]; then
    echo "ERROR: one of --input or --stdin is required" >&2
    usage
  fi
fi

# default dict path
if [[ -z "$DICT_PATH" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
  DICT_PATH="${REPO_ROOT}/.claude/rules/client-redaction.yaml"
fi

if [[ ! -f "$DICT_PATH" ]]; then
  echo "ERROR: dict file not found: $DICT_PATH" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required but not found" >&2
  exit 1
fi

# Read from stdin
if [[ "$USE_STDIN" == "true" ]]; then
  INPUT="$(cat)"
fi

export DICT_PATH_PY="$DICT_PATH"
export INPUT_TEXT_PY="$INPUT"

exec python3 - <<'PYEOF'
import os
import sys
import re

try:
    import yaml
except ImportError:
    print("ERROR: python3-yaml (PyYAML) is required but not installed", file=sys.stderr)
    sys.exit(1)

DICT_PATH = os.environ["DICT_PATH_PY"]
INPUT_TEXT = os.environ.get("INPUT_TEXT_PY", "")

EXPECTED_SCHEMA = "client-redaction.v1"

# Sentinel patterns (D43 decision 4: double-replacement guard)
# Stash existing redact marks into placeholders, then restore after redaction
SENTINEL_PATTERNS = [
    re.compile(r"\[REDACTED_[A-Za-z0-9_]+\]"),
    re.compile(r"\[Entity\]"),
    re.compile(r"\[Client_[A-Za-z0-9_]+\]"),
    re.compile(r"\[Person_[A-Za-z0-9_]+\]"),
    re.compile(r"\[Domain_[A-Za-z0-9_]+\]"),
]

# ---- yaml load + schema validation ----
try:
    with open(DICT_PATH, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)
except yaml.YAMLError as e:
    print(f"ERROR: yaml parse failed: {e}", file=sys.stderr)
    sys.exit(1)

if data is None:
    print(f"ERROR: dict yaml is empty: {DICT_PATH}", file=sys.stderr)
    sys.exit(1)

schema_version = data.get("schema_version")
if schema_version != EXPECTED_SCHEMA:
    print(f"ERROR: schema_version must be '{EXPECTED_SCHEMA}', got: {schema_version!r}", file=sys.stderr)
    sys.exit(1)

# ---- Extract entries (clients + people + domains) ----
entries = []
seen_rule_ids = set()

for category in ("clients", "people", "domains"):
    items = data.get(category) or []
    if not isinstance(items, list):
        print(f"ERROR: '{category}' must be a list", file=sys.stderr)
        sys.exit(1)
    for i, item in enumerate(items):
        if not isinstance(item, dict):
            print(f"ERROR: {category}[{i}] must be an object", file=sys.stderr)
            sys.exit(1)

        rule_id = item.get("rule_id")
        name = item.get("name")
        replace_with = item.get("replace_with")
        aliases = item.get("aliases") or []

        if not isinstance(rule_id, str) or rule_id == "":
            print(f"ERROR: {category}[{i}].rule_id must be a non-empty string", file=sys.stderr)
            sys.exit(1)
        if rule_id in seen_rule_ids:
            print(f"ERROR: duplicate rule_id: {rule_id}", file=sys.stderr)
            sys.exit(1)
        seen_rule_ids.add(rule_id)

        if not isinstance(name, str) or name == "":
            print(f"ERROR: {category}[{i}].name must be a non-empty string", file=sys.stderr)
            sys.exit(1)

        if not isinstance(replace_with, str) or replace_with == "":
            print(f"ERROR: {category}[{i}].replace_with must be a non-empty string", file=sys.stderr)
            sys.exit(1)

        if not isinstance(aliases, list):
            print(f"ERROR: {category}[{i}].aliases must be a list if present", file=sys.stderr)
            sys.exit(1)
        for j, a in enumerate(aliases):
            if not isinstance(a, str) or a == "":
                print(f"ERROR: {category}[{i}].aliases[{j}] must be a non-empty string", file=sys.stderr)
                sys.exit(1)

        entries.append({
            "rule_id": rule_id,
            "name": name,
            "aliases": aliases,
            "replace_with": replace_with,
            "category": category,
        })

# ---- Double-replacement guard: stash sentinels ----
# Stash existing sentinel marks into {{__SENTINEL_<idx>__}}
text = INPUT_TEXT
sentinel_storage = []  # for restoration (idx, original)

def stash_sentinels(t):
    """Stash sentinel marks in t into placeholders and update the stash list"""
    out = t
    for pat in SENTINEL_PATTERNS:
        def replace(m):
            idx = len(sentinel_storage)
            sentinel_storage.append(m.group(0))
            return f"__CCHX_SENTINEL_{idx}__"
        out = pat.sub(replace, out)
    return out

text = stash_sentinels(text)

# ---- redaction (longer aliases first to avoid partial overshadow) ----
# Collect [name] + [aliases] for each entry → sort by length DESC →
# literal replace in order. This ensures "Tanaka Taro" is replaced before "Tanaka".
hit_count = 0

# Build replacement list: (search_string, replace_with) — sort by length DESC
all_replacements = []
for e in entries:
    targets = [e["name"]] + e["aliases"]
    for t in targets:
        all_replacements.append((t, e["replace_with"]))

# Sort by length descending (when aliases include both "Tanaka" and "Tanaka Taro", replace the longer one first)
all_replacements.sort(key=lambda x: len(x[0]), reverse=True)

for search_str, replace_with in all_replacements:
    if search_str == "":
        continue
    if search_str in text:
        # count occurrences then replace
        count = text.count(search_str)
        text = text.replace(search_str, replace_with)
        hit_count += count

# ---- Restore sentinels ----
for idx, original in enumerate(sentinel_storage):
    text = text.replace(f"__CCHX_SENTINEL_{idx}__", original)

# ---- output ----
sys.stdout.write(text)
# Respect trailing newline from input (write does not add a newline)

if hit_count > 0:
    print(f"redacted: {hit_count} tokens", file=sys.stderr)

sys.exit(0)
PYEOF
