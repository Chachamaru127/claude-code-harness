#!/bin/bash
# stop-plans-reminder.sh
# For Stop hook: reminder to update Plans.md markers
#
# Claude Code 2.1.1 互換: prompt タイプの代わりに command タイプで実装
# 出力: JSON 形式 {"decision": "approve", "reason": "...", "systemMessage": "..."}

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

# Decision variables
NEED_REMINDER="false"
REASON=""
MESSAGE=""

# Check if there are changes
HAS_CHANGES="false"

# Git uncommitted changes
if [ -d ".git" ]; then
  GIT_UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ' || echo "0")
  if [ "$GIT_UNCOMMITTED" -gt 0 ]; then
    HAS_CHANGES="true"
  fi
fi

# Changes during session
if [ -f ".claude/state/session.json" ] && command -v jq >/dev/null 2>&1; then
  SESSION_CHANGES=$(jq '.changes_this_session // 0' .claude/state/session.json 2>/dev/null || echo "0")
  if [ "$SESSION_CHANGES" != "0" ] && [ "$SESSION_CHANGES" != "null" ]; then
    HAS_CHANGES="true"
  fi
fi

# Check Plans.md only if there are changes
if [ "$HAS_CHANGES" = "true" ] && [ -f "$PLANS_PATH" ]; then
  PM_PENDING=$(count_plan_tasks "(pm:(requested|依頼中)|cursor:依頼中)" "$PLANS_PATH")
  CC_WIP=$(count_plan_tasks "cc:(wip|WIP)" "$PLANS_PATH")
  CC_DONE=$(count_plan_tasks "cc:(done|完了)" "$PLANS_PATH")

  # PM-requested tasks exist
  if [ "$PM_PENDING" -gt 0 ]; then
    NEED_REMINDER="true"
    REASON="pm_pending_tasks > 0"
    MESSAGE="Plans.md: ${PM_PENDING} pm:requested task(s) remain. Start work with cc:wip and mark completion with cc:done."
  fi

  # WIP tasks exist
  if [ "$CC_WIP" -gt 0 ]; then
    NEED_REMINDER="true"
    REASON="cc_wip_tasks > 0"
    MESSAGE="Plans.md: ${CC_WIP} cc:wip task(s) remain. Mark completed work with cc:done."
  fi

  # Completed tasks exist (awaiting PM review)
  if [ "$CC_DONE" -gt 0 ]; then
    NEED_REMINDER="true"
    REASON="cc_done_tasks > 0"
    MESSAGE="Plans.md: ${CC_DONE} cc:done task(s) await PM review. After PM confirms, use pm:approved."
  fi
fi

# JSON output
if [ "$NEED_REMINDER" = "true" ]; then
  cat << EOF
{"decision": "approve", "reason": "$REASON", "systemMessage": "$MESSAGE"}
EOF
else
  cat << EOF
{"decision": "approve", "reason": "No reminder needed", "systemMessage": ""}
EOF
fi
