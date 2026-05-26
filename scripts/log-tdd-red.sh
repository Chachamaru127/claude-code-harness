#!/bin/bash
# log-tdd-red.sh
# Phase 68 - TDD Red evidence JSONL recording helper
#
# When a Worker runs a failing test, appends the execution result to
# .claude/state/tdd-red-log/<task-id>.jsonl.
# Single signal source shared by all 4 enforcement layers
# (L1 worker self_review / L2 reviewer critical / L3 R14 hook /
# L4 validate-plugin compliance).
#
# Usage:
#   bash scripts/log-tdd-red.sh \
#     --task-id <id> \
#     --test-file <path> \
#     --exit-code <n> \
#     [--framework <name>] \
#     [--stderr-tail <text>]
#
# Output (JSONL line appended to .claude/state/tdd-red-log/<task-id>.jsonl):
#   {timestamp, task_id, test_file, exit_code, framework, stderr_tail, cwd_hash}
#
# Idempotent: does not re-record an entry with the same {test_file, exit_code} as the previous one.
# Rotation: trims to the last 400 lines when exceeding 500.

set -euo pipefail

# === Path resolution ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/path-utils.sh" ]; then
  # shellcheck source=/dev/null
  source "${SCRIPT_DIR}/path-utils.sh"
fi

# Use detect_project_root if available; otherwise fall back to PROJECT_ROOT env or pwd
if command -v detect_project_root >/dev/null 2>&1; then
  PROJECT_ROOT="${PROJECT_ROOT:-$(detect_project_root 2>/dev/null || pwd)}"
else
  PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
fi

# === Defaults ===
TASK_ID=""
TEST_FILE=""
EXIT_CODE=""
FRAMEWORK=""
STDERR_TAIL=""

# === Args ===
while [ $# -gt 0 ]; do
  case "$1" in
    --task-id)      TASK_ID="${2:-}"; shift 2 ;;
    --test-file)    TEST_FILE="${2:-}"; shift 2 ;;
    --exit-code)    EXIT_CODE="${2:-}"; shift 2 ;;
    --framework)    FRAMEWORK="${2:-}"; shift 2 ;;
    --stderr-tail)  STDERR_TAIL="${2:-}"; shift 2 ;;
    --help|-h)
      sed -n '2,24p' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    *)
      echo "Error: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# === Validation ===
if [ -z "${TASK_ID}" ] || [ -z "${TEST_FILE}" ] || [ -z "${EXIT_CODE}" ]; then
  echo "Error: --task-id, --test-file, --exit-code are required" >&2
  exit 1
fi

# task_id sanitization (strip path separators / shell metacharacters)
SAFE_TASK_ID="$(printf '%s' "${TASK_ID}" | tr -c '[:alnum:]._-' '_')"
if [ -z "${SAFE_TASK_ID}" ]; then
  echo "Error: --task-id sanitized to empty string" >&2
  exit 1
fi

# === State dir ===
STATE_DIR="${PROJECT_ROOT}/.claude/state/tdd-red-log"
mkdir -p "${STATE_DIR}" 2>/dev/null || true
chmod 700 "${STATE_DIR}" 2>/dev/null || true

LOG_FILE="${STATE_DIR}/${SAFE_TASK_ID}.jsonl"

# === Helpers ===
get_timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Hash of CWD (for tracking where the record was made; prevents git worktree collisions)
cwd_hash() {
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "${PROJECT_ROOT}" | sha256sum | awk '{print substr($1, 1, 12)}'
  elif command -v shasum >/dev/null 2>&1; then
    printf '%s' "${PROJECT_ROOT}" | shasum -a 256 | awk '{print substr($1, 1, 12)}'
  else
    # fallback: first 12 characters (safe side; collisions do not affect evaluation)
    printf '%s' "${PROJECT_ROOT}" | head -c 12
  fi
}

rotate_jsonl() {
  local file="$1"
  local _lines
  _lines="$(wc -l < "${file}" 2>/dev/null)" || _lines=0
  if [ "${_lines}" -gt 500 ] 2>/dev/null; then
    tail -400 "${file}" > "${file}.tmp" 2>/dev/null && \
      mv "${file}.tmp" "${file}" 2>/dev/null || true
  fi
}

# Idempotent guard: deduplicate entries with the same {test_file, exit_code} as the last line
is_duplicate_last() {
  local file="$1"
  local test_file="$2"
  local exit_code="$3"
  [ -f "${file}" ] || return 1
  local last_line
  last_line="$(tail -n 1 "${file}" 2>/dev/null)" || return 1
  [ -z "${last_line}" ] && return 1
  if command -v jq >/dev/null 2>&1; then
    local last_tf last_ec
    last_tf="$(printf '%s' "${last_line}" | jq -r '.test_file // ""' 2>/dev/null || printf '')"
    last_ec="$(printf '%s' "${last_line}" | jq -r '.exit_code | tostring' 2>/dev/null || printf '')"
    if [ "${last_tf}" = "${test_file}" ] && [ "${last_ec}" = "${exit_code}" ]; then
      return 0
    fi
  fi
  return 1
}

# === Compose log entry ===
TS="$(get_timestamp)"
HASH="$(cwd_hash)"

if is_duplicate_last "${LOG_FILE}" "${TEST_FILE}" "${EXIT_CODE}"; then
  # Same as previous: idempotent skip (exit 0)
  exit 0
fi

log_entry=""
if command -v jq >/dev/null 2>&1; then
  log_entry="$(jq -nc \
    --arg ts "${TS}" \
    --arg task_id "${TASK_ID}" \
    --arg test_file "${TEST_FILE}" \
    --arg exit_code "${EXIT_CODE}" \
    --arg framework "${FRAMEWORK}" \
    --arg stderr_tail "${STDERR_TAIL}" \
    --arg cwd_hash "${HASH}" \
    '{timestamp:$ts, task_id:$task_id, test_file:$test_file, exit_code:($exit_code|tonumber? // $exit_code), framework:$framework, stderr_tail:$stderr_tail, cwd_hash:$cwd_hash}')"
elif command -v python3 >/dev/null 2>&1; then
  log_entry="$(TS="${TS}" TASK_ID="${TASK_ID}" TEST_FILE="${TEST_FILE}" EXIT_CODE="${EXIT_CODE}" FRAMEWORK="${FRAMEWORK}" STDERR_TAIL="${STDERR_TAIL}" CWD_HASH="${HASH}" python3 -c "
import json, os, sys
try:
    raw = os.environ['EXIT_CODE']
    try:
        ec = int(raw)
    except ValueError:
        ec = raw
    sys.stdout.write(json.dumps({
        'timestamp': os.environ['TS'],
        'task_id': os.environ['TASK_ID'],
        'test_file': os.environ['TEST_FILE'],
        'exit_code': ec,
        'framework': os.environ['FRAMEWORK'],
        'stderr_tail': os.environ['STDERR_TAIL'],
        'cwd_hash': os.environ['CWD_HASH'],
    }, ensure_ascii=False))
except Exception:
    pass
" 2>/dev/null)" || log_entry=""
fi

if [ -z "${log_entry}" ]; then
  echo "Error: no JSON writer available (jq or python3 required)" >&2
  exit 1
fi

# === Append and rotate ===
printf '%s\n' "${log_entry}" >> "${LOG_FILE}"
rotate_jsonl "${LOG_FILE}"

exit 0
