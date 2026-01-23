#!/bin/bash
# pretooluse-inbox-check.sh
# PreToolUse Hook: ツール実行前に未読メッセージをチェック
#
# Write|Edit 実行前に他セッションからのメッセージを確認し、
# 重要な変更通知を見逃さないようにする
#
# 入力: stdin から JSON
# 出力: JSON (hookSpecificOutput)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== 設定 =====
SESSIONS_DIR=".claude/sessions"
BROADCAST_FILE="${SESSIONS_DIR}/broadcast.md"
SESSION_FILE=".claude/state/session.json"
CHECK_INTERVAL_FILE="${SESSIONS_DIR}/.last_inbox_check"
CHECK_INTERVAL=300  # 5分ごとにチェック（頻繁すぎる通知を防ぐ）

# ===== stdin から JSON 入力を読み取り =====
INPUT=""
if [ -t 0 ]; then
  : # stdin が TTY の場合は入力なし
else
  INPUT=$(cat 2>/dev/null || true)
fi

# ===== チェック間隔の確認 =====
current_time=$(date +%s)
last_check=0

if [ -f "$CHECK_INTERVAL_FILE" ]; then
  last_check=$(cat "$CHECK_INTERVAL_FILE" 2>/dev/null || echo "0")
fi

time_since_check=$((current_time - last_check))

# チェック間隔内の場合はスキップ
if [ "$time_since_check" -lt "$CHECK_INTERVAL" ]; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":""}}'
  exit 0
fi

# チェック時刻を更新
mkdir -p "$SESSIONS_DIR"
echo "$current_time" > "$CHECK_INTERVAL_FILE"

# ===== 未読メッセージをチェック =====
if [ ! -f "$BROADCAST_FILE" ]; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":""}}'
  exit 0
fi

# inbox-check スクリプトを使用
UNREAD_COUNT=$(bash "$SCRIPT_DIR/session-inbox-check.sh" --count 2>/dev/null || echo "0")

if [ "$UNREAD_COUNT" -gt 0 ]; then
  # 未読メッセージの概要を取得
  INBOX_SUMMARY=$(bash "$SCRIPT_DIR/session-inbox-check.sh" 2>/dev/null | head -5 || echo "")

  # エスケープ処理
  ESCAPED_SUMMARY=$(echo "$INBOX_SUMMARY" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n' | sed 's/\\n$//')

  cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"📨 他セッションからの未読メッセージが ${UNREAD_COUNT}件 あります。\\n/session-inbox で確認してください。"}}
EOF
else
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":""}}'
fi

exit 0
