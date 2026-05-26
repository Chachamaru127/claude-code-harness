#!/bin/bash
# auto-cleanup-hook.sh
# PostToolUse Hook: automatically checks file sizes after writes to Plans.md etc.
#
# Environment variables:
#   $CLAUDE_FILE_PATHS - changed file paths (space-separated)
#
# Configuration:
#   Thresholds can be customized in .claude-code-harness.config.yaml

# Default thresholds
PLANS_MAX_LINES=${PLANS_MAX_LINES:-200}
SESSION_LOG_MAX_LINES=${SESSION_LOG_MAX_LINES:-500}
CLAUDE_MD_MAX_LINES=${CLAUDE_MD_MAX_LINES:-100}

# Load config file if present
CONFIG_FILE=".claude-code-harness.config.yaml"
if [ -f "$CONFIG_FILE" ]; then
  # Simple YAML parse
  PLANS_MAX_LINES=$(grep -A5 "plans:" "$CONFIG_FILE" | grep "max_lines:" | head -1 | awk '{print $2}' || echo $PLANS_MAX_LINES)
  SESSION_LOG_MAX_LINES=$(grep -A5 "session_log:" "$CONFIG_FILE" | grep "max_lines:" | head -1 | awk '{print $2}' || echo $SESSION_LOG_MAX_LINES)
  CLAUDE_MD_MAX_LINES=$(grep -A5 "claude_md:" "$CONFIG_FILE" | grep "max_lines:" | head -1 | awk '{print $2}' || echo $CLAUDE_MD_MAX_LINES)
fi

# Variable to accumulate feedback
FEEDBACK=""

# Check each file
for file in $CLAUDE_FILE_PATHS; do
  # Check Plans.md
  if [[ "$file" == *"Plans.md"* ]] || [[ "$file" == *"plans.md"* ]] || [[ "$file" == *"PLANS.MD"* ]]; then
    if [ -f "$file" ]; then
      lines=$(wc -l < "$file" | tr -d ' ')
      if [ "$lines" -gt "$PLANS_MAX_LINES" ]; then
        FEEDBACK="${FEEDBACK}Plans.md is ${lines} lines (limit: ${PLANS_MAX_LINES}). Consider running \`/maintenance\` to archive old tasks.\n"
      fi
    fi
  fi

  # Check session-log.md
  if [[ "$file" == *"session-log.md"* ]]; then
    if [ -f "$file" ]; then
      lines=$(wc -l < "$file" | tr -d ' ')
      if [ "$lines" -gt "$SESSION_LOG_MAX_LINES" ]; then
        FEEDBACK="${FEEDBACK}session-log.md is ${lines} lines (limit: ${SESSION_LOG_MAX_LINES}). Consider running \`/maintenance\` to split by month.\n"
      fi
    fi
  fi

  # Check CLAUDE.md
  if [[ "$file" == *"CLAUDE.md"* ]] || [[ "$file" == *"claude.md"* ]]; then
    if [ -f "$file" ]; then
      lines=$(wc -l < "$file" | tr -d ' ')
      if [ "$lines" -gt "$CLAUDE_MD_MAX_LINES" ]; then
        FEEDBACK="${FEEDBACK}CLAUDE.md is ${lines} lines. Consider moving non-essential content to docs/ and referencing it with \`@docs/filename.md\`.\n"
      fi
    fi
  fi
done

# Output feedback if any (feedback to Claude Code)
if [ -n "$FEEDBACK" ]; then
  echo -e "⚠️ File size warning:\n${FEEDBACK}"
fi

# Always exit with success (do not block)
exit 0
