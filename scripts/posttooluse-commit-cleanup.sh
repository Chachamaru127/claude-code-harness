#!/bin/bash
# posttooluse-commit-cleanup.sh
# Clears review approval state after successful git commit.
#
# Input: stdin JSON from Claude Code PostToolUse hook
# Output: None (silent cleanup)

set +e

INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

[ -z "$INPUT" ] && exit 0

TOOL_NAME=""
COMMAND=""
TOOL_RESULT=""

if command -v jq >/dev/null 2>&1; then
  TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"
  COMMAND="$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"
  TOOL_RESULT="$(echo "$INPUT" | jq -r '.tool_result // empty' 2>/dev/null)"
fi

[ "$TOOL_NAME" != "Bash" ] && exit 0
[ -z "$COMMAND" ] && exit 0

# Check if this was a git commit command
if echo "$COMMAND" | grep -Eiq '(^|[[:space:]])git[[:space:]]+commit([[:space:]]|$)'; then
  REVIEW_STATE_FILE=".claude/state/review-approved.json"

  # Only clear if the commit was successful (no error in result)
  # Check for common success patterns
  if [ -f "$REVIEW_STATE_FILE" ]; then
    # Check if result contains error indicators
    if ! echo "$TOOL_RESULT" | grep -Eiq 'error|fatal|failed|nothing to commit'; then
      # Commit was successful, clear the approval state
      rm -f "$REVIEW_STATE_FILE" 2>/dev/null

      # Log the cleanup
      echo "[Commit Guard] レビュー承認状態をクリアしました。次回のコミット前に再度 /harness-review を実行してください。" >&2
    fi
  fi
fi

exit 0
