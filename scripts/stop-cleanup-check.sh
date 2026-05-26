#!/bin/bash
# stop-cleanup-check.sh
# For Stop hook: determine whether to recommend cleanup at session end
#
# Claude Code 2.1.1 互換: prompt タイプの代わりに command タイプで実装
# 出力: JSON 形式 {"decision": "approve", "reason": "...", "systemMessage": "..."}

set -euo pipefail

# Decision variables
RECOMMEND_CLEANUP="false"
REASON=""
MESSAGE=""

# Analyze Plans.md
if [ -f "Plans.md" ]; then
  PLANS_LINES=$(wc -l < "Plans.md" | tr -d ' ')
  COMPLETED_TASKS=$(grep -c "\[x\].*cc:done\|\[x\].*cc:完了\|pm:approved\|pm:確認済\|cursor:確認済" Plans.md 2>/dev/null || echo "0")

  # Condition 1: 10 or more completed tasks
  if [ "$COMPLETED_TASKS" -ge 10 ]; then
    RECOMMEND_CLEANUP="true"
    REASON="completed_tasks >= 10"
    MESSAGE="Cleanup recommended: ${COMPLETED_TASKS} completed task(s) found (say 'clean up' to launch the maintenance skill)"
  fi

  # Condition 2: Plans.md exceeds 200 lines
  if [ "$PLANS_LINES" -gt 200 ]; then
    RECOMMEND_CLEANUP="true"
    REASON="Plans.md > 200 lines"
    MESSAGE="Cleanup recommended: Plans.md has grown to ${PLANS_LINES} lines (say 'clean up' to launch the maintenance skill)"
  fi
fi

# Condition 3: session-log.md exceeds 500 lines
if [ -f ".claude/memory/session-log.md" ]; then
  SESSION_LOG_LINES=$(wc -l < ".claude/memory/session-log.md" | tr -d ' ')
  if [ "$SESSION_LOG_LINES" -gt 500 ]; then
    RECOMMEND_CLEANUP="true"
    REASON="session-log.md > 500 lines"
    MESSAGE="Cleanup recommended: session-log.md has grown to ${SESSION_LOG_LINES} lines (say 'clean up' to launch the maintenance skill)"
  fi
fi

# Condition 4: CLAUDE.md exceeds 100 lines
if [ -f "CLAUDE.md" ]; then
  CLAUDE_MD_LINES=$(wc -l < "CLAUDE.md" | tr -d ' ')
  if [ "$CLAUDE_MD_LINES" -gt 100 ]; then
    RECOMMEND_CLEANUP="true"
    REASON="CLAUDE.md > 100 lines"
    MESSAGE="Cleanup recommended: CLAUDE.md has ${CLAUDE_MD_LINES} lines (consider splitting into .claude/rules/)"
  fi
fi

# JSON output
if [ "$RECOMMEND_CLEANUP" = "true" ]; then
  cat << EOF
{"decision": "approve", "reason": "$REASON", "systemMessage": "$MESSAGE"}
EOF
else
  cat << EOF
{"decision": "approve", "reason": "No cleanup needed", "systemMessage": ""}
EOF
fi
