#!/usr/bin/env bash
# elicitation-handler.sh
# Elicitation hook handler
# Fires when an MCP server requests structured input from the user
# During Breezing sessions (background Worker/Reviewer), interaction is not possible, so auto-skip
#
# Input: stdin JSON from Claude Code hooks
# Output: JSON response
# Hook event: Elicitation

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

# Log file
STATE_DIR="${PROJECT_ROOT}/.claude/state"
LOG_FILE="${STATE_DIR}/elicitation-events.jsonl"

# === Utility functions ===

ensure_state_dir() {
  mkdir -p "${STATE_DIR}" 2>/dev/null || true
  chmod 700 "${STATE_DIR}" 2>/dev/null || true
}

# JSONL rotation (trim to 400 lines when exceeding 500)
rotate_jsonl() {
  local file="$1"
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
  echo '{"decision":"approve","reason":"Elicitation: no payload"}'
  exit 0
fi

# === Field extraction ===
MCP_SERVER=""
ELICITATION_ID=""
MESSAGE=""

if command -v jq >/dev/null 2>&1; then
  MCP_SERVER="$(printf '%s' "${INPUT}" | jq -r '.mcp_server_name // .server_name // .matcher // ""' 2>/dev/null || true)"
  ELICITATION_ID="$(printf '%s' "${INPUT}" | jq -r '.elicitation_id // .id // ""' 2>/dev/null || true)"
  MESSAGE="$(printf '%s' "${INPUT}" | jq -r '.message // ""' 2>/dev/null || true)"
elif command -v python3 >/dev/null 2>&1; then
  _parsed="$(printf '%s' "${INPUT}" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('mcp_server_name', d.get('server_name', d.get('matcher', ''))))
    print(d.get('elicitation_id', d.get('id', '')))
    print(d.get('message', ''))
except:
    print('')
    print('')
    print('')
" 2>/dev/null)"
  MCP_SERVER="$(echo "${_parsed}" | sed -n '1p')"
  ELICITATION_ID="$(echo "${_parsed}" | sed -n '2p')"
  MESSAGE="$(echo "${_parsed}" | sed -n '3p')"
fi

# === Timeline logging ===
ensure_state_dir
TS="$(get_timestamp)"

log_entry=""
if command -v jq >/dev/null 2>&1; then
  log_entry="$(jq -nc \
    --arg event "elicitation" \
    --arg mcp_server "${MCP_SERVER}" \
    --arg elicitation_id "${ELICITATION_ID}" \
    --arg message "${MESSAGE}" \
    --arg breezing "${HARNESS_BREEZING_SESSION_ID:-}" \
    --arg timestamp "${TS}" \
    '{event:$event, mcp_server:$mcp_server, elicitation_id:$elicitation_id, message:$message, breezing_session:$breezing, timestamp:$timestamp}')"
elif command -v python3 >/dev/null 2>&1; then
  log_entry="$(python3 -c "
import json, sys
print(json.dumps({
    'event': 'elicitation',
    'mcp_server': sys.argv[1],
    'elicitation_id': sys.argv[2],
    'message': sys.argv[3],
    'breezing_session': sys.argv[4],
    'timestamp': sys.argv[5]
}, ensure_ascii=False))
" "${MCP_SERVER}" "${ELICITATION_ID}" "${MESSAGE}" "${HARNESS_BREEZING_SESSION_ID:-}" "${TS}" 2>/dev/null)" || log_entry=""
fi

if [ -n "${log_entry}" ]; then
  echo "${log_entry}" >> "${LOG_FILE}" 2>/dev/null || true
  rotate_jsonl "${LOG_FILE}"
fi

# === Auto-skip elicitation during Breezing sessions ===
# Background Worker/Reviewer cannot interact with the UI
if [ -n "${HARNESS_BREEZING_SESSION_ID:-}" ]; then
  SKIP_REASON="Breezing session (${HARNESS_BREEZING_SESSION_ID}): background agent cannot interact with elicitation UI"
  if command -v jq >/dev/null 2>&1; then
    jq -nc \
      --arg reason "${SKIP_REASON}" \
      '{"decision":"deny","reason":$reason}'
  else
    printf '{"decision":"deny","reason":"Breezing session: background agent cannot interact with elicitation UI"}\n'
  fi
  exit 0
fi

# === Normal session: pass through (user responds interactively) ===
echo '{"decision":"approve","reason":"Elicitation: forwarding to user"}'
exit 0
