#!/bin/bash
# webhook-notify.sh
# POSTs to an external webhook only when HARNESS_WEBHOOK_URL is set.
# Because environment variables are not expanded in the url field of HTTP hooks,
# this is implemented as a command hook + curl.
#
# Usage: bash webhook-notify.sh <event-name>
# Input: stdin JSON from Claude Code hooks
# Env:
#   HARNESS_WEBHOOK_URL (optional, skip if unset) — external webhook POST
#   HARNESS_TERMINAL_NOTIFY (optional) — CC 2.1.141+ terminalSequence opt-in
#     Details: .claude/rules/hooks-2.1.139-plus.md

set -euo pipefail

EVENT_NAME="${1:-unknown}"

# Load terminalSequence helper (CC 2.1.141+)
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${_SCRIPT_DIR}/../lib/terminal-notify.sh" ]; then
  # shellcheck disable=SC1091
  source "${_SCRIPT_DIR}/../lib/terminal-notify.sh"
fi

# Helper to build the terminalSequence JSON field for output
# Args: $1 = title, $2 = body (optional)
# Stdout: `,"terminalSequence":"..."` または空文字列
_render_terminal_sequence_field() {
  if ! command -v build_terminal_sequence >/dev/null 2>&1; then
    return 0
  fi
  local _seq _encoded
  _seq="$(build_terminal_sequence "${1:-}" "${2:-}")"
  if [ -z "${_seq}" ]; then
    return 0
  fi
  _encoded="$(encode_terminal_sequence_json "${_seq}")"
  if [ -n "${_encoded}" ]; then
    printf ',"terminalSequence":%s' "${_encoded}"
  fi
}

# Exit without doing anything if HARNESS_WEBHOOK_URL is unset (opt-in)
# However, if only terminalSequence is opted in, fire a local notification
if [ -z "${HARNESS_WEBHOOK_URL:-}" ]; then
  _ts_field="$(_render_terminal_sequence_field "Claude Code: ${EVENT_NAME}" "")"
  if [ -n "${_ts_field}" ]; then
    printf '{"decision":"approve","reason":"webhook URL not configured; local terminal notify only"%s}\n' "${_ts_field}"
  else
    echo '{"decision":"approve","reason":"webhook URL not configured, skipping"}'
  fi
  exit 0
fi

# Read hook payload from stdin
PAYLOAD=""
if [ ! -t 0 ]; then
  PAYLOAD=$(cat)
fi

# Mask the URL (secret protection: show scheme only)
# Hides everything including user:pass@host, ?token=xxx, /services/T00/B00/xxx, etc.
MASKED_URL="$(echo "${HARNESS_WEBHOOK_URL}" | sed -E 's|^(https?://).*|\1***/***|')"

# POST via curl (5-second timeout; continue with approve on failure but report the result)
HTTP_CODE=""
CURL_EXIT=0
HTTP_CODE=$(curl --silent --output /dev/null --write-out "%{http_code}" --max-time 5 \
  --request POST \
  --header "Content-Type: application/json" \
  --header "X-Harness-Event: ${EVENT_NAME}" \
  --data "${PAYLOAD:-"{}"}" \
  "${HARNESS_WEBHOOK_URL}" 2>/dev/null) || CURL_EXIT=$?

# terminalSequence payload (title differs for success vs. failure)
_TS_FIELD_SUCCESS="$(_render_terminal_sequence_field "Claude Code: ${EVENT_NAME}" "webhook sent")"
_TS_FIELD_FAILURE="$(_render_terminal_sequence_field "Claude Code: ${EVENT_NAME} (failed)" "webhook delivery failed")"

# Build JSON safely with jq if available, otherwise use a fixed message
if [ "$CURL_EXIT" -ne 0 ]; then
  if command -v jq >/dev/null 2>&1; then
    _BASE="$(jq -nc --arg reason "webhook delivery failed (curl exit $CURL_EXIT)" \
           --arg msg "[webhook-notify] POST to ${MASKED_URL} failed (curl exit $CURL_EXIT)" \
           '{"decision":"approve","reason":$reason,"systemMessage":$msg}')"
    if [ -n "${_TS_FIELD_FAILURE}" ]; then
      printf '%s\n' "${_BASE%\}}${_TS_FIELD_FAILURE}}"
    else
      printf '%s\n' "${_BASE}"
    fi
  else
    printf '{"decision":"approve","reason":"webhook delivery failed","systemMessage":"[webhook-notify] POST failed"%s}\n' "${_TS_FIELD_FAILURE}"
  fi
elif [ "${HTTP_CODE:-000}" -ge 200 ] && [ "${HTTP_CODE:-000}" -lt 300 ] 2>/dev/null; then
  printf '{"decision":"approve","reason":"webhook notification sent"%s}\n' "${_TS_FIELD_SUCCESS}"
else
  if command -v jq >/dev/null 2>&1; then
    _BASE="$(jq -nc --arg reason "webhook returned HTTP ${HTTP_CODE}" \
           --arg msg "[webhook-notify] POST to ${MASKED_URL} returned HTTP ${HTTP_CODE}" \
           '{"decision":"approve","reason":$reason,"systemMessage":$msg}')"
    if [ -n "${_TS_FIELD_FAILURE}" ]; then
      printf '%s\n' "${_BASE%\}}${_TS_FIELD_FAILURE}}"
    else
      printf '%s\n' "${_BASE}"
    fi
  else
    printf '{"decision":"approve","reason":"webhook returned HTTP %s","systemMessage":"[webhook-notify] POST returned HTTP %s"%s}\n' "${HTTP_CODE}" "${HTTP_CODE}" "${_TS_FIELD_FAILURE}"
  fi
fi
