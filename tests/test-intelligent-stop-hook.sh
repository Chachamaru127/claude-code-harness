#!/bin/bash
# test-intelligent-stop-hook.sh
# Stop Hook (type: "command") tests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Test result counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test function
run_test() {
  local test_name="$1"
  local test_func="$2"

  TESTS_RUN=$((TESTS_RUN + 1))
  echo -n "  Testing: $test_name... "

  if "$test_func"; then
    echo -e "${GREEN}PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}FAILED${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# ==================================================
# Test 1: Stop hook has command type
# ==================================================
test_stop_hook_has_command() {
  local hooks_file="$PROJECT_ROOT/hooks/hooks.json"

  if [ ! -f "$hooks_file" ]; then
    echo "    Error: hooks.json not found"
    return 1
  fi

  if jq -e '.hooks.Stop[] | .hooks[]? | select(.type == "command")' "$hooks_file" >/dev/null 2>&1; then
    return 0
  fi

  echo "    Error: No command-type Stop hook found"
  return 1
}

# ==================================================
# Test 2: No prompt-type Stop hook remains
# ==================================================
test_no_prompt_stop_hook() {
  local hooks_file="$PROJECT_ROOT/hooks/hooks.json"

  if jq -e '.hooks.Stop[] | .hooks[]? | select(.type == "prompt")' "$hooks_file" >/dev/null 2>&1; then
    echo "    Error: prompt-type Stop hook still exists"
    return 1
  fi

  return 0
}

# ==================================================
# Test 3: stop-session-evaluator command is configured
# ==================================================
test_stop_evaluator_hook_exists() {
  local hooks_file="$PROJECT_ROOT/hooks/hooks.json"
  local command

  command=$(jq -r '.hooks.Stop[] | .hooks[]? | select((.command // "") | contains("stop-session-evaluator") or contains("hook stop-evaluator")) | .command // empty' "$hooks_file" 2>/dev/null | head -n 1)

  if [ -z "$command" ]; then
    echo "    Error: stop-session-evaluator hook command not found"
    return 1
  fi

  return 0
}

# ==================================================
# Test 4: stop-session-evaluator timeout is appropriate
# ==================================================
test_stop_evaluator_timeout() {
  local hooks_file="$PROJECT_ROOT/hooks/hooks.json"
  local timeout

  timeout=$(jq -r '.hooks.Stop[] | .hooks[]? | select((.command // "") | contains("stop-session-evaluator") or contains("hook stop-evaluator")) | .timeout // 0' "$hooks_file" 2>/dev/null | head -n 1)

  if ! [[ "$timeout" =~ ^[0-9]+$ ]]; then
    echo "    Error: Timeout is not numeric: $timeout"
    return 1
  fi

  if [ "$timeout" -lt 30 ]; then
    echo "    Error: Timeout should be >= 30 seconds, got $timeout"
    return 1
  fi

  return 0
}

# ==================================================
# Test 5: stop-session-evaluator script exists
# ==================================================
test_stop_evaluator_script_exists() {
  local script="$PROJECT_ROOT/scripts/hook-handlers/stop-session-evaluator.sh"

  if [ ! -f "$script" ]; then
    echo "    Error: stop-session-evaluator.sh not found"
    return 1
  fi

  return 0
}

# ==================================================
# Test 6: stop-session-evaluator returns valid JSON
# ==================================================
test_stop_evaluator_outputs_json() {
  local script="$PROJECT_ROOT/scripts/hook-handlers/stop-session-evaluator.sh"
  local output

  if [ ! -f "$script" ]; then
    echo "    Error: stop-session-evaluator.sh not found"
    return 1
  fi

  output=$(bash "$script" 2>/dev/null || true)

  if [ -z "$output" ]; then
    echo "    Error: stop-session-evaluator produced empty output"
    return 1
  fi

  if ! echo "$output" | jq -e '.ok == true' >/dev/null 2>&1; then
    echo "    Error: invalid evaluator output: $output"
    return 1
  fi

  return 0
}

# ==================================================
# Test 7: session-summary command hook is maintained
# ==================================================
test_session_summary_maintained() {
  local hooks_file="$PROJECT_ROOT/hooks/hooks.json"

  if jq -e '.hooks.Stop[] | .hooks[]? | select(.type == "command") | select((.command // "") | contains("session-summary"))' "$hooks_file" >/dev/null 2>&1; then
    return 0
  fi

  echo "    Error: session-summary command hook not found"
  return 1
}

# ==================================================
# Test 8: Stop hook count is appropriate
# ==================================================
test_stop_hook_count() {
  local hooks_file="$PROJECT_ROOT/hooks/hooks.json"
  local hook_count

  hook_count=$(jq '[.hooks.Stop[].hooks[]] | length' "$hooks_file" 2>/dev/null)

  if [ "$hook_count" -lt 2 ] || [ "$hook_count" -gt 4 ]; then
    echo "    Error: Expected 2-4 hooks in Stop, got $hook_count"
    return 1
  fi

  return 0
}

# ==================================================
# Main execution
# ==================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Intelligent Stop Hook tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Verify jq is available
if ! command -v jq &> /dev/null; then
  echo -e "${RED}Error: jq is required but not installed${NC}"
  exit 1
fi

echo "Phase 2: Command-based Stop Hook verification"
echo ""

run_test "command-type Stop hook exists" test_stop_hook_has_command
run_test "no prompt-type Stop hook remains" test_no_prompt_stop_hook
run_test "stop-session-evaluator hook is configured" test_stop_evaluator_hook_exists
run_test "stop-session-evaluator timeout is appropriate (>= 30s)" test_stop_evaluator_timeout
run_test "stop-session-evaluator script exists" test_stop_evaluator_script_exists
run_test "stop-session-evaluator returns valid JSON" test_stop_evaluator_outputs_json
run_test "session-summary (command) is maintained" test_session_summary_maintained
run_test "Stop hook count is appropriate (2-4)" test_stop_hook_count

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Test results: $TESTS_PASSED/$TESTS_RUN passed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$TESTS_FAILED" -gt 0 ]; then
  echo -e "${YELLOW}Note: Inconsistency with Stop Hook implementation. Please re-check hooks configuration and tests.${NC}"
  exit 1
fi

exit 0
