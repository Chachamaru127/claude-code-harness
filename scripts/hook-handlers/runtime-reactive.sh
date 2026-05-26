#!/bin/bash
# runtime-reactive.sh
# Integrates Claude Code v2.1.83+/v2.1.84+ reactive hooks for Harness use.
#
# Supported events:
# - TaskCreated: records background task creation
# - FileChanged: detects changes to Plans / rules / settings and prompts a re-read
# - CwdChanged: prompts context re-verification on worktree / repo switches

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [ -f "${PARENT_DIR}/path-utils.sh" ]; then
  # shellcheck source=../path-utils.sh
  source "${PARENT_DIR}/path-utils.sh"
fi

INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null || true)"
fi

if [ -z "${INPUT}" ]; then
  echo '{"decision":"approve","reason":"Reactive hook: no payload"}'
  exit 0
fi

HOOK_EVENT_NAME=""
SESSION_ID=""
PROJECT_ROOT=""
FILE_PATH=""
PREVIOUS_CWD=""
TASK_ID=""
TASK_TITLE=""

normalize_for_match() {
  local raw_path="$1"
  local normalized_root=""

  [ -z "${raw_path}" ] && return 0

  if declare -F normalize_path >/dev/null 2>&1; then
    raw_path="$(normalize_path "${raw_path}")"
  fi

  normalized_root="${PROJECT_ROOT}"
  if [ -n "${normalized_root}" ] && declare -F normalize_path >/dev/null 2>&1; then
    normalized_root="$(normalize_path "${normalized_root}")"
  fi

  if [ -n "${normalized_root}" ]; then
    case "${raw_path}" in
      "${normalized_root}")
        raw_path="."
        ;;
      "${normalized_root}/"*)
        raw_path="${raw_path#"${normalized_root}/"}"
        ;;
    esac
  fi

  raw_path="${raw_path#./}"
  printf '%s' "${raw_path}"
}

if command -v jq >/dev/null 2>&1; then
  HOOK_EVENT_NAME="$(printf '%s' "${INPUT}" | jq -r '.hook_event_name // .event_name // ""' 2>/dev/null || true)"
  SESSION_ID="$(printf '%s' "${INPUT}" | jq -r '.session_id // ""' 2>/dev/null || true)"
  PROJECT_ROOT="$(printf '%s' "${INPUT}" | jq -r '.cwd // .project_root // ""' 2>/dev/null || true)"
  FILE_PATH="$(printf '%s' "${INPUT}" | jq -r '.file_path // .path // ""' 2>/dev/null || true)"
  PREVIOUS_CWD="$(printf '%s' "${INPUT}" | jq -r '.previous_cwd // .from_cwd // ""' 2>/dev/null || true)"
  TASK_ID="$(printf '%s' "${INPUT}" | jq -r '.task_id // .task.id // ""' 2>/dev/null || true)"
  TASK_TITLE="$(printf '%s' "${INPUT}" | jq -r '.task_title // .task.title // .task.description // .description // ""' 2>/dev/null || true)"
elif command -v python3 >/dev/null 2>&1; then
  _parsed="$(printf '%s' "${INPUT}" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    data = {}
task = data.get("task", {}) if isinstance(data.get("task"), dict) else {}
fields = [
    str(data.get("hook_event_name") or data.get("event_name") or ""),
    str(data.get("session_id") or ""),
    str(data.get("cwd") or data.get("project_root") or ""),
    str(data.get("file_path") or data.get("path") or ""),
    str(data.get("previous_cwd") or data.get("from_cwd") or ""),
    str(data.get("task_id") or task.get("id") or ""),
    str(data.get("task_title") or task.get("title") or task.get("description") or data.get("description") or ""),
]
print("\t".join(fields))
' 2>/dev/null || true)"
  if [ -n "${_parsed}" ]; then
    IFS=$'\t' read -r HOOK_EVENT_NAME SESSION_ID PROJECT_ROOT FILE_PATH PREVIOUS_CWD TASK_ID TASK_TITLE <<< "${_parsed}"
  fi
  unset _parsed
fi

if [ -z "${PROJECT_ROOT}" ]; then
  if declare -F detect_project_root >/dev/null 2>&1; then
    PROJECT_ROOT="$(detect_project_root 2>/dev/null || pwd)"
  else
    PROJECT_ROOT="$(pwd)"
  fi
fi

if declare -F normalize_path >/dev/null 2>&1; then
  PROJECT_ROOT="$(normalize_path "${PROJECT_ROOT}")"
fi

FILE_PATH="$(normalize_for_match "${FILE_PATH}")"
PREVIOUS_CWD="$(normalize_for_match "${PREVIOUS_CWD}")"

STATE_DIR="${PROJECT_ROOT}/.claude/state"
LOG_FILE="${STATE_DIR}/runtime-reactive.jsonl"
mkdir -p "${STATE_DIR}" 2>/dev/null || true

TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ")"

MESSAGE=""

case "${HOOK_EVENT_NAME}" in
  FileChanged)
    case "${FILE_PATH}" in
      Plans.md|*/Plans.md)
        MESSAGE="Plans.md has been updated. Please re-read the latest task state before the next implementation or review."
        ;;
      AGENTS.md|*/AGENTS.md|CLAUDE.md|*/CLAUDE.md|.claude/rules/*|*/.claude/rules/*|hooks/hooks.json|*/hooks/hooks.json|.claude-plugin/settings.json|*/.claude-plugin/settings.json)
        MESSAGE="Working rules or Harness settings have been updated. Proceed with the next operation based on the latest rules."
        ;;
    esac
    ;;
  CwdChanged)
    MESSAGE="Working directory has switched. If you have moved to a different repository or worktree, please re-check AGENTS.md, Plans.md, and local rules."
    ;;
esac

if command -v jq >/dev/null 2>&1; then
  jq -nc \
    --arg event "${HOOK_EVENT_NAME}" \
    --arg timestamp "${TIMESTAMP}" \
    --arg session_id "${SESSION_ID}" \
    --arg cwd "${PROJECT_ROOT}" \
    --arg file_path "${FILE_PATH}" \
    --arg previous_cwd "${PREVIOUS_CWD}" \
    --arg task_id "${TASK_ID}" \
    --arg task_title "${TASK_TITLE}" \
    '{event:$event, timestamp:$timestamp, session_id:$session_id, cwd:$cwd, file_path:$file_path, previous_cwd:$previous_cwd, task_id:$task_id, task_title:$task_title}' \
    >> "${LOG_FILE}" 2>/dev/null || true
fi

if [ -n "${MESSAGE}" ]; then
  if command -v jq >/dev/null 2>&1; then
    jq -nc \
      --arg event "${HOOK_EVENT_NAME}" \
      --arg ctx "${MESSAGE}" \
      '{hookSpecificOutput:{hookEventName:$event, additionalContext:$ctx}}'
  else
    escaped_message="$(printf '%s' "${MESSAGE}" | sed 's/\\/\\\\/g; s/"/\\"/g')"
    printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' "${HOOK_EVENT_NAME}" "${escaped_message}"
  fi
else
  printf '{"decision":"approve","reason":"Reactive hook tracked: %s"}\n' "${HOOK_EVENT_NAME:-unknown}"
fi

exit 0
