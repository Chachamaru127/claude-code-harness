#!/bin/bash
# test-hooks-sync.sh
# hooks/hooks.json と .claude-plugin/hooks.json の同期を検証
#
# TDD: Phase 7 テストケース

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# テスト結果カウンター
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# テスト関数
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
# Test 1: 両方のファイルが存在するか
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
# Test 2: 両ファイルの内容が同一か
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
# Test 3: JSON が有効か
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
# Test 4: 必須フックイベントが存在するか
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
# Test 5: 禁止パターン (type: "prompt" の不正使用) がないか
# ==================================================
test_no_forbidden_prompt_usage() {
  local hooks_file="$PROJECT_ROOT/hooks/hooks.json"

  # PreToolUse, PostToolUse, UserPromptSubmit で prompt 型は禁止
  # (セキュリティ上の理由 - D13)
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
# Test 6: CLAUDE_PLUGIN_ROOT 空時に /bin/harness へ落ちないか
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
# Test 7: CLAUDE_PLUGIN_ROOT 未設定でも hook command が root 解決できるか
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
# Test 8: identity 不一致の plugin root を実行しないか
# ==================================================
test_untrusted_plugin_root_is_rejected() {
  local hooks_file="$PROJECT_ROOT/hooks/hooks.json"
  local command
  local tmp_dir
  local fake_root
  local output

  command="$(jq -r '.hooks.PreToolUse[] | select(.matcher=="Write|Edit|MultiEdit|Bash|Read") | .hooks[] | select(.type=="command") | .command' "$hooks_file" | head -n 1)"
  if [ -z "$command" ] || [ "$command" = "null" ]; then
    echo "    Error: could not extract PreToolUse command"
    return 1
  fi

  tmp_dir="$(mktemp -d)"
  fake_root="$tmp_dir/untrusted"
  mkdir -p "$fake_root/bin" "$fake_root/.claude-plugin" "$tmp_dir/cwd" "$tmp_dir/home"
  printf '%s\n' '#!/bin/sh' 'echo UNTRUSTED_ROOT_EXECUTED' > "$fake_root/bin/harness"
  chmod +x "$fake_root/bin/harness"
  printf '%s\n' '{"name":"not-claude-code-harness"}' > "$fake_root/.claude-plugin/plugin.json"

  output="$(
    cd "$tmp_dir/cwd" && \
      HOME="$tmp_dir/home" CLAUDE_PLUGIN_ROOT="$fake_root" CLAUDE_PROJECT_DIR="$fake_root" \
      /bin/sh -c "$command" </dev/null 2>/dev/null || true
  )"
  rm -rf "$tmp_dir"

  if [ -n "$output" ]; then
    echo "    Error: untrusted plugin root produced output: $output"
    return 1
  fi

  return 0
}

# ==================================================
# Test 9: decision/safety hooks を async 化していないか
# ==================================================
test_safety_hooks_remain_synchronous() {
  local hooks_file="$PROJECT_ROOT/hooks/hooks.json"
  local hook_name
  local missing=""
  local async_hooks=""
  local safety_hooks=(
    pre-tool
    pre-tool-use-file-lease
    permission
    post-tool
    quality-pack
    plans-watcher
    tdd-check
    stop-evaluator
  )

  for hook_name in "${safety_hooks[@]}"; do
    if ! jq -e --arg hook_name "$hook_name" '
      .. | objects
      | select(.command? | strings | test("hook " + $hook_name + "($|[[:space:]])"))
    ' "$hooks_file" >/dev/null 2>&1; then
      missing="${missing}${hook_name}, "
      continue
    fi
    if jq -e --arg hook_name "$hook_name" '
      .. | objects
      | select(.command? | strings | test("hook " + $hook_name + "($|[[:space:]])"))
      | select(.async == true)
    ' "$hooks_file" >/dev/null 2>&1; then
      async_hooks="${async_hooks}${hook_name}, "
    fi
  done

  if jq -e '.. | objects | select(.type? == "agent" and .async == true)' "$hooks_file" >/dev/null 2>&1; then
    async_hooks="${async_hooks}agent hook, "
  fi

  if [ -n "$missing" ]; then
    echo "    Error: missing safety hooks: ${missing%, }"
    return 1
  fi
  if [ -n "$async_hooks" ]; then
    echo "    Error: safety hooks must be synchronous: ${async_hooks%, }"
    return 1
  fi

  return 0
}

# ==================================================
# メイン実行
# ==================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Hooks 同期テスト"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# jq が利用可能か確認
if ! command -v jq &> /dev/null; then
  echo -e "${RED}Error: jq is required but not installed${NC}"
  exit 1
fi

run_test "両方の hooks.json が存在する" test_both_files_exist
run_test "hooks.json の内容が同一" test_files_identical
run_test "JSON が有効" test_valid_json
run_test "必須フックイベントが存在" test_required_hook_events
run_test "禁止された prompt 使用がない" test_no_forbidden_prompt_usage
run_test "CLAUDE_PLUGIN_ROOT 空時に /bin/harness へ落ちない" test_no_raw_plugin_root_harness_paths
run_test "CLAUDE_PLUGIN_ROOT 未設定でも hook command が root 解決できる" test_hook_command_resolves_without_plugin_root
run_test "identity 不一致の plugin root を拒否する" test_untrusted_plugin_root_is_rejected
run_test "decision/safety hooks が同期実行される" test_safety_hooks_remain_synchronous

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " テスト結果: $TESTS_PASSED/$TESTS_RUN passed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$TESTS_FAILED" -gt 0 ]; then
  exit 1
fi

exit 0
