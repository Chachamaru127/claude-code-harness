#!/bin/bash
# collect-cleanup-context.sh
# Stop Hook 用: セッション終了時にクリーンアップ推奨判断のためのコンテキストを収集
#
# 出力: JSON 形式でファイル状態・タスク統計を出力

set -e

# JSON出力用の変数
PLANS_EXISTS="false"
PLANS_LINES=0
COMPLETED_TASKS=0
WIP_TASKS=0
TODO_TASKS=0
PM_PENDING_TASKS=0
PM_CONFIRMED_TASKS=0
CC_WIP_TASKS=0
CC_DONE_TASKS=0
OLDEST_COMPLETED_DATE=""
SESSION_LOG_LINES=0
CLAUDE_MD_LINES=0
GIT_UNCOMMITTED=0
SESSION_CHANGES=0

# Plans.md の分析
if [ -f "Plans.md" ]; then
  PLANS_EXISTS="true"
  PLANS_LINES=$(wc -l < "Plans.md" | tr -d ' ')

  # タスク数をカウント
  COMPLETED_TASKS=$(grep -c "\[x\].*cc:完了\|pm:確認済\|cursor:確認済" Plans.md 2>/dev/null || echo "0")
  WIP_TASKS=$(grep -c "cc:WIP\|pm:依頼中\|cursor:依頼中" Plans.md 2>/dev/null || echo "0")
  TODO_TASKS=$(grep -c "cc:TODO" Plans.md 2>/dev/null || echo "0")
  PM_PENDING_TASKS=$(( $(grep -c "pm:依頼中" Plans.md 2>/dev/null || echo "0") + $(grep -c "cursor:依頼中" Plans.md 2>/dev/null || echo "0") ))
  PM_CONFIRMED_TASKS=$(( $(grep -c "pm:確認済" Plans.md 2>/dev/null || echo "0") + $(grep -c "cursor:確認済" Plans.md 2>/dev/null || echo "0") ))
  CC_WIP_TASKS=$(grep -c "cc:WIP" Plans.md 2>/dev/null || echo "0")
  CC_DONE_TASKS=$(grep -c "cc:完了" Plans.md 2>/dev/null || echo "0")

  # 最も古い完了日を取得（YYYY-MM-DD 形式を探す）
  OLDEST_COMPLETED_DATE=$(grep -oE "[0-9]{4}-[0-9]{2}-[0-9]{2}" Plans.md 2>/dev/null | sort | head -1 || echo "")
fi

# session-log.md の行数
if [ -f ".claude/memory/session-log.md" ]; then
  SESSION_LOG_LINES=$(wc -l < ".claude/memory/session-log.md" | tr -d ' ')
fi

# CLAUDE.md の行数
if [ -f "CLAUDE.md" ]; then
  CLAUDE_MD_LINES=$(wc -l < "CLAUDE.md" | tr -d ' ')
fi

# Git 未コミット数
if [ -d ".git" ]; then
  GIT_UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ' || echo "0")
fi

# セッション中の変更数（あれば）
if [ -f ".claude/state/session.json" ] && command -v jq >/dev/null 2>&1; then
  SESSION_CHANGES=$(jq '.changes_this_session | length' .claude/state/session.json 2>/dev/null || echo "0")
fi

# 今日の日付
TODAY=$(date +%Y-%m-%d)

# JSON 出力
cat << EOF
{
  "today": "$TODAY",
  "plans": {
    "exists": $PLANS_EXISTS,
    "lines": $PLANS_LINES,
    "completed_tasks": $COMPLETED_TASKS,
    "wip_tasks": $WIP_TASKS,
    "todo_tasks": $TODO_TASKS,
    "pm_pending_tasks": $PM_PENDING_TASKS,
    "pm_confirmed_tasks": $PM_CONFIRMED_TASKS,
    "cc_wip_tasks": $CC_WIP_TASKS,
    "cc_done_tasks": $CC_DONE_TASKS,
    "oldest_completed_date": "$OLDEST_COMPLETED_DATE"
  },
  "git": {
    "uncommitted_changes": $GIT_UNCOMMITTED
  },
  "session": {
    "changes_this_session": $SESSION_CHANGES
  },
  "session_log_lines": $SESSION_LOG_LINES,
  "claude_md_lines": $CLAUDE_MD_LINES
}
EOF
