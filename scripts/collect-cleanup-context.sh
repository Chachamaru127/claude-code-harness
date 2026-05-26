#!/bin/bash
# collect-cleanup-context.sh
# For Stop Hook: collect context at session end to determine whether cleanup is recommended
#
# Output: file state and task statistics in JSON format

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
CONFIG_FILE="${CONFIG_FILE:-${PROJECT_ROOT}/.claude-code-harness.config.yaml}"
PLANS_PATH="${PROJECT_ROOT}/Plans.md"
if [ -f "${SCRIPT_DIR}/config-utils.sh" ]; then
  # shellcheck source=./config-utils.sh
  source "${SCRIPT_DIR}/config-utils.sh"
  resolved_plans_path="$(get_plans_file_path 2>/dev/null || printf 'Plans.md')"
  case "$resolved_plans_path" in
    /*) PLANS_PATH="$resolved_plans_path" ;;
    *) PLANS_PATH="${PROJECT_ROOT}/${resolved_plans_path}" ;;
  esac
fi

count_plan_tasks() {
  local pattern="$1"
  local file="$2"

  awk -v pattern="$pattern" '
    function trim(value) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      return value
    }
    function is_task_line(line, fields, first_cell) {
      if (line ~ /^[[:space:]]*[-*+][[:space:]]+\[[ xX]\]/) {
        return 1
      }
      if (line !~ /^[[:space:]]*\|/) {
        return 0
      }
      split(line, fields, /\|/)
      first_cell = trim(fields[2])
      gsub(/`/, "", first_cell)
      if (first_cell == "" || first_cell == "Task" || first_cell ~ /^[-]+$/) {
        return 0
      }
      if (first_cell ~ /^(pm|cc|cursor):/) {
        return 0
      }
      return 1
    }
    is_task_line($0) && $0 ~ pattern { count++ }
    END { print count + 0 }
  ' "$file" 2>/dev/null || printf '0\n'
}

# Variables for JSON output
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

# Analyze Plans.md
if [ -f "$PLANS_PATH" ]; then
  PLANS_EXISTS="true"
  PLANS_LINES=$(wc -l < "$PLANS_PATH" | tr -d ' ')

  # Count tasks
  COMPLETED_TASKS=$(count_plan_tasks "(cc:(done|完了)|pm:(approved|確認済)|cursor:確認済)" "$PLANS_PATH")
  WIP_TASKS=$(count_plan_tasks "(cc:(wip|WIP)|pm:(requested|依頼中)|cursor:依頼中)" "$PLANS_PATH")
  TODO_TASKS=$(count_plan_tasks "cc:(todo|TODO)" "$PLANS_PATH")
  PM_PENDING_TASKS=$(count_plan_tasks "(pm:(requested|依頼中)|cursor:依頼中)" "$PLANS_PATH")
  PM_CONFIRMED_TASKS=$(count_plan_tasks "(pm:(approved|確認済)|cursor:確認済)" "$PLANS_PATH")
  CC_WIP_TASKS=$(count_plan_tasks "cc:(wip|WIP)" "$PLANS_PATH")
  CC_DONE_TASKS=$(count_plan_tasks "cc:(done|完了)" "$PLANS_PATH")

  # Get the oldest completion date (looks for YYYY-MM-DD format)
  OLDEST_COMPLETED_DATE=$(grep -oE "[0-9]{4}-[0-9]{2}-[0-9]{2}" "$PLANS_PATH" 2>/dev/null | sort | head -1 || echo "")
fi

# session-log.md line count
if [ -f ".claude/memory/session-log.md" ]; then
  SESSION_LOG_LINES=$(wc -l < ".claude/memory/session-log.md" | tr -d ' ')
fi

# CLAUDE.md line count
if [ -f "CLAUDE.md" ]; then
  CLAUDE_MD_LINES=$(wc -l < "CLAUDE.md" | tr -d ' ')
fi

# Git uncommitted count
if [ -d ".git" ]; then
  GIT_UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ' || echo "0")
fi

# Number of changes during the session (if available)
if [ -f ".claude/state/session.json" ] && command -v jq >/dev/null 2>&1; then
  SESSION_CHANGES=$(jq '.changes_this_session | length' .claude/state/session.json 2>/dev/null || echo "0")
fi

# Today's date
TODAY=$(date +%Y-%m-%d)

# JSON output
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
