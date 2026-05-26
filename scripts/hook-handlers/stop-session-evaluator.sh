#!/bin/bash
# stop-session-evaluator.sh
# Session completion evaluation for Stop hook
#
# A command-type hook that reliably outputs valid JSON as an alternative to prompt type.
# Inspects session state and decides whether to allow or block the stop.
# CC 2.1.47+: reads last_assistant_message from stdin and records it in session.json.
#
# Input:  stdin (JSON: { stop_hook_active, transcript_path, last_assistant_message, ... })
# Output: {"ok": true} or {"ok": false, "reason": "..."}
#
# Issue: #42 - Stop hook "JSON validation failed" on every turn

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Load path-utils.sh
if [ -f "${PARENT_DIR}/path-utils.sh" ]; then
  source "${PARENT_DIR}/path-utils.sh"
fi

# Check if detect_project_root is defined before calling it
if declare -F detect_project_root > /dev/null 2>&1; then
  PROJECT_ROOT="${PROJECT_ROOT:-$(detect_project_root 2>/dev/null || pwd)}"
else
  PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
fi

STATE_FILE="${PROJECT_ROOT}/.claude/state/session.json"

# If jq is absent, return ok immediately (safe fallback)
if ! command -v jq &> /dev/null; then
  echo '{"ok":true}'
  exit 0
fi

# Portable timeout detection
_TIMEOUT=""
if command -v timeout > /dev/null 2>&1; then
  _TIMEOUT="timeout"
elif command -v gtimeout > /dev/null 2>&1; then
  _TIMEOUT="gtimeout"
fi

# Read hook payload from stdin (with size limit + timeout)
PAYLOAD=""
if [ -t 0 ]; then
  # Skip when stdin is a TTY (e.g. during test execution)
  :
else
  if [ -n "$_TIMEOUT" ]; then
    PAYLOAD=$($_TIMEOUT 5 head -c 65536 2>/dev/null || true)
  else
    # timeout not available: use dd to cap byte count (POSIX standard)
    PAYLOAD=$(dd bs=65536 count=1 2>/dev/null || true)
  fi
fi

# Record last_assistant_message metadata to session.json (content is hashed)
if [ -n "$PAYLOAD" ] && [ -f "$STATE_FILE" ]; then
  LAST_MSG=$(echo "$PAYLOAD" | jq -r '.last_assistant_message // ""' 2>/dev/null || true)
  if [ -n "$LAST_MSG" ] && [ "$LAST_MSG" != "null" ]; then
    # Record only message length and hash (plaintext content is not stored)
    MSG_LENGTH=${#LAST_MSG}
    # Portable hash: shasum (macOS) / sha256sum (Linux) / fallback
    if command -v shasum > /dev/null 2>&1; then
      MSG_HASH=$(printf '%s' "$LAST_MSG" | shasum -a 256 | cut -c1-16)
    elif command -v sha256sum > /dev/null 2>&1; then
      MSG_HASH=$(printf '%s' "$LAST_MSG" | sha256sum | cut -c1-16)
    else
      MSG_HASH="no-hash"
    fi
    # atomic write: mktemp + mv
    STATE_DIR="$(dirname "$STATE_FILE")"
    TMP_FILE=$(mktemp "${STATE_DIR}/session.json.XXXXXX" 2>/dev/null || echo "")
    if [ -n "$TMP_FILE" ]; then
      trap 'rm -f "$TMP_FILE"' EXIT
      jq --argjson len "$MSG_LENGTH" --arg hash "$MSG_HASH" \
        '.last_message_length = $len | .last_message_hash = $hash' \
        "$STATE_FILE" > "$TMP_FILE" 2>/dev/null && mv "$TMP_FILE" "$STATE_FILE" || rm -f "$TMP_FILE"
      trap - EXIT
    fi
  fi
fi

# If state file is absent, return ok immediately
if [ ! -f "$STATE_FILE" ]; then
  echo '{"ok":true}'
  exit 0
fi

# Inspect session state
SESSION_STATE=$(jq -r '.state // "unknown"' "$STATE_FILE" 2>/dev/null)

# Already stopped — return ok immediately
if [ "$SESSION_STATE" = "stopped" ]; then
  echo '{"ok":true}'
  exit 0
fi

# Default: allow stop
# When the user explicitly presses Stop, generally allow it
echo '{"ok":true}'
exit 0
