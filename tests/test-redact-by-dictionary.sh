#!/bin/bash
# tests/test-redact-by-dictionary.sh
# Phase 65.3.2 - redact-by-dictionary.sh mechanical validation
#
# Validation cases (corresponding to Plans.md §65.3.2 DoD d):
#   1. 0 hits       - no match, original text unchanged, no stderr
#   2. 1 hit        - 1 replacement, stderr shows "redacted: 1 tokens"
#   3. multiple hits - 1 entry's name appears 2 times → 2 hits
#   4. aliases hit  - both main name and alias use the same replace_with
#   5. duplicate redact_as - multiple entries with same replace_with, correct count
#
# Additional validation (D43 decision 4 double-replacement guard):
#   6. sentinel marks ([REDACTED_*], [Entity], [Client_*], [Person_*], [Domain_*])
#      are excluded from redaction targets

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SCRIPT="$ROOT_DIR/scripts/redact-by-dictionary.sh"
DEFAULT_DICT="$ROOT_DIR/.claude/rules/client-redaction.yaml"

PASS=0
FAIL=0
FAIL_MESSAGES=()

pass() { PASS=$((PASS + 1)); echo "✓ $1"; }
fail() { FAIL=$((FAIL + 1)); FAIL_MESSAGES+=("$1"); echo "✗ $1" >&2; }

# ---- pre-checks ----

if [[ ! -x "$SCRIPT" ]]; then
  fail "redact-by-dictionary.sh not executable"
  echo "PASS=$PASS FAIL=$FAIL"
  exit 1
fi
pass "redact-by-dictionary.sh exists and is executable"

if [[ ! -f "$DEFAULT_DICT" ]]; then
  fail "default dict not found: $DEFAULT_DICT"
  echo "PASS=$PASS FAIL=$FAIL"
  exit 1
fi
pass "default dict exists at .claude/rules/client-redaction.yaml"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/test-redact-by-dict.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

# ============================================================
# Case 1: 0 hits (no match, original text unchanged, no stderr)
# ============================================================

DICT1="$TMP_DIR/dict1-with-clients.yaml"
cat > "$DICT1" <<'YAML'
schema_version: client-redaction.v1
clients:
  - rule_id: c-001
    name: NoraiCorp
    replace_with: "[Client_A]"
people: []
domains: []
YAML

OUTPUT="$(bash "$SCRIPT" --input "completely unrelated text" --dict "$DICT1" 2>"$TMP_DIR/c1-stderr.txt")"
if [[ "$OUTPUT" == "completely unrelated text" ]]; then
  pass "Case 1 (no hit): stdout = original text"
else
  fail "Case 1 (no hit): stdout != original. got: $OUTPUT"
fi

if [[ ! -s "$TMP_DIR/c1-stderr.txt" ]]; then
  pass "Case 1 (no hit): stderr is empty"
else
  fail "Case 1 (no hit): stderr should be empty. got: $(cat "$TMP_DIR/c1-stderr.txt")"
fi

# ============================================================
# Case 2: 1 hit (NoraiCorp appears once)
# ============================================================

OUTPUT="$(bash "$SCRIPT" --input "NoraiCorp partnership story" --dict "$DICT1" 2>"$TMP_DIR/c2-stderr.txt")"
if [[ "$OUTPUT" == "[Client_A] partnership story" ]]; then
  pass "Case 2 (1 hit): NoraiCorp → [Client_A]"
else
  fail "Case 2 (1 hit): unexpected output. got: $OUTPUT"
fi

if grep -q "redacted: 1 tokens" "$TMP_DIR/c2-stderr.txt"; then
  pass "Case 2 (1 hit): stderr contains 'redacted: 1 tokens'"
else
  fail "Case 2 (1 hit): stderr missing count. got: $(cat "$TMP_DIR/c2-stderr.txt")"
fi

# ============================================================
# Case 3: multiple hits (NoraiCorp appears 3 times)
# ============================================================

OUTPUT="$(bash "$SCRIPT" --input "NoraiCorp and NoraiCorp and NoraiCorp collaborate" --dict "$DICT1" 2>"$TMP_DIR/c3-stderr.txt")"
if [[ "$OUTPUT" == "[Client_A] and [Client_A] and [Client_A] collaborate" ]]; then
  pass "Case 3 (3 hits): all 3 NoraiCorp replaced"
else
  fail "Case 3 (3 hits): unexpected output. got: $OUTPUT"
fi

if grep -q "redacted: 3 tokens" "$TMP_DIR/c3-stderr.txt"; then
  pass "Case 3 (3 hits): stderr count = 3"
else
  fail "Case 3 (3 hits): stderr count wrong. got: $(cat "$TMP_DIR/c3-stderr.txt")"
fi

# ============================================================
# Case 4: aliases hit (both main name and alias use same replace)
# ============================================================

DICT4="$TMP_DIR/dict4-aliases.yaml"
cat > "$DICT4" <<'YAML'
schema_version: client-redaction.v1
clients: []
people:
  - rule_id: p-001
    name: 田中太郎
    aliases:
      - 田中
      - Mr. Tanaka
    replace_with: "[Person_A]"
domains: []
YAML

# Main name hit
OUTPUT="$(bash "$SCRIPT" --input "田中太郎が来ました" --dict "$DICT4" 2>"$TMP_DIR/c4a-stderr.txt")"
if [[ "$OUTPUT" == "[Person_A]が来ました" ]]; then
  pass "Case 4-a (main name): 田中太郎 → [Person_A]"
else
  fail "Case 4-a (main name): unexpected output. got: $OUTPUT"
fi

# Alias hit (田中)
OUTPUT="$(bash "$SCRIPT" --input "田中だけ来ました" --dict "$DICT4" 2>"$TMP_DIR/c4b-stderr.txt")"
if [[ "$OUTPUT" == "[Person_A]だけ来ました" ]]; then
  pass "Case 4-b (alias 田中): 田中 → [Person_A]"
else
  fail "Case 4-b (alias 田中): unexpected output. got: $OUTPUT"
fi

# Alias hit (Mr. Tanaka)
OUTPUT="$(bash "$SCRIPT" --input "Mr. Tanaka came" --dict "$DICT4" 2>"$TMP_DIR/c4c-stderr.txt")"
if [[ "$OUTPUT" == "[Person_A] came" ]]; then
  pass "Case 4-c (alias Mr. Tanaka): replaced"
else
  fail "Case 4-c (alias Mr. Tanaka): unexpected output. got: $OUTPUT"
fi

# Mixed main name + alias: "田中太郎と田中" (length DESC sort processes 田中太郎 first)
OUTPUT="$(bash "$SCRIPT" --input "田中太郎と田中が話した" --dict "$DICT4" 2>"$TMP_DIR/c4d-stderr.txt")"
if [[ "$OUTPUT" == "[Person_A]と[Person_A]が話した" ]]; then
  pass "Case 4-d (mixed name + alias): both → [Person_A]"
else
  fail "Case 4-d (mixed): unexpected output. got: $OUTPUT"
fi

if grep -q "redacted: 2 tokens" "$TMP_DIR/c4d-stderr.txt"; then
  pass "Case 4-d: stderr count = 2"
else
  fail "Case 4-d: stderr count wrong. got: $(cat "$TMP_DIR/c4d-stderr.txt")"
fi

# ============================================================
# Case 5: duplicate redact_as (multiple entries with same replace_with)
# ============================================================

DICT5="$TMP_DIR/dict5-duplicate-replace.yaml"
cat > "$DICT5" <<'YAML'
schema_version: client-redaction.v1
clients:
  - rule_id: c-001
    name: NoraiCorp
    replace_with: "[Client_X]"
  - rule_id: c-002
    name: YorozuPro
    replace_with: "[Client_X]"
people: []
domains: []
YAML

OUTPUT="$(bash "$SCRIPT" --input "NoraiCorp and YorozuPro compete" --dict "$DICT5" 2>"$TMP_DIR/c5-stderr.txt")"
if [[ "$OUTPUT" == "[Client_X] and [Client_X] compete" ]]; then
  pass "Case 5 (duplicate replace_with): both → [Client_X]"
else
  fail "Case 5: unexpected output. got: $OUTPUT"
fi

if grep -q "redacted: 2 tokens" "$TMP_DIR/c5-stderr.txt"; then
  pass "Case 5: stderr count = 2 (both entries hit)"
else
  fail "Case 5: stderr count wrong. got: $(cat "$TMP_DIR/c5-stderr.txt")"
fi

# ============================================================
# Case 6 (D43 decision 4): double-replacement guard — sentinel mark protection
# ============================================================

# 6-a: when existing [REDACTED_*] is in input, it is preserved
OUTPUT="$(bash "$SCRIPT" --input "Already [REDACTED_email] in text" --dict "$DICT1" 2>"$TMP_DIR/c6a-stderr.txt")"
if [[ "$OUTPUT" == "Already [REDACTED_email] in text" ]]; then
  pass "Case 6-a (sentinel guard): [REDACTED_email] preserved"
else
  fail "Case 6-a: sentinel was modified. got: $OUTPUT"
fi

# 6-b: mixed dict match and sentinel mark
#   "NoraiCorp and [Client_X] mixed" — NoraiCorp is redacted, [Client_X] is preserved
OUTPUT="$(bash "$SCRIPT" --input "NoraiCorp and [Client_X] mixed" --dict "$DICT1" 2>"$TMP_DIR/c6b-stderr.txt")"
if [[ "$OUTPUT" == "[Client_A] and [Client_X] mixed" ]]; then
  pass "Case 6-b (sentinel + dict mix): [Client_X] preserved, NoraiCorp redacted"
else
  fail "Case 6-b: unexpected output. got: $OUTPUT"
fi

if grep -q "redacted: 1 tokens" "$TMP_DIR/c6b-stderr.txt"; then
  pass "Case 6-b: stderr count = 1 (sentinel not counted)"
else
  fail "Case 6-b: count should be 1. got: $(cat "$TMP_DIR/c6b-stderr.txt")"
fi

# 6-c: [Entity], [Person_*], [Domain_*] are similarly protected
OUTPUT="$(bash "$SCRIPT" --input "[Entity] and [Person_A] and [Domain_X] appear" --dict "$DICT1" 2>"$TMP_DIR/c6c-stderr.txt")"
if [[ "$OUTPUT" == "[Entity] and [Person_A] and [Domain_X] appear" ]]; then
  pass "Case 6-c (multi sentinel): all preserved"
else
  fail "Case 6-c: unexpected output. got: $OUTPUT"
fi

# ============================================================
# Common: stdin mode
# ============================================================

OUTPUT="$(echo "NoraiCorp test" | bash "$SCRIPT" --stdin --dict "$DICT1" 2>"$TMP_DIR/stdin-stderr.txt")"
# echo appends trailing newline
if [[ "$OUTPUT" == "[Client_A] test" ]]; then
  pass "stdin mode: redacts correctly"
else
  fail "stdin mode: unexpected output. got: $OUTPUT"
fi

# ============================================================
# Common: default dict (empty SSOT) is still valid
# ============================================================

OUTPUT="$(bash "$SCRIPT" --input "default empty dict test" 2>"$TMP_DIR/default-stderr.txt")"
if [[ "$OUTPUT" == "default empty dict test" ]]; then
  pass "default dict (empty SSOT): no redaction"
else
  fail "default dict: unexpected output. got: $OUTPUT"
fi

# ============================================================
# Common: dict file not found → exit 1
# ============================================================

if bash "$SCRIPT" --input "x" --dict "/nonexistent/missing.yaml" >/dev/null 2>"$TMP_DIR/missing-stderr.txt"; then
  fail "missing dict: expected exit 1, got 0"
else
  pass "missing dict: exit 1 as expected"
fi

if grep -q "dict file not found" "$TMP_DIR/missing-stderr.txt"; then
  pass "missing dict: stderr contains 'dict file not found'"
else
  fail "missing dict: stderr missing expected text"
fi

# ============================================================
# Common: schema_version mismatch → exit 1
# ============================================================

DICT_BAD="$TMP_DIR/bad-schema.yaml"
cat > "$DICT_BAD" <<'YAML'
schema_version: client-redaction.v999
clients: []
people: []
domains: []
YAML

if bash "$SCRIPT" --input "x" --dict "$DICT_BAD" >/dev/null 2>"$TMP_DIR/badschema-stderr.txt"; then
  fail "wrong schema_version: expected exit 1, got 0"
else
  pass "wrong schema_version: exit 1 as expected"
fi

# ============================================================
# Common: duplicate rule_id → exit 1
# ============================================================

DICT_DUP="$TMP_DIR/dup-rule-id.yaml"
cat > "$DICT_DUP" <<'YAML'
schema_version: client-redaction.v1
clients:
  - rule_id: dup-001
    name: A
    replace_with: "[A]"
people:
  - rule_id: dup-001
    name: B
    replace_with: "[B]"
domains: []
YAML

if bash "$SCRIPT" --input "x" --dict "$DICT_DUP" >/dev/null 2>"$TMP_DIR/dup-stderr.txt"; then
  fail "duplicate rule_id: expected exit 1, got 0"
else
  pass "duplicate rule_id: exit 1 as expected"
fi

if grep -q "duplicate rule_id" "$TMP_DIR/dup-stderr.txt"; then
  pass "duplicate rule_id: stderr contains 'duplicate rule_id'"
else
  fail "duplicate rule_id: stderr missing expected text"
fi

# ============================================================
# Result
# ============================================================

echo ""
echo "============================================================"
echo "Test Summary (test-redact-by-dictionary.sh)"
echo "============================================================"
echo "PASS: $PASS"
echo "FAIL: $FAIL"

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "Failed tests:"
  for msg in "${FAIL_MESSAGES[@]}"; do
    echo "  - $msg"
  done
  exit 1
fi

exit 0
