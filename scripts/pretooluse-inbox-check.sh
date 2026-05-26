#!/bin/bash
# pretooluse-inbox-check.sh
# PreToolUse Hook: Check unread messages before tool execution
#
# Before Write|Edit, check for messages from other sessions
# so that important change notifications are not missed.
#
# Input: JSON from stdin
# Output: JSON (hookSpecificOutput)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== Configuration =====
SESSIONS_DIR=".claude/sessions"
BROADCAST_FILE="${SESSIONS_DIR}/broadcast.md"
SESSION_FILE=".claude/state/session.json"
CHECK_INTERVAL_FILE="${SESSIONS_DIR}/.last_inbox_check"
CHECK_INTERVAL=300  # Check every 5 minutes (prevents too-frequent notifications)

# ===== Read JSON input from stdin =====
INPUT=""
if [ -t 0 ]; then
  : # No input when stdin is a TTY
else
  INPUT=$(cat 2>/dev/null || true)
fi

# ===== Check interval verification =====
current_time=$(date +%s)
last_check=0

if [ -f "$CHECK_INTERVAL_FILE" ]; then
  last_check=$(cat "$CHECK_INTERVAL_FILE" 2>/dev/null || echo "0")
fi

time_since_check=$((current_time - last_check))

# Skip if within check interval (no output → does not affect permission decisions)
if [ "$time_since_check" -lt "$CHECK_INTERVAL" ]; then
  exit 0
fi

# Update last check timestamp
mkdir -p "$SESSIONS_DIR"
echo "$current_time" > "$CHECK_INTERVAL_FILE"

# ===== Check for unread messages =====
if [ ! -f "$BROADCAST_FILE" ]; then
  exit 0
fi

# Use inbox-check script
UNREAD_COUNT=$(bash "$SCRIPT_DIR/session-inbox-check.sh" --count 2>/dev/null || echo "0")

if [ "$UNREAD_COUNT" -gt 0 ]; then
  # Fetch unread message contents (up to 5)
  # Extract actual message lines from session-inbox-check.sh output
  INBOX_MESSAGES=$(bash "$SCRIPT_DIR/session-inbox-check.sh" 2>/dev/null | grep -E '^\[' | head -5 || echo "")

  if [ -n "$INBOX_MESSAGES" ]; then
    bash "$SCRIPT_DIR/session-inbox-check.sh" --mark >/dev/null 2>/dev/null || true

    # Escape message content
    ESCAPED_MESSAGES=$(echo "$INBOX_MESSAGES" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n' | sed 's/\\n$//')

    # Display message content directly (permissionDecision: "allow" does not affect permission decisions)
    cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","additionalContext":"📨 Messages from other sessions (${UNREAD_COUNT}):\\n---\\n${ESCAPED_MESSAGES}\\n---"}}
EOF
  else
    # Fallback when message extraction fails
    cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","additionalContext":"📨 You have ${UNREAD_COUNT} unread message(s) from other sessions"}}
EOF
  fi
else
  # No unread messages → output nothing (does not affect permission decisions)
  :
fi

exit 0
