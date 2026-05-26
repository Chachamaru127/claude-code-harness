#!/bin/bash
# skill-child-reminder.sh
# PostToolUse hook: remind to load child skills after Skill tool use
#
# Usage: Automatically executed from PostToolUse hook (matcher="Skill")
# Input: stdin JSON (Claude Code hooks)
# Output: Reminder message (when child skills exist)

set +e

# Read JSON input from stdin
INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

[ -z "$INPUT" ] && exit 0

# Extract tool name and skill name from JSON
TOOL_NAME=""
SKILL_NAME=""

if command -v jq >/dev/null 2>&1; then
  TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"
  SKILL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_input.skill // empty' 2>/dev/null)"
elif command -v python3 >/dev/null 2>&1; then
  eval "$(printf '%s' "$INPUT" | python3 -c '
import json, shlex, sys
try:
    data = json.load(sys.stdin)
except Exception:
    data = {}
tool_name = data.get("tool_name") or ""
tool_input = data.get("tool_input") or {}
skill_name = tool_input.get("skill") or ""
print(f"TOOL_NAME={shlex.quote(tool_name)}")
print(f"SKILL_NAME={shlex.quote(skill_name)}")
' 2>/dev/null)"
fi

# Skip if not the Skill tool
[ "$TOOL_NAME" != "Skill" ] && exit 0
[ -z "$SKILL_NAME" ] && exit 0

# Get plugin root
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$(realpath "$0")")")}"

# Extract category from skill name (e.g. "claude-code-harness:impl" -> "impl")
SKILL_CATEGORY="${SKILL_NAME##*:}"

# Check if child skill directory exists
SKILL_DIR="${PLUGIN_ROOT}/skills/${SKILL_CATEGORY}"

if [ -d "$SKILL_DIR" ]; then
  # Get list of child skills (doc.md)
  CHILD_SKILLS=""
  for child_dir in "$SKILL_DIR"/*/; do
    if [ -f "${child_dir}doc.md" ]; then
      child_name=$(basename "$child_dir")
      CHILD_SKILLS="${CHILD_SKILLS}  - ${SKILL_CATEGORY}/${child_name}/doc.md\n"
    fi
  done

  # Output reminder only if child skills exist
  if [ -n "$CHILD_SKILLS" ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📚 Skill Hierarchy Reminder"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "The \"${SKILL_CATEGORY}\" skill has the following child skills:"
    echo ""
    echo -e "$CHILD_SKILLS"
    echo ""
    echo "⚠️  Please Read the relevant doc.md according to the user's intent."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
  fi
fi

exit 0
