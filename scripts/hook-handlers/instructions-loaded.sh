#!/bin/bash
# instructions-loaded.sh
# InstructionsLoaded hook handler (CC 2.1.69+)
#
# Purpose:
# - Record the instructions loading event before session start
# - Lightly validate prerequisites for the rules/hook environment
#
# Input: stdin JSON
# Output: {"decision":"approve", ...}

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
  echo '{"decision":"approve","reason":"InstructionsLoaded: no payload"}'
  exit 0
fi

SESSION_ID=""
CWD=""
AGENT_ID=""
AGENT_TYPE=""
EVENT_NAME=""

if command -v jq >/dev/null 2>&1; then
  _jq_parsed="$(printf '%s' "${INPUT}" | jq -r '[
    (.session_id // ""),
    (.cwd // ""),
    (.agent_id // ""),
    (.agent_type // ""),
    (.hook_event_name // .event_name // "InstructionsLoaded")
  ] | @tsv' 2>/dev/null)"
  if [ -n "${_jq_parsed}" ]; then
    IFS=$'\t' read -r SESSION_ID CWD AGENT_ID AGENT_TYPE EVENT_NAME <<< "${_jq_parsed}"
  fi
  unset _jq_parsed
fi

PROJECT_ROOT="${CWD}"
if [ -z "${PROJECT_ROOT}" ]; then
  if declare -F detect_project_root >/dev/null 2>&1; then
    PROJECT_ROOT="$(detect_project_root 2>/dev/null || pwd)"
  else
    PROJECT_ROOT="$(pwd)"
  fi
fi

STATE_DIR="${PROJECT_ROOT}/.claude/state"
LOG_FILE="${STATE_DIR}/instructions-loaded.jsonl"
mkdir -p "${STATE_DIR}" 2>/dev/null || true

TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

if command -v jq >/dev/null 2>&1; then
  jq -nc \
    --arg event "${EVENT_NAME}" \
    --arg timestamp "${TS}" \
    --arg session_id "${SESSION_ID}" \
    --arg agent_id "${AGENT_ID}" \
    --arg agent_type "${AGENT_TYPE}" \
    --arg cwd "${PROJECT_ROOT}" \
    '{event:$event, timestamp:$timestamp, session_id:$session_id, agent_id:$agent_id, agent_type:$agent_type, cwd:$cwd}' \
    >> "${LOG_FILE}" 2>/dev/null || true
fi

# Lightweight prerequisite check (missing items do not block)
if [ ! -f "${PROJECT_ROOT}/hooks/hooks.json" ] && [ ! -f "${PROJECT_ROOT}/.claude-plugin/hooks.json" ]; then
  echo '{"decision":"approve","reason":"InstructionsLoaded: hooks.json not found in project root"}'
  exit 0
fi

echo '{"decision":"approve","reason":"InstructionsLoaded tracked"}'
exit 0
