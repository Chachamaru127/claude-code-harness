#!/bin/bash
# tests/test-accept-past-issues.sh
# Phase 65.2.2 - mechanical validation of accept-past-issues.sh
#
# Validation cases (DoD d):
#   1. case-zero-issues       : items=[] → 0 items output
#   2. case-three-verified    : 3 items all verified → 3 items output, all true
#   3. case-mixed-verified    : 4 items (verified mix) → top 3 output (by relevance), half verified
#
# Common validation:
#   (a) --project / --task required; exit 2 when missing
#   (b) does not call cross-project search (verify project parameter is required)
#   (c) output schema = "past-issue.v1" + project / task_description / generated_at included
#   (d) fetch top 3 + verified_in_current_task present on each item
#   (e) sorted by relevance_score descending

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SCRIPT="$ROOT_DIR/scripts/accept-past-issues.sh"
FIX_DIR="$ROOT_DIR/tests/fixtures/accept-past-issues"

PASS=0
FAIL=0
FAIL_MESSAGES=()

pass() { PASS=$((PASS + 1)); echo "✓ $1"; }
fail() { FAIL=$((FAIL + 1)); FAIL_MESSAGES+=("$1"); echo "✗ $1" >&2; }

# ---- pre-checks ----

if [[ ! -x "$SCRIPT" ]]; then
  fail "accept-past-issues.sh not executable: $SCRIPT"
  echo "PASS=$PASS FAIL=$FAIL"
  exit 1
fi
pass "accept-past-issues.sh exists and is executable"

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
bash "$SCRIPT" --task "x" 2>/dev/null
exit_code=$?
set -e
if [[ "$exit_code" -eq 2 ]]; then
  pass "Script exits 2 when --project missing (DoD b: project enforcement)"
else
  fail "Script should exit 2 when --project missing (got $exit_code)"
fi

set +e
bash "$SCRIPT" --project "demo" 2>/dev/null
exit_code=$?
set -e
if [[ "$exit_code" -eq 2 ]]; then
  pass "Script exits 2 when --task missing"
else
  fail "Script should exit 2 when --task missing (got $exit_code)"
fi

# ---- helper: run one case ----
# args: <case_label> <fixture_basename> <expected_items_count> <expected_verified_count>

run_case() {
  local label="$1"
  local fixture_base="$2"
  local exp_items="$3"
  local exp_verified="$4"

  local fixture="$FIX_DIR/${fixture_base}.json"

  if [[ ! -f "$fixture" ]]; then
    fail "[$label] fixture missing: $fixture"
    return
  fi

  local out
  out="$(bash "$SCRIPT" --project "demo-project" --task "Plan Brief MVP acceptance" --issues-source "$fixture" 2>&1)" || {
    fail "[$label] script failed: $out"
    return
  }

  # JSON parse
  if printf '%s' "$out" | jq -e '.' >/dev/null 2>&1; then
    pass "[$label] output is valid JSON"
  else
    fail "[$label] output is not valid JSON"
    return
  fi

  # schema field
  local schema
  schema="$(printf '%s' "$out" | jq -r '.schema')"
  if [[ "$schema" == "past-issue.v1" ]]; then
    pass "[$label] schema = past-issue.v1"
  else
    fail "[$label] schema mismatch: $schema"
  fi

  # project / task propagate
  local proj task
  proj="$(printf '%s' "$out" | jq -r '.project')"
  task="$(printf '%s' "$out" | jq -r '.task_description')"
  if [[ "$proj" == "demo-project" ]]; then
    pass "[$label] project propagates"
  else
    fail "[$label] project mismatch: $proj"
  fi
  if [[ "$task" == "Plan Brief MVP acceptance" ]]; then
    pass "[$label] task_description propagates"
  else
    fail "[$label] task_description mismatch: $task"
  fi

  # generated_at ISO8601
  local ts
  ts="$(printf '%s' "$out" | jq -r '.generated_at')"
  if printf '%s' "$ts" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'; then
    pass "[$label] generated_at is ISO8601 UTC"
  else
    fail "[$label] generated_at not ISO8601 UTC: $ts"
  fi

  # items count (DoD c: top 3 max)
  local items_count
  items_count="$(printf '%s' "$out" | jq '.items | length')"
  if [[ "$items_count" -eq "$exp_items" ]]; then
    pass "[$label] items count = $exp_items (DoD c: top 3)"
  else
    fail "[$label] items count: got $items_count, expected $exp_items"
  fi

  # verified count (DoD c: verified_in_current_task assigned)
  if [[ "$items_count" -gt 0 ]]; then
    # Each item has verified_in_current_task field
    local missing_field
    missing_field="$(printf '%s' "$out" | jq '[.items[] | select(has("verified_in_current_task") | not)] | length')"
    if [[ "$missing_field" -eq 0 ]]; then
      pass "[$label] all items have verified_in_current_task field"
    else
      fail "[$label] $missing_field items missing verified_in_current_task"
    fi

    local actual_verified
    actual_verified="$(printf '%s' "$out" | jq '[.items[] | select(.verified_in_current_task == true)] | length')"
    if [[ "$actual_verified" -eq "$exp_verified" ]]; then
      pass "[$label] verified count = $exp_verified"
    else
      fail "[$label] verified count: got $actual_verified, expected $exp_verified"
    fi

    # relevance_score descending order check
    local sorted_check
    sorted_check="$(printf '%s' "$out" | jq '
      .items
      | map(.relevance_score // 0)
      | . as $scores
      | $scores == ($scores | sort | reverse)
    ')"
    if [[ "$sorted_check" == "true" ]]; then
      pass "[$label] items sorted by relevance_score descending"
    else
      fail "[$label] items NOT sorted by relevance_score descending"
    fi
  else
    pass "[$label] no items — verified_in_current_task / sort check skipped (expected for empty)"
  fi
}

# ---- Case 1: zero issues ----
run_case "zero-issues" "case-zero-issues" 0 0

# ---- Case 2: three verified ----
# fixture has 3 items, all verified=true → output 3 items, 3 verified
run_case "three-verified" "case-three-verified" 3 3

# ---- Case 3: mixed verified ----
# fixture has 4 items (verified true/false/true/false) → top 3 by relevance:
#   P5 (0.92, true), P12 (0.80, false), AR-2026-04-30 (0.75, true)
# expected: 3 items, 2 verified true (half of 3, rounded up)
run_case "mixed-verified" "case-mixed-verified" 3 2

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
