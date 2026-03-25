#!/bin/bash
# stop-failure.sh
# StopFailure hook handler (v2.1.78+)
# Fires when the turn ends due to an API error (rate limit, auth failure, etc.)
# Logs the failure and notifies Lead for Breezing recovery.
#
# Input: stdin JSON from Claude Code hooks
# Output: JSON with systemMessage for recovery guidance

set -euo pipefail

# === Setup ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [ -f "${PARENT_DIR}/path-utils.sh" ]; then
  source "${PARENT_DIR}/path-utils.sh"
fi

PROJECT_ROOT="${PROJECT_ROOT:-$(detect_project_root 2>/dev/null || pwd)}"
STATE_DIR="${PROJECT_ROOT}/.claude/state"

# === Utility ===

ensure_state_dir() {
  local state_parent
  state_parent="$(dirname "${STATE_DIR}")"

  if [ -L "${state_parent}" ] || [ -L "${STATE_DIR}" ]; then
    return 1
  fi

  mkdir -p "${STATE_DIR}" 2>/dev/null || true
  chmod 700 "${STATE_DIR}" 2>/dev/null || true

  [ -d "${STATE_DIR}" ] || return 1
  [ ! -L "${STATE_DIR}" ] || return 1
  return 0
}

# === Read stdin ===
INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

if [ -z "${INPUT}" ]; then
  echo '{}'
  exit 0
fi

# === Extract fields ===
ERROR_TYPE=""
ERROR_MSG=""
AGENT_TYPE=""

if command -v jq >/dev/null 2>&1; then
  ERROR_TYPE="$(printf '%s' "${INPUT}" | jq -r '.error_type // .errorType // "unknown"' 2>/dev/null || echo "unknown")"
  ERROR_MSG="$(printf '%s' "${INPUT}" | jq -r '(.error // .message // "" | tostring)[0:300]' 2>/dev/null || echo "")"
  AGENT_TYPE="$(printf '%s' "${INPUT}" | jq -r '.agent_type // .agentType // ""' 2>/dev/null || echo "")"
elif command -v python3 >/dev/null 2>&1; then
  _parsed="$(printf '%s' "${INPUT}" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('error_type', d.get('errorType', 'unknown')))
    err = str(d.get('error', d.get('message', '')))
    print(err[:300])
    print(d.get('agent_type', d.get('agentType', '')))
except:
    print('unknown')
    print('')
    print('')
" 2>/dev/null)"
  ERROR_TYPE="$(echo "${_parsed}" | sed -n '1p')"
  ERROR_MSG="$(echo "${_parsed}" | sed -n '2p')"
  AGENT_TYPE="$(echo "${_parsed}" | sed -n '3p')"
fi

# === Log to stop-failure events file ===
if ensure_state_dir; then
  LOG_FILE="${STATE_DIR}/stop-failure-events.jsonl"

  if [ ! -L "${LOG_FILE}" ]; then
    NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%s)"

    if command -v jq >/dev/null 2>&1; then
      jq -nc \
        --arg ts "${NOW}" \
        --arg type "${ERROR_TYPE}" \
        --arg msg "${ERROR_MSG}" \
        --arg agent "${AGENT_TYPE}" \
        '{timestamp: $ts, error_type: $type, message: $msg, agent_type: $agent}' >> "${LOG_FILE}" 2>/dev/null || true
    else
      printf '{"timestamp":"%s","error_type":"%s","agent_type":"%s"}\n' \
        "${NOW}" "${ERROR_TYPE}" "${AGENT_TYPE}" >> "${LOG_FILE}" 2>/dev/null || true
    fi
  fi
fi

# === Build recovery guidance ===
RECOVERY_MSG=""

case "${ERROR_TYPE}" in
  *rate_limit*|*429*|*RateLimit*)
    RECOVERY_MSG="API rate limit hit. Wait before retrying. If in Breezing mode, consider reducing parallel workers or switching to a lower-cost model."
    ;;
  *auth*|*401*|*403*|*Auth*)
    RECOVERY_MSG="Authentication error. Check API keys or OIDC token. For local dev, re-run 'vercel env pull' if using AI Gateway."
    ;;
  *overloaded*|*529*|*Overloaded*)
    RECOVERY_MSG="API overloaded. Retry after a delay. This is transient — the request should succeed on retry."
    ;;
  *)
    RECOVERY_MSG="API error caused turn failure (type: ${ERROR_TYPE}). Check connection and credentials."
    ;;
esac

# === Output ===
if command -v jq >/dev/null 2>&1; then
  jq -nc \
    --arg recovery "${RECOVERY_MSG}" \
    --arg type "${ERROR_TYPE}" \
    --arg agent "${AGENT_TYPE}" \
    '{systemMessage: ("STOP_FAILURE: " + $recovery + (if $agent != "" then (" [agent: " + $agent + "]") else "" end))}'
else
  printf '{"systemMessage":"STOP_FAILURE: %s"}\n' "${RECOVERY_MSG}"
fi

exit 0
