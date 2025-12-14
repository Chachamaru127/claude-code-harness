#!/bin/bash
# plans-watcher.sh - Plans.md の変更を監視し、PM への通知を生成（互換: cursor:*）
# PostToolUse フックから呼び出される

set +e  # エラーで停止しない

# 変更されたファイルを取得（stdin JSON優先 / 互換: $1,$2）
INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

CHANGED_FILE="${1:-}"
TOOL_NAME="${2:-}"
CWD=""

if [ -n "$INPUT" ]; then
  if command -v jq >/dev/null 2>&1; then
    TOOL_NAME_FROM_STDIN="$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"
    FILE_PATH_FROM_STDIN="$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_response.filePath // empty' 2>/dev/null)"
    CWD_FROM_STDIN="$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)"
  elif command -v python3 >/dev/null 2>&1; then
    eval "$(echo "$INPUT" | python3 - <<'PY' 2>/dev/null
import json, shlex, sys
try:
    data = json.load(sys.stdin)
except Exception:
    data = {}
tool_name = data.get("tool_name") or ""
cwd = data.get("cwd") or ""
tool_input = data.get("tool_input") or {}
tool_response = data.get("tool_response") or {}
file_path = tool_input.get("file_path") or tool_response.get("filePath") or ""
print(f"TOOL_NAME_FROM_STDIN={shlex.quote(tool_name)}")
print(f"CWD_FROM_STDIN={shlex.quote(cwd)}")
print(f"FILE_PATH_FROM_STDIN={shlex.quote(file_path)}")
PY
)"
  fi

  [ -z "$CHANGED_FILE" ] && CHANGED_FILE="${FILE_PATH_FROM_STDIN:-}"
  [ -z "$TOOL_NAME" ] && TOOL_NAME="${TOOL_NAME_FROM_STDIN:-}"
  CWD="${CWD_FROM_STDIN:-}"
fi

# 可能ならプロジェクト相対パスへ正規化
if [ -n "$CWD" ] && [ -n "$CHANGED_FILE" ] && [[ "$CHANGED_FILE" == "$CWD/"* ]]; then
  CHANGED_FILE="${CHANGED_FILE#$CWD/}"
fi

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
if [ -z "$PLANS_FILE" ]; then
    exit 0
fi

case "$CHANGED_FILE" in
    "$PLANS_FILE"|*/"$PLANS_FILE") ;;
    *) exit 0 ;;
esac

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

# 現在の状態を取得（pm:* を正規。cursor:* は互換で同義扱い）
PM_PENDING=$(( $(count_markers "pm:依頼中") + $(count_markers "cursor:依頼中") ))
CC_TODO=$(count_markers "cc:TODO")
CC_WIP=$(count_markers "cc:WIP")
CC_DONE=$(count_markers "cc:完了")
PM_CONFIRMED=$(( $(count_markers "pm:確認済") + $(count_markers "cursor:確認済") ))

# 新しいタスクを検出
NEW_TASKS=""
if [ -f "$PREV_STATE_FILE" ]; then
    PREV_PM_PENDING=$(jq -r '.pm_pending // 0' "$PREV_STATE_FILE" 2>/dev/null || echo "0")
    if [ "$PM_PENDING" -gt "$PREV_PM_PENDING" ] 2>/dev/null; then
        NEW_TASKS="pm:依頼中"
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
  "pm_pending": $PM_PENDING,
  "cc_todo": $CC_TODO,
  "cc_wip": $CC_WIP,
  "cc_done": $CC_DONE,
  "pm_confirmed": $PM_CONFIRMED
}
EOF

# 通知を生成
generate_notification() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Plans.md 更新検知"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ -n "$NEW_TASKS" ]; then
        echo "🆕 新規タスク: PM から依頼あり"
        echo "   → /start-task で確認してください"
    fi

    if [ -n "$COMPLETED_TASKS" ]; then
        echo "✅ タスク完了: PM へ報告可能"
        echo "   → /handoff-to-pm-claude（または /handoff-to-cursor）で報告してください"
    fi

    echo ""
    echo "📊 現在のステータス:"
    echo "   pm:依頼中      : $PM_PENDING 件（互換: cursor:依頼中）"
    echo "   cc:TODO        : $CC_TODO 件"
    echo "   cc:WIP         : $CC_WIP 件"
    echo "   cc:完了        : $CC_DONE 件"
    echo "   pm:確認済      : $PM_CONFIRMED 件（互換: cursor:確認済）"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# 変更がある場合のみ通知
if [ -n "$NEW_TASKS" ] || [ -n "$COMPLETED_TASKS" ]; then
    generate_notification
fi

# PM 通知用のファイルを生成（2ロール運用の連携用）
if [ -n "$NEW_TASKS" ] || [ -n "$COMPLETED_TASKS" ]; then
    PM_NOTIFICATION_FILE="${STATE_DIR}/pm-notification.md"
    CURSOR_NOTIFICATION_FILE="${STATE_DIR}/cursor-notification.md" # 互換
    cat > "$PM_NOTIFICATION_FILE" << EOF
# PM への通知

**生成日時**: $(date +"%Y-%m-%d %H:%M:%S")

## ステータス変更

EOF

    if [ -n "$NEW_TASKS" ]; then
        echo "### 🆕 新規タスク" >> "$PM_NOTIFICATION_FILE"
        echo "" >> "$PM_NOTIFICATION_FILE"
        echo "PM から新しいタスクが依頼されました（pm:依頼中 / 互換: cursor:依頼中）。" >> "$PM_NOTIFICATION_FILE"
        echo "" >> "$PM_NOTIFICATION_FILE"
    fi

    if [ -n "$COMPLETED_TASKS" ]; then
        echo "### ✅ 完了タスク" >> "$PM_NOTIFICATION_FILE"
        echo "" >> "$PM_NOTIFICATION_FILE"
        echo "Impl Claude がタスクを完了しました。レビューをお願いします（cc:完了）。" >> "$PM_NOTIFICATION_FILE"
        echo "" >> "$PM_NOTIFICATION_FILE"
    fi

    echo "---" >> "$PM_NOTIFICATION_FILE"
    echo "" >> "$PM_NOTIFICATION_FILE"
    echo "**次のアクション**: PM Claude でレビューし、必要なら再依頼（/handoff-to-impl-claude）。" >> "$PM_NOTIFICATION_FILE"

    # 互換: 旧ファイル名にも同内容を出力
    cp -f "$PM_NOTIFICATION_FILE" "$CURSOR_NOTIFICATION_FILE" 2>/dev/null || true
fi
