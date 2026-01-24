#!/bin/bash
# session-list.sh
# アクティブセッション一覧を表示
#
# 使用方法:
#   ./session-list.sh
#
# 出力: アクティブセッション一覧

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== Cleanup trap for temp files =====
TEMP_FILES=()
cleanup() {
  for f in "${TEMP_FILES[@]:-}"; do
    [ -f "$f" ] && rm -f "$f"
  done
}
trap cleanup EXIT

# ===== 設定 =====
SESSIONS_DIR=".claude/sessions"
ACTIVE_FILE="${SESSIONS_DIR}/active.json"
SESSION_FILE=".claude/state/session.json"
STALE_THRESHOLD=3600  # 1時間経過したセッションは stale とみなす

# ===== ヘルパー関数 =====
get_current_session_id() {
  if [ -f "$SESSION_FILE" ] && command -v jq >/dev/null 2>&1; then
    jq -r '.session_id // "unknown"' "$SESSION_FILE" 2>/dev/null
  else
    echo "unknown"
  fi
}

get_current_timestamp() {
  date +%s
}

# ===== メイン処理 =====
main() {
  mkdir -p "$SESSIONS_DIR"

  local current_session=$(get_current_session_id)
  local current_time=$(get_current_timestamp)

  # 現在のセッションを登録/更新
  if [ -n "$current_session" ] && [ "$current_session" != "unknown" ]; then
    local session_data="{}"

    if [ -f "$ACTIVE_FILE" ] && command -v jq >/dev/null 2>&1; then
      session_data=$(cat "$ACTIVE_FILE")
    fi

    if command -v jq >/dev/null 2>&1; then
      local short_id="${current_session:0:12}"
      local tmp_file=$(mktemp)
      TEMP_FILES+=("$tmp_file")

      echo "$session_data" | jq \
        --arg id "$current_session" \
        --arg short "$short_id" \
        --arg time "$current_time" \
        --arg pid "$$" \
        '.[$id] = {
          "short_id": $short,
          "last_seen": ($time | tonumber),
          "pid": $pid,
          "status": "active"
        }' > "$tmp_file" && mv "$tmp_file" "$ACTIVE_FILE"
    fi
  fi

  # セッション一覧を表示
  echo "📋 アクティブセッション一覧"
  echo ""

  if [ ! -f "$ACTIVE_FILE" ]; then
    echo "  (セッションなし)"
    exit 0
  fi

  if ! command -v jq >/dev/null 2>&1; then
    echo "  ⚠️ jq がインストールされていないため詳細表示できません"
    exit 0
  fi

  # 古いセッションをクリーンアップしながら表示
  local active_count=0
  local stale_count=0

  echo "| セッションID | 最終アクティブ | 状態 |"
  echo "|-------------|---------------|------|"

  # セッションを処理
  jq -r 'to_entries[] | "\(.key)|\(.value.short_id)|\(.value.last_seen)|\(.value.status)"' "$ACTIVE_FILE" 2>/dev/null | while IFS='|' read -r full_id short_id last_seen status; do
    local age=$((current_time - last_seen))
    local time_ago=""
    local display_status=""

    if [ "$age" -lt 60 ]; then
      time_ago="${age}秒前"
    elif [ "$age" -lt 3600 ]; then
      time_ago="$((age / 60))分前"
    elif [ "$age" -lt 86400 ]; then
      time_ago="$((age / 3600))時間前"
    else
      time_ago="$((age / 86400))日前"
    fi

    if [ "$full_id" = "$current_session" ]; then
      display_status="🟢 現在のセッション"
    elif [ "$age" -lt "$STALE_THRESHOLD" ]; then
      display_status="🟡 アクティブ"
    else
      display_status="⚪ 非アクティブ"
    fi

    echo "| ${short_id} | ${time_ago} | ${display_status} |"
  done

  echo ""
  echo "💡 ヒント:"
  echo "  - /session-broadcast \"メッセージ\" で全セッションに通知"
  echo "  - /session-inbox で受信メッセージを確認"
}

main "$@"
