#!/bin/bash
# stop-cleanup-check.sh
# Stop Hook 用: セッション終了時にクリーンアップを推奨するか判定
#
# Claude Code 2.1.1 互換: prompt タイプの代わりに command タイプで実装
# 出力: JSON 形式 {"decision": "approve", "reason": "...", "systemMessage": "..."}

set -euo pipefail

# 判定用変数
RECOMMEND_CLEANUP="false"
REASON=""
MESSAGE=""

# Plans.md の分析
if [ -f "Plans.md" ]; then
  PLANS_LINES=$(wc -l < "Plans.md" | tr -d ' ')
  COMPLETED_TASKS=$(grep -c "\[x\].*cc:完了\|pm:確認済\|cursor:確認済" Plans.md 2>/dev/null || echo "0")

  # 判定条件1: 完了タスク10件以上
  if [ "$COMPLETED_TASKS" -ge 10 ]; then
    RECOMMEND_CLEANUP="true"
    REASON="completed_tasks >= 10"
    MESSAGE="整理推奨: 完了タスクが${COMPLETED_TASKS}件あります（「整理して」で maintenance スキル起動）"
  fi

  # 判定条件2: Plans.md が200行超え
  if [ "$PLANS_LINES" -gt 200 ]; then
    RECOMMEND_CLEANUP="true"
    REASON="Plans.md > 200 lines"
    MESSAGE="整理推奨: Plans.md が${PLANS_LINES}行と肥大化しています（「整理して」で maintenance スキル起動）"
  fi
fi

# 判定条件3: session-log.md が500行超え
if [ -f ".claude/memory/session-log.md" ]; then
  SESSION_LOG_LINES=$(wc -l < ".claude/memory/session-log.md" | tr -d ' ')
  if [ "$SESSION_LOG_LINES" -gt 500 ]; then
    RECOMMEND_CLEANUP="true"
    REASON="session-log.md > 500 lines"
    MESSAGE="整理推奨: session-log.md が${SESSION_LOG_LINES}行と肥大化しています（「整理して」で maintenance スキル起動）"
  fi
fi

# 判定条件4: CLAUDE.md が100行超え
if [ -f "CLAUDE.md" ]; then
  CLAUDE_MD_LINES=$(wc -l < "CLAUDE.md" | tr -d ' ')
  if [ "$CLAUDE_MD_LINES" -gt 100 ]; then
    RECOMMEND_CLEANUP="true"
    REASON="CLAUDE.md > 100 lines"
    MESSAGE="整理推奨: CLAUDE.md が${CLAUDE_MD_LINES}行あります（.claude/rules/ への分割を検討）"
  fi
fi

# JSON 出力
if [ "$RECOMMEND_CLEANUP" = "true" ]; then
  cat << EOF
{"decision": "approve", "reason": "$REASON", "systemMessage": "$MESSAGE"}
EOF
else
  cat << EOF
{"decision": "approve", "reason": "No cleanup needed", "systemMessage": ""}
EOF
fi
