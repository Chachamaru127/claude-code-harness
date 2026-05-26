#!/bin/bash
# posttooluse-clear-pending.sh
# Clears pending-skills on PostToolUse/Skill
#
# Usage: auto-executed from PostToolUse hook (Skill matcher)
# Input: stdin JSON (Claude Code hooks)
# Output: JSON (continue)

set +e

STATE_DIR=".claude/state"
PENDING_DIR="${STATE_DIR}/pending-skills"

# Skip if pending directory does not exist
[ ! -d "$PENDING_DIR" ] && { echo '{"continue":true}'; exit 0; }

# Clear all pending files if any exist
# (Skill invocation = quality gate considered executed)
PENDING_FILES=$(ls "$PENDING_DIR"/*.pending 2>/dev/null || true)

if [ -n "$PENDING_FILES" ]; then
  for f in $PENDING_FILES; do
    rm -f "$f" 2>/dev/null || true
  done
fi

echo '{"continue":true}'
exit 0
