#!/bin/bash
# post-tool-failure.sh
# PostToolUseFailure hook handler
# Tracks consecutive tool failures and escalates after 3
#
# Input: stdin JSON from Claude Code hooks
# Output: JSON with systemMessage for escalation

set -euo pipefail

# === Configuration ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Load path-utils.sh
if [ -f "${PARENT_DIR}/path-utils.sh" ]; then
  source "${PARENT_DIR}/path-utils.sh"
fi

# Detect project root
PROJECT_ROOT="${PROJECT_ROOT:-$(detect_project_root 2>/dev/null || pwd)}"

# State directory
STATE_DIR="${PROJECT_ROOT}/.claude/state"

# === Utility functions ===

ensure_state_dir() {
  local state_parent
  state_parent="$(dirname "${STATE_DIR}")"

  # Security: refuse symlinked state paths to avoid overwriting arbitrary files.
  if [ -L "${state_parent}" ] || [ -L "${STATE_DIR}" ]; then
    return 1
  fi

  mkdir -p "${STATE_DIR}" 2>/dev/null || true
  chmod 700 "${STATE_DIR}" 2>/dev/null || true

  [ -d "${STATE_DIR}" ] || return 1
  [ ! -L "${STATE_DIR}" ] || return 1
  return 0
}

write_counter_file() {
  local count="$1"
  local timestamp="$2"

  if [ -L "${COUNTER_FILE}" ]; then
    return 1
  fi

  printf '%s %s\n' "${count}" "${timestamp}" > "${COUNTER_FILE}"
  return 0
}

# === Read JSON payload from stdin ===
INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

# Skip if payload is empty
if [ -z "${INPUT}" ]; then
  echo '{}'
  exit 0
fi

# === Field extraction ===
TOOL_NAME=""
ERROR_MSG=""

if command -v jq >/dev/null 2>&1; then
  TOOL_NAME="$(printf '%s' "${INPUT}" | jq -r '.tool_name // .toolName // "unknown"' 2>/dev/null || echo "unknown")"
  ERROR_MSG="$(printf '%s' "${INPUT}" | jq -r '(.error // .message // "" | tostring)[0:200]' 2>/dev/null || echo "")"
elif command -v python3 >/dev/null 2>&1; then
  _parsed="$(printf '%s' "${INPUT}" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_name', d.get('toolName', 'unknown')))
    err = str(d.get('error', d.get('message', '')))
    print(err[:200])
except:
    print('unknown')
    print('')
" 2>/dev/null)"
  TOOL_NAME="$(echo "${_parsed}" | sed -n '1p')"
  ERROR_MSG="$(echo "${_parsed}" | sed -n '2p')"
fi

# === Consecutive failure counter (with timestamp) ===
if ! ensure_state_dir; then
  echo '{}'
  exit 0
fi
COUNTER_FILE="${STATE_DIR}/tool-failure-counter.txt"
STALENESS_THRESHOLD=60  # seconds. Reset if more than 60 seconds have passed since the last failure

if [ -L "${COUNTER_FILE}" ]; then
  echo '{}'
  exit 0
fi

CURRENT_COUNT=0
LAST_TIMESTAMP=0
NOW="$(date +%s)"

if [ -f "${COUNTER_FILE}" ]; then
  # Format: "count timestamp"
  _line="$(cat "${COUNTER_FILE}" 2>/dev/null || echo "0 0")"
  CURRENT_COUNT="$(echo "${_line}" | awk '{print $1}')"
  LAST_TIMESTAMP="$(echo "${_line}" | awk '{print $2}')"
  # Guard against non-numeric values
  if ! printf '%d' "${CURRENT_COUNT}" >/dev/null 2>&1; then
    CURRENT_COUNT=0
  fi
  if ! printf '%d' "${LAST_TIMESTAMP}" >/dev/null 2>&1; then
    LAST_TIMESTAMP=0
  fi
  # Reset if enough time has passed since the last failure (not consecutive)
  ELAPSED=$((NOW - LAST_TIMESTAMP))
  if [ "${ELAPSED}" -gt "${STALENESS_THRESHOLD}" ]; then
    CURRENT_COUNT=0
  fi
fi
CURRENT_COUNT=$((CURRENT_COUNT + 1))
if ! write_counter_file "${CURRENT_COUNT}" "${NOW}"; then
  echo '{}'
  exit 0
fi

# === Escalate after 3 consecutive failures ===
if [ "${CURRENT_COUNT}" -ge 3 ]; then
  # Build escaped error message
  if command -v jq >/dev/null 2>&1; then
    jq -nc \
      --arg tool "${TOOL_NAME}" \
      --arg error "${ERROR_MSG}" \
      --arg count "${CURRENT_COUNT}" \
      '{systemMessage: ("WARNING: " + $count + " consecutive tool failures detected (tool: " + $tool + "). Stop retrying the same approach. Diagnose the root cause or try an alternative approach. Last error: " + $error)}'
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c "
import json, sys
tool, error, count = sys.argv[1], sys.argv[2], sys.argv[3]
msg = f'WARNING: {count} consecutive tool failures detected (tool: {tool}). Stop retrying the same approach. Diagnose the root cause or try an alternative approach. Last error: {error}'
print(json.dumps({'systemMessage': msg}, ensure_ascii=False))
" "${TOOL_NAME}" "${ERROR_MSG}" "${CURRENT_COUNT}" 2>/dev/null
  else
    printf '{"systemMessage":"WARNING: %s consecutive tool failures detected (tool: %s). Stop retrying the same approach."}\n' "${CURRENT_COUNT}" "${TOOL_NAME}"
  fi
  # Reset counter
  write_counter_file "0" "0" || true
else
  if command -v jq >/dev/null 2>&1; then
    jq -nc \
      --arg tool "${TOOL_NAME}" \
      --arg count "${CURRENT_COUNT}" \
      '{systemMessage: ("Tool failure #" + $count + "/3 (tool: " + $tool + "). Will escalate after 3 consecutive failures.")}'
  else
    printf '{"systemMessage":"Tool failure #%s/3 (tool: %s). Will escalate after 3 consecutive failures."}\n' "${CURRENT_COUNT}" "${TOOL_NAME}"
  fi
fi

exit 0
