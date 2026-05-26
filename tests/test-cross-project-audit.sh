#!/bin/bash
# tests/test-cross-project-audit.sh
# Phase 65.3.6 - mechanical validation of cross-project audit log + HTML summary
#
# Validation cases (Plans.md §65.3.6 DoD e):
#   1. redaction 0    - clean text → audit line with dict:0, ner:0, passed:true
#   2. multiple redactions - dict + NER hit → audit line with non-zero counts, passed:true
#   3. final scan failure - residue detected → audit line with passed:false, HTML not generated
#
# Common validation:
#   (a) cross-project-audit-log.sh works standalone
#   (b) JSON Lines schema compliant (cross-project-audit.v1)
#   (c) raw query string not recorded (hash only)
#   (d) HTML footer shows "redacted: dict X items + NER Y items"
#   (e) without --audit-group, audit log is not appended

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

AUDIT_SCRIPT="$ROOT_DIR/scripts/cross-project-audit-log.sh"
RENDER_SCRIPT="$ROOT_DIR/scripts/render-html.sh"

PASS=0
FAIL=0
FAIL_MESSAGES=()

pass() { PASS=$((PASS + 1)); echo "✓ $1"; }
fail() { FAIL=$((FAIL + 1)); FAIL_MESSAGES+=("$1"); echo "✗ $1" >&2; }

if [[ ! -x "$AUDIT_SCRIPT" ]]; then
  fail "cross-project-audit-log.sh not executable"
  echo "PASS=$PASS FAIL=$FAIL"
  exit 1
fi
pass "cross-project-audit-log.sh exists and executable"

TOKENIZER_AVAILABLE="false"
if python3 -c "from fugashi import Tagger; Tagger()" 2>/dev/null; then
  TOKENIZER_AVAILABLE="true"
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/test-audit.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

HASH_OF() {
  printf '%s' "$1" | shasum -a 256 | awk '{print $1}'
}

# Common test dict (catches NoraiCorp)
DICT_TEST="$TMP_DIR/dict.yaml"
cat > "$DICT_TEST" <<'YAML'
schema_version: client-redaction.v1
clients:
  - rule_id: c-001
    name: NoraiCorp
    replace_with: "[Client_X]"
people: []
domains: []
YAML

# ============================================================
# Common (a)(b)(c): audit-log.sh standalone operation
# ============================================================

AUDIT1="$TMP_DIR/audit1.jsonl"
HASH1="$(HASH_OF "test-query-1")"
if bash "$AUDIT_SCRIPT" \
    --group "G1" --members "p1,p2,p3" \
    --query-hash "$HASH1" \
    --dict-count 2 --ner-count 1 \
    --passed-final-scan true \
    --out "$AUDIT1" 2>/dev/null; then
  pass "audit-log.sh: exit 0 with valid args"
else
  fail "audit-log.sh: unexpected exit"
fi

if [[ -f "$AUDIT1" ]] && [[ "$(wc -l < "$AUDIT1" | tr -d ' ')" == "1" ]]; then
  pass "audit-log.sh: 1 line appended"
else
  fail "audit-log.sh: expected 1 line, got $(wc -l < "$AUDIT1" 2>/dev/null || echo missing)"
fi

# JSON schema validation
LINE1="$(head -1 "$AUDIT1")"
if echo "$LINE1" | jq -e '.schema_version == "cross-project-audit.v1"' >/dev/null; then
  pass "audit-log.sh: schema_version = cross-project-audit.v1"
else
  fail "audit-log.sh: schema_version mismatch"
fi

if echo "$LINE1" | jq -e '.member_projects | length == 3' >/dev/null; then
  pass "audit-log.sh: member_projects array length = 3"
else
  fail "audit-log.sh: member_projects wrong length"
fi

if echo "$LINE1" | jq -e ".query_hash == \"$HASH1\"" >/dev/null; then
  pass "audit-log.sh: query_hash recorded as sha256"
else
  fail "audit-log.sh: query_hash mismatch"
fi

# verify raw query string not recorded: line must not contain "test-query-1"
if grep -q "test-query-1" "$AUDIT1"; then
  fail "audit-log.sh: raw query string leaked!"
else
  pass "audit-log.sh: raw query NOT recorded (hash only)"
fi

# 2nd append (verify append-only)
HASH2="$(HASH_OF "test-query-2")"
bash "$AUDIT_SCRIPT" \
  --group "G2" --members "p4" \
  --query-hash "$HASH2" \
  --dict-count 0 --ner-count 0 \
  --passed-final-scan true \
  --out "$AUDIT1" >/dev/null 2>&1

if [[ "$(wc -l < "$AUDIT1" | tr -d ' ')" == "2" ]]; then
  pass "audit-log.sh: append-only (2 lines after 2nd call)"
else
  fail "audit-log.sh: expected 2 lines, got $(wc -l < "$AUDIT1")"
fi

# ============================================================
# Case 1: redaction 0 — render-html.sh from clean data
# ============================================================

DATA1="$TMP_DIR/data1-clean.json"
cat > "$DATA1" <<'JSON'
{"title":"Hello clean text","sections":[{"name":"Foo"}]}
JSON

OUT1="$TMP_DIR/out1.html"
AUDIT_C1="$TMP_DIR/audit-c1.jsonl"
HASH_C1="$(HASH_OF "case-1")"

if bash "$RENDER_SCRIPT" --template test-fixture --data "$DATA1" --out "$OUT1" \
    --with-redaction \
    --audit-group "C1" --audit-members "p1" --audit-query-hash "$HASH_C1" 2>"$TMP_DIR/c1-stderr.txt"; then
  pass "Case 1 (redaction 0): exit 0"
else
  fail "Case 1: unexpected non-zero exit. stderr: $(cat "$TMP_DIR/c1-stderr.txt")"
fi

# Default audit log location
DEFAULT_AUDIT="$ROOT_DIR/.claude/state/audit/cross-project-search.jsonl"
if [[ -f "$DEFAULT_AUDIT" ]]; then
  LATEST_C1="$(tail -1 "$DEFAULT_AUDIT")"
  if echo "$LATEST_C1" | jq -e '.redaction_count.dict == 0 and .redaction_count.ner == 0' >/dev/null; then
    pass "Case 1: audit log shows dict:0, ner:0"
  else
    fail "Case 1: audit counts wrong. line: $LATEST_C1"
  fi
  if echo "$LATEST_C1" | jq -e '.output_passed_final_scan == true' >/dev/null; then
    pass "Case 1: passed_final_scan = true"
  else
    fail "Case 1: passed_final_scan != true"
  fi
else
  fail "Case 1: audit log not found at $DEFAULT_AUDIT"
fi

# HTML footer
if grep -q 'redacted: dict 0 件 + NER 0 件' "$OUT1"; then
  pass "Case 1: HTML footer 'redacted: dict 0 件 + NER 0 件' present"
else
  fail "Case 1: HTML footer missing or wrong content"
fi

# ============================================================
# Case 2: multiple redactions — dict + NER hit
# ============================================================

if [[ "$TOKENIZER_AVAILABLE" == "true" ]]; then
  DATA2="$TMP_DIR/data2-multi-hit.json"
  cat > "$DATA2" <<'JSON'
{"title":"NoraiCorp and Tanaka Taro in a meeting","sections":[{"name":"Foo"}]}
JSON

  OUT2="$TMP_DIR/out2.html"
  HASH_C2="$(HASH_OF "case-2")"

  if bash "$RENDER_SCRIPT" --template test-fixture --data "$DATA2" --out "$OUT2" \
      --with-redaction --client-dict "$DICT_TEST" \
      --audit-group "C2" --audit-members "p1,p2" --audit-query-hash "$HASH_C2" 2>"$TMP_DIR/c2-stderr.txt"; then
    pass "Case 2 (multiple redactions): exit 0"
  else
    fail "Case 2: unexpected non-zero exit. stderr: $(cat "$TMP_DIR/c2-stderr.txt")"
  fi

  LATEST_C2="$(tail -1 "$DEFAULT_AUDIT")"
  if echo "$LATEST_C2" | jq -e '.redaction_count.dict > 0' >/dev/null; then
    pass "Case 2: audit log shows dict count > 0"
  else
    fail "Case 2: dict count = 0 (expected > 0). line: $LATEST_C2"
  fi
  if echo "$LATEST_C2" | jq -e '.redaction_count.ner > 0' >/dev/null; then
    pass "Case 2: audit log shows ner count > 0"
  else
    fail "Case 2: ner count = 0 (expected > 0). line: $LATEST_C2"
  fi

  # HTML footer
  if grep -q 'redacted: dict' "$OUT2" && grep -q 'NER' "$OUT2"; then
    pass "Case 2: HTML footer present"
  else
    fail "Case 2: HTML footer missing"
  fi
else
  pass "Case 2 (multiple redactions): SKIPPED (tokenizer unavailable)"
  pass "Case 2 dict count: SKIPPED"
  pass "Case 2 ner count: SKIPPED"
  pass "Case 2 footer: SKIPPED"
fi

# ============================================================
# Case 3: final scan failure — residue → exit 1, audit line passed:false
# ============================================================

DATA3="$TMP_DIR/data3-final-scan-fail.json"
cat > "$DATA3" <<'JSON'
{"title":"project main board feedback","sections":[{"name":"Foo"}]}
JSON

OUT3="$TMP_DIR/out3.html"
HASH_C3="$(HASH_OF "case-3")"

if bash "$RENDER_SCRIPT" --template test-fixture --data "$DATA3" --out "$OUT3" \
    --with-redaction \
    --audit-group "C3" --audit-members "p1" --audit-query-hash "$HASH_C3" 2>"$TMP_DIR/c3-stderr.txt"; then
  fail "Case 3: expected exit 1 (final scan failure), got 0"
else
  pass "Case 3 (final scan failure): exit 1 as expected"
fi

if [[ ! -f "$OUT3" ]]; then
  pass "Case 3: HTML NOT created (fail-safe)"
else
  fail "Case 3: HTML should not exist after final scan fail"
fi

# verify audit log records failure
LATEST_C3="$(tail -1 "$DEFAULT_AUDIT")"
if echo "$LATEST_C3" | jq -e '.output_passed_final_scan == false' >/dev/null; then
  pass "Case 3: audit log passed_final_scan = false"
else
  fail "Case 3: audit log should have passed=false. line: $LATEST_C3"
fi

# ============================================================
# Common (e): without --audit-group, audit log is not appended
# ============================================================

PRE_LINE_COUNT="$(wc -l < "$DEFAULT_AUDIT" | tr -d ' ')"

OUT4="$TMP_DIR/out4.html"
bash "$RENDER_SCRIPT" --template test-fixture --data "$DATA1" --out "$OUT4" --with-redaction 2>/dev/null

POST_LINE_COUNT="$(wc -l < "$DEFAULT_AUDIT" | tr -d ' ')"

if [[ "$PRE_LINE_COUNT" == "$POST_LINE_COUNT" ]]; then
  pass "no --audit-group: audit log NOT appended ($PRE_LINE_COUNT → $POST_LINE_COUNT)"
else
  fail "no --audit-group: audit log was appended ($PRE_LINE_COUNT → $POST_LINE_COUNT)"
fi

# ============================================================
# Common: schema validation - all lines must be schema compliant
# ============================================================

ALL_VALID="true"
while IFS= read -r line; do
  if ! echo "$line" | jq -e '
    .schema_version == "cross-project-audit.v1" and
    (.timestamp | type == "string") and
    (.group_name | type == "string") and
    (.member_projects | type == "array") and
    (.query_hash | test("^[0-9a-f]{64}$")) and
    (.redaction_count.dict | type == "number") and
    (.redaction_count.ner | type == "number") and
    (.output_passed_final_scan | type == "boolean")
  ' >/dev/null 2>&1; then
    ALL_VALID="false"
    break
  fi
done < "$DEFAULT_AUDIT"

if [[ "$ALL_VALID" == "true" ]]; then
  pass "all audit log lines pass cross-project-audit.v1 schema"
else
  fail "schema validation failed for some line"
fi

# ============================================================
# Result
# ============================================================

echo ""
echo "============================================================"
echo "Test Summary (test-cross-project-audit.sh)"
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
