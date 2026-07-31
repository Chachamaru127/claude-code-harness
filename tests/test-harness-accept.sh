#!/bin/bash
# tests/test-harness-accept.sh
# Phase 65.2.1 - harness-accept skill の機械検証
#
# 検証観点:
#   1. SKILL.md frontmatter (skill-editing.md 規約準拠)
#   2. SKILL.md の project enforcement / cross-project 禁止 / Plan Brief 連携記述
#   3. JSON Schema (acceptance-context.v1) の妥当性
#   4. 4 ケース fixture (DoD e):
#      - case-all-verified    : 5/5 = 100% → ship
#      - case-half-verified   : 3/5 = 60%  → wait
#      - case-all-unverified  : 0/5 = 0%   → reject
#      - case-zero-criteria   : 0/0        → reject (safe-side)
#   5. recommendation 算出ルール (DoD d) を 4 ケースで固定
#   6. evidence 空文字列 → HTML で警告表示 (DoD c)
#   7. HTML 生成 (template + render-html.sh) が成功

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SKILL_PATH="$ROOT_DIR/skills/harness-accept/SKILL.md"
SCHEMA_PATH="$ROOT_DIR/skills/harness-accept/schemas/acceptance-context.v1.schema.json"
TEMPLATE_PATH="$ROOT_DIR/templates/html/accept.html.template"
RENDER_SCRIPT="$ROOT_DIR/scripts/render-html.sh"
FIX_DIR="$ROOT_DIR/tests/fixtures/harness-accept"

PASS=0
FAIL=0
FAIL_MESSAGES=()

TEMP_FILES=()
cleanup_temp_files() {
  if [[ ${#TEMP_FILES[@]} -gt 0 ]]; then
    rm -f "${TEMP_FILES[@]}" 2>/dev/null || true
  fi
}
trap cleanup_temp_files EXIT

pass() { PASS=$((PASS + 1)); echo "✓ $1"; }
fail() { FAIL=$((FAIL + 1)); FAIL_MESSAGES+=("$1"); echo "✗ $1" >&2; }

# ---- 1. SKILL.md frontmatter ----

if [[ ! -f "$SKILL_PATH" ]]; then
  fail "SKILL.md not found: $SKILL_PATH"
else
  pass "SKILL.md exists"

  FM_END_LINE="$(awk '/^---$/{c++; if(c==2){print NR; exit}}' "$SKILL_PATH")"
  if [[ -z "$FM_END_LINE" ]]; then
    fail "SKILL.md frontmatter has no closing '---' marker"
  else
    FM_CONTENT="$(sed -n "1,${FM_END_LINE}p" "$SKILL_PATH")"
    for required in "name: harness-accept" "user-invocable: true" "argument-hint:" "allowed-tools:" "description:" "description-en:" "description-ja:"; do
      if printf '%s' "$FM_CONTENT" | grep -q "$required"; then
        pass "SKILL.md frontmatter has '$required'"
      else
        fail "SKILL.md frontmatter missing '$required'"
      fi
    done
  fi
fi

# ---- 2. SKILL.md instruction sanity ----

if [[ -f "$SKILL_PATH" ]]; then
  if grep -qE 'mcp__harness__harness_mem_search' "$SKILL_PATH"; then
    pass "SKILL.md references mcp__harness__harness_mem_search"
  else
    fail "SKILL.md does not reference mcp__harness__harness_mem_search (DoD b)"
  fi

  if grep -qE 'project: *<?PROJECT|basename.+git rev-parse' "$SKILL_PATH"; then
    pass "SKILL.md instructs project parameter enforcement"
  else
    fail "SKILL.md does not instruct project parameter enforcement"
  fi

  if grep -qE 'strict_project:[[:space:]]*true' "$SKILL_PATH"; then
    pass "SKILL.md instructs strict_project: true"
  else
    fail "SKILL.md does not instruct strict_project: true"
  fi

  # Plan Brief 連携 (DoD b)
  if grep -qE 'user_request_hash' "$SKILL_PATH" && grep -qE 'personal-preference\.v1|plan-brief-approval' "$SKILL_PATH"; then
    pass "SKILL.md documents Plan Brief join via user_request_hash + personal-preference.v1"
  else
    fail "SKILL.md missing Plan Brief join documentation (DoD b)"
  fi

  # cross-project 禁止 (Phase 65.3 まで保留)
  if grep -qE 'cross-project[^.]*(行わ|呼ばない|禁止|opt-in|Phase 65.3)' "$SKILL_PATH"; then
    pass "SKILL.md forbids cross-project explicitly"
  else
    fail "SKILL.md does not explicitly forbid cross-project"
  fi
fi

# ---- 3. JSON Schema validity ----

if [[ ! -f "$SCHEMA_PATH" ]]; then
  fail "JSON Schema not found: $SCHEMA_PATH"
else
  if jq -e '.' "$SCHEMA_PATH" >/dev/null 2>&1; then
    pass "JSON Schema is parseable"
  else
    fail "JSON Schema is not valid JSON"
  fi

  for req in "user_request" "user_request_hash" "demo_artifacts" "verified_criteria" "unverified_caveats" "past_issue_patterns" "recommendation" "recommendation_evidence" "project" "generated_at"; do
    if jq -e --arg k "$req" '.required | index($k)' "$SCHEMA_PATH" >/dev/null 2>&1; then
      pass "Schema requires field '$req'"
    else
      fail "Schema missing required field '$req'"
    fi
  done

  # recommendation enum
  if jq -e '.properties.recommendation.enum | (index("ship") and index("wait") and index("reject"))' "$SCHEMA_PATH" >/dev/null 2>&1; then
    pass "Schema recommendation enum is ship/wait/reject"
  else
    fail "Schema recommendation enum incorrect"
  fi

  # user_request_hash sha256 pattern
  if jq -e '.properties.user_request_hash.pattern == "^[0-9a-f]{64}$"' "$SCHEMA_PATH" >/dev/null 2>&1; then
    pass "Schema user_request_hash enforces sha256 hex pattern"
  else
    fail "Schema user_request_hash does not enforce sha256 pattern"
  fi
fi

# ---- ヘルパー: 4 ケース実行 ----
# 引数: <case_label> <fixture_basename> <expected_recommendation>
#       <expected_verified_count> <expected_total_count>

run_case() {
  local label="$1"
  local fixture_base="$2"
  local exp_rec="$3"
  local exp_verified="$4"
  local exp_total="$5"

  local fixture="$FIX_DIR/${fixture_base}.json"

  if [[ ! -f "$fixture" ]]; then
    fail "[$label] fixture missing: $fixture"
    return
  fi

  if jq -e '.' "$fixture" >/dev/null 2>&1; then
    pass "[$label] fixture is valid JSON"
  else
    fail "[$label] fixture is not valid JSON"
    return
  fi

  # Schema validate (Python jsonschema 優先)
  validated=0
  if command -v python3 >/dev/null 2>&1; then
    if python3 -c "
import json, sys
try: import jsonschema
except ImportError: sys.exit(2)
schema = json.load(open('$SCHEMA_PATH'))
data   = json.load(open('$fixture'))
try:
    jsonschema.validate(data, schema)
    print('OK')
except jsonschema.ValidationError as e:
    print(f'FAIL: {e.message}')
    sys.exit(1)
" 2>/dev/null | grep -q OK; then
      pass "[$label] fixture validates against schema (Python jsonschema)"
      validated=1
    fi
  fi
  if [[ "$validated" -eq 0 ]]; then
    if jq -e '.schema == "acceptance-context.v1"' "$fixture" >/dev/null 2>&1; then
      pass "[$label] fixture has acceptance-context.v1 schema (jq fallback)"
    else
      fail "[$label] fixture schema field mismatch"
    fi
  fi

  # recommendation match
  local actual_rec
  actual_rec="$(jq -r '.recommendation' "$fixture")"
  if [[ "$actual_rec" == "$exp_rec" ]]; then
    pass "[$label] recommendation = $exp_rec"
  else
    fail "[$label] recommendation mismatch: got $actual_rec, expected $exp_rec"
  fi

  # 算出ルール検証: verified count / total を独立計算して期待値と一致
  local actual_verified actual_total
  actual_verified="$(jq '[.verified_criteria[] | select(.passed == true)] | length' "$fixture")"
  actual_total="$(jq '.verified_criteria | length' "$fixture")"

  if [[ "$actual_verified" -eq "$exp_verified" ]]; then
    pass "[$label] verified count = $exp_verified"
  else
    fail "[$label] verified count: got $actual_verified, expected $exp_verified"
  fi

  if [[ "$actual_total" -eq "$exp_total" ]]; then
    pass "[$label] total criteria = $exp_total"
  else
    fail "[$label] total criteria: got $actual_total, expected $exp_total"
  fi

  # Recommendation rule independent re-derivation
  local derived_rec
  if [[ "$actual_total" -eq 0 ]]; then
    derived_rec="reject"
  else
    local ratio_x10
    ratio_x10=$((actual_verified * 10 / actual_total))
    if   [[ "$ratio_x10" -ge 8 ]]; then derived_rec="ship"
    elif [[ "$ratio_x10" -ge 5 ]]; then derived_rec="wait"
    else                                derived_rec="reject"
    fi
  fi
  if [[ "$derived_rec" == "$exp_rec" ]]; then
    pass "[$label] recommendation rule (verified/total → ship/wait/reject) derives to $exp_rec"
  else
    fail "[$label] recommendation rule derivation: got $derived_rec, expected $exp_rec"
  fi

  # HTML render check
  local tmp_out
  tmp_out="$(mktemp "${TMPDIR:-/tmp}/accept-test-${fixture_base}.XXXXXX")"
  TEMP_FILES+=("$tmp_out")

  if bash "$RENDER_SCRIPT" --template accept --data "$fixture" --out "$tmp_out" 2>/dev/null; then
    pass "[$label] render-html.sh succeeds with accept template"

    # All {{...}} resolved
    if grep -qE '\{\{[a-zA-Z]' "$tmp_out"; then
      fail "[$label] HTML contains unresolved {{...}} tags"
    else
      pass "[$label] all {{...}} tags resolved"
    fi

    # recommendation literal in HTML
    if grep -qE "verdict.*${exp_rec}|class=\"recommendation ${exp_rec}\"" "$tmp_out"; then
      pass "[$label] HTML carries recommendation '$exp_rec' literal"
    else
      fail "[$label] HTML does not carry recommendation literal '$exp_rec'"
    fi

    # DoD c: evidence='' triggers warning rendering
    local empty_evidence_count
    empty_evidence_count="$(jq '[.verified_criteria_items[] | select(.evidence_warn != "")] | length' "$fixture")"
    if [[ "$empty_evidence_count" -gt 0 ]]; then
      if grep -qF "⚠ evidence 未提示" "$tmp_out"; then
        pass "[$label] HTML shows evidence warning for empty evidence (DoD c)"
      else
        fail "[$label] HTML missing evidence warning text for $empty_evidence_count empty entries"
      fi
    else
      pass "[$label] no empty evidence entries — warning rendering not triggered (expected)"
    fi
  else
    fail "[$label] render-html.sh failed for accept template"
  fi
  rm -f "$tmp_out"
}

# ---- Case 1: all verified (5/5 = 100%) → ship ----
run_case "all-verified" "case-all-verified" "ship" 5 5

# ---- Case 2: half verified (3/5 = 60%) → wait ----
run_case "half-verified" "case-half-verified" "wait" 3 5

# ---- Case 3: all unverified (0/5 = 0%) → reject ----
run_case "all-unverified" "case-all-unverified" "reject" 0 5

# ---- Case 4: zero criteria (0/0) → reject (safe-side) ----
run_case "zero-criteria" "case-zero-criteria" "reject" 0 0

# ---- Summary ----

echo ""
echo "============================================"
echo "PASS=$PASS FAIL=$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "FAIL details:" >&2
  for msg in "${FAIL_MESSAGES[@]}"; do
    echo "  - $msg" >&2
  done
  exit 1
fi
echo "All assertions passed."
exit 0
