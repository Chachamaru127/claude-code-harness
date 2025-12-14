#!/bin/bash
# auto-cleanup-hook.sh
# PostToolUse Hook: Plans.md 等への書き込み後に自動でサイズチェック
#
# 環境変数:
#   $CLAUDE_FILE_PATHS - 変更されたファイルパス（スペース区切り）
#
# 設定:
#   .claude-code-harness.config.yaml で閾値をカスタマイズ可能

# デフォルト閾値
PLANS_MAX_LINES=${PLANS_MAX_LINES:-200}
SESSION_LOG_MAX_LINES=${SESSION_LOG_MAX_LINES:-500}
CLAUDE_MD_MAX_LINES=${CLAUDE_MD_MAX_LINES:-100}

# 設定ファイルがあれば読み込み
CONFIG_FILE=".claude-code-harness.config.yaml"
if [ -f "$CONFIG_FILE" ]; then
  # 簡易 YAML パース
  PLANS_MAX_LINES=$(grep -A5 "plans:" "$CONFIG_FILE" | grep "max_lines:" | head -1 | awk '{print $2}' || echo $PLANS_MAX_LINES)
  SESSION_LOG_MAX_LINES=$(grep -A5 "session_log:" "$CONFIG_FILE" | grep "max_lines:" | head -1 | awk '{print $2}' || echo $SESSION_LOG_MAX_LINES)
  CLAUDE_MD_MAX_LINES=$(grep -A5 "claude_md:" "$CONFIG_FILE" | grep "max_lines:" | head -1 | awk '{print $2}' || echo $CLAUDE_MD_MAX_LINES)
fi

# フィードバックを格納する変数
FEEDBACK=""

# 各ファイルをチェック
for file in $CLAUDE_FILE_PATHS; do
  # Plans.md のチェック
  if [[ "$file" == *"Plans.md"* ]] || [[ "$file" == *"plans.md"* ]] || [[ "$file" == *"PLANS.MD"* ]]; then
    if [ -f "$file" ]; then
      lines=$(wc -l < "$file" | tr -d ' ')
      if [ "$lines" -gt "$PLANS_MAX_LINES" ]; then
        FEEDBACK="${FEEDBACK}Plans.md が ${lines} 行です（上限: ${PLANS_MAX_LINES}行）。\`/cleanup plans\` で古いタスクをアーカイブすることを推奨します。\n"
      fi
    fi
  fi

  # session-log.md のチェック
  if [[ "$file" == *"session-log.md"* ]]; then
    if [ -f "$file" ]; then
      lines=$(wc -l < "$file" | tr -d ' ')
      if [ "$lines" -gt "$SESSION_LOG_MAX_LINES" ]; then
        FEEDBACK="${FEEDBACK}session-log.md が ${lines} 行です（上限: ${SESSION_LOG_MAX_LINES}行）。\`/cleanup sessions\` で月別に分割することを推奨します。\n"
      fi
    fi
  fi

  # CLAUDE.md のチェック
  if [[ "$file" == *"CLAUDE.md"* ]] || [[ "$file" == *"claude.md"* ]]; then
    if [ -f "$file" ]; then
      lines=$(wc -l < "$file" | tr -d ' ')
      if [ "$lines" -gt "$CLAUDE_MD_MAX_LINES" ]; then
        FEEDBACK="${FEEDBACK}CLAUDE.md が ${lines} 行です。常に必要な情報以外は docs/ に分割し、\`@docs/filename.md\` で参照することを検討してください。\n"
      fi
    fi
  fi
done

# フィードバックがあれば出力（Claude Code へのフィードバック）
if [ -n "$FEEDBACK" ]; then
  echo -e "⚠️ ファイルサイズ警告:\n${FEEDBACK}"
fi

# 常に成功で終了（ブロックしない）
exit 0
