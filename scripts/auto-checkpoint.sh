#!/bin/bash
# auto-checkpoint.sh
# Called in Phase B-5 to call the harness-mem checkpoint API for persistence
# and write a local audit record.
#
# Usage: ./scripts/auto-checkpoint.sh task_id commit_hash sprint_contract_path review_result_path

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

# ── Environment variables ───────────────────────────────────────────────────────────────────
# HARNESS_MEM_CLIENT: path to the old shell client (`scripts/harness-mem-client.sh`).
# When migrating to managed-companion in Phase 60 (v2.20.10),
# `scripts/harness-mem-client.sh` was removed from the claude-harness distribution.
# Current architecture:
#   - persistence via memory-bridge.sh (HTTP daemon API)
#   - management operations via `bin/harness mem ...` (Phase 60 contract)
# This path is kept for **test fixture use only**:
#   - default (env unset): empty string → skip API call, audit only
#   - HARNESS_MEM_CLIENT=/abs/path → validate record-checkpoint API with a fake client, etc.
# Details: docs/harness-mem-companion-contract.md
HARNESS_MEM_CLIENT="${HARNESS_MEM_CLIENT:-}"
# HARNESS_MEM_DISABLE: when set to 1, skip API calls (for fallback validation)
HARNESS_MEM_DISABLE="${HARNESS_MEM_DISABLE:-0}"
# HARNESS_MEM_CLIENT_TIMEOUT_SEC: API call timeout in seconds
export HARNESS_MEM_CLIENT_TIMEOUT_SEC="${HARNESS_MEM_CLIENT_TIMEOUT_SEC:-8}"
# CHECKPOINT_LOCK_TIMEOUT: flock/lockf wait timeout in seconds
CHECKPOINT_LOCK_TIMEOUT="${CHECKPOINT_LOCK_TIMEOUT:-10}"

# ── Arguments ──────────────────────────────────────────────────────────────────────
if [ $# -lt 4 ]; then
  echo "Usage: $0 task_id commit_hash sprint_contract_path review_result_path" >&2
  exit 1
fi

TASK_ID="$1"
COMMIT_HASH="$2"
SPRINT_CONTRACT_PATH="$3"
REVIEW_RESULT_PATH="$4"

# ── Constants ──────────────────────────────────────────────────────────────────────
STATE_DIR="${PROJECT_ROOT}/.claude/state"
LOCKS_DIR="${STATE_DIR}/locks"
LOCK_FILE="${LOCKS_DIR}/phase-b.lock"
CHECKPOINT_EVENTS_FILE="${STATE_DIR}/checkpoint-events.jsonl"
SESSION_EVENTS_FILE="${STATE_DIR}/session-events.jsonl"

# ── Utilities ────────────────────────────────────────────────────────────
timestamp_iso8601() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

json_escape() {
  # Basic JSON string escaping (via python3)
  printf '%s' "$1" | python3 -c 'import json,sys; sys.stdout.write(json.dumps(sys.stdin.read())[1:-1])' 2>/dev/null \
    || printf '%s' "$1" | sed 's/\\/\\\\/g;s/"/\\"/g;s/	/\\t/g'
}

read_json_file() {
  local path="$1"
  if [ -f "$path" ]; then
    # Remove newlines and collapse to a single line
    tr -d '\n\r' < "$path" | tr -s ' '
  else
    printf '{}'
  fi
}

append_jsonl() {
  local file="$1"
  local record="$2"
  # Create file if it does not exist
  mkdir -p "$(dirname "$file")"
  printf '%s\n' "$record" >> "$file"
}

# ── Lock implementation (flock/lockf/mkdir fallback) ────────────────────────────
_LOCK_ACQUIRED=0
_LOCK_MUTEX_DIR="${LOCK_FILE}.dir"

acquire_lock() {
  local timeout="${CHECKPOINT_LOCK_TIMEOUT}"
  mkdir -p "${LOCKS_DIR}"

  if command -v flock >/dev/null 2>&1; then
    # Linux: flock -w timeout fd
    exec 9>"${LOCK_FILE}"
    if flock -w "${timeout}" 9; then
      _LOCK_ACQUIRED=1
      return 0
    else
      exec 9>&- 2>/dev/null || true
      return 1
    fi
  fi

  if command -v lockf >/dev/null 2>&1; then
    # macOS: lockf -t timeout -k file shell -c "..."
    # lockf wraps a command, so use FD-based form
    # lockf -s -t N fd form for blocking wait
    exec 9>"${LOCK_FILE}"
    if lockf -s -t "${timeout}" 9; then
      _LOCK_ACQUIRED=2
      return 0
    else
      exec 9>&- 2>/dev/null || true
      return 1
    fi
  fi

  # Fallback: mutual exclusion via mkdir
  local waited=0
  while ! mkdir "${_LOCK_MUTEX_DIR}" 2>/dev/null; do
    sleep 0.2
    waited=$((waited + 1))
    if [ "${waited}" -ge $((timeout * 5)) ]; then
      return 1
    fi
  done
  _LOCK_ACQUIRED=3
  return 0
}

release_lock() {
  case "${_LOCK_ACQUIRED}" in
    1)
      # flock
      flock -u 9 2>/dev/null || true
      exec 9>&- 2>/dev/null || true
      ;;
    2)
      # lockf
      exec 9>&- 2>/dev/null || true
      ;;
    3)
      # mkdir fallback
      rmdir "${_LOCK_MUTEX_DIR}" 2>/dev/null || true
      ;;
  esac
  _LOCK_ACQUIRED=0
}

# ── Main logic ─────────────────────────────────────────────────────────────
main() {
  mkdir -p "${LOCKS_DIR}"

  local timestamp
  timestamp="$(timestamp_iso8601)"

  local status="ok"
  local error_msg="null"

  # ── Acquire lock (timeout: CHECKPOINT_LOCK_TIMEOUT seconds) ──────────────
  if ! acquire_lock; then
    echo "[auto-checkpoint] ERROR: timed out acquiring phase-b.lock (${CHECKPOINT_LOCK_TIMEOUT}s)" >&2
    # Write a failure record to checkpoint-events.jsonl even on timeout
    local timeout_record
    timeout_record="$(printf \
      '{"type":"checkpoint","status":"failed","task":"%s","commit":"%s","sprint_contract":"%s","review_result":"%s","timestamp":"%s","error":"lock_timeout"}' \
      "$(json_escape "${TASK_ID}")" \
      "$(json_escape "${COMMIT_HASH}")" \
      "$(json_escape "${SPRINT_CONTRACT_PATH}")" \
      "$(json_escape "${REVIEW_RESULT_PATH}")" \
      "${timestamp}")"
    append_jsonl "${CHECKPOINT_EVENTS_FILE}" "${timeout_record}"
    exit 1
  fi

  # ── Lock acquired. Release on EXIT ──────────────────────────────────────
  trap 'release_lock' EXIT

  # ── harness-mem API call ──────────────────────────────────────────────
  local api_success=0
  local api_error=""

  if [ "${HARNESS_MEM_DISABLE}" = "1" ]; then
    api_success=0
    api_error="HARNESS_MEM_DISABLE=1"
  elif [ ! -x "${HARNESS_MEM_CLIENT}" ]; then
    api_success=0
    api_error="harness-mem-client not found or not executable: ${HARNESS_MEM_CLIENT}"
  else
    # session_id: read from CLAUDE_SESSION_ID env var, fall back to uuidgen
    local session_id
    session_id="${CLAUDE_SESSION_ID:-}"
    if [ -z "${session_id}" ]; then
      session_id="$(uuidgen 2>/dev/null \
        || cat /proc/sys/kernel/random/uuid 2>/dev/null \
        || printf 'fallback-%s' "${TASK_ID}")"
    fi

    # Load sprint_contract and review_result
    local contract_content result_content
    contract_content="$(read_json_file "${SPRINT_CONTRACT_PATH}")"
    result_content="$(read_json_file "${REVIEW_RESULT_PATH}")"

    # Escape content as a JSON string
    local raw_content
    raw_content="$(printf '{"commit":"%s","sprint_contract":%s,"review_result":%s}' \
      "$(json_escape "${COMMIT_HASH}")" \
      "${contract_content}" \
      "${result_content}")"
    local content_escaped
    content_escaped="$(json_escape "${raw_content}")"

    # Build payload JSON
    local payload
    payload="$(printf \
      '{"session_id":"%s","title":"Phase checkpoint: %s","content":"%s","platform":"claude-code","project":"claude-code-harness","tags":["checkpoint","phase-b","task:%s"]}' \
      "$(json_escape "${session_id}")" \
      "$(json_escape "${TASK_ID}")" \
      "${content_escaped}" \
      "$(json_escape "${TASK_ID}")")"

    # Call the API
    local api_response=""
    if api_response="$("${HARNESS_MEM_CLIENT}" record-checkpoint "${payload}" 2>&1)"; then
      # Treat as success if the ok field is not false
      if printf '%s' "${api_response}" | grep -q '"ok":false'; then
        api_success=0
        api_error="$(printf '%s' "${api_response}" | grep -o '"error":"[^"]*"' | head -1 | sed 's/"error":"//;s/"//' || printf 'api_error')"
      else
        api_success=1
      fi
    else
      api_success=0
      api_error="${api_response:-api_call_failed}"
    fi
  fi

  # ── On failure: write degraded output to session-events.jsonl ────────────────────────────
  if [ "${api_success}" = "0" ]; then
    status="failed"
    error_msg="$(json_escape "${api_error}")"

    local session_event
    session_event="$(printf \
      '{"type":"checkpoint_failed","task":"%s","commit":"%s","timestamp":"%s","error":"%s"}' \
      "$(json_escape "${TASK_ID}")" \
      "$(json_escape "${COMMIT_HASH}")" \
      "${timestamp}" \
      "${error_msg}")"
    append_jsonl "${SESSION_EVENTS_FILE}" "${session_event}"

    echo "[auto-checkpoint] WARNING: harness-mem API call failed — ${api_error}" >&2
  fi

  # ── Append audit record to checkpoint-events.jsonl regardless of success/failure ─────
  local error_field
  if [ "${error_msg}" = "null" ]; then
    error_field="null"
  else
    error_field="\"${error_msg}\""
  fi

  local checkpoint_record
  checkpoint_record="$(printf \
    '{"type":"checkpoint","status":"%s","task":"%s","commit":"%s","sprint_contract":"%s","review_result":"%s","timestamp":"%s","error":%s}' \
    "${status}" \
    "$(json_escape "${TASK_ID}")" \
    "$(json_escape "${COMMIT_HASH}")" \
    "$(json_escape "${SPRINT_CONTRACT_PATH}")" \
    "$(json_escape "${REVIEW_RESULT_PATH}")" \
    "${timestamp}" \
    "${error_field}")"
  append_jsonl "${CHECKPOINT_EVENTS_FILE}" "${checkpoint_record}"

  if [ "${status}" = "failed" ]; then
    exit 1
  fi

  echo "[auto-checkpoint] OK: task=${TASK_ID} commit=${COMMIT_HASH}" >&2
  exit 0
}

main "$@"
