#!/bin/bash
# stop-failure.sh
# StopFailure hook handler (v2.1.78+)
#
# Fires when session stop fails due to an API error (rate limit, auth failure, etc.).
# Logs the error and attempts to notify Lead in Breezing mode.
#
# Input:  stdin (JSON: { error, session_id, ... })
# Output: none (logging only)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Load path-utils.sh
if [ -f "${PARENT_DIR}/path-utils.sh" ]; then
  source "${PARENT_DIR}/path-utils.sh"
fi

# Check if detect_project_root is defined before calling it
if declare -F detect_project_root > /dev/null 2>&1; then
  PROJECT_ROOT="${PROJECT_ROOT:-$(detect_project_root 2>/dev/null || pwd)}"
else
  PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
fi

# State directory (scoped per project when CLAUDE_PLUGIN_DATA is in use)
if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
  _project_hash="$(printf '%s' "${PROJECT_ROOT}" | { shasum -a 256 2>/dev/null || sha256sum 2>/dev/null || echo "default  -"; } | cut -c1-12)"
  [ -z "${_project_hash}" ] && _project_hash="default"
  STATE_DIR="${CLAUDE_PLUGIN_DATA}/projects/${_project_hash}"
else
  STATE_DIR="${PROJECT_ROOT}/.claude/state"
fi
LOG_FILE="${STATE_DIR}/stop-failures.jsonl"

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

# JSONL rotation (trim to 400 lines when exceeding 500)
rotate_jsonl() {
  local file="$1"

  # Security: refuse symlinked log or tmp files
  if [ -L "${file}" ] || [ -L "${file}.tmp" ]; then
    return 1
  fi

  local _lines
  _lines="$(wc -l < "${file}" 2>/dev/null)" || _lines=0
  if [ "${_lines}" -gt 500 ] 2>/dev/null; then
    tail -400 "${file}" > "${file}.tmp" 2>/dev/null && \
      mv "${file}.tmp" "${file}" 2>/dev/null || true
  fi
}

# === Read input from stdin ===
INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)" || true
fi

# Skip if payload is empty
if [ -z "${INPUT}" ]; then
  exit 0
fi

# === Ensure state directory ===
if ! ensure_state_dir; then
  exit 0
fi

# === Extract error information ===
ERROR_MSG="unknown"
ERROR_CODE="unknown"
SESSION_ID="unknown"

if command -v jq > /dev/null 2>&1; then
  ERROR_MSG="$(printf '%s' "${INPUT}" | jq -r '.error.message // .error // "unknown"' 2>/dev/null || echo "unknown")"
  ERROR_CODE="$(printf '%s' "${INPUT}" | jq -r '.error.status // .error.code // "unknown"' 2>/dev/null || echo "unknown")"
  SESSION_ID="$(printf '%s' "${INPUT}" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")"
elif command -v python3 > /dev/null 2>&1; then
  _parsed="$(printf '%s' "${INPUT}" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    err = d.get('error', {})
    if isinstance(err, dict):
        print(err.get('message', 'unknown'))
        print(err.get('status', err.get('code', 'unknown')))
    else:
        print(str(err))
        print('unknown')
    print(d.get('session_id', 'unknown'))
except:
    print('unknown')
    print('unknown')
    print('unknown')
" 2>/dev/null)" || _parsed=""
  if [ -n "${_parsed}" ]; then
    ERROR_MSG="$(echo "${_parsed}" | sed -n '1p')"
    ERROR_CODE="$(echo "${_parsed}" | sed -n '2p')"
    SESSION_ID="$(echo "${_parsed}" | sed -n '3p')"
  fi
fi

TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ")"

# === Write log entry to JSONL (safely escaped via jq/python3) ===
log_entry=""
if command -v jq > /dev/null 2>&1; then
  log_entry="$(jq -nc \
    --arg event "stop_failure" \
    --arg timestamp "${TIMESTAMP}" \
    --arg session_id "${SESSION_ID}" \
    --arg error_code "${ERROR_CODE}" \
    --arg message "${ERROR_MSG}" \
    '{event:$event, timestamp:$timestamp, session_id:$session_id, error_code:$error_code, message:$message}')"
elif command -v python3 > /dev/null 2>&1; then
  log_entry="$(python3 -c "
import json, sys
print(json.dumps({
    'event': 'stop_failure',
    'timestamp': sys.argv[1],
    'session_id': sys.argv[2],
    'error_code': sys.argv[3],
    'message': sys.argv[4]
}, ensure_ascii=False))
" "${TIMESTAMP}" "${SESSION_ID}" "${ERROR_CODE}" "${ERROR_MSG}" 2>/dev/null)" || log_entry=""
fi

if [ -n "${log_entry}" ]; then
  # Security: refuse symlinked log file
  if [ -L "${LOG_FILE}" ]; then
    exit 0
  fi
  echo "${log_entry}" >> "${LOG_FILE}" 2>/dev/null || true
  rotate_jsonl "${LOG_FILE}"
fi

# === Notify Lead (on 429 rate limit) ===
if [ "${ERROR_CODE}" = "429" ]; then
  # Notify Lead via systemMessage (CC hooks protocol)
  # Safely escape SESSION_ID via jq/python3 when building JSON
  _sys_msg=""
  if command -v jq > /dev/null 2>&1; then
    _sys_msg="$(jq -nc --arg sid "${SESSION_ID}" \
      '{systemMessage: ("[StopFailure] Worker " + $sid + " stopped due to rate limit (429). Breezing Lead: please retry with exponential backoff.")}')"
  elif command -v python3 > /dev/null 2>&1; then
    _sys_msg="$(python3 -c "
import json, sys
print(json.dumps({'systemMessage': '[StopFailure] Worker ' + sys.argv[1] + ' stopped due to rate limit (429). Breezing Lead: please retry with exponential backoff.'}, ensure_ascii=False))
" "${SESSION_ID}" 2>/dev/null)" || _sys_msg=""
  fi
  [ -n "${_sys_msg}" ] && echo "${_sys_msg}"
fi

# Also output to stderr (for debugging)
echo "[StopFailure] session=${SESSION_ID} code=${ERROR_CODE} msg=${ERROR_MSG}" >&2

exit 0
