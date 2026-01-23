#!/bin/bash
# session-auto-broadcast.sh
# ファイル変更時の自動ブロードキャスト
#
# PostToolUse (Write|Edit) で呼び出される
# 重要なファイル（API、型定義など）の変更時に自動通知
#
# 入力: stdin から JSON (tool_input を含む)
# 出力: JSON (hookSpecificOutput)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== 設定 =====
# 自動ブロードキャスト対象のパターン
AUTO_BROADCAST_PATTERNS=(
  "src/api/"
  "src/types/"
  "src/interfaces/"
  "api/"
  "types/"
  "schema.prisma"
  "openapi"
  "swagger"
  ".graphql"
)

# 設定ファイルパス
CONFIG_FILE=".claude/sessions/auto-broadcast.json"

# ===== stdin から JSON 入力を読み取り =====
INPUT=""
if [ -t 0 ]; then
  : # stdin が TTY の場合は入力なし
else
  INPUT=$(cat 2>/dev/null || true)
fi

# ===== ファイルパスを抽出 =====
FILE_PATH=""
if [ -n "$INPUT" ] && command -v jq >/dev/null 2>&1; then
  FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)"
fi

# ファイルパスがない場合は終了
if [ -z "$FILE_PATH" ]; then
  echo '{"hookSpecificOutput":{"hookEventName":"AutoBroadcast","additionalContext":""}}'
  exit 0
fi

# ===== 自動ブロードキャストが有効かチェック =====
AUTO_BROADCAST_ENABLED="true"
if [ -f "$CONFIG_FILE" ] && command -v jq >/dev/null 2>&1; then
  AUTO_BROADCAST_ENABLED="$(jq -r '.enabled // true' "$CONFIG_FILE" 2>/dev/null)"
fi

if [ "$AUTO_BROADCAST_ENABLED" != "true" ]; then
  echo '{"hookSpecificOutput":{"hookEventName":"AutoBroadcast","additionalContext":""}}'
  exit 0
fi

# ===== パターンマッチング =====
should_broadcast="false"
matched_pattern=""

for pattern in "${AUTO_BROADCAST_PATTERNS[@]}"; do
  if [[ "$FILE_PATH" == *"$pattern"* ]]; then
    should_broadcast="true"
    matched_pattern="$pattern"
    break
  fi
done

# カスタムパターンもチェック
if [ "$should_broadcast" = "false" ] && [ -f "$CONFIG_FILE" ] && command -v jq >/dev/null 2>&1; then
  CUSTOM_PATTERNS=$(jq -r '.patterns // [] | .[]' "$CONFIG_FILE" 2>/dev/null)
  while IFS= read -r pattern; do
    if [ -n "$pattern" ] && [[ "$FILE_PATH" == *"$pattern"* ]]; then
      should_broadcast="true"
      matched_pattern="$pattern"
      break
    fi
  done <<< "$CUSTOM_PATTERNS"
fi

# ===== ブロードキャスト実行 =====
if [ "$should_broadcast" = "true" ]; then
  # ファイル名を抽出
  FILE_NAME=$(basename "$FILE_PATH")

  # ブロードキャストを実行
  HOOK_OUTPUT=true bash "$SCRIPT_DIR/session-broadcast.sh" --auto "$FILE_PATH" "パターン '$matched_pattern' にマッチ" 2>/dev/null || true

  # 通知メッセージを出力
  cat <<EOF
{"hookSpecificOutput":{"hookEventName":"AutoBroadcast","additionalContext":"📢 自動ブロードキャスト: ${FILE_NAME} の変更を他セッションに通知しました"}}
EOF
else
  echo '{"hookSpecificOutput":{"hookEventName":"AutoBroadcast","additionalContext":""}}'
fi

exit 0
