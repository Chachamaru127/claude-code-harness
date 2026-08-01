#!/bin/bash
# tests/test-plan-brief-record.sh
# Phase 65.1.4 - plan-brief-record-decision.sh の機械検証
#
# 検証ケース (DoD c に対応):
#   1. action=approve   - chosen_option + rejected_options が data に入る
#   2. action=revise    - reasoning が data に入る
#   3. action=question  - reasoning が data に入る (chosen は空)
#
# 共通検証:
#   (a) --action / --user-request / --project 必須
#   (b) tags = ["personal-preference", "plan-brief-approval"] 固定 (DoD b)
#   (c) data.user_request_hash が sha256 hex (64 chars)
#   (d) data.action が approve/revise/question のいずれか
#   (e) schema = "personal-preference.v1"
#   (f) observation_type = "decision"

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SCRIPT="$ROOT_DIR/scripts/plan-brief-record-decision.sh"

PASS=0
FAIL=0
FAIL_MESSAGES=()

pass() { PASS=$((PASS + 1)); echo "✓ $1"; }
fail() { FAIL=$((FAIL + 1)); FAIL_MESSAGES+=("$1"); echo "✗ $1" >&2; }

# ---- pre-checks ----

if [[ ! -x "$SCRIPT" ]]; then
  fail "plan-brief-record-decision.sh not executable: $SCRIPT"
  echo "PASS=$PASS FAIL=$FAIL"
  exit 1
fi
pass "plan-brief-record-decision.sh exists and is executable"

# ---- (a) 必須引数 ----

set +e
bash "$SCRIPT" 2>/dev/null
exit_code=$?
set -e
if [[ "$exit_code" -eq 2 ]]; then
  pass "Script exits 2 with no args"
else
  fail "Script should exit 2 with no args (got $exit_code)"
fi

set +e
bash "$SCRIPT" --action approve 2>/dev/null
exit_code=$?
set -e
if [[ "$exit_code" -eq 2 ]]; then
  pass "Script exits 2 when --user-request and --project missing"
else
  fail "Script should exit 2 when args missing (got $exit_code)"
fi

set +e
bash "$SCRIPT" --action wrong --user-request "x" --project "y" 2>/dev/null
exit_code=$?
set -e
if [[ "$exit_code" -eq 2 ]]; then
  pass "Script exits 2 with invalid --action value"
else
  fail "Script should exit 2 with invalid action (got $exit_code)"
fi

# ---- ヘルパー: 1 ケース実行 ----

run_action_case() {
  local label="$1"
  local action="$2"
  shift 2
  local extra_args=("$@")

  local out
  out="$(bash "$SCRIPT" \
    --action "$action" \
    --user-request "Plan Brief 機能を実装したい" \
    --project "demo-project" \
    "${extra_args[@]}" 2>&1)" || {
    fail "[$label] script failed: $out"
    return
  }

  # JSON parse
  if printf '%s' "$out" | jq -e '.' >/dev/null 2>&1; then
    pass "[$label] output is valid JSON"
  else
    fail "[$label] output is not valid JSON: $out"
    return
  fi

  # schema
  local schema
  schema="$(printf '%s' "$out" | jq -r '.schema')"
  if [[ "$schema" == "personal-preference.v1" ]]; then
    pass "[$label] schema = personal-preference.v1"
  else
    fail "[$label] schema mismatch: $schema"
  fi

  # observation_type
  local obs_type
  obs_type="$(printf '%s' "$out" | jq -r '.observation_type')"
  if [[ "$obs_type" == "decision" ]]; then
    pass "[$label] observation_type = decision"
  else
    fail "[$label] observation_type mismatch: $obs_type"
  fi

  # tags fixed (DoD b)
  local tags_count
  tags_count="$(printf '%s' "$out" | jq -r '.tags | length')"
  if [[ "$tags_count" -eq 2 ]]; then
    pass "[$label] tags has exactly 2 entries"
  else
    fail "[$label] tags count: got $tags_count, expected 2"
  fi

  if printf '%s' "$out" | jq -e '.tags | index("personal-preference")' >/dev/null 2>&1; then
    pass "[$label] tags includes 'personal-preference'"
  else
    fail "[$label] tags missing 'personal-preference'"
  fi

  if printf '%s' "$out" | jq -e '.tags | index("plan-brief-approval")' >/dev/null 2>&1; then
    pass "[$label] tags includes 'plan-brief-approval'"
  else
    fail "[$label] tags missing 'plan-brief-approval'"
  fi

  # data.user_request_hash is sha256 hex (64 chars, [0-9a-f])
  local hash
  hash="$(printf '%s' "$out" | jq -r '.data.user_request_hash')"
  if [[ "${#hash}" -eq 64 ]] && grep -qE '^[0-9a-f]{64}$' <<<"$hash"; then
    pass "[$label] data.user_request_hash is sha256 hex (64 chars)"
  else
    fail "[$label] data.user_request_hash invalid: '$hash' (length ${#hash})"
  fi

  # data.action matches
  local recorded_action
  recorded_action="$(printf '%s' "$out" | jq -r '.data.action')"
  if [[ "$recorded_action" == "$action" ]]; then
    pass "[$label] data.action = $action"
  else
    fail "[$label] data.action mismatch: got $recorded_action, expected $action"
  fi

  # data.timestamp is ISO8601 UTC
  local ts
  ts="$(printf '%s' "$out" | jq -r '.data.timestamp')"
  if grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' <<<"$ts"; then
    pass "[$label] data.timestamp is ISO8601 UTC"
  else
    fail "[$label] data.timestamp not ISO8601 UTC: $ts"
  fi

  # data.project propagates
  local proj
  proj="$(printf '%s' "$out" | jq -r '.data.project')"
  if [[ "$proj" == "demo-project" ]]; then
    pass "[$label] data.project = demo-project"
  else
    fail "[$label] data.project mismatch: $proj"
  fi
}

# ---- Case 1: approve with chosen_option + rejected_options ----
run_action_case "approve" "approve" \
  --chosen-option "Option A: Simple HTML" \
  --rejected-options "Option B: Heavy JS, Option C: PDF" \
  --reasoning "シンプルさ優先"

# Verify approve-specific fields
out_approve="$(bash "$SCRIPT" --action approve \
  --user-request "Plan Brief 機能を実装したい" --project "demo-project" \
  --chosen-option "Option A" --rejected-options "Option B, Option C" 2>/dev/null)"
chosen="$(printf '%s' "$out_approve" | jq -r '.data.chosen_option')"
rejected_count="$(printf '%s' "$out_approve" | jq -r '.data.rejected_options | length')"
if [[ "$chosen" == "Option A" ]]; then
  pass "[approve] chosen_option propagates"
else
  fail "[approve] chosen_option mismatch: $chosen"
fi
if [[ "$rejected_count" -eq 2 ]]; then
  pass "[approve] rejected_options csv splits to 2 entries"
else
  fail "[approve] rejected_options count: got $rejected_count, expected 2"
fi

# ---- Case 2: revise ----
run_action_case "revise" "revise" --reasoning "もっと簡潔にして"

out_revise="$(bash "$SCRIPT" --action revise \
  --user-request "test" --project "demo-project" \
  --reasoning "もっと簡潔にして" 2>/dev/null)"
revise_reasoning="$(printf '%s' "$out_revise" | jq -r '.data.reasoning')"
if [[ "$revise_reasoning" == "もっと簡潔にして" ]]; then
  pass "[revise] reasoning propagates"
else
  fail "[revise] reasoning mismatch: $revise_reasoning"
fi

# ---- Case 3: question ----
run_action_case "question" "question" --reasoning "Phase 65.3 と何が違いますか"

out_q="$(bash "$SCRIPT" --action question \
  --user-request "test" --project "demo-project" \
  --reasoning "Phase 65.3 と何が違いますか" 2>/dev/null)"
q_reasoning="$(printf '%s' "$out_q" | jq -r '.data.reasoning')"
q_chosen="$(printf '%s' "$out_q" | jq -r '.data.chosen_option')"
if [[ "$q_reasoning" == "Phase 65.3 と何が違いますか" ]]; then
  pass "[question] reasoning propagates"
else
  fail "[question] reasoning mismatch: $q_reasoning"
fi
if [[ "$q_chosen" == "" ]]; then
  pass "[question] chosen_option is empty"
else
  fail "[question] chosen_option should be empty: $q_chosen"
fi

# ---- Determinism: same input → same hash ----
out1="$(bash "$SCRIPT" --action approve \
  --user-request "deterministic test" --project "p" 2>/dev/null)"
out2="$(bash "$SCRIPT" --action approve \
  --user-request "deterministic test" --project "p" 2>/dev/null)"
hash1="$(printf '%s' "$out1" | jq -r '.data.user_request_hash')"
hash2="$(printf '%s' "$out2" | jq -r '.data.user_request_hash')"
if [[ "$hash1" == "$hash2" ]]; then
  pass "Same user_request produces same hash (deterministic)"
else
  fail "Hash not deterministic: $hash1 vs $hash2"
fi

# Different request → different hash
out3="$(bash "$SCRIPT" --action approve \
  --user-request "different test" --project "p" 2>/dev/null)"
hash3="$(printf '%s' "$out3" | jq -r '.data.user_request_hash')"
if [[ "$hash1" != "$hash3" ]]; then
  pass "Different user_request produces different hash"
else
  fail "Hash collision (unexpected): both $hash1"
fi

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
