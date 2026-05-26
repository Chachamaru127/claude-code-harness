#!/bin/bash
# tests/test-plan-brief-compile.sh
# Phase 65.1.3 - plan-brief-compile.sh mechanical validation
#
# Test cases (corresponds to DoD c):
#   1. case-empty           : 0 similar cases + 0 D/P + request has 1 sentence with number
#                              => confidence ≈ DoD component only
#   2. case-5-all-done      : 5 similar cases all done + D 4 + P 2 (=6 → 30pt)
#                              => confidence = 40 + 30 + 30 = 100
#   3. case-5-half-failed   : 2/5 similar cases done (40%) + D 2 + P 1 (=3 → 20pt)
#                              => confidence = 16 + 30 + 20 = 66
#   4. case-5-all-done-no-dp: 5 similar cases all done + 0 D/P
#                              => confidence = 40 + 30 + 0 = 70
#
# Common validation:
#   (a) --query / --project required; exit 2 if missing
#   (b) confidence is integer in 0-100
#   (c) confidence_evidence has at least 1 line in "M of N (X%) cc:done" format
#   (d) output schema is "plan-brief-context.v1"
#   (e) each related D/P element is passed to related_decisions (count matches)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

COMPILE_SCRIPT="$ROOT_DIR/scripts/plan-brief-compile.sh"
FIX_DIR="$ROOT_DIR/tests/fixtures/plan-brief-compile"

PASS=0
FAIL=0
FAIL_MESSAGES=()

pass() { PASS=$((PASS + 1)); echo "✓ $1"; }
fail() { FAIL=$((FAIL + 1)); FAIL_MESSAGES+=("$1"); echo "✗ $1" >&2; }

# ---- pre-checks ----

if [[ ! -x "$COMPILE_SCRIPT" ]]; then
  fail "plan-brief-compile.sh not executable: $COMPILE_SCRIPT"
  echo "PASS=$PASS FAIL=$FAIL"
  exit 1
fi
pass "plan-brief-compile.sh exists and is executable"

# ---- (a) Required argument check ----

set +e
bash "$COMPILE_SCRIPT" 2>/dev/null
exit_code=$?
set -e
if [[ "$exit_code" -eq 2 ]]; then
  pass "Compile script exits 2 when --query and --project missing"
else
  fail "Compile script should exit 2 when args missing (got $exit_code)"
fi

set +e
bash "$COMPILE_SCRIPT" --query "test" 2>/dev/null
exit_code=$?
set -e
if [[ "$exit_code" -eq 2 ]]; then
  pass "Compile script exits 2 when --project missing"
else
  fail "Compile script should exit 2 when --project missing (got $exit_code)"
fi

# ---- Helper: run 1 case ----
# Args: <case_label> <fixture_path> <expected_confidence_min> <expected_confidence_max>
#       <query_text> <expected_decisions_count> <expected_plans_count>

run_case() {
  local label="$1"
  local fixture="$2"
  local conf_min="$3"
  local conf_max="$4"
  local query="$5"
  local exp_decisions="$6"
  local exp_plans="$7"

  local out
  out="$(bash "$COMPILE_SCRIPT" --query "$query" --project "demo" --mem-results "$fixture" 2>&1)" || {
    fail "[$label] compile script failed: $out"
    return
  }

  # schema check
  local schema
  schema="$(printf '%s' "$out" | jq -r '.schema')"
  if [[ "$schema" == "plan-brief-context.v1" ]]; then
    pass "[$label] schema = plan-brief-context.v1"
  else
    fail "[$label] schema mismatch: $schema"
  fi

  # confidence in expected range
  local conf
  conf="$(printf '%s' "$out" | jq -r '.confidence')"
  if [[ "$conf" -ge "$conf_min" && "$conf" -le "$conf_max" ]]; then
    pass "[$label] confidence = $conf (expected ${conf_min}-${conf_max})"
  else
    fail "[$label] confidence out of range: $conf (expected ${conf_min}-${conf_max})"
  fi

  # confidence is integer 0-100
  if [[ "$conf" -ge 0 && "$conf" -le 100 ]]; then
    pass "[$label] confidence is in [0, 100]"
  else
    fail "[$label] confidence out of [0, 100]: $conf"
  fi

  # confidence_evidence has past plans line with "M of N (X%)" or "0 items (insufficient signal)"
  local evidence_text
  evidence_text="$(printf '%s' "$out" | jq -r '.confidence_evidence | join("\n")')"
  if printf '%s' "$evidence_text" | grep -qE '[0-9]+ of [0-9]+ \([0-9]+%\) cc:done|0 items \(insufficient signal\)'; then
    pass "[$label] confidence_evidence contains past plans rate evidence"
  else
    fail "[$label] confidence_evidence missing past plans rate line"
  fi

  # related_decisions length matches fixture
  local rd_count
  rd_count="$(printf '%s' "$out" | jq -r '.related_decisions | length')"
  if [[ "$rd_count" == "$exp_decisions" ]]; then
    pass "[$label] related_decisions count = $exp_decisions"
  else
    fail "[$label] related_decisions count: got $rd_count, expected $exp_decisions"
  fi

  # similar_past_plans length matches fixture
  local sp_count
  sp_count="$(printf '%s' "$out" | jq -r '.similar_past_plans | length')"
  if [[ "$sp_count" == "$exp_plans" ]]; then
    pass "[$label] similar_past_plans count = $exp_plans"
  else
    fail "[$label] similar_past_plans count: got $sp_count, expected $exp_plans"
  fi

  # confidence_evidence_items derived field present (for template iteration)
  local items_count
  items_count="$(printf '%s' "$out" | jq -r '.confidence_evidence_items | length')"
  if [[ "$items_count" -eq 3 ]]; then
    pass "[$label] confidence_evidence_items has 3 items (past + DoD + D/P)"
  else
    fail "[$label] confidence_evidence_items count: got $items_count, expected 3"
  fi
}

# ---- Case 1: empty mem results ----
# query: 1 sentence with 1 number → DoD 100% × 30 = 30
# past 0 items → 0, D/P 0 items → 0
# expected confidence: 30 (only DoD contributes)
run_case "empty" "$FIX_DIR/case-empty.json" 28 32 "I want to create 1 Plan Brief" 0 0

# ---- Case 2: 5 all done + D 4 + P 2 (= 6 D/P) ----
# past 5 items all done → 40
# query: 1 sentence with 1 number → 30
# D/P 6+ items → 30
# expected: 100
run_case "5-all-done" "$FIX_DIR/case-5-all-done.json" 98 100 "I want to complete all 5 tasks" 4 5

# ---- Case 3: 5 half failed + D 2 + P 1 (= 3 D/P) ----
# 2/5 past items done (40%) → 16
# query: 1 sentence with number → 30
# D/P 3 items → 20
# expected: 66 (allow 64-68 for rounding)
run_case "5-half-failed" "$FIX_DIR/case-5-half-failed.json" 64 68 "Advance 5 tasks" 2 5

# ---- Case 4: 5 all done + 0 D/P ----
# past 5 items all done → 40
# query: 1 sentence with number → 30
# D/P 0 items → 0
# expected: 70
run_case "5-all-done-no-dp" "$FIX_DIR/case-5-all-done-no-dp.json" 68 72 "Advance 5 tasks" 0 5

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
