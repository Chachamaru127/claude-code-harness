#!/bin/bash
# tests/test-render-html-redaction.sh
# Phase 65.3.4 - render-html.sh --with-redaction mechanical validation
#
# Validation cases (corresponding to Plans.md §65.3.4 DoD d):
#   1. all clean        - nothing needs redacting → exit 0, HTML generated
#   2. dict hit only    - dict match found → exit 0, HTML generated (redacted)
#   3. NER hit only     - proper noun found → exit 0, HTML generated (redacted)
#   4. final scan catch - 5+ consecutive katakana → exit 1, HTML not generated

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SCRIPT="$ROOT_DIR/scripts/render-html.sh"
TEMPLATE="test-fixture"

PASS=0
FAIL=0
FAIL_MESSAGES=()

pass() { PASS=$((PASS + 1)); echo "✓ $1"; }
fail() { FAIL=$((FAIL + 1)); FAIL_MESSAGES+=("$1"); echo "✗ $1" >&2; }

if [[ ! -x "$SCRIPT" ]]; then
  fail "render-html.sh not executable"
  echo "PASS=$PASS FAIL=$FAIL"
  exit 1
fi
pass "render-html.sh exists and is executable"

# Tokenizer availability (for NER case skip decision)
TOKENIZER_AVAILABLE="false"
if python3 -c "from fugashi import Tagger; Tagger()" 2>/dev/null; then
  TOKENIZER_AVAILABLE="true"
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/test-render-redaction.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

# ============================================================
# Case 1: all clean — nothing to redact, exit 0, HTML generated
# ============================================================

DATA1="$TMP_DIR/data1-clean.json"
cat > "$DATA1" <<'JSON'
{
  "title": "Hello World",
  "sections": [
    {"name": "Foo"},
    {"name": "Bar"}
  ]
}
JSON

OUT1="$TMP_DIR/out1.html"
if bash "$SCRIPT" --template "$TEMPLATE" --data "$DATA1" --out "$OUT1" --with-redaction 2>"$TMP_DIR/c1-stderr.txt"; then
  pass "Case 1 (all clean): exit 0"
else
  fail "Case 1: unexpected non-zero exit"
fi

if [[ -f "$OUT1" ]]; then
  pass "Case 1: HTML file generated"
else
  fail "Case 1: HTML file not created"
fi

if grep -q "Hello World" "$OUT1" 2>/dev/null; then
  pass "Case 1: title present unchanged"
else
  fail "Case 1: title missing or changed"
fi

# ============================================================
# Case 2: dict hit only — using custom client dict
# ============================================================

DICT2="$TMP_DIR/dict2-test.yaml"
cat > "$DICT2" <<'YAML'
schema_version: client-redaction.v1
clients:
  - rule_id: c-test-001
    name: NoraiCorp
    replace_with: "[Client_TestA]"
people: []
domains: []
YAML

DATA2="$TMP_DIR/data2-dict-hit.json"
cat > "$DATA2" <<'JSON'
{
  "title": "Project NoraiCorp Plan",
  "sections": [
    {"name": "Foo"}
  ]
}
JSON

OUT2="$TMP_DIR/out2.html"
if bash "$SCRIPT" --template "$TEMPLATE" --data "$DATA2" --out "$OUT2" --with-redaction --client-dict "$DICT2" 2>"$TMP_DIR/c2-stderr.txt"; then
  pass "Case 2 (dict hit): exit 0"
else
  fail "Case 2: unexpected non-zero exit. stderr: $(cat "$TMP_DIR/c2-stderr.txt")"
fi

if grep -q "\[Client_TestA\]" "$OUT2" 2>/dev/null; then
  pass "Case 2: dict replacement [Client_TestA] present in HTML"
else
  fail "Case 2: dict replacement missing"
fi

if grep -q "NoraiCorp" "$OUT2" 2>/dev/null; then
  fail "Case 2: original 'NoraiCorp' should NOT appear in HTML"
else
  pass "Case 2: original 'NoraiCorp' redacted (not in HTML)"
fi

# ============================================================
# Case 3: NER hit only — 田中太郎 in title
# ============================================================

if [[ "$TOKENIZER_AVAILABLE" == "true" ]]; then
  DATA3="$TMP_DIR/data3-ner-hit.json"
  cat > "$DATA3" <<'JSON'
{
  "title": "田中太郎のプラン",
  "sections": [
    {"name": "Foo"}
  ]
}
JSON

  OUT3="$TMP_DIR/out3.html"
  if bash "$SCRIPT" --template "$TEMPLATE" --data "$DATA3" --out "$OUT3" --with-redaction 2>"$TMP_DIR/c3-stderr.txt"; then
    pass "Case 3 (NER hit): exit 0"
  else
    fail "Case 3: unexpected non-zero exit. stderr: $(cat "$TMP_DIR/c3-stderr.txt")"
  fi

  if grep -q "\[Entity\]" "$OUT3" 2>/dev/null; then
    pass "Case 3: NER replacement [Entity] present in HTML"
  else
    fail "Case 3: NER replacement missing"
  fi

  if grep -q "田中太郎" "$OUT3" 2>/dev/null; then
    fail "Case 3: original '田中太郎' should NOT appear in HTML (not redacted)"
  else
    pass "Case 3: original '田中太郎' redacted (not in HTML)"
  fi
else
  pass "Case 3 (NER hit): SKIPPED (tokenizer unavailable)"
  pass "Case 3 [Entity] check: SKIPPED"
  pass "Case 3 redaction check: SKIPPED"
fi

# ============================================================
# Case 4: final scan catch — title containing 5+ consecutive katakana
# ============================================================
# Layer 3 catches "5+ consecutive katakana" missed by Layer 2 (dict + NER).
# Short katakana detected as proper nouns by fugashi are removed by NER,
# so we use a **long katakana sequence not in the proper noun dictionary**.

DATA4="$TMP_DIR/data4-final-scan.json"
cat > "$DATA4" <<'JSON'
{
  "title": "プロジェクトメインボードフィードバック",
  "sections": [
    {"name": "Foo"}
  ]
}
JSON

# Note: if tokenizer is available, we need a katakana sequence not recognized as a proper noun.
# "プロジェクトメインボードフィードバック" is a common-noun sequence; fugashi does not treat it as proper noun,
# and as a long katakana run, Layer 3 is expected to catch it.

OUT4="$TMP_DIR/out4.html"
if bash "$SCRIPT" --template "$TEMPLATE" --data "$DATA4" --out "$OUT4" --with-redaction 2>"$TMP_DIR/c4-stderr.txt"; then
  CATCH_RESULT="rendered"
else
  CATCH_RESULT="aborted"
fi

# Depending on the tokenizer, "メインボード" may be 1 token and "フィードバック" 1 token,
# each treated as a common noun (not proper noun). Layer 3 final scan sees consecutive katakana
# as a single run, so `プロジェクト` `メインボード` `フィードバック` etc. concatenated
# form a 5+ character run (scanned after sentinel escape, so [Entity] etc. are unaffected).
if [[ "$CATCH_RESULT" == "aborted" ]]; then
  pass "Case 4 (final scan): exit 1 (HTML generation aborted)"
else
  fail "Case 4: expected exit 1 but render-html succeeded"
fi

if [[ ! -f "$OUT4" ]]; then
  pass "Case 4: HTML file NOT created (fail-safe)"
else
  fail "Case 4: HTML should not exist after final scan failure"
fi

if grep -q "detected:" "$TMP_DIR/c4-stderr.txt" 2>/dev/null; then
  pass "Case 4: stderr contains 'detected:' line"
else
  fail "Case 4: stderr missing 'detected:'. content: $(cat "$TMP_DIR/c4-stderr.txt")"
fi

if grep -q "Layer 3 final scan detected residue" "$TMP_DIR/c4-stderr.txt" 2>/dev/null; then
  pass "Case 4: stderr contains 'Layer 3 final scan detected residue'"
else
  fail "Case 4: stderr missing aborted message"
fi

# ============================================================
# Case 5 (additional): no --with-redaction → existing behavior preserved
# ============================================================

OUT5="$TMP_DIR/out5.html"
if bash "$SCRIPT" --template "$TEMPLATE" --data "$DATA1" --out "$OUT5" 2>"$TMP_DIR/c5-stderr.txt"; then
  pass "Case 5 (no flag): backward-compat — exit 0 without --with-redaction"
else
  fail "Case 5: backward-compat broken"
fi

if [[ -f "$OUT5" ]] && grep -q "Hello World" "$OUT5" 2>/dev/null; then
  pass "Case 5: HTML generated normally without redaction"
else
  fail "Case 5: HTML missing or content lost"
fi

# ============================================================
# Result
# ============================================================

echo ""
echo "============================================================"
echo "Test Summary (test-render-html-redaction.sh)"
echo "============================================================"
echo "PASS: $PASS"
echo "FAIL: $FAIL"
if [[ "$TOKENIZER_AVAILABLE" == "false" ]]; then
  echo "(NOTE: NER tests skipped — fugashi unavailable)"
fi

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "Failed tests:"
  for msg in "${FAIL_MESSAGES[@]}"; do
    echo "  - $msg"
  done
  exit 1
fi

exit 0
