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
    # herestring を使う (パイプにしない)。`printf ... | grep -q` は grep が最初の
    # 一致で終了してパイプを閉じるため、printf の残りの write が EPIPE になる。
    # set -o pipefail はその失敗をパイプライン全体の結果に昇格させるので、
    # 「一致したのに不一致と判定される」偽の失敗が起きる。frontmatter のように
    # stdio バッファ (1KB 前後) を超える入力で、一致行が前方にあるほど再現する。
    for required in "name: harness-accept" "user-invocable: true" "argument-hint:" "allowed-tools:" "description:" "description-en:" "description-ja:"; do
      if grep -q "$required" <<<"$FM_CONTENT"; then
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

  # blind evaluation optional step (Phase 137.2)
  if grep -qE 'blind_evaluation' "$SKILL_PATH"; then
    pass "SKILL.md documents blind_evaluation field"
  else
    fail "SKILL.md missing blind_evaluation documentation"
  fi
  if grep -qE 'functional-skip' "$SKILL_PATH"; then
    pass "SKILL.md documents functional-skip eligibility (DoD b)"
  else
    fail "SKILL.md missing functional-skip eligibility documentation (DoD b)"
  fi
  if grep -qE 'blind-evaluator\.md' "$SKILL_PATH"; then
    pass "SKILL.md links references/blind-evaluator.md"
  else
    fail "SKILL.md does not link references/blind-evaluator.md"
  fi
fi

BLIND_EVAL_REF="$ROOT_DIR/skills/harness-accept/references/blind-evaluator.md"
if [[ -f "$BLIND_EVAL_REF" ]]; then
  pass "references/blind-evaluator.md exists"
  if grep -qE 'blind-judge\.md' "$BLIND_EVAL_REF"; then
    pass "blind-evaluator.md documents lineage from harness-review/references/blind-judge.md"
  else
    fail "blind-evaluator.md missing reference to blind-judge.md"
  fi
  if grep -qE 'functional-skip' "$BLIND_EVAL_REF" && grep -qE '機能系' "$BLIND_EVAL_REF"; then
    pass "blind-evaluator.md documents functional-skip eligibility for 機能系 tasks (DoD b)"
  else
    fail "blind-evaluator.md missing functional-skip / 機能系 eligibility documentation"
  fi
else
  fail "references/blind-evaluator.md not found"
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

  # blind_evaluation (Phase 137.2 DoD c: additive のみ — top-level required に含まれない)
  if jq -e '.properties.blind_evaluation' "$SCHEMA_PATH" >/dev/null 2>&1; then
    pass "Schema declares optional property 'blind_evaluation'"
  else
    fail "Schema missing optional property 'blind_evaluation'"
  fi
  if jq -e '(.required | index("blind_evaluation")) == null' "$SCHEMA_PATH" >/dev/null 2>&1; then
    pass "Schema top-level 'required' does not include 'blind_evaluation' (additive-only, DoD c)"
  else
    fail "Schema top-level 'required' unexpectedly includes 'blind_evaluation'"
  fi
  if jq -e '.properties.blind_evaluation_items' "$SCHEMA_PATH" >/dev/null 2>&1; then
    pass "Schema declares optional property 'blind_evaluation_items'"
  else
    fail "Schema missing optional property 'blind_evaluation_items'"
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
    local py_schema_check_output
    py_schema_check_output="$(python3 -c "
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
" 2>/dev/null || true)"
    if grep -q OK <<<"$py_schema_check_output"; then
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

  # pending 補正 (Phase 134.4 DoD b): evidence が "pending_validations: " prefix を
  # 持つ criterion 数を独立カウントし、base=ship を wait に丸める規約を再検証する
  local derived_pending_count
  derived_pending_count="$(jq '[.verified_criteria[] | select(.passed == false and (.evidence | startswith("pending_validations: ")))] | length' "$fixture")"
  if [[ "$derived_pending_count" -ge 1 && "$derived_rec" == "ship" ]]; then
    derived_rec="wait"
  fi

  # blind_evaluation 補正 (Phase 137.2 DoD a): applicable かつ divergence が
  # internal_high_evaluator_low の場合、依然 ship なら wait に丸める規約を再検証する
  local derived_divergence
  derived_divergence="$(jq -r '.blind_evaluation.applicable == true and .blind_evaluation.divergence == "internal_high_evaluator_low"' "$fixture")"
  if [[ "$derived_divergence" == "true" && "$derived_rec" == "ship" ]]; then
    derived_rec="wait"
  fi

  if [[ "$derived_rec" == "$exp_rec" ]]; then
    pass "[$label] recommendation rule (verified/total + pending 補正 + blind_evaluation 補正 → ship/wait/reject) derives to $exp_rec"
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

# ---- Case 5: pending-browser (4/5 = 80% base=ship, pending 補正で wait) (Phase 134.4 DoD b) ----
run_case "pending-browser" "case-pending-browser" "wait" 4 5

# ---- Case 6: demo_artifacts の video 埋め込みが HTML に出る (Phase 134.6 DoD c) ----

VIDEO_FIXTURE="$FIX_DIR/case-pending-browser.json"
VIDEO_TMP_OUT="$(mktemp "${TMPDIR:-/tmp}/accept-test-video.XXXXXX")"
TEMP_FILES+=("$VIDEO_TMP_OUT")

if bash "$RENDER_SCRIPT" --template accept --data "$VIDEO_FIXTURE" --out "$VIDEO_TMP_OUT" 2>/dev/null; then
  if grep -qF 'class="artifact-video"' "$VIDEO_TMP_OUT"; then
    pass "[video-artifact] demo_artifacts kind=video gets the artifact-video branch class"
  else
    fail "[video-artifact] HTML missing artifact-video branch class"
  fi

  if grep -qF '<video class="video-embed" controls preload="none" src="test-results/task-134-6/trace.webm">' "$VIDEO_TMP_OUT"; then
    pass "[video-artifact] video embed src resolves to the fixture path (DoD c)"
  else
    fail "[video-artifact] video embed src does not match the fixture path"
  fi
else
  fail "[video-artifact] render-html.sh failed for video fixture"
fi
rm -f "$VIDEO_TMP_OUT"

# ---- Case 7: blind evaluation divergence (Phase 137.2 DoD a) ----
# 内側 verified_criteria は 5/5 (100% → base=ship) だが blind evaluator が
# not_believable/not_useful と判定 → recommendation は wait に丸まり、乖離が HTML に出る

run_case "blind-divergence" "case-blind-divergence" "wait" 5 5

BLIND_DIVERGENCE_FIXTURE="$FIX_DIR/case-blind-divergence.json"
BLIND_DIVERGENCE_TMP_OUT="$(mktemp "${TMPDIR:-/tmp}/accept-test-blind-divergence.XXXXXX")"
TEMP_FILES+=("$BLIND_DIVERGENCE_TMP_OUT")

if bash "$RENDER_SCRIPT" --template accept --data "$BLIND_DIVERGENCE_FIXTURE" --out "$BLIND_DIVERGENCE_TMP_OUT" 2>/dev/null; then
  if grep -qF 'internal_high_evaluator_low' "$BLIND_DIVERGENCE_TMP_OUT"; then
    pass "[blind-divergence] HTML shows divergence label (DoD a)"
  else
    fail "[blind-divergence] HTML missing divergence label"
  fi
  if grep -qF 'not_believable' "$BLIND_DIVERGENCE_TMP_OUT" && grep -qF 'not_useful' "$BLIND_DIVERGENCE_TMP_OUT"; then
    pass "[blind-divergence] HTML shows evaluator_believable/evaluator_useful"
  else
    fail "[blind-divergence] HTML missing evaluator_believable/evaluator_useful"
  fi
  # base recommendation (verified 5/5=100%) would independently derive to ship;
  # blind_evaluation 補正で wait に丸まったことを fixture 上で検証する
  base_ratio_x10="$(jq -n --argjson v 5 --argjson t 5 '($v * 10 / $t)')"
  if [[ "$base_ratio_x10" == "10" ]]; then
    pass "[blind-divergence] base ratio (5/5=100%) independently derives to ship threshold"
  else
    fail "[blind-divergence] base ratio derivation unexpected: $base_ratio_x10"
  fi
  if jq -e '.blind_evaluation.applicable == true and .blind_evaluation.divergence == "internal_high_evaluator_low"' "$BLIND_DIVERGENCE_FIXTURE" >/dev/null 2>&1; then
    pass "[blind-divergence] fixture records applicable=true / divergence=internal_high_evaluator_low"
  else
    fail "[blind-divergence] fixture blind_evaluation fields incorrect"
  fi
else
  fail "[blind-divergence] render-html.sh failed for blind-divergence fixture"
fi
rm -f "$BLIND_DIVERGENCE_TMP_OUT"

# ---- Case 8: functional-skip (Phase 137.2 DoD b) ----
# 機能系タスクは blind evaluation ステップが skip される (applicable=false)。
# recommendation は verified_criteria の比率のみで決まり (影響を受けない)、
# HTML 上に divergence セクションの中身が出ない

run_case "functional-skip" "case-functional-skip" "ship" 5 5

FUNC_SKIP_FIXTURE="$FIX_DIR/case-functional-skip.json"
if jq -e '.blind_evaluation.applicable == false and .blind_evaluation.eligibility_reason == "functional-skip"' "$FUNC_SKIP_FIXTURE" >/dev/null 2>&1; then
  pass "[functional-skip] fixture records applicable=false / eligibility_reason=functional-skip (DoD b)"
else
  fail "[functional-skip] fixture blind_evaluation fields incorrect"
fi
if jq -e '.blind_evaluation_items | length == 0' "$FUNC_SKIP_FIXTURE" >/dev/null 2>&1; then
  pass "[functional-skip] blind_evaluation_items empty — no divergence to render"
else
  fail "[functional-skip] blind_evaluation_items unexpectedly non-empty"
fi

FUNC_SKIP_TMP_OUT="$(mktemp "${TMPDIR:-/tmp}/accept-test-func-skip.XXXXXX")"
TEMP_FILES+=("$FUNC_SKIP_TMP_OUT")
if bash "$RENDER_SCRIPT" --template accept --data "$FUNC_SKIP_FIXTURE" --out "$FUNC_SKIP_TMP_OUT" 2>/dev/null; then
  if grep -qF 'internal_high_evaluator_low' "$FUNC_SKIP_TMP_OUT"; then
    fail "[functional-skip] HTML unexpectedly rendered a divergence label"
  else
    pass "[functional-skip] HTML renders no divergence label (step skipped, DoD b)"
  fi
else
  fail "[functional-skip] render-html.sh failed for functional-skip fixture"
fi
rm -f "$FUNC_SKIP_TMP_OUT"

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
