#!/bin/bash
# plans-watcher.sh - Plans.md の変更を監視し、Cursor (PM) への通知を生成
# PostToolUse フックから呼び出される

set +e  # エラーで停止しない

# 変更されたファイルを取得
CHANGED_FILE="${1:-}"
TOOL_NAME="${2:-}"

# Plans.md のパス（大文字小文字を区別しない）
find_plans_file() {
    for f in Plans.md plans.md PLANS.md PLANS.MD; do
        if [ -f "$f" ]; then
            echo "$f"
            return 0
        fi
    done
    return 1
}

PLANS_FILE=$(find_plans_file)

# Plans.md 以外の変更はスキップ
if [ -z "$PLANS_FILE" ] || [ "$CHANGED_FILE" != "$PLANS_FILE" ]; then
    exit 0
fi

# 状態ディレクトリ
STATE_DIR=".claude/state"
mkdir -p "$STATE_DIR"

# 前回の状態を取得
PREV_STATE_FILE="${STATE_DIR}/plans-state.json"

# マーカーをカウント
count_markers() {
    local marker=$1
    local count=0
    if [ -f "$PLANS_FILE" ]; then
        count=$(grep -c "$marker" "$PLANS_FILE" 2>/dev/null || true)
        [ -z "$count" ] && count=0
    fi
    echo "$count"
}

# 現在の状態を取得
CURSOR_PENDING=$(count_markers "cursor:依頼中")
CC_TODO=$(count_markers "cc:TODO")
CC_WIP=$(count_markers "cc:WIP")
CC_DONE=$(count_markers "cc:完了")
CURSOR_CONFIRMED=$(count_markers "cursor:確認済")

# 新しいタスクを検出
NEW_TASKS=""
if [ -f "$PREV_STATE_FILE" ]; then
    PREV_CURSOR_PENDING=$(jq -r '.cursor_pending // 0' "$PREV_STATE_FILE" 2>/dev/null || echo "0")
    if [ "$CURSOR_PENDING" -gt "$PREV_CURSOR_PENDING" ] 2>/dev/null; then
        NEW_TASKS="cursor:依頼中"
    fi
fi

# 完了タスクを検出
COMPLETED_TASKS=""
if [ -f "$PREV_STATE_FILE" ]; then
    PREV_CC_DONE=$(jq -r '.cc_done // 0' "$PREV_STATE_FILE" 2>/dev/null || echo "0")
    if [ "$CC_DONE" -gt "$PREV_CC_DONE" ] 2>/dev/null; then
        COMPLETED_TASKS="cc:完了"
    fi
fi

# 状態を保存
cat > "$PREV_STATE_FILE" << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "cursor_pending": $CURSOR_PENDING,
  "cc_todo": $CC_TODO,
  "cc_wip": $CC_WIP,
  "cc_done": $CC_DONE,
  "cursor_confirmed": $CURSOR_CONFIRMED
}
EOF

# 通知を生成
generate_notification() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Plans.md 更新検知"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ -n "$NEW_TASKS" ]; then
        echo "🆕 新規タスク: Cursor から依頼あり"
        echo "   → /start-task で確認してください"
    fi

    if [ -n "$COMPLETED_TASKS" ]; then
        echo "✅ タスク完了: Cursor へ報告可能"
        echo "   → /handoff-to-cursor で報告してください"
    fi

    echo ""
    echo "📊 現在のステータス:"
    echo "   cursor:依頼中  : $CURSOR_PENDING 件"
    echo "   cc:TODO        : $CC_TODO 件"
    echo "   cc:WIP         : $CC_WIP 件"
    echo "   cc:完了        : $CC_DONE 件"
    echo "   cursor:確認済  : $CURSOR_CONFIRMED 件"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# 変更がある場合のみ通知
if [ -n "$NEW_TASKS" ] || [ -n "$COMPLETED_TASKS" ]; then
    generate_notification
fi

# Cursor 通知用のファイルを生成（2エージェント間の連携用）
if [ -n "$NEW_TASKS" ] || [ -n "$COMPLETED_TASKS" ]; then
    NOTIFICATION_FILE="${STATE_DIR}/cursor-notification.md"
    cat > "$NOTIFICATION_FILE" << EOF
# Cursor (PM) への通知

**生成日時**: $(date +"%Y-%m-%d %H:%M:%S")

## ステータス変更

EOF

    if [ -n "$NEW_TASKS" ]; then
        echo "### 🆕 新規タスク" >> "$NOTIFICATION_FILE"
        echo "" >> "$NOTIFICATION_FILE"
        echo "Cursor から新しいタスクが依頼されました。" >> "$NOTIFICATION_FILE"
        echo "" >> "$NOTIFICATION_FILE"
    fi

    if [ -n "$COMPLETED_TASKS" ]; then
        echo "### ✅ 完了タスク" >> "$NOTIFICATION_FILE"
        echo "" >> "$NOTIFICATION_FILE"
        echo "Claude Code がタスクを完了しました。レビューをお願いします。" >> "$NOTIFICATION_FILE"
        echo "" >> "$NOTIFICATION_FILE"
    fi

    echo "---" >> "$NOTIFICATION_FILE"
    echo "" >> "$NOTIFICATION_FILE"
    echo "**次のアクション**: Cursor で \`/review-cc-work\` を実行してください。" >> "$NOTIFICATION_FILE"
fi
