#!/bin/bash
# test-hooks-sync.sh
# Verify synchronization between hooks/hooks.json and .claude-plugin/hooks.json
#
# TDD: Phase 7 test cases

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
# Test 1: Both files exist
# ==================================================
test_both_files_exist() {
  local hooks_file="$PROJECT_ROOT/hooks/hooks.json"
  local plugin_hooks_file="$PROJECT_ROOT/.claude-plugin/hooks.json"

  if [ ! -f "$hooks_file" ]; then
    echo "    Error: hooks/hooks.json not found"
    return 1
  fi

  if [ ! -f "$plugin_hooks_file" ]; then
    echo "    Error: .claude-plugin/hooks.json not found"
    return 1
  fi

  return 0
}

# ==================================================
# Test 2: Both files have identical content
# ==================================================
test_files_identical() {
  local hooks_file="$PROJECT_ROOT/hooks/hooks.json"
  local plugin_hooks_file="$PROJECT_ROOT/.claude-plugin/hooks.json"

  if diff -q "$hooks_file" "$plugin_hooks_file" > /dev/null 2>&1; then
    return 0
  else
    echo "    Error: Files are not identical"
    echo "    Run: ./scripts/sync-plugin-cache.sh to sync"
    return 1
  fi
}

# ==================================================
# Test 3: JSON is valid
# ==================================================
test_valid_json() {
  local hooks_file="$PROJECT_ROOT/hooks/hooks.json"
  local plugin_hooks_file="$PROJECT_ROOT/.claude-plugin/hooks.json"

  if ! jq empty "$hooks_file" 2>/dev/null; then
    echo "    Error: hooks/hooks.json is not valid JSON"
    return 1
  fi

  if ! jq empty "$plugin_hooks_file" 2>/dev/null; then
    echo "    Error: .claude-plugin/hooks.json is not valid JSON"
    return 1
  fi

  return 0
}

# ==================================================
# Test 4: Required hook events exist
# ==================================================
test_required_hook_events() {
  local hooks_file="$PROJECT_ROOT/hooks/hooks.json"

  local required_events=("PreToolUse" "SessionStart" "Stop" "PostToolUse")
  local missing=""

  for event in "${required_events[@]}"; do
    if ! jq -e ".hooks.$event" "$hooks_file" > /dev/null 2>&1; then
      missing="${missing}$event, "
    fi
  done

  if [ -n "$missing" ]; then
    echo "    Error: Missing required events: ${missing%, }"
    return 1
  fi

  return 0
}

# ==================================================
# Test 5: No forbidden pattern (invalid use of type: "prompt")
# ==================================================
test_no_forbidden_prompt_usage() {
  local hooks_file="$PROJECT_ROOT/hooks/hooks.json"

  # prompt type is forbidden in PreToolUse, PostToolUse, UserPromptSubmit
  # (security reasons - D13)
  local forbidden_events=("PreToolUse" "PostToolUse" "UserPromptSubmit")
  local violations=""

  for event in "${forbidden_events[@]}"; do
    if jq -e ".hooks.$event[]?.hooks[]? | select(.type == \"prompt\")" "$hooks_file" > /dev/null 2>&1; then
      violations="${violations}$event, "
    fi
  done

  if [ -n "$violations" ]; then
    echo "    Error: type: prompt should not be used in: ${violations%, }"
    echo "    (Stop and SubagentStop are the only valid events for prompt type)"
    return 1
  fi

  return 0
}

# ==================================================
# Test 6: Does not fall through to /bin/harness when CLAUDE_PLUGIN_ROOT is empty
# ==================================================
test_no_raw_plugin_root_harness_paths() {
  local hooks_file="$PROJECT_ROOT/hooks/hooks.json"
  local plugin_hooks_file="$PROJECT_ROOT/.claude-plugin/hooks.json"
  local violations=""

  for file in "$hooks_file" "$plugin_hooks_file"; do
    if jq -e '.. | objects | select(.command? | strings | test("^\"\\\\$\\\\{CLAUDE_PLUGIN_ROOT\\\\}/bin/harness\"|^bash \"\\\\$\\\\{CLAUDE_PLUGIN_ROOT\\\\}/scripts/"))' "$file" >/dev/null 2>&1; then
      violations="${violations}${file}, "
    fi
  done

  if [ -n "$violations" ]; then
    echo "    Error: raw CLAUDE_PLUGIN_ROOT hook command remains in: ${violations%, }"
    echo "    These commands become /bin/harness when CLAUDE_PLUGIN_ROOT is empty."
    return 1
  fi

  return 0
}

# ==================================================
# Test 7: hook command resolves root even when CLAUDE_PLUGIN_ROOT is unset
# ==================================================
test_hook_command_resolves_without_plugin_root() {
  local hooks_file="$PROJECT_ROOT/hooks/hooks.json"
  local command
  local script_command
  local tmp_dir
  local output
  local script_status

  command="$(jq -r '.hooks.PreToolUse[] | select(.matcher=="Write|Edit|MultiEdit|Bash|Read") | .hooks[] | select(.type=="command") | .command' "$hooks_file" | head -n 1)"
  if [ -z "$command" ] || [ "$command" = "null" ]; then
    echo "    Error: could not extract PreToolUse command"
    return 1
  fi

  tmp_dir="$(mktemp -d)"
  output="$(
    cd "$tmp_dir" && \
      env -u CLAUDE_PLUGIN_ROOT CLAUDE_PROJECT_DIR="$PROJECT_ROOT" /bin/sh -c "$command" </dev/null 2>/dev/null
  )"
  rm -rf "$tmp_dir"

  echo "$output" | jq -e '.decision == "approve"' >/dev/null 2>&1 || {
    echo "    Error: hook command did not resolve harness without CLAUDE_PLUGIN_ROOT"
    echo "    Output: ${output}"
    return 1
  }

  script_command="$(jq -r '.hooks.UserPromptSubmit[] | select(.matcher=="*") | .hooks[] | select(.type=="command" and (.command | contains("userprompt-inject-policy.sh"))) | .command' "$hooks_file" | head -n 1)"
  if [ -z "$script_command" ] || [ "$script_command" = "null" ]; then
    echo "    Error: could not extract UserPromptSubmit script command"
    return 1
  fi

  tmp_dir="$(mktemp -d)"
  set +e
  (
    cd "$tmp_dir" && \
      env -u CLAUDE_PLUGIN_ROOT CLAUDE_PROJECT_DIR="$PROJECT_ROOT" /bin/sh -c "$script_command" </dev/null >/dev/null 2>/dev/null
  )
  script_status=$?
  set -e
  rm -rf "$tmp_dir"

  if [ "$script_status" -ne 0 ]; then
    echo "    Error: shell script hook did not resolve root without CLAUDE_PLUGIN_ROOT"
    echo "    Exit status: ${script_status}"
    return 1
  fi

  return 0
}

# ==================================================
# Main execution
# ==================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Hooks sync test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Verify jq is available
if ! command -v jq &> /dev/null; then
  echo -e "${RED}Error: jq is required but not installed${NC}"
  exit 1
fi

run_test "Both hooks.json files exist" test_both_files_exist
run_test "hooks.json content is identical" test_files_identical
run_test "JSON is valid" test_valid_json
run_test "Required hook events exist" test_required_hook_events
run_test "No forbidden prompt usage" test_no_forbidden_prompt_usage
run_test "Does not fall through to /bin/harness when CLAUDE_PLUGIN_ROOT is empty" test_no_raw_plugin_root_harness_paths
run_test "hook command resolves root even when CLAUDE_PLUGIN_ROOT is unset" test_hook_command_resolves_without_plugin_root

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Test results: $TESTS_PASSED/$TESTS_RUN passed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$TESTS_FAILED" -gt 0 ]; then
  exit 1
fi

exit 0
