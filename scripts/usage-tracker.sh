#!/usr/bin/env bash
#
# usage-tracker.sh - PostToolUse hook for tracking Skill, Command, Agent usage
#
# This hook captures:
# - Skill tool invocations
# - SlashCommand (/) invocations
# - Task tool invocations (agents)
#
# Environment variables from Claude Code:
# - TOOL_NAME: The tool that was used
# - TOOL_INPUT: JSON input to the tool
# - TOOL_RESPONSE: Tool response (not used here)
#

set -euo pipefail

# Check for jq dependency - silently exit if not available
# (usage tracking should never block the main workflow)
if ! command -v jq &>/dev/null; then
  echo '{"continue":true}'
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RECORD_USAGE="$SCRIPT_DIR/record-usage.js"

# Read input from stdin (Claude Code hook format)
INPUT=$(cat)

# Extract tool name and input from the hook input
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || echo "")
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // empty' 2>/dev/null || echo "")

# If we can't parse, try environment variables
if [ -z "$TOOL_NAME" ]; then
  TOOL_NAME="${TOOL_NAME:-}"
fi

# Early exit if no tool name
if [ -z "$TOOL_NAME" ]; then
  echo '{"continue":true}'
  exit 0
fi

# Track based on tool type
case "$TOOL_NAME" in
  Skill)
    # Extract skill name from tool input
    SKILL_NAME=$(echo "$TOOL_INPUT" | jq -r '.skill // empty' 2>/dev/null || echo "")
    if [ -n "$SKILL_NAME" ]; then
      # Extract base skill name (e.g., "impl" from "claude-code-harness:impl")
      BASE_NAME=$(echo "$SKILL_NAME" | sed 's/.*://')
      node "$RECORD_USAGE" skill "$BASE_NAME" 2>/dev/null || true
    fi
    ;;

  SlashCommand)
    # Extract command name from tool input
    CMD_NAME=$(echo "$TOOL_INPUT" | jq -r '.command // .name // empty' 2>/dev/null || echo "")
    if [ -n "$CMD_NAME" ]; then
      # Remove leading slash if present
      BASE_NAME=$(echo "$CMD_NAME" | sed 's/^\///')
      node "$RECORD_USAGE" command "$BASE_NAME" 2>/dev/null || true
    fi
    ;;

  Task)
    # Extract agent type from tool input
    AGENT_TYPE=$(echo "$TOOL_INPUT" | jq -r '.subagent_type // empty' 2>/dev/null || echo "")
    if [ -n "$AGENT_TYPE" ]; then
      node "$RECORD_USAGE" agent "$AGENT_TYPE" 2>/dev/null || true
    fi
    ;;
esac

# Always continue - usage tracking should never block
echo '{"continue":true}'
