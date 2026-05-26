#!/bin/bash
# session-list.sh
# Display list of active sessions
#
# Usage:
#   ./session-list.sh
#
# Output: List of active sessions

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== Cleanup trap for temp files =====
TEMP_FILES=()
cleanup() {
  for f in "${TEMP_FILES[@]:-}"; do
    [ -f "$f" ] && rm -f "$f"
  done
}
trap cleanup EXIT

# ===== Configuration =====
SESSIONS_DIR=".claude/sessions"
ACTIVE_FILE="${SESSIONS_DIR}/active.json"
SESSION_FILE=".claude/state/session.json"
STALE_THRESHOLD=3600  # sessions inactive for 1 hour are considered stale

# ===== Helper functions =====
get_current_session_id() {
  if [ -f "$SESSION_FILE" ] && command -v jq >/dev/null 2>&1; then
    jq -r '.session_id // "unknown"' "$SESSION_FILE" 2>/dev/null
  else
    echo "unknown"
  fi
}

get_current_timestamp() {
  date +%s
}

# ===== Main processing =====
main() {
  mkdir -p "$SESSIONS_DIR"

  local current_session=$(get_current_session_id)
  local current_time=$(get_current_timestamp)

  # Register/update current session
  if [ -n "$current_session" ] && [ "$current_session" != "unknown" ]; then
    local session_data="{}"

    if [ -f "$ACTIVE_FILE" ] && command -v jq >/dev/null 2>&1; then
      session_data=$(cat "$ACTIVE_FILE")
    fi

    if command -v jq >/dev/null 2>&1; then
      local short_id="${current_session:0:12}"
      local tmp_file=$(mktemp)
      TEMP_FILES+=("$tmp_file")

      echo "$session_data" | jq \
        --arg id "$current_session" \
        --arg short "$short_id" \
        --arg time "$current_time" \
        --arg pid "$$" \
        '.[$id] = {
          "short_id": $short,
          "last_seen": ($time | tonumber),
          "pid": $pid,
          "status": "active"
        }' > "$tmp_file" && mv "$tmp_file" "$ACTIVE_FILE"
    fi
  fi

  # Display session list
  echo "📋 Active session list"
  echo ""

  if [ ! -f "$ACTIVE_FILE" ]; then
    echo "  (no sessions)"
    exit 0
  fi

  if ! command -v jq >/dev/null 2>&1; then
    echo "  ⚠️ Cannot display details because jq is not installed"
    exit 0
  fi

  # Display while cleaning up old sessions
  local active_count=0
  local stale_count=0

  echo "| Session ID | Last active | Status |"
  echo "|------------|-------------|--------|"

  # Process sessions
  jq -r 'to_entries[] | "\(.key)|\(.value.short_id)|\(.value.last_seen)|\(.value.status)"' "$ACTIVE_FILE" 2>/dev/null | while IFS='|' read -r full_id short_id last_seen status; do
    local age=$((current_time - last_seen))
    local time_ago=""
    local display_status=""

    if [ "$age" -lt 60 ]; then
      time_ago="${age}s ago"
    elif [ "$age" -lt 3600 ]; then
      time_ago="$((age / 60))m ago"
    elif [ "$age" -lt 86400 ]; then
      time_ago="$((age / 3600))h ago"
    else
      time_ago="$((age / 86400))d ago"
    fi

    if [ "$full_id" = "$current_session" ]; then
      display_status="🟢 current session"
    elif [ "$age" -lt "$STALE_THRESHOLD" ]; then
      display_status="🟡 active"
    else
      display_status="⚪ inactive"
    fi

    echo "| ${short_id} | ${time_ago} | ${display_status} |"
  done

  echo ""
  echo "💡 Tips:"
  echo "  - /session broadcast \"message\" to notify all sessions"
  echo "  - /session inbox to check received messages"
}

main "$@"
