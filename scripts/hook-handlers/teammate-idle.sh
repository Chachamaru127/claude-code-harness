#!/bin/bash
# teammate-idle.sh
# TeammateIdle hook handler
# Records to timeline when a Teammate becomes idle
#
# Input: stdin JSON from Claude Code hooks
# Output: JSON to approve the event

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

# Timeline file
STATE_DIR="${PROJECT_ROOT}/.claude/state"
TIMELINE_FILE="${STATE_DIR}/breezing-timeline.jsonl"

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
  echo '{"decision":"approve","reason":"TeammateIdle: no payload"}'
  exit 0
fi

# === Field extraction ===
TEAMMATE_NAME=""
TEAM_NAME=""
AGENT_ID=""
AGENT_TYPE=""
HOOK_CONTINUE=""
STOP_REASON=""

if command -v jq >/dev/null 2>&1; then
  TEAMMATE_NAME="$(printf '%s' "${INPUT}" | jq -r '.teammate_name // .agent_name // ""' 2>/dev/null || true)"
  TEAM_NAME="$(printf '%s' "${INPUT}" | jq -r '.team_name // ""' 2>/dev/null || true)"
  AGENT_ID="$(printf '%s' "${INPUT}" | jq -r '.agent_id // ""' 2>/dev/null || true)"
  AGENT_TYPE="$(printf '%s' "${INPUT}" | jq -r '.agent_type // ""' 2>/dev/null || true)"
  HOOK_CONTINUE="$(printf '%s' "${INPUT}" | jq -r '(if has("continue") then (.continue | tostring) else "" end)' 2>/dev/null || true)"
  STOP_REASON="$(printf '%s' "${INPUT}" | jq -r '.stopReason // .stop_reason // ""' 2>/dev/null || true)"
elif command -v python3 >/dev/null 2>&1; then
  _parsed="$(echo "${INPUT}" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('teammate_name', d.get('agent_name', '')))
    print(d.get('team_name', ''))
    print(d.get('agent_id', ''))
    print(d.get('agent_type', ''))
    cont = d.get('continue', '')
    print(str(cont).lower() if isinstance(cont, bool) else str(cont))
    print(d.get('stopReason', d.get('stop_reason', '')))
except:
    print('')
    print('')
    print('')
    print('')
    print('')
    print('')
" 2>/dev/null)"
  TEAMMATE_NAME="$(echo "${_parsed}" | sed -n '1p')"
  TEAM_NAME="$(echo "${_parsed}" | sed -n '2p')"
  AGENT_ID="$(echo "${_parsed}" | sed -n '3p')"
  AGENT_TYPE="$(echo "${_parsed}" | sed -n '4p')"
  HOOK_CONTINUE="$(echo "${_parsed}" | sed -n '5p')"
  STOP_REASON="$(echo "${_parsed}" | sed -n '6p')"
fi

# === Deduplication (skip idle events for the same teammate within 5 seconds) ===
ensure_state_dir

DEDUP_KEY="${TEAMMATE_NAME:-${AGENT_ID}}"

if [ -n "${DEDUP_KEY}" ] && [ -f "${TIMELINE_FILE}" ]; then
  _last="$(grep -F '"teammate_idle"' "${TIMELINE_FILE}" 2>/dev/null | grep -F "\"${DEDUP_KEY}\"" 2>/dev/null | tail -1 || true)"
  if [ -n "${_last}" ]; then
    if command -v jq >/dev/null 2>&1; then
      _ts="$(printf '%s' "${_last}" | jq -r '.timestamp // ""' 2>/dev/null || true)"
    elif command -v python3 >/dev/null 2>&1; then
      _ts="$(printf '%s' "${_last}" | python3 -c "
import sys, json
try: print(json.load(sys.stdin).get('timestamp',''))
except: print('')
" 2>/dev/null || true)"
    else
      _ts=""
    fi
    if [ -n "${_ts}" ] && command -v python3 >/dev/null 2>&1; then
      _skip="$(python3 -c "
import sys, datetime
try:
    ts = sys.argv[1]
    dt = datetime.datetime.fromisoformat(ts.replace('Z','+00:00'))
    now = datetime.datetime.now(datetime.timezone.utc)
    print('skip' if (now - dt).total_seconds() < 5 else 'ok')
except:
    print('ok')
" "${_ts}" 2>/dev/null || true)"
      if [ "${_skip}" = "skip" ]; then
        echo '{"decision":"approve","reason":"TeammateIdle dedup: skipped"}'
        exit 0
      fi
    fi
  fi
fi

# === Record to timeline (safe JSON construction via jq -nc) ===
TS="$(get_timestamp)"

if command -v jq >/dev/null 2>&1; then
  log_entry="$(jq -nc \
    --arg event "teammate_idle" \
    --arg teammate "${TEAMMATE_NAME}" \
    --arg team "${TEAM_NAME}" \
    --arg agent_id "${AGENT_ID}" \
    --arg agent_type "${AGENT_TYPE}" \
    --arg timestamp "${TS}" \
    '{event:$event, teammate:$teammate, team:$team, agent_id:$agent_id, agent_type:$agent_type, timestamp:$timestamp}')"
else
  # Fallback: safely escape via python3
  log_entry="$(python3 -c "
import json, sys
print(json.dumps({
    'event': 'teammate_idle',
    'teammate': sys.argv[1],
    'team': sys.argv[2],
    'agent_id': sys.argv[3],
    'agent_type': sys.argv[4],
    'timestamp': sys.argv[5]
}, ensure_ascii=False))
" "${TEAMMATE_NAME}" "${TEAM_NAME}" "${AGENT_ID}" "${AGENT_TYPE}" "${TS}" 2>/dev/null)" || log_entry=""
fi

if [ -n "${log_entry}" ]; then
  echo "${log_entry}" >> "${TIMELINE_FILE}" 2>/dev/null || true
  rotate_jsonl "${TIMELINE_FILE}"
fi

# === Response ===
if [ "${HOOK_CONTINUE}" = "false" ] || [ -n "${STOP_REASON}" ]; then
  FINAL_STOP_REASON="${STOP_REASON:-TeammateIdle requested stop}"
  if command -v jq >/dev/null 2>&1; then
    jq -nc --arg reason "${FINAL_STOP_REASON}" '{"continue": false, "stopReason": $reason}'
  else
    printf '{"continue": false, "stopReason": "%s"}\n' "${FINAL_STOP_REASON//\"/\\\"}"
  fi
  exit 0
fi

echo '{"decision":"approve","reason":"TeammateIdle tracked"}'
exit 0
