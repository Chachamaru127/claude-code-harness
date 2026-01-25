#!/bin/bash
# test-harness-ui-register.sh
# harness-ui-register.sh のユニットテスト

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTER_SCRIPT="$SCRIPT_DIR/harness-ui-register.sh"
TEST_BASE="/tmp/harness-ui-register-tests"
PASSED=0
FAILED=0

# カラー出力
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() {
  echo -e "${GREEN}✓ PASS${NC}: $1"
  ((PASSED++))
}

fail() {
  echo -e "${RED}✗ FAIL${NC}: $1 (expected: $2, got: $3)"
  ((FAILED++))
}

setup() {
  rm -rf "$TEST_BASE"
  mkdir -p "$TEST_BASE"
}

cleanup() {
  rm -rf "$TEST_BASE"
  # harness-ui からテストプロジェクトを削除
  if curl -s --connect-timeout 1 http://localhost:37778/api/sync-status >/dev/null 2>&1; then
    for id in $(curl -s http://localhost:37778/api/projects 2>/dev/null | jq -r '.projects[]? | select(.path | startswith("'"$TEST_BASE"'")) | .id' 2>/dev/null); do
      curl -s -X DELETE "http://localhost:37778/api/projects/$id" >/dev/null 2>&1 || true
    done
  fi
}

run_script() {
  local dir="$1"
  (cd "$dir" && bash "$REGISTER_SCRIPT" 2>/dev/null)
}

was_registered() {
  echo "$1" | grep -q "プロジェクト登録"
}

echo -e "${YELLOW}========================================"
echo "  harness-ui-register.sh テスト"
echo -e "========================================${NC}"
echo ""

setup

# Test 1: .claude-code-harness-version あり
echo -e "${YELLOW}Test 1: .claude-code-harness-version ファイルあり${NC}"
TEST_DIR="$TEST_BASE/test1"
mkdir -p "$TEST_DIR"
echo "2.5.0" > "$TEST_DIR/.claude-code-harness-version"
OUTPUT=$(run_script "$TEST_DIR")
if was_registered "$OUTPUT"; then
  pass ".claude-code-harness-version があれば登録される"
else
  fail ".claude-code-harness-version があれば登録される" "registered" "not registered"
fi

# Test 2: Plans.md に cc:TODO マーカー
echo -e "${YELLOW}Test 2: Plans.md に cc:TODO マーカー${NC}"
TEST_DIR="$TEST_BASE/test2"
mkdir -p "$TEST_DIR"
echo '## Task `cc:TODO`' > "$TEST_DIR/Plans.md"
OUTPUT=$(run_script "$TEST_DIR")
if was_registered "$OUTPUT"; then
  pass "Plans.md に cc:TODO があれば登録される"
else
  fail "Plans.md に cc:TODO があれば登録される" "registered" "not registered"
fi

# Test 3: Plans.md に cc:WIP マーカー
echo -e "${YELLOW}Test 3: Plans.md に cc:WIP マーカー${NC}"
TEST_DIR="$TEST_BASE/test3"
mkdir -p "$TEST_DIR"
echo '## Task `cc:WIP`' > "$TEST_DIR/Plans.md"
OUTPUT=$(run_script "$TEST_DIR")
if was_registered "$OUTPUT"; then
  pass "Plans.md に cc:WIP があれば登録される"
else
  fail "Plans.md に cc:WIP があれば登録される" "registered" "not registered"
fi

# Test 4: Plans.md に cc:DONE マーカー
echo -e "${YELLOW}Test 4: Plans.md に cc:DONE マーカー${NC}"
TEST_DIR="$TEST_BASE/test4"
mkdir -p "$TEST_DIR"
echo '## Task `cc:DONE`' > "$TEST_DIR/Plans.md"
OUTPUT=$(run_script "$TEST_DIR")
if was_registered "$OUTPUT"; then
  pass "Plans.md に cc:DONE があれば登録される"
else
  fail "Plans.md に cc:DONE があれば登録される" "registered" "not registered"
fi

# Test 5: Plans.md に pm:依頼中 マーカー
echo -e "${YELLOW}Test 5: Plans.md に pm:依頼中 マーカー${NC}"
TEST_DIR="$TEST_BASE/test5"
mkdir -p "$TEST_DIR"
echo '## Task `pm:依頼中`' > "$TEST_DIR/Plans.md"
OUTPUT=$(run_script "$TEST_DIR")
if was_registered "$OUTPUT"; then
  pass "Plans.md に pm:依頼中 があれば登録される"
else
  fail "Plans.md に pm:依頼中 があれば登録される" "registered" "not registered"
fi

# Test 6: 普通の Plans.md（マーカーなし）→ 登録されない
echo -e "${YELLOW}Test 6: 普通の Plans.md（マーカーなし）${NC}"
TEST_DIR="$TEST_BASE/test6"
mkdir -p "$TEST_DIR"
echo '# My Plans
- Do something' > "$TEST_DIR/Plans.md"
OUTPUT=$(run_script "$TEST_DIR")
if was_registered "$OUTPUT"; then
  fail "マーカーなし Plans.md は登録されない" "not registered" "registered"
else
  pass "マーカーなし Plans.md は登録されない"
fi

# Test 7: 何もないディレクトリ → 登録されない
echo -e "${YELLOW}Test 7: 何もないディレクトリ${NC}"
TEST_DIR="$TEST_BASE/test7"
mkdir -p "$TEST_DIR"
OUTPUT=$(run_script "$TEST_DIR")
if was_registered "$OUTPUT"; then
  fail "空ディレクトリは登録されない" "not registered" "registered"
else
  pass "空ディレクトリは登録されない"
fi

# Test 8: cc:WORK マーカー
echo -e "${YELLOW}Test 8: Plans.md に cc:WORK マーカー${NC}"
TEST_DIR="$TEST_BASE/test8"
mkdir -p "$TEST_DIR"
echo '## Task `cc:WORK`' > "$TEST_DIR/Plans.md"
OUTPUT=$(run_script "$TEST_DIR")
if was_registered "$OUTPUT"; then
  pass "Plans.md に cc:WORK があれば登録される"
else
  fail "Plans.md に cc:WORK があれば登録される" "registered" "not registered"
fi

# 結果サマリー
echo ""
echo -e "${YELLOW}========================================"
echo "  テスト結果"
echo -e "========================================${NC}"
echo -e "  ${GREEN}Passed${NC}: $PASSED"
echo -e "  ${RED}Failed${NC}: $FAILED"
echo "  Total: $((PASSED + FAILED))"

cleanup

if [ $FAILED -eq 0 ]; then
  echo -e "\n${GREEN}All tests passed!${NC}"
  exit 0
else
  echo -e "\n${RED}Some tests failed.${NC}"
  exit 1
fi
