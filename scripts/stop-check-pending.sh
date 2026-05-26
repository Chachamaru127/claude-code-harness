#!/bin/bash
# stop-check-pending.sh
# Check for unresolved pending-skills on Stop and warn
#
# Usage: Automatically executed from Stop hook (type: command)
# Input: stdin JSON (Claude Code hooks)
# Output: Human-readable text warning (written directly to stdout)

set +e

STATE_DIR=".claude/state"
PENDING_DIR="${STATE_DIR}/pending-skills"

# Exit silently if pending directory does not exist
if [ ! -d "$PENDING_DIR" ]; then
  exit 0
fi

# Check pending files
PENDING_FILES=$(ls "$PENDING_DIR"/*.pending 2>/dev/null || true)

if [ -z "$PENDING_FILES" ]; then
  exit 0
fi

# Unresolved pending items exist
PENDING_COMMANDS=""
for f in $PENDING_FILES; do
  CMD_NAME=$(basename "$f" .pending)
  PENDING_COMMANDS="${PENDING_COMMANDS}${CMD_NAME}, "
done
PENDING_COMMANDS=$(echo "$PENDING_COMMANDS" | sed 's/, $//')

# Clear pending files (already warned)
rm -f "$PENDING_DIR"/*.pending 2>/dev/null || true

# Write human-readable text warning to stdout
cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️  Quality gate not executed
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

The following commands were run but the corresponding Skill was not invoked:
  → ${PENDING_COMMANDS}

This may cause the following issues:
  1. Missing usage statistics: Skill usage history was not recorded
  2. Quality guardrails skipped: review/validation skills may not have been applied

Recommendation: run /harness-review manually to perform a quality check.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF

exit 0
