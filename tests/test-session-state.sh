#!/bin/bash
# test-session-state.sh
# Unit tests for session-state.sh
#
# Usage: ./tests/test-session-state.sh

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
SESSION_STATE_SCRIPT="$PLUGIN_ROOT/scripts/session-state.sh"

# Temporary directory for tests
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

cd "$TEST_DIR"

# Color output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0

pass_test() {
  echo -e "${GREEN}✓${NC} $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail_test() {
  echo -e "${RED}✗${NC} $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

echo "=========================================="
echo "session-state.sh unit tests"
echo "=========================================="
echo ""

# Check that the script exists
if [ ! -f "$SESSION_STATE_SCRIPT" ]; then
  fail_test "session-state.sh not found: $SESSION_STATE_SCRIPT"
  exit 1
fi

if [ ! -x "$SESSION_STATE_SCRIPT" ]; then
  fail_test "session-state.sh is not executable"
  exit 1
fi

pass_test "session-state.sh exists and is executable"

echo ""
echo "1. Transition tests from initial state"
echo "----------------------------------------"

# idle → initialized (session.start)
if "$SESSION_STATE_SCRIPT" --state initialized --event session.start >/dev/null 2>&1; then
  pass_test "idle → initialized (session.start)"
else
  fail_test "idle → initialized (session.start)"
fi

# Verify session.json was created
if [ -f ".claude/state/session.json" ]; then
  pass_test "session.json was created"

  # Check the state field
  if command -v jq >/dev/null 2>&1; then
    state=$(jq -r '.state' .claude/state/session.json 2>/dev/null)
    if [ "$state" = "initialized" ]; then
      pass_test "state = initialized"
    else
      fail_test "state is not 'initialized': $state"
    fi
  fi
else
  fail_test "session.json was not created"
fi

echo ""
echo "2. Valid state transition tests"
echo "----------------------------------------"

# initialized → planning (plan.ready)
if "$SESSION_STATE_SCRIPT" --state planning --event plan.ready >/dev/null 2>&1; then
  pass_test "initialized → planning (plan.ready)"
else
  fail_test "initialized → planning (plan.ready)"
fi

# planning → executing (work.start)
if "$SESSION_STATE_SCRIPT" --state executing --event work.start >/dev/null 2>&1; then
  pass_test "planning → executing (work.start)"
else
  fail_test "planning → executing (work.start)"
fi

# executing → reviewing (work.task_complete)
if "$SESSION_STATE_SCRIPT" --state reviewing --event work.task_complete >/dev/null 2>&1; then
  pass_test "executing → reviewing (work.task_complete)"
else
  fail_test "executing → reviewing (work.task_complete)"
fi

# reviewing → verifying (verify.start)
if "$SESSION_STATE_SCRIPT" --state verifying --event verify.start >/dev/null 2>&1; then
  pass_test "reviewing → verifying (verify.start)"
else
  fail_test "reviewing → verifying (verify.start)"
fi

# verifying → completed (verify.passed)
if "$SESSION_STATE_SCRIPT" --state completed --event verify.passed >/dev/null 2>&1; then
  pass_test "verifying → completed (verify.passed)"
else
  fail_test "verifying → completed (verify.passed)"
fi

echo ""
echo "3. Wildcard transition tests (any state → stopped)"
echo "----------------------------------------"

# completed → stopped (session.stop)
if "$SESSION_STATE_SCRIPT" --state stopped --event session.stop >/dev/null 2>&1; then
  pass_test "completed → stopped (session.stop)"
else
  fail_test "completed → stopped (session.stop)"
fi

echo ""
echo "4. Invalid transition tests"
echo "----------------------------------------"

# stopped → completed is not allowed
if "$SESSION_STATE_SCRIPT" --state completed --event verify.passed 2>/dev/null; then
  fail_test "stopped → completed (verify.passed) was allowed (expected: denied)"
else
  pass_test "stopped → completed (verify.passed) was correctly denied"
fi

echo ""
echo "5. Event log tests"
echo "----------------------------------------"

if [ -f ".claude/state/session.events.jsonl" ]; then
  pass_test "session.events.jsonl was created"

  EVENT_COUNT=$(wc -l < .claude/state/session.events.jsonl | tr -d ' ')
  if [ "$EVENT_COUNT" -gt 0 ]; then
    pass_test "Event log has $EVENT_COUNT entries"
  else
    fail_test "Event log is empty"
  fi

  # Check the last event
  if command -v jq >/dev/null 2>&1; then
    LAST_EVENT=$(tail -n 1 .claude/state/session.events.jsonl)
    LAST_STATE=$(echo "$LAST_EVENT" | jq -r '.state' 2>/dev/null)
    if [ "$LAST_STATE" = "stopped" ]; then
      pass_test "Last event state = stopped"
    else
      fail_test "Last event state is not 'stopped': $LAST_STATE"
    fi
  fi
else
  fail_test "session.events.jsonl was not created"
fi

echo ""
echo "=========================================="
echo "Test results summary"
echo "=========================================="
echo -e "${GREEN}Passed:${NC} $PASS_COUNT"
echo -e "${RED}Failed:${NC} $FAIL_COUNT"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
  echo -e "${GREEN}✓ All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}✗ $FAIL_COUNT test(s) failed${NC}"
  exit 1
fi
