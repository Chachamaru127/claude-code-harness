#!/usr/bin/env bash
# permission-denied-handler.sh
# PermissionDenied hook handler (v2.1.89+)
#
# Fires when the auto mode classifier denies a command.
# Records the denial event in telemetry; in Breezing mode includes a notification to the Lead.
# Returning {retry: true} signals to the model that it can retry.
#
# Input:  stdin (JSON: { tool, input, denied_reason, session_id, agent_id, ... })
# Output: JSON (systemMessage for awareness, optional retry hint)
# Hook event: PermissionDenied

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Load path-utils.sh
if [ -f "${PARENT_DIR}/path-utils.sh" ]; then
  source "${PARENT_DIR}/path-utils.sh"
fi

# Detect project root
if declare -F detect_project_root > /dev/null 2>&1; then
  PROJECT_ROOT="${PROJECT_ROOT:-$(detect_project_root 2>/dev/null || pwd)}"
else
  PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
fi

# State directory (scoped per project when CLAUDE_PLUGIN_DATA is set)
if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
  _project_hash="$(printf '%s' "${PROJECT_ROOT}" | { shasum -a 256 2>/dev/null || sha256sum 2>/dev/null || echo "default  -"; } | cut -c1-12)"
  [ -z "${_project_hash}" ] && _project_hash="default"
  STATE_DIR="${CLAUDE_PLUGIN_DATA}/projects/${_project_hash}"
else
  STATE_DIR="${PROJECT_ROOT}/.claude/state"
fi
LOG_FILE="${STATE_DIR}/permission-denied.jsonl"

# === Utility functions ===

ensure_state_dir() {
  local state_parent
  state_parent="$(dirname "${STATE_DIR}")"

  # Security: refuse symlinked state paths
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

# === Extract denial information ===
TOOL_NAME="unknown"
DENIED_REASON="unknown"
SESSION_ID="unknown"
AGENT_ID="unknown"
AGENT_TYPE="unknown"

if command -v jq > /dev/null 2>&1; then
  TOOL_NAME="$(printf '%s' "${INPUT}" | jq -r '.tool // .tool_name // "unknown"' 2>/dev/null || echo "unknown")"
  DENIED_REASON="$(printf '%s' "${INPUT}" | jq -r '.denied_reason // .reason // "unknown"' 2>/dev/null || echo "unknown")"
  SESSION_ID="$(printf '%s' "${INPUT}" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")"
  AGENT_ID="$(printf '%s' "${INPUT}" | jq -r '.agent_id // "unknown"' 2>/dev/null || echo "unknown")"
  AGENT_TYPE="$(printf '%s' "${INPUT}" | jq -r '.agent_type // "unknown"' 2>/dev/null || echo "unknown")"
elif command -v python3 > /dev/null 2>&1; then
  _parsed="$(printf '%s' "${INPUT}" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool', d.get('tool_name', 'unknown')))
    print(d.get('denied_reason', d.get('reason', 'unknown')))
    print(d.get('session_id', 'unknown'))
    print(d.get('agent_id', 'unknown'))
    print(d.get('agent_type', 'unknown'))
except:
    for _ in range(5): print('unknown')
" 2>/dev/null)" || _parsed=""
  if [ -n "${_parsed}" ]; then
    TOOL_NAME="$(echo "${_parsed}" | sed -n '1p')"
    DENIED_REASON="$(echo "${_parsed}" | sed -n '2p')"
    SESSION_ID="$(echo "${_parsed}" | sed -n '3p')"
    AGENT_ID="$(echo "${_parsed}" | sed -n '4p')"
    AGENT_TYPE="$(echo "${_parsed}" | sed -n '5p')"
  fi
fi

TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ")"

# === Log to JSONL ===
log_entry=""
if command -v jq > /dev/null 2>&1; then
  log_entry="$(jq -nc \
    --arg event "permission_denied" \
    --arg timestamp "${TIMESTAMP}" \
    --arg session_id "${SESSION_ID}" \
    --arg agent_id "${AGENT_ID}" \
    --arg agent_type "${AGENT_TYPE}" \
    --arg tool "${TOOL_NAME}" \
    --arg reason "${DENIED_REASON}" \
    '{event:$event, timestamp:$timestamp, session_id:$session_id, agent_id:$agent_id, agent_type:$agent_type, tool:$tool, reason:$reason}')"
elif command -v python3 > /dev/null 2>&1; then
  log_entry="$(python3 -c "
import json, sys
print(json.dumps({
    'event': 'permission_denied',
    'timestamp': sys.argv[1],
    'session_id': sys.argv[2],
    'agent_id': sys.argv[3],
    'agent_type': sys.argv[4],
    'tool': sys.argv[5],
    'reason': sys.argv[6]
}, ensure_ascii=False))
" "${TIMESTAMP}" "${SESSION_ID}" "${AGENT_ID}" "${AGENT_TYPE}" "${TOOL_NAME}" "${DENIED_REASON}" 2>/dev/null)" || log_entry=""
fi

if [ -n "${log_entry}" ]; then
  # Security: refuse symlinked log file
  if [ -L "${LOG_FILE}" ]; then
    exit 0
  fi
  echo "${log_entry}" >> "${LOG_FILE}" 2>/dev/null || true
  rotate_jsonl "${LOG_FILE}"
fi

# === For Breezing Workers: notify Lead + retry instruction ===
# When a Worker is denied, inform the Lead so it can consider an alternative approach
# Returning retry: true signals to the model that it can retry
_notification_text="[PermissionDenied] Worker tool ${TOOL_NAME} was denied in auto mode. Reason: ${DENIED_REASON}. Consider an alternative approach or manually approve if needed."
_is_worker=false
if [ "${AGENT_TYPE}" = "worker" ] || [ "${AGENT_TYPE}" = "task-worker" ] || echo "${AGENT_TYPE}" | grep -qE ':worker$'; then
  _is_worker=true

  # Write to broadcast file (so the Lead session can read it)
  _broadcast_script="${SCRIPT_DIR}/../session-broadcast.sh"
  if [ -f "${_broadcast_script}" ]; then
    bash "${_broadcast_script}" "${_notification_text}" >/dev/null 2>&1 || true
  fi

  # Return retry: true + systemMessage
  if command -v jq > /dev/null 2>&1; then
    jq -nc \
      --arg msg "${_notification_text}" \
      '{"retry": true, "systemMessage": $msg}'
  else
    echo "{\"retry\": true, \"systemMessage\": \"${_notification_text//\"/\\\"}\"}"
  fi
fi

# Non-Worker: pass through without retry — defer judgment to the user
if [ "${_is_worker}" = "false" ]; then
  echo '{"decision":"approve","reason":"PermissionDenied logged"}'
fi

# Also output to stderr (for debugging)
echo "[PermissionDenied] agent=${AGENT_ID} type=${AGENT_TYPE} tool=${TOOL_NAME} reason=${DENIED_REASON}" >&2

exit 0
