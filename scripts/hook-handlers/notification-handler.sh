#!/usr/bin/env bash
# notification-handler.sh
# Notification hook handler
# Fires when Claude Code issues a notification
# Records events such as permission_prompt, idle_prompt, auth_success, etc.
#
# Input: stdin JSON from Claude Code hooks
# Output: JSON to approve the event
# Hook event: Notification

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

# Log file (scoped per project when CLAUDE_PLUGIN_DATA is set)
if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
  _project_hash="$(printf '%s' "${PROJECT_ROOT}" | { shasum -a 256 2>/dev/null || sha256sum 2>/dev/null || echo "default  -"; } | cut -c1-12)"
  [ -z "${_project_hash}" ] && _project_hash="default"
  STATE_DIR="${CLAUDE_PLUGIN_DATA}/projects/${_project_hash}"
else
  STATE_DIR="${PROJECT_ROOT}/.claude/state"
fi
LOG_FILE="${STATE_DIR}/notification-events.jsonl"

# terminalSequence helper (CC 2.1.141+, opt-in via HARNESS_TERMINAL_NOTIFY)
# Details: .claude/rules/hooks-2.1.139-plus.md
if [ -f "${PARENT_DIR}/lib/terminal-notify.sh" ]; then
  # shellcheck disable=SC1091
  source "${PARENT_DIR}/lib/terminal-notify.sh"
fi

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

get_timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# === Read JSON payload from stdin ===
INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

# Skip if payload is empty
if [ -z "${INPUT}" ]; then
  exit 0
fi

# === Field extraction ===
NOTIFICATION_TYPE=""
SESSION_ID=""
AGENT_TYPE=""

if command -v jq >/dev/null 2>&1; then
  NOTIFICATION_TYPE="$(printf '%s' "${INPUT}" | jq -r '.notification_type // .type // .matcher // ""' 2>/dev/null || true)"
  SESSION_ID="$(printf '%s' "${INPUT}" | jq -r '.session_id // ""' 2>/dev/null || true)"
  AGENT_TYPE="$(printf '%s' "${INPUT}" | jq -r '.agent_type // ""' 2>/dev/null || true)"
elif command -v python3 >/dev/null 2>&1; then
  _parsed="$(printf '%s' "${INPUT}" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('notification_type', d.get('type', d.get('matcher', ''))))
    print(d.get('session_id', ''))
    print(d.get('agent_type', ''))
except:
    print('')
    print('')
    print('')
" 2>/dev/null)"
  NOTIFICATION_TYPE="$(echo "${_parsed}" | sed -n '1p')"
  SESSION_ID="$(echo "${_parsed}" | sed -n '2p')"
  AGENT_TYPE="$(echo "${_parsed}" | sed -n '3p')"
fi

# === Logging ===
if ! ensure_state_dir; then
  exit 0
fi
TS="$(get_timestamp)"

log_entry=""
if command -v jq >/dev/null 2>&1; then
  log_entry="$(jq -nc \
    --arg event "notification" \
    --arg notification_type "${NOTIFICATION_TYPE}" \
    --arg session_id "${SESSION_ID}" \
    --arg agent_type "${AGENT_TYPE}" \
    --arg timestamp "${TS}" \
    '{event:$event, notification_type:$notification_type, session_id:$session_id, agent_type:$agent_type, timestamp:$timestamp}')"
elif command -v python3 >/dev/null 2>&1; then
  log_entry="$(python3 -c "
import json, sys
print(json.dumps({
    'event': 'notification',
    'notification_type': sys.argv[1],
    'session_id': sys.argv[2],
    'agent_type': sys.argv[3],
    'timestamp': sys.argv[4]
}, ensure_ascii=False))
" "${NOTIFICATION_TYPE}" "${SESSION_ID}" "${AGENT_TYPE}" "${TS}" 2>/dev/null)" || log_entry=""
fi

if [ -n "${log_entry}" ]; then
  # Security: refuse symlinked log file
  if [ -L "${LOG_FILE}" ]; then
    exit 0
  fi
  echo "${log_entry}" >> "${LOG_FILE}" 2>/dev/null || true
  rotate_jsonl "${LOG_FILE}"
fi

# === Detection of important notifications during Breezing ===
# Background Workers in Breezing cannot perform UI operations
# Logging enables post-hoc analysis

# permission_prompt: Worker cannot respond to permission dialogs
if [ "${NOTIFICATION_TYPE}" = "permission_prompt" ] && [ -n "${AGENT_TYPE}" ]; then
  echo "Notification: permission_prompt for agent_type=${AGENT_TYPE}" >&2
fi

# elicitation_dialog: input request from MCP server (v2.1.76+)
# Background Workers cannot respond to Elicitation forms
# Already auto-skipped by the Elicitation hook, but also kept in the notification log
if [ "${NOTIFICATION_TYPE}" = "elicitation_dialog" ] && [ -n "${AGENT_TYPE}" ]; then
  echo "Notification: elicitation_dialog for agent_type=${AGENT_TYPE} (auto-skipped in background)" >&2
fi

# === terminalSequence output (CC 2.1.141+, opt-in via HARNESS_TERMINAL_NOTIFY) ===
# For notifications that require operator attention, such as permission_prompt / elicitation_dialog,
# Claude Code can fire desktop notifications / window title / bell even without a controlling terminal.
# Details: .claude/rules/hooks-2.1.139-plus.md
if command -v build_terminal_sequence >/dev/null 2>&1; then
  _NOTIFY_TITLE=""
  _NOTIFY_BODY=""
  case "${NOTIFICATION_TYPE}" in
    permission_prompt)
      _NOTIFY_TITLE="Claude Code: permission prompt"
      _NOTIFY_BODY="${AGENT_TYPE:-main} waiting for approval"
      ;;
    elicitation_dialog)
      _NOTIFY_TITLE="Claude Code: elicitation"
      _NOTIFY_BODY="${AGENT_TYPE:-main} MCP elicitation"
      ;;
    idle_prompt)
      _NOTIFY_TITLE="Claude Code: idle"
      _NOTIFY_BODY="session idle"
      ;;
    auth_success)
      _NOTIFY_TITLE="Claude Code: auth success"
      _NOTIFY_BODY=""
      ;;
  esac

  if [ -n "${_NOTIFY_TITLE}" ]; then
    _TS_SEQ="$(build_terminal_sequence "${_NOTIFY_TITLE}" "${_NOTIFY_BODY}")"
    if [ -n "${_TS_SEQ}" ]; then
      _TS_ENCODED="$(encode_terminal_sequence_json "${_TS_SEQ}")"
      if [ -n "${_TS_ENCODED}" ]; then
        printf '{"decision":"approve","reason":"notification logged","terminalSequence":%s}\n' "${_TS_ENCODED}"
        exit 0
      fi
    fi
  fi
fi

exit 0
