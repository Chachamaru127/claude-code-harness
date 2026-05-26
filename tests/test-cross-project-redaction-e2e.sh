#!/bin/bash
# tests/test-cross-project-redaction-e2e.sh
# Phase 65.3.7 - e2e validation of Cross-Project + 3-Layer Redaction
#
# Validation flow (Plans.md §65.3.7 DoD a-h):
#   (a) fixture group (3 member projects)
#   (b) embed proper nouns in observation-equivalent data for each member project
#   (c) verify generated HTML contains 0 occurrences of proper nouns
#       (NoraiCorp / YorozuPro / Tanaka / Sato) via grep
#   (d) audit log correctly records redaction counts
#   (e) (executed by separate script) validate-plugin.sh PASS
#   (f) (separate script) check-consistency.sh PASS
#   (g) embedding proper nouns in envelope (signals + prose) structure does
#       not break validateProseContainsSignals-equivalent consistency
#   (h) double-replacement guard for existing server-side [REDACTED_*] marks

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

LOADER="$ROOT_DIR/scripts/load-cross-project-groups.sh"
RENDER="$ROOT_DIR/scripts/render-html.sh"

PASS=0
FAIL=0
FAIL_MESSAGES=()

pass() { PASS=$((PASS + 1)); echo "✓ $1"; }
fail() { FAIL=$((FAIL + 1)); FAIL_MESSAGES+=("$1"); echo "✗ $1" >&2; }

TOKENIZER_AVAILABLE="false"
if python3 -c "from fugashi import Tagger; Tagger()" 2>/dev/null; then
  TOKENIZER_AVAILABLE="true"
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/test-redaction-e2e.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

# ============================================================
# (a) fixture group: 3 member projects
# ============================================================

GROUPS_YAML="$TMP_DIR/cross-project-groups.yaml"
cat > "$GROUPS_YAML" <<'YAML'
schema_version: cross-project-group.v1
groups:
  - name: TestE2E
    description: e2e validation group with 3 members
    members:
      - project-alpha
      - project-beta
      - project-gamma
YAML

MEMBERS_OUT="$(bash "$LOADER" --yaml "$GROUPS_YAML" --group "TestE2E" 2>/dev/null)"
if echo "$MEMBERS_OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if len(d)==3 else 1)"; then
  pass "(a) Fixture group resolves to 3 members"
else
  fail "(a) Fixture group resolution failed"
fi

# ============================================================
# (b) fixture client dict
# ============================================================

CLIENT_DICT="$TMP_DIR/client-redaction.yaml"
cat > "$CLIENT_DICT" <<'YAML'
schema_version: client-redaction.v1
clients:
  - rule_id: e2e-c-001
    name: NoraiCorp
    aliases:
      - Norai Corp
    replace_with: "[Client_E2E_A]"
  - rule_id: e2e-c-002
    name: YorozuPro
    replace_with: "[Client_E2E_B]"
people: []
domains: []
YAML

# ============================================================
# (b) merged Plan Brief data with proper nouns embedded
# (synthetic fixture simulating actual MCP search return values)
#
# Embedded proper nouns:
#   - NoraiCorp / YorozuPro (redacted via dict layer)
#   - Tanaka / Sato (redacted via NER layer, when fugashi is available)
#   - [REDACTED_email] (sentinel guard test, item h)
#   - signals/prose (envelope structure, item g)
# ============================================================

DATA_E2E="$TMP_DIR/e2e-data.json"
cat > "$DATA_E2E" <<'JSON'
{
  "title": "NoraiCorp and YorozuPro joint project in progress with Tanaka and Sato",
  "sections": [
    {"name": "Meeting notes with NoraiCorp"},
    {"name": "YorozuPro feedback: Tanaka checks with Sato"},
    {"name": "Already redacted: [REDACTED_email] is in input"},
    {"name": "envelope-signal: source=project-alpha, label=NoraiCorp"}
  ]
}
JSON

# ============================================================
# Execute render-html.sh --with-redaction (Layer 2/3)
# + audit log (--audit-group / --audit-members / --audit-query-hash)
# ============================================================

OUT_HTML="$TMP_DIR/e2e-output.html"
QUERY_HASH="$(printf 'e2e-cross-project-test' | shasum -a 256 | awk '{print $1}')"
MEMBERS_CSV="project-alpha,project-beta,project-gamma"

# Clean default audit log first
rm -f .claude/state/audit/cross-project-search.jsonl

if bash "$RENDER" \
    --template test-fixture \
    --data "$DATA_E2E" \
    --out "$OUT_HTML" \
    --with-redaction \
    --client-dict "$CLIENT_DICT" \
    --audit-group "TestE2E" \
    --audit-members "$MEMBERS_CSV" \
    --audit-query-hash "$QUERY_HASH" \
    2>"$TMP_DIR/render-stderr.txt"; then
  pass "render-html.sh exit 0 with full --with-redaction + audit"
else
  fail "render-html.sh failed. stderr: $(cat "$TMP_DIR/render-stderr.txt")"
fi

if [[ ! -f "$OUT_HTML" ]]; then
  fail "HTML output not generated"
  echo "PASS=$PASS FAIL=$FAIL"
  exit 1
fi
pass "HTML output generated successfully"

# ============================================================
# (c) Plans.md DoD: verify via grep that no proper nouns remain in generated HTML
# ============================================================

# Latin literals (covered by dict layer)
if grep -q -E "(NoraiCorp|YorozuPro)" "$OUT_HTML"; then
  fail "(c) Latin proper noun leaked: $(grep -E '(NoraiCorp|YorozuPro)' "$OUT_HTML" | head -1)"
else
  pass "(c) Latin proper nouns (NoraiCorp, YorozuPro) NOT in HTML (dict layer worked)"
fi

# Japanese names (covered by NER layer, tokenizer required)
if [[ "$TOKENIZER_AVAILABLE" == "true" ]]; then
  if grep -q -E "(Tanaka|Sato)" "$OUT_HTML"; then
    fail "(c) Japanese name leaked: $(grep -E '(Tanaka|Sato)' "$OUT_HTML" | head -1)"
  else
    pass "(c) Japanese names (Tanaka, Sato) NOT in HTML (NER layer worked)"
  fi
else
  pass "(c) Japanese names check: SKIPPED (tokenizer unavailable)"
fi

# Combined: the canonical Plans.md DoD command
if grep -q -E "(NoraiCorp|YorozuPro|Tanaka|Sato)" "$OUT_HTML"; then
  if [[ "$TOKENIZER_AVAILABLE" == "true" ]]; then
    fail "(c) Plans.md DoD grep: residue found"
  else
    pass "(c) Plans.md DoD grep: tokenizer unavailable (Latin checked, JP skipped)"
  fi
else
  pass "(c) Plans.md DoD grep -E '(NoraiCorp|YorozuPro|Tanaka|Sato)' returns 0 results"
fi

# ============================================================
# (d) audit log: counts recorded, passed=true, schema compliant
# ============================================================

DEFAULT_AUDIT="$ROOT_DIR/.claude/state/audit/cross-project-search.jsonl"
if [[ -f "$DEFAULT_AUDIT" ]]; then
  pass "(d) audit log file exists at default location"
else
  fail "(d) audit log not created"
fi

LATEST_LINE="$(tail -1 "$DEFAULT_AUDIT" 2>/dev/null || echo '{}')"

if echo "$LATEST_LINE" | jq -e '.schema_version == "cross-project-audit.v1"' >/dev/null 2>&1; then
  pass "(d) audit line schema = cross-project-audit.v1"
else
  fail "(d) audit line schema mismatch"
fi

if echo "$LATEST_LINE" | jq -e '.group_name == "TestE2E"' >/dev/null 2>&1; then
  pass "(d) audit line group_name = TestE2E"
else
  fail "(d) audit line group_name wrong"
fi

if echo "$LATEST_LINE" | jq -e '.member_projects | length == 3' >/dev/null 2>&1; then
  pass "(d) audit line records 3 member projects"
else
  fail "(d) audit line member_projects count wrong"
fi

if echo "$LATEST_LINE" | jq -e ".query_hash == \"$QUERY_HASH\"" >/dev/null 2>&1; then
  pass "(d) audit line query_hash matches"
else
  fail "(d) audit line query_hash mismatch"
fi

# raw query string 'e2e-cross-project-test' must not be recorded in audit (privacy)
if grep -q "e2e-cross-project-test" "$DEFAULT_AUDIT"; then
  fail "(d) RAW query string leaked in audit log!"
else
  pass "(d) audit log does NOT contain raw query string (privacy preserved)"
fi

# count: dict must be at least 1 (NoraiCorp/YorozuPro appear 4-5 times)
DICT_HIT="$(echo "$LATEST_LINE" | jq -r '.redaction_count.dict')"
if [[ "$DICT_HIT" -gt 0 ]]; then
  pass "(d) audit dict count > 0 (got: $DICT_HIT)"
else
  fail "(d) audit dict count = 0 (expected > 0). line: $LATEST_LINE"
fi

if [[ "$TOKENIZER_AVAILABLE" == "true" ]]; then
  NER_HIT="$(echo "$LATEST_LINE" | jq -r '.redaction_count.ner')"
  if [[ "$NER_HIT" -gt 0 ]]; then
    pass "(d) audit NER count > 0 (got: $NER_HIT)"
  else
    fail "(d) audit NER count = 0 (expected > 0). line: $LATEST_LINE"
  fi
else
  pass "(d) audit NER count check: SKIPPED"
fi

# passed_final_scan: true (would be false if any residue remained)
if echo "$LATEST_LINE" | jq -e '.output_passed_final_scan == true' >/dev/null 2>&1; then
  pass "(d) audit output_passed_final_scan = true"
else
  fail "(d) audit output_passed_final_scan != true"
fi

# ============================================================
# (g) envelope consistency: passing signals/prose structure through redaction
#     does not break invariants (verify that envelope-like section embedded
#     in test-fixture template is present)
# ============================================================

# After rendering, the "envelope-signal" label is preserved, but the Latin
# proper noun (NoraiCorp) inside it is redacted. This demonstrates that
# prose/signals consistency is maintained by replacing proper nouns with
# a common token.
if grep -q "envelope-signal" "$OUT_HTML"; then
  pass "(g) envelope-signal label preserved in output (structural label intact)"
else
  fail "(g) envelope-signal label lost"
fi

if grep -q "source=project-alpha" "$OUT_HTML"; then
  pass "(g) envelope source field preserved"
else
  fail "(g) envelope source field lost"
fi

# label=NoraiCorp is redacted to label=[Client_E2E_A] (dict layer)
if grep -q "label=\[Client_E2E_A\]" "$OUT_HTML"; then
  pass "(g) envelope label NoraiCorp → [Client_E2E_A] (signals consistent with prose redaction)"
else
  fail "(g) envelope label redaction did not propagate"
fi

# ============================================================
# (h) double-replacement guard: existing [REDACTED_email] mark is preserved
# ============================================================

if grep -q "\[REDACTED_email\]" "$OUT_HTML"; then
  pass "(h) [REDACTED_email] sentinel mark preserved (double-replacement guard active)"
else
  fail "(h) [REDACTED_email] was modified by Layer 2/3"
fi

# Plus dict-emitted [Client_E2E_A] / [Client_E2E_B] are sentinels for
# next-pass (idempotency)
if grep -q "\[Client_E2E_A\]" "$OUT_HTML"; then
  pass "(h) dict replacement [Client_E2E_A] present (and not re-replaced by NER)"
else
  fail "(h) dict replacement [Client_E2E_A] missing"
fi

# ============================================================
# Common: HTML footer must include audit summary
# ============================================================

if grep -q 'audit-summary' "$OUT_HTML" && grep -q 'redacted: dict' "$OUT_HTML"; then
  pass "HTML footer audit-summary present"
else
  fail "HTML footer audit-summary missing"
fi

# ============================================================
# Cleanup default audit (test isolation)
# ============================================================

rm -f .claude/state/audit/cross-project-search.jsonl

# ============================================================
# Result
# ============================================================

echo ""
echo "============================================================"
echo "Test Summary (test-cross-project-redaction-e2e.sh)"
echo "============================================================"
echo "PASS: $PASS"
echo "FAIL: $FAIL"
if [[ "$TOKENIZER_AVAILABLE" == "false" ]]; then
  echo "(NOTE: NER cases skipped — fugashi unavailable)"
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
