#!/bin/bash
# ======================================
# tmux を使った Claude 評価スクリプト
# ======================================
#
# Usage:
#   ./run-with-tmux.sh "プロンプト" [モード] [タイムアウト秒]
#
# モード:
#   with-plugin: /plan-with-agent を付けて実行
#   no-plugin: プロンプトのみで実行

set -e

PROMPT="$1"
MODE="${2:-no-plugin}"
TIMEOUT="${3:-180}"
SESSION_NAME="eval-$$"
RESULT_DIR="/tmp/claude-eval-results"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

mkdir -p "$RESULT_DIR"

if [[ -z "$PROMPT" ]]; then
    echo "Usage: $0 \"プロンプト\" [with-plugin|no-plugin] [timeout]"
    exit 1
fi

# フルプロンプトの構築
FULL_PROMPT="$PROMPT"
if [[ "$MODE" == "with-plugin" ]]; then
    FULL_PROMPT="/claude-code-harness:core:plan-with-agent $PROMPT"
fi

echo "=== Claude 評価 ($MODE) ==="
echo "プロンプト: $FULL_PROMPT"
echo "タイムアウト: ${TIMEOUT}s"

# 作業ディレクトリを設定
WORK_DIR="${WORK_DIR:-$(pwd)}"

# tmux セッションを作成
tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true
tmux new-session -d -s "$SESSION_NAME" "bash"

# 作業ディレクトリに移動
tmux send-keys -t "$SESSION_NAME" "cd '$WORK_DIR'" Enter
sleep 1

# Claude を起動
tmux send-keys -t "$SESSION_NAME" "claude --dangerously-skip-permissions" Enter
sleep 5

# プロンプトを送信
tmux send-keys -t "$SESSION_NAME" "$FULL_PROMPT" Enter

# 応答を待つ
echo "応答待ち..."
ELAPSED=0
INTERVAL=10

while [[ $ELAPSED -lt $TIMEOUT ]]; do
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))

    # 画面をキャプチャ
    SCREEN=$(tmux capture-pane -t "$SESSION_NAME" -p -S -50 2>/dev/null)

    # 質問が来たら Enter で進む
    if echo "$SCREEN" | grep -q "Enter to select"; then
        tmux send-keys -t "$SESSION_NAME" Enter
        continue
    fi

    # 入力待ちになったら完了
    if echo "$SCREEN" | grep -qE "^❯\\s*$"; then
        echo "完了 (${ELAPSED}s)"
        break
    fi

    echo "  ... ${ELAPSED}s"
done

# 最終画面をキャプチャ
FINAL_OUTPUT=$(tmux capture-pane -t "$SESSION_NAME" -p -S -200)

# 結果を保存
RESULT_FILE="$RESULT_DIR/${MODE}_${TIMESTAMP}.txt"
echo "$FINAL_OUTPUT" > "$RESULT_FILE"
echo "結果: $RESULT_FILE"

# セッションを終了
tmux send-keys -t "$SESSION_NAME" C-c
sleep 2
tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true

# 生成されたファイルを確認
echo ""
echo "=== 生成ファイル ==="
if [[ -f "$WORK_DIR/Plans.md" ]]; then
    echo "✅ Plans.md"
    PLANS_TASKS=$(grep -c '^\s*- \[' "$WORK_DIR/Plans.md" 2>/dev/null || echo 0)
    echo "   タスク数: $PLANS_TASKS"
else
    echo "❌ Plans.md なし"
fi

TEST_COUNT=$(find "$WORK_DIR" -name '*.test.ts' -o -name '*.spec.ts' 2>/dev/null | wc -l | tr -d ' ')
echo "テストファイル: $TEST_COUNT"

echo ""
echo "=== 完了 ==="
