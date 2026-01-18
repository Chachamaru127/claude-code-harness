#!/bin/bash
# test-session-state.sh
# session-state.sh の単体テスト
#
# Usage: ./tests/test-session-state.sh

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
SESSION_STATE_SCRIPT="$PLUGIN_ROOT/scripts/session-state.sh"

# テスト用一時ディレクトリ
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

cd "$TEST_DIR"

# カラー出力
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
echo "session-state.sh 単体テスト"
echo "=========================================="
echo ""

# スクリプトの存在確認
if [ ! -f "$SESSION_STATE_SCRIPT" ]; then
  fail_test "session-state.sh が見つかりません: $SESSION_STATE_SCRIPT"
  exit 1
fi

if [ ! -x "$SESSION_STATE_SCRIPT" ]; then
  fail_test "session-state.sh に実行権限がありません"
  exit 1
fi

pass_test "session-state.sh が存在し実行権限があります"

echo ""
echo "1. 初期状態からの遷移テスト"
echo "----------------------------------------"

# idle → initialized (session.start)
if "$SESSION_STATE_SCRIPT" --state initialized --event session.start >/dev/null 2>&1; then
  pass_test "idle → initialized (session.start)"
else
  fail_test "idle → initialized (session.start)"
fi

# session.json の確認
if [ -f ".claude/state/session.json" ]; then
  pass_test "session.json が作成されました"

  # state フィールドの確認
  if command -v jq >/dev/null 2>&1; then
    state=$(jq -r '.state' .claude/state/session.json 2>/dev/null)
    if [ "$state" = "initialized" ]; then
      pass_test "state = initialized"
    else
      fail_test "state が 'initialized' ではありません: $state"
    fi
  fi
else
  fail_test "session.json が作成されませんでした"
fi

echo ""
echo "2. 正常な状態遷移テスト"
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
echo "3. ワイルドカード遷移テスト (任意の状態 → stopped)"
echo "----------------------------------------"

# completed → stopped (session.stop)
if "$SESSION_STATE_SCRIPT" --state stopped --event session.stop >/dev/null 2>&1; then
  pass_test "completed → stopped (session.stop)"
else
  fail_test "completed → stopped (session.stop)"
fi

echo ""
echo "4. 無効な遷移テスト"
echo "----------------------------------------"

# stopped → completed は許可されていない
if "$SESSION_STATE_SCRIPT" --state completed --event verify.passed 2>/dev/null; then
  fail_test "stopped → completed (verify.passed) が許可されました（期待: 拒否）"
else
  pass_test "stopped → completed (verify.passed) が正しく拒否されました"
fi

echo ""
echo "5. イベントログのテスト"
echo "----------------------------------------"

if [ -f ".claude/state/session.events.jsonl" ]; then
  pass_test "session.events.jsonl が作成されました"

  EVENT_COUNT=$(wc -l < .claude/state/session.events.jsonl | tr -d ' ')
  if [ "$EVENT_COUNT" -gt 0 ]; then
    pass_test "イベントログに $EVENT_COUNT 件のエントリがあります"
  else
    fail_test "イベントログが空です"
  fi

  # 最後のイベントを確認
  if command -v jq >/dev/null 2>&1; then
    LAST_EVENT=$(tail -n 1 .claude/state/session.events.jsonl)
    LAST_STATE=$(echo "$LAST_EVENT" | jq -r '.state' 2>/dev/null)
    if [ "$LAST_STATE" = "stopped" ]; then
      pass_test "最後のイベントの state = stopped"
    else
      fail_test "最後のイベントの state が 'stopped' ではありません: $LAST_STATE"
    fi
  fi
else
  fail_test "session.events.jsonl が作成されませんでした"
fi

echo ""
echo "=========================================="
echo "テスト結果サマリー"
echo "=========================================="
echo -e "${GREEN}合格:${NC} $PASS_COUNT"
echo -e "${RED}失敗:${NC} $FAIL_COUNT"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
  echo -e "${GREEN}✓ 全てのテストに合格しました！${NC}"
  exit 0
else
  echo -e "${RED}✗ $FAIL_COUNT 件のテストが失敗しました${NC}"
  exit 1
fi
