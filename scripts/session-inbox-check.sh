#!/bin/bash
# session-inbox-check.sh
# Check incoming messages between sessions
#
# Usage:
#   ./session-inbox-check.sh           # Show unread messages
#   ./session-inbox-check.sh --count   # Show unread count only
#   ./session-inbox-check.sh --mark    # Mark as read
#
# Output: List of unread messages or JSON (for hooks)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== Configuration =====
SESSIONS_DIR=".claude/sessions"
BROADCAST_FILE="${SESSIONS_DIR}/broadcast.md"
SESSION_FILE=".claude/state/session.json"

# ===== Helper functions =====
get_session_id() {
  if [ -f "$SESSION_FILE" ] && command -v jq >/dev/null 2>&1; then
    jq -r '.session_id // "unknown"' "$SESSION_FILE" 2>/dev/null
  else
    echo "unknown"
  fi
}

get_last_read_file() {
  local session_id=$(get_session_id)
  echo "${SESSIONS_DIR}/.last_inbox_read_${session_id}"
}

get_last_read_time() {
  local last_read_file=$(get_last_read_file)
  if [ -f "$last_read_file" ]; then
    cat "$last_read_file"
  elif [ -f "${SESSIONS_DIR}/.last_read_$(get_session_id)" ]; then
    cat "${SESSIONS_DIR}/.last_read_$(get_session_id)"
  else
    echo "1970-01-01T00:00:00Z"
  fi
}

mark_as_read() {
  local last_read_file=$(get_last_read_file)
  mkdir -p "$SESSIONS_DIR"
  date -u +%Y-%m-%dT%H:%M:%SZ > "$last_read_file"
}

# ===== Main processing =====
main() {
  local mode="list"
  local hook_output="false"

  # Argument parsing
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --count)
        mode="count"
        shift
        ;;
      --mark)
        mode="mark"
        shift
        ;;
      --hook)
        hook_output="true"
        shift
        ;;
      --help|-h)
        echo "Usage: session-inbox-check.sh [--count|--mark|--hook]"
        echo ""
        echo "Options:"
        echo "  --count  Show unread count only"
        echo "  --mark   Mark all as read"
        echo "  --hook   Output JSON for hooks"
        exit 0
        ;;
      *)
        shift
        ;;
    esac
  done

  # Broadcast file does not exist
  if [ ! -f "$BROADCAST_FILE" ]; then
    if [ "$hook_output" = "true" ]; then
      echo '{"hookSpecificOutput":{"hookEventName":"InboxCheck","additionalContext":""}}'
    elif [ "$mode" = "count" ]; then
      echo "0"
    else
      echo "📭 No messages"
    fi
    exit 0
  fi

  # Mark as read processing
  if [ "$mode" = "mark" ]; then
    mark_as_read
    echo "✅ All messages marked as read"
    exit 0
  fi

  # Get last read time
  local last_read=$(get_last_read_time)
  local current_session=$(get_session_id)
  local short_current="${current_session:0:12}"

  # Extract unread messages
  local unread_messages=""
  local unread_count=0
  local in_message=false
  local current_timestamp=""
  local current_sender=""
  local current_content=""

  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" =~ ^##\ ([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z)\ \[([^\]]+)\] ]]; then
      # Process previous message
      if [ "$in_message" = true ] && [ -n "$current_content" ]; then
        if [[ "$current_timestamp" > "$last_read" ]] && [[ "$current_sender" != "$short_current" ]]; then
          unread_count=$((unread_count + 1))
          unread_messages="${unread_messages}\n[${current_timestamp:0:10} ${current_timestamp:11:5}] ${current_sender}: ${current_content}"
        fi
      fi

      # Start new message
      current_timestamp="${BASH_REMATCH[1]}"
      current_sender="${BASH_REMATCH[2]}"
      current_content=""
      in_message=true
    elif [ "$in_message" = true ] && [ -n "$line" ]; then
      current_content="$line"
    fi
  done < "$BROADCAST_FILE"

  # Process the last message
  if [ "$in_message" = true ] && [ -n "$current_content" ]; then
    if [[ "$current_timestamp" > "$last_read" ]] && [[ "$current_sender" != "$short_current" ]]; then
      unread_count=$((unread_count + 1))
      unread_messages="${unread_messages}\n[${current_timestamp:0:10} ${current_timestamp:11:5}] ${current_sender}: ${current_content}"
    fi
  fi

  # Output
  if [ "$mode" = "count" ]; then
    echo "$unread_count"
  elif [ "$hook_output" = "true" ]; then
    if [ "$unread_count" -gt 0 ]; then
      local escaped_messages=$(echo -e "$unread_messages" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n' | sed 's/\\n$//')
      cat <<EOF
{"hookSpecificOutput":{"hookEventName":"InboxCheck","additionalContext":"📨 Unread messages: ${unread_count}:\\n${escaped_messages}"}}
EOF
    else
      echo '{"hookSpecificOutput":{"hookEventName":"InboxCheck","additionalContext":""}}'
    fi
  else
    if [ "$unread_count" -gt 0 ]; then
      echo "📨 Unread messages: ${unread_count}"
      echo -e "$unread_messages"
      echo ""
      echo "💡 Use /session inbox --mark to mark as read"
    else
      echo "📭 No unread messages"
    fi
  fi
}

main "$@"
