#!/bin/bash
# session-register.sh
# Register the session in active.json (no output)
#
# Usage:
#   ./session-register.sh [session_id]
#
# If session_id is omitted, it is read from .claude/state/session.json.
# When called from a hook, output is suppressed to avoid mixing with JSON output.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== Configuration =====
SESSIONS_DIR=".claude/sessions"
ACTIVE_FILE="${SESSIONS_DIR}/active.json"
SESSION_FILE=".claude/state/session.json"
STALE_THRESHOLD=3600  # Sessions older than 1 hour are considered stale

# ===== Helper functions =====
get_session_id_from_file() {
  if [ -f "$SESSION_FILE" ] && command -v jq >/dev/null 2>&1; then
    jq -r '.session_id // empty' "$SESSION_FILE" 2>/dev/null
  fi
}

get_current_timestamp() {
  date +%s
}

# ===== Main processing =====
main() {
  # Get session ID (argument takes priority; otherwise read from file)
  local session_id="${1:-}"
  if [ -z "$session_id" ]; then
    session_id=$(get_session_id_from_file)
  fi

  # Do nothing if there is no session ID (no error output either)
  if [ -z "$session_id" ] || [ "$session_id" = "null" ]; then
    exit 0
  fi

  # Do nothing if jq is unavailable
  if ! command -v jq >/dev/null 2>&1; then
    exit 0
  fi

  # Create directory
  mkdir -p "$SESSIONS_DIR"

  local current_time=$(get_current_timestamp)
  local short_id="${session_id:0:12}"

  # Load active.json (use empty object if it does not exist)
  local session_data="{}"
  if [ -f "$ACTIVE_FILE" ]; then
    session_data=$(cat "$ACTIVE_FILE" 2>/dev/null || echo "{}")
  fi

  # Set up cleanup for temporary file
  local tmp_file=""
  cleanup_tmp() { [ -n "$tmp_file" ] && [ -f "$tmp_file" ] && rm -f "$tmp_file"; }
  trap cleanup_tmp EXIT

  # Register / update session
  tmp_file=$(mktemp)
  echo "$session_data" | jq \
    --arg id "$session_id" \
    --arg short "$short_id" \
    --arg time "$current_time" \
    --arg pid "$$" \
    '.[$id] = {
      "short_id": $short,
      "last_seen": ($time | tonumber),
      "pid": $pid,
      "status": "active"
    }' > "$tmp_file" && mv "$tmp_file" "$ACTIVE_FILE"

  # Clean up old sessions (those older than 24 hours)
  local cleanup_threshold=$((current_time - 86400))
  tmp_file=$(mktemp)
  jq --arg threshold "$cleanup_threshold" \
    'to_entries | map(select(.value.last_seen > ($threshold | tonumber))) | from_entries' \
    "$ACTIVE_FILE" > "$tmp_file" && mv "$tmp_file" "$ACTIVE_FILE"
}

main "$@"
