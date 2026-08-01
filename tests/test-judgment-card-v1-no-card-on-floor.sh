#!/usr/bin/env bash
# Phase 95.2.2 — floor hard-stop regression (93.3.3 contract)
#
# floor 該当時は judgment card 非発行 + HARD_STOP / hard_stop=true
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/judgment-card.sh"

PASS=0
FAIL=0
FAIL_MESSAGES=()

pass() { PASS=$((PASS + 1)); echo "✓ $1" >&2; }
fail() { FAIL=$((FAIL + 1)); FAIL_MESSAGES+=("$1"); echo "✗ $1" >&2; }

assert_exit() {
  local label="$1"
  local expected_exit="$2"
  shift 2
  set +e
  local output
  output="$("$@" 2>&1)"
  local exit_code=$?
  set -e
  if [[ "$exit_code" -eq "$expected_exit" ]]; then
    pass "$label"
  else
    fail "$label (expected exit ${expected_exit}, got ${exit_code}; output: ${output})"
    printf '%s' "$output"
    return
  fi
  printf '%s' "$output"
}

assert_eq() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    pass "$label"
  else
    fail "$label (expected '${expected}', got '${actual}')"
  fi
}

if [[ ! -x "$SCRIPT" ]]; then
  fail "pre-flight: judgment-card.sh missing or not executable"
  echo "PASS=$PASS FAIL=$FAIL"
  exit 1
fi
pass "pre-flight: judgment-card.sh exists"

# should-issue floor → HARD_STOP (93.3.3 unchanged)
out_should="$(assert_exit "should-issue floor egress exit 2" 2 \
  bash "$SCRIPT" should-issue --reason tradeoff --floor-category egress)"
assert_eq "should-issue floor output" "HARD_STOP: floor (egress)" "$out_should"

# compute-impact floor → hard_stop
out_impact="$(assert_exit "compute-impact floor egress exit 2" 2 \
  bash "$SCRIPT" compute-impact --files-changed 1 --lines-changed 1 --floor-category egress)"

python3 - <<'PY' "$out_impact"
import json
import sys

data = json.loads(sys.argv[1].strip())
assert data["impact_score"] == 100
assert data["hard_stop"] is True
print("ok")
PY
if [[ $? -eq 0 ]]; then
  pass "compute-impact floor: hard_stop=true impact_score=100"
else
  fail "compute-impact floor JSON assertion failed"
fi

# floor 該当時は ISSUE_CARD が出ない（should-issue が HARD_STOP のみ）
if grep -q 'ISSUE_CARD' <<<"$out_should"; then
  fail "floor should not emit ISSUE_CARD"
else
  pass "floor should-issue does not emit ISSUE_CARD"
fi

# compute-impact もカード発行シグナルなし（hard_stop JSON のみ）
if grep -q 'ISSUE_CARD' <<<"$out_impact"; then
  fail "compute-impact floor should not emit ISSUE_CARD"
else
  pass "compute-impact floor does not emit ISSUE_CARD"
fi

echo ""
echo "PASS=$PASS FAIL=$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  echo "Failures:" >&2
  for msg in "${FAIL_MESSAGES[@]}"; do
    echo "  - $msg" >&2
  done
  exit 1
fi

echo "test-judgment-card-v1-no-card-on-floor: ok"
