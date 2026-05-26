#!/bin/bash
# ci-status-checker.sh
# Asynchronously checks CI status after git push / gh pr in the PostToolUse (Bash matcher)
# and injects a message via additionalContext recommending spawning ci-cd-fixer on CI failure detection
#
# Input: stdin JSON from Claude Code hooks (PostToolUse/Bash)
# Output: JSON to approve the event (with optional additionalContext)

set +e  # Do not stop on errors

# === Read JSON payload from stdin ===
INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

# Skip if payload is empty
if [ -z "${INPUT}" ]; then
  echo '{"decision":"approve","reason":"ci-status-checker: no payload"}'
  exit 0
fi

# === Get command and exit code from Bash tool output ===
TOOL_NAME=""
BASH_CMD=""
BASH_EXIT_CODE=""
BASH_OUTPUT=""

if command -v jq >/dev/null 2>&1; then
  _parsed="$(printf '%s' "${INPUT}" | jq -r '[
    (.tool_name // ""),
    (.tool_input.command // ""),
    ((.tool_response.exit_code // .tool_response.exitCode // -1) | tostring),
    ((.tool_response.output // .tool_response.stdout // "") | .[0:500])
  ] | @tsv' 2>/dev/null)"
  if [ -n "${_parsed}" ]; then
    IFS=$'\t' read -r TOOL_NAME BASH_CMD BASH_EXIT_CODE BASH_OUTPUT <<< "${_parsed}"
  fi
elif command -v python3 >/dev/null 2>&1; then
  _parsed="$(printf '%s' "${INPUT}" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    tr = d.get('tool_response', {})
    ti = d.get('tool_input', {})
    print(d.get('tool_name', ''))
    print(ti.get('command', ''))
    print(str(tr.get('exit_code', tr.get('exitCode', -1))))
    out = tr.get('output', tr.get('stdout', ''))
    print(str(out)[:500])
except:
    print('')
    print('')
    print('-1')
    print('')
" 2>/dev/null)"
  TOOL_NAME="$(echo "${_parsed}" | sed -n '1p')"
  BASH_CMD="$(echo "${_parsed}" | sed -n '2p')"
  BASH_EXIT_CODE="$(echo "${_parsed}" | sed -n '3p')"
  BASH_OUTPUT="$(echo "${_parsed}" | sed -n '4p')"
fi

# === Determine whether the command is git push / gh pr ===
is_push_or_pr_command() {
  local cmd="$1"
  # Detect git push / gh pr create / gh pr merge / gh workflow run etc.
  if echo "${cmd}" | grep -Eq '(^|[[:space:]])(git\s+push|gh\s+pr\s+(create|merge|edit)|gh\s+workflow\s+run)'; then
    return 0
  fi
  return 1
}

if ! is_push_or_pr_command "${BASH_CMD}"; then
  echo '{"decision":"approve","reason":"ci-status-checker: not a push/PR command"}'
  exit 0
fi

# === プロジェクトルートを検出 ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
if [ -f "${PARENT_DIR}/path-utils.sh" ]; then
  source "${PARENT_DIR}/path-utils.sh" 2>/dev/null || true
fi
PROJECT_ROOT="${PROJECT_ROOT:-$(detect_project_root 2>/dev/null || pwd)}"
STATE_DIR="${PROJECT_ROOT}/.claude/state"
mkdir -p "${STATE_DIR}" 2>/dev/null || true

# === Check CI status asynchronously (background job) ===
# CI check polls for a maximum of 60 seconds (only when the gh command is available)
CI_STATUS_FILE="${STATE_DIR}/ci-status.json"
TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

check_ci_status_async() {
  if ! command -v gh >/dev/null 2>&1; then
    return
  fi

  local max_wait=60
  local poll_interval=10
  local elapsed=0
  local status="unknown"
  local conclusion="unknown"

  while [ "${elapsed}" -lt "${max_wait}" ]; do
    sleep "${poll_interval}"
    elapsed=$(( elapsed + poll_interval ))

    # Get the latest PR check
    local runs_json
    runs_json="$(gh run list --limit 1 --json status,conclusion,name,url 2>/dev/null)" || runs_json=""
    if [ -z "${runs_json}" ]; then
      continue
    fi

    if command -v jq >/dev/null 2>&1; then
      status="$(printf '%s' "${runs_json}" | jq -r '.[0].status // "unknown"' 2>/dev/null)" || status="unknown"
      conclusion="$(printf '%s' "${runs_json}" | jq -r '.[0].conclusion // "unknown"' 2>/dev/null)" || conclusion="unknown"
    fi

    # Still running if status is not completed
    if [ "${status}" != "completed" ]; then
      continue
    fi

    # Record the result
    if command -v jq >/dev/null 2>&1; then
      jq -n \
        --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        --arg trigger_cmd "${BASH_CMD}" \
        --arg status "${status}" \
        --arg conclusion "${conclusion}" \
        '{timestamp:$ts, trigger_command:$trigger_cmd, status:$status, conclusion:$conclusion}' \
        > "${CI_STATUS_FILE}" 2>/dev/null || true
    fi

    # Write a signal file on CI failure
    if [ "${conclusion}" = "failure" ] || [ "${conclusion}" = "timed_out" ] || [ "${conclusion}" = "cancelled" ]; then
      SIGNALS_FILE="${STATE_DIR}/breezing-signals.jsonl"
      if command -v jq >/dev/null 2>&1; then
        jq -nc \
          --arg signal "ci_failure_detected" \
          --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
          --arg conclusion "${conclusion}" \
          --arg trigger_cmd "${BASH_CMD}" \
          '{signal:$signal, timestamp:$timestamp, conclusion:$conclusion, trigger_command:$trigger_cmd}' \
          >> "${SIGNALS_FILE}" 2>/dev/null || true
      fi
    fi

    return
  done
}

# Run CI check in the background (do not block the hook)
check_ci_status_async &
disown 2>/dev/null || true

# === Check for the most recent CI failure signal and inject additionalContext ===
ADDITIONAL_CONTEXT=""
SIGNALS_FILE="${STATE_DIR}/breezing-signals.jsonl"

if [ -f "${SIGNALS_FILE}" ]; then
  # Get the most recent ci_failure_detected signal (within the last 10 minutes)
  _recent_failure=""
  if command -v jq >/dev/null 2>&1; then
    _recent_failure="$(grep '"ci_failure_detected"' "${SIGNALS_FILE}" 2>/dev/null | tail -1)" || _recent_failure=""
  fi

  if [ -n "${_recent_failure}" ]; then
    _failure_conclusion=""
    if command -v jq >/dev/null 2>&1; then
      _failure_conclusion="$(printf '%s' "${_recent_failure}" | jq -r '.conclusion // ""' 2>/dev/null)" || _failure_conclusion=""
    fi

    ADDITIONAL_CONTEXT="[CI failure detected]\nCI status: ${_failure_conclusion}\nTrigger command: ${BASH_CMD}\n\nRecommended action: spawn /breezing or the ci-cd-fixer agent to automatically repair the CI failure.\n  Example: ask ci-cd-fixer 'CI failed. Please check the logs and fix the issue.'"
  fi
fi

# === Response ===
if [ -n "${ADDITIONAL_CONTEXT}" ]; then
  if command -v jq >/dev/null 2>&1; then
    jq -nc \
      --arg reason "ci-status-checker: push/PR detected, CI failure context injected" \
      --arg ctx "${ADDITIONAL_CONTEXT}" \
      '{"decision":"approve","reason":$reason,"additionalContext":$ctx}'
  else
    echo '{"decision":"approve","reason":"ci-status-checker: push/PR detected, CI failure context injected"}'
  fi
else
  echo '{"decision":"approve","reason":"ci-status-checker: push/PR detected, CI monitoring started"}'
fi
exit 0
