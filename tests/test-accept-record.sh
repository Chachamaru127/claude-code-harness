#!/bin/bash
# tests/test-accept-record.sh
# Phase 65.2.3 - mechanical validation of accept-record-decision.sh
#
# Validation cases (DoD d):
#   1. action=accept   - recommendation_taken=true, override_reason empty
#   2. action=override - recommendation_taken=false, override_reason required
#   3. action=reject   - recommendation_taken computed based on recommendation
#                        (true if rec=reject, false otherwise)
#
# Common validation:
#   (a) --action / --user-request / --project / --recommendation required
#   (b) tags = ["personal-preference", "acceptance-decision"] fixed
#   (c) data.user_request_hash is sha256 hex (64 chars)
#   (d) same user_request as Phase 65.1.4 plan-brief-record-decision.sh →
#       same user_request_hash (structural verification of DoD c "joinable")
#   (e) schema = "acceptance-decision.v1"
#   (f) override action requires override_reason (exit 2 if empty)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SCRIPT="$ROOT_DIR/scripts/accept-record-decision.sh"
PLAN_BRIEF_SCRIPT="$ROOT_DIR/scripts/plan-brief-record-decision.sh"

PASS=0
FAIL=0
FAIL_MESSAGES=()

pass() { PASS=$((PASS + 1)); echo "✓ $1"; }
fail() { FAIL=$((FAIL + 1)); FAIL_MESSAGES+=("$1"); echo "✗ $1" >&2; }

# ---- pre-checks ----

if [[ ! -x "$SCRIPT" ]]; then
  fail "accept-record-decision.sh not executable: $SCRIPT"
  echo "PASS=$PASS FAIL=$FAIL"
  exit 1
fi
pass "accept-record-decision.sh exists and is executable"

# ---- (a) required arguments ----

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
bash "$SCRIPT" --action accept --user-request "x" --project "p" 2>/dev/null
exit_code=$?
set -e
if [[ "$exit_code" -eq 2 ]]; then
  pass "Script exits 2 when --recommendation missing"
else
  fail "Script should exit 2 when --recommendation missing (got $exit_code)"
fi

set +e
bash "$SCRIPT" --action wrong --user-request "x" --project "p" --recommendation ship 2>/dev/null
exit_code=$?
set -e
if [[ "$exit_code" -eq 2 ]]; then
  pass "Script exits 2 with invalid --action"
else
  fail "Script should exit 2 with invalid action (got $exit_code)"
fi

set +e
bash "$SCRIPT" --action accept --user-request "x" --project "p" --recommendation invalid 2>/dev/null
exit_code=$?
set -e
if [[ "$exit_code" -eq 2 ]]; then
  pass "Script exits 2 with invalid --recommendation"
else
  fail "Script should exit 2 with invalid recommendation (got $exit_code)"
fi

# (f) override action requires --override-reason
set +e
bash "$SCRIPT" --action override --user-request "x" --project "p" --recommendation wait 2>/dev/null
exit_code=$?
set -e
if [[ "$exit_code" -eq 2 ]]; then
  pass "Script exits 2 when --action override but --override-reason missing"
else
  fail "Script should exit 2 when override missing reason (got $exit_code)"
fi

# ---- helper: run one case ----

run_action_case() {
  local label="$1"
  local action="$2"
  local rec="$3"
  local exp_taken="$4"  # "true" | "false"
  shift 4
  local extra_args=("$@")

  local out
  out="$(bash "$SCRIPT" \
    --action "$action" \
    --user-request "Plan Brief MVP acceptance" \
    --project "demo-project" \
    --recommendation "$rec" \
    ${extra_args[@]+"${extra_args[@]}"} 2>&1)" || {
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
  if [[ "$schema" == "acceptance-decision.v1" ]]; then
    pass "[$label] schema = acceptance-decision.v1"
  else
    fail "[$label] schema mismatch: $schema"
  fi

  # observation_type
  if [[ "$(printf '%s' "$out" | jq -r '.observation_type')" == "decision" ]]; then
    pass "[$label] observation_type = decision"
  else
    fail "[$label] observation_type mismatch"
  fi

  # tags fixed
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

  if printf '%s' "$out" | jq -e '.tags | index("acceptance-decision")' >/dev/null 2>&1; then
    pass "[$label] tags includes 'acceptance-decision'"
  else
    fail "[$label] tags missing 'acceptance-decision'"
  fi

  # user_request_hash sha256 hex
  local hash
  hash="$(printf '%s' "$out" | jq -r '.data.user_request_hash')"
  if [[ "${#hash}" -eq 64 ]] && printf '%s' "$hash" | grep -qE '^[0-9a-f]{64}$'; then
    pass "[$label] data.user_request_hash is sha256 hex (64 chars)"
  else
    fail "[$label] data.user_request_hash invalid: '$hash'"
  fi

  # action
  local recorded_action
  recorded_action="$(printf '%s' "$out" | jq -r '.data.action')"
  if [[ "$recorded_action" == "$action" ]]; then
    pass "[$label] data.action = $action"
  else
    fail "[$label] data.action mismatch: got $recorded_action, expected $action"
  fi

  # recommendation_shown
  local rec_shown
  rec_shown="$(printf '%s' "$out" | jq -r '.data.recommendation_shown')"
  if [[ "$rec_shown" == "$rec" ]]; then
    pass "[$label] data.recommendation_shown = $rec"
  else
    fail "[$label] recommendation_shown mismatch: got $rec_shown, expected $rec"
  fi

  # recommendation_taken
  local taken
  taken="$(printf '%s' "$out" | jq -r '.data.recommendation_taken')"
  if [[ "$taken" == "$exp_taken" ]]; then
    pass "[$label] data.recommendation_taken = $exp_taken"
  else
    fail "[$label] recommendation_taken: got $taken, expected $exp_taken"
  fi

  # timestamp
  local ts
  ts="$(printf '%s' "$out" | jq -r '.data.timestamp')"
  if printf '%s' "$ts" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'; then
    pass "[$label] data.timestamp ISO8601 UTC"
  else
    fail "[$label] timestamp not ISO8601 UTC"
  fi

  # project propagates
  local proj
  proj="$(printf '%s' "$out" | jq -r '.data.project')"
  if [[ "$proj" == "demo-project" ]]; then
    pass "[$label] data.project propagates"
  else
    fail "[$label] project mismatch: $proj"
  fi
}

# ---- Case 1: action=accept ----
# rec=ship adopted → recommendation_taken=true
run_action_case "accept" "accept" "ship" "true"

# accept-specific: override_reason is empty
out_accept="$(bash "$SCRIPT" --action accept --user-request "Plan Brief MVP acceptance" \
  --project "demo-project" --recommendation ship 2>/dev/null)"
override_a="$(printf '%s' "$out_accept" | jq -r '.data.override_reason')"
if [[ -z "$override_a" ]]; then
  pass "[accept] override_reason is empty"
else
  fail "[accept] override_reason should be empty: $override_a"
fi

# ---- Case 2: action=override (rec=wait → ship adopted) ----
run_action_case "override" "override" "wait" "false" \
  --override-reason "shipping because all 5 verified items confirmed"

# override-specific: override_reason propagates
out_override="$(bash "$SCRIPT" --action override --user-request "Plan Brief MVP acceptance" \
  --project "demo-project" --recommendation wait \
  --override-reason "shipping because all 5 verified items confirmed" 2>/dev/null)"
override_o="$(printf '%s' "$out_override" | jq -r '.data.override_reason')"
if [[ "$override_o" == "shipping because all 5 verified items confirmed" ]]; then
  pass "[override] override_reason propagates"
else
  fail "[override] override_reason mismatch: $override_o"
fi

# ---- Case 3: action=reject (rec=ship → reject decision = override equivalent) ----
# rec=ship + reject decision → recommendation_taken=false
run_action_case "reject" "reject" "ship" "false" \
  --override-reason "critical bug found late in the process"

# reject + rec=reject = recommendation adopted as-is
run_action_case "reject-rec-reject" "reject" "reject" "true"

# ---- DoD c: joinability with Plan Brief side ----
# same user_request string → hash identical to Phase 65.1.4

USER_REQ="request for plan to acceptance trace verification"

if [[ -x "$PLAN_BRIEF_SCRIPT" ]]; then
  hash_plan="$(bash "$PLAN_BRIEF_SCRIPT" --action approve \
    --user-request "$USER_REQ" --project "demo-project" 2>/dev/null \
    | jq -r '.data.user_request_hash')"
  hash_accept="$(bash "$SCRIPT" --action accept \
    --user-request "$USER_REQ" --project "demo-project" --recommendation ship 2>/dev/null \
    | jq -r '.data.user_request_hash')"

  if [[ -n "$hash_plan" && "$hash_plan" == "$hash_accept" ]]; then
    pass "DoD c: joinable with Plan Brief personal-preference.v1 (same hash: ${hash_plan:0:16}...)"
  else
    fail "DoD c: hash mismatch — plan=$hash_plan, accept=$hash_accept"
  fi
else
  fail "Phase 65.1.4 script not found (required for join verification)"
fi

# handling of verified_criteria_at_decision
TMP_CRITERIA="$(mktemp /tmp/criteria-XXXXXX.json)"
cat > "$TMP_CRITERIA" <<'JSON'
{
  "items": [
    { "name": "AC-1", "passed": true,  "evidence": "OK" },
    { "name": "AC-2", "passed": false, "evidence": "" }
  ]
}
JSON

out_with_crit="$(bash "$SCRIPT" --action accept \
  --user-request "test crit" --project "demo-project" --recommendation wait \
  --verified-criteria-source "$TMP_CRITERIA" 2>/dev/null)"
crit_count="$(printf '%s' "$out_with_crit" | jq '.data.verified_criteria_at_decision | length')"
if [[ "$crit_count" -eq 2 ]]; then
  pass "verified_criteria_at_decision propagates from --verified-criteria-source (2 entries)"
else
  fail "verified_criteria_at_decision count: got $crit_count, expected 2"
fi
rm -f "$TMP_CRITERIA"

# post_launch_concerns csv split
out_concerns="$(bash "$SCRIPT" --action accept \
  --user-request "test concerns" --project "demo-project" --recommendation ship \
  --post-launch-concerns "concern A, concern B, concern C" 2>/dev/null)"
concerns_count="$(printf '%s' "$out_concerns" | jq '.data.post_launch_concerns | length')"
if [[ "$concerns_count" -eq 3 ]]; then
  pass "post_launch_concerns csv splits to 3 entries"
else
  fail "post_launch_concerns count: got $concerns_count, expected 3"
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
