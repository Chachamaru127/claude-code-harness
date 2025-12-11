#!/bin/bash
# track-changes.sh
# ファイル変更を追跡し、状態ファイルを更新
#
# Usage: PostToolUse hook から自動実行
# Input: $1 = tool_name, $2 = file_path (optional)

set +e

TOOL_NAME="${1:-unknown}"
FILE_PATH="${2:-}"
STATE_FILE=".claude/state/session.json"
CURRENT_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# 状態ファイルがなければスキップ
if [ ! -f "$STATE_FILE" ]; then
  exit 0
fi

# ファイルパスがなければスキップ
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# 重要なファイルの変更を検出
IMPORTANT_FILES="Plans.md CLAUDE.md AGENTS.md"
IS_IMPORTANT="false"

for important in $IMPORTANT_FILES; do
  if [[ "$FILE_PATH" == *"$important"* ]]; then
    IS_IMPORTANT="true"
    break
  fi
done

# テストファイルの検出
if [[ "$FILE_PATH" == *".test."* ]] || [[ "$FILE_PATH" == *".spec."* ]] || [[ "$FILE_PATH" == *"__tests__"* ]]; then
  IS_IMPORTANT="true"
fi

# 変更を記録（jq があれば使用、なければスキップ）
if command -v jq &> /dev/null; then
  # 新しい変更エントリを追加
  TEMP_FILE=$(mktemp)
  jq --arg file "$FILE_PATH" \
     --arg action "$TOOL_NAME" \
     --arg timestamp "$CURRENT_TIME" \
     --arg important "$IS_IMPORTANT" \
     '.changes_this_session += [{
       "file": $file,
       "action": $action,
       "timestamp": $timestamp,
       "important": ($important == "true")
     }]' "$STATE_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$STATE_FILE"
fi

# 重要なファイルの変更時は通知
if [ "$IS_IMPORTANT" = "true" ]; then
  case "$FILE_PATH" in
    *Plans.md*)
      echo "📋 Plans.md が更新されました"
      ;;
    *CLAUDE.md*)
      echo "📝 CLAUDE.md が更新されました"
      ;;
    *AGENTS.md*)
      echo "📝 AGENTS.md が更新されました"
      ;;
    *.test.*|*.spec.*|*__tests__*)
      echo "🧪 テストファイルが更新されました: $(basename "$FILE_PATH")"
      ;;
  esac
fi

exit 0
