#!/bin/bash
# test-hook-event-names.sh
# Verify that hookEventName matches the hook event type
#
# PostToolUse hook → hookEventName: "PostToolUse"
# PreToolUse hook  → hookEventName: "PreToolUse"
# etc.

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
NC='\033[0m'

# POSIX-compatible extraction function (avoids grep -P)
extract_hook_event_names() {
  local file="$1"
  sed -n 's/.*"hookEventName"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$file"
}

# Test function
run_test() {
  local test_name="$1"
  local test_func="$2"

  TESTS_RUN=$((TESTS_RUN + 1))
  echo -n "  Testing: $test_name... "

  if $test_func; then
    echo -e "${GREEN}PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}FAILED${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# ==================================================
# Test 1: session-auto-broadcast.sh returns PostToolUse
# ==================================================
test_auto_broadcast_event_name() {
  local script="$PROJECT_ROOT/scripts/session-auto-broadcast.sh"

  if [ ! -f "$script" ]; then
    echo "    Error: session-auto-broadcast.sh not found"
    return 1
  fi

  # Check that hookEventName does not contain anything other than PostToolUse
  local bad_names
  bad_names=$(extract_hook_event_names "$script" | grep -v '^PostToolUse$' || true)

  if [ -n "$bad_names" ]; then
    echo "    Error: Invalid hookEventName found: $bad_names (expected PostToolUse)"
    return 1
  fi

  # Check that at least one hookEventName exists
  local count
  count=$(grep -c '"hookEventName"' "$script" || echo "0")
  if [ "$count" -eq 0 ]; then
    echo "    Error: No hookEventName found in script"
    return 1
  fi

  return 0
}

# ==================================================
# Test 2: hookEventName consistency for PostToolUse-registered scripts
# ==================================================
test_posttooluse_scripts_consistency() {
  local hooks_file="$PROJECT_ROOT/hooks/hooks.json"
  local violations=""

  if [ ! -f "$hooks_file" ]; then
    echo "    Error: hooks/hooks.json not found"
    return 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    echo "    Skipped: jq not available"
    return 0
  fi

  # Extract script names registered under PostToolUse
  local scripts
  scripts=$(jq -r '
    .hooks.PostToolUse[]?.hooks[]?.command // empty
    | try (capture("run-script\\.js\"\\s+(?<name>\\S+)").name) catch empty
  ' "$hooks_file")

  for script_name in $scripts; do
    local script_path="$PROJECT_ROOT/scripts/${script_name}.sh"
    if [ ! -f "$script_path" ]; then
      continue
    fi

    # Only check scripts that contain hookEventName
    if grep -q '"hookEventName"' "$script_path" 2>/dev/null; then
      local bad
      bad=$(extract_hook_event_names "$script_path" | grep -v '^PostToolUse$' || true)
      if [ -n "$bad" ]; then
        violations="${violations}  ${script_name}: uses '$bad' instead of 'PostToolUse'\n"
      fi
    fi
  done

  if [ -n "$violations" ]; then
    echo -e "    Error: hookEventName mismatch:\n$violations"
    return 1
  fi

  return 0
}

# ==================================================
# Test 3: session-auto-broadcast stdout is clean JSON only
# ==================================================
test_auto_broadcast_clean_output() {
  local script="$PROJECT_ROOT/scripts/session-auto-broadcast.sh"

  if [ ! -f "$script" ]; then
    echo "    Error: session-auto-broadcast.sh not found"
    return 1
  fi

  # Check that subprocess stdout is redirected to /dev/null
  if grep -q 'session-broadcast\.sh' "$script"; then
    if ! grep 'session-broadcast\.sh' "$script" | grep -q '>/dev/null'; then
      echo "    Error: session-broadcast.sh stdout not redirected to /dev/null"
      return 1
    fi
  fi

  return 0
}

# ==================================================
# Test 4: No validation error on empty input
# ==================================================
test_auto_broadcast_empty_input() {
  local script="$PROJECT_ROOT/scripts/session-auto-broadcast.sh"

  if [ ! -f "$script" ]; then
    echo "    Error: session-auto-broadcast.sh not found"
    return 1
  fi

  # Run with empty input
  local output
  output=$(echo '' | bash "$script" 2>/dev/null || true)

  # Check that output is valid JSON with PostToolUse hookEventName
  if ! echo "$output" | grep -q '"hookEventName":"PostToolUse"'; then
    echo "    Error: Empty input should return PostToolUse hookEventName"
    echo "    Got: $output"
    return 1
  fi

  return 0
}

# ==================================================
# Test 5: No validation error on non-matching pattern
# ==================================================
test_auto_broadcast_no_match() {
  local script="$PROJECT_ROOT/scripts/session-auto-broadcast.sh"

  if [ ! -f "$script" ]; then
    echo "    Error: session-auto-broadcast.sh not found"
    return 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    echo "    Skipped: jq not available"
    return 0
  fi

  # Run with a file path that does not match any pattern
  local output
  output=$(echo '{"tool_input":{"file_path":"src/components/Button.tsx"}}' | bash "$script" 2>/dev/null || true)

  # Check that output is valid JSON with PostToolUse hookEventName
  if ! echo "$output" | grep -q '"hookEventName":"PostToolUse"'; then
    echo "    Error: Non-matching path should return PostToolUse hookEventName"
    echo "    Got: $output"
    return 1
  fi

  return 0
}

# ==================================================
# Main execution
# ==================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " hookEventName consistency test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

run_test "session-auto-broadcast.sh returns PostToolUse" test_auto_broadcast_event_name
run_test "hookEventName consistency for PostToolUse scripts" test_posttooluse_scripts_consistency
run_test "session-auto-broadcast stdout is clean" test_auto_broadcast_clean_output
run_test "returns PostToolUse on empty input" test_auto_broadcast_empty_input
run_test "returns PostToolUse on non-matching pattern" test_auto_broadcast_no_match

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Test results: $TESTS_PASSED/$TESTS_RUN passed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$TESTS_FAILED" -gt 0 ]; then
  exit 1
fi

exit 0
