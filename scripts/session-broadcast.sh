#!/bin/bash
# session-broadcast.sh
# セッション間ブロードキャストメッセージ送信
#
# 使用方法:
#   ./session-broadcast.sh "メッセージ"
#   ./session-broadcast.sh --auto "ファイル名" "変更内容"
#
# 出力: ブロードキャストメッセージを .claude/sessions/broadcast.md に追記

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
BROADCAST_FILE="${SESSIONS_DIR}/broadcast.md"
SESSION_FILE=".claude/state/session.json"
MAX_MESSAGES=100  # 最大保持メッセージ数

# ===== ヘルパー関数 =====
get_session_id() {
  if [ -f "$SESSION_FILE" ] && command -v jq >/dev/null 2>&1; then
    jq -r '.session_id // "unknown"' "$SESSION_FILE" 2>/dev/null
  else
    echo "session-$(date +%s)"
  fi
}

get_timestamp() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

# ===== メイン処理 =====
main() {
  local mode="manual"
  local message=""
  local file_path=""

  # 引数解析
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --auto)
        mode="auto"
        shift
        if [[ $# -ge 2 ]]; then
          file_path="$1"
          message="$2"
          shift 2
        else
          echo "Error: --auto requires <file_path> <message>" >&2
          exit 1
        fi
        ;;
      --help|-h)
        echo "Usage: session-broadcast.sh [--auto <file> <msg>] <message>"
        echo ""
        echo "Options:"
        echo "  --auto <file> <msg>  Auto-broadcast for file changes"
        echo "  --help               Show this help"
        exit 0
        ;;
      *)
        message="$1"
        shift
        ;;
    esac
  done

  if [ -z "$message" ]; then
    echo "Error: Message is required" >&2
    exit 1
  fi

  # ディレクトリ作成
  mkdir -p "$SESSIONS_DIR"

  # セッションIDとタイムスタンプを取得
  local session_id=$(get_session_id)
  local timestamp=$(get_timestamp)
  local short_id="${session_id:0:12}"

  # メッセージ種別のプレフィックス
  local prefix=""
  if [ "$mode" = "auto" ]; then
    prefix="[AUTO] "
    message="📁 \`${file_path}\` が変更されました: ${message}"
  fi

  # ブロードキャストファイルに追記
  {
    echo ""
    echo "## ${timestamp} [${short_id}]"
    echo "${prefix}${message}"
  } >> "$BROADCAST_FILE"

  # 古いメッセージを削除（MAX_MESSAGES を超えた場合）
  if [ -f "$BROADCAST_FILE" ]; then
    local msg_count=$(grep -c "^## " "$BROADCAST_FILE" 2>/dev/null || echo "0")
    if [ "$msg_count" -gt "$MAX_MESSAGES" ]; then
      # 最新の MAX_MESSAGES 件のみ保持
      local temp_file=$(mktemp)
      TEMP_FILES+=("$temp_file")
      local skip_count=$((msg_count - MAX_MESSAGES))
      awk -v skip="$skip_count" '
        /^## / { count++ }
        count > skip { print }
      ' "$BROADCAST_FILE" > "$temp_file"
      mv "$temp_file" "$BROADCAST_FILE"
    fi
  fi

  # 成功メッセージを出力
  echo "📤 Broadcast sent: ${message:0:50}..."

  # JSON 出力（hooks 用）
  if [ "${HOOK_OUTPUT:-}" = "true" ]; then
    cat <<EOF
{"hookSpecificOutput":{"hookEventName":"Broadcast","additionalContext":"📤 ブロードキャスト送信: ${message:0:50}..."}}
EOF
  fi
}

main "$@"
