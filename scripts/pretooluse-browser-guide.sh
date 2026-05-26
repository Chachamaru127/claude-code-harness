#!/bin/bash
# pretooluse-browser-guide.sh
# Hook that suggests agent-browser when MCP browser tools are used.
#
# Target tools:
#   - mcp__chrome-devtools__*
#   - mcp__playwright__* / mcp__plugin_playwright__*
#
# Behavior:
#   - Recommends agent-browser when it is installed
#   - Does not block (informational only)
#
# Input: stdin JSON from Claude Code hooks (pre-filtered by matcher)
# Output: JSON with hookSpecificOutput format

set -euo pipefail

# Read JSON from stdin
INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

# Do nothing if there is no input
[ -z "$INPUT" ] && exit 0

# Check if agent-browser is installed
if command -v agent-browser &> /dev/null; then
  # Output recommendation message (hookSpecificOutput format)
  # The matcher already narrows to MCP browser tools, so no additional tool name check needed
  if command -v jq >/dev/null 2>&1; then
    CONTEXT="💡 **It is recommended to try agent-browser first**

agent-browser is a browser automation tool optimized for AI agents.

\`\`\`bash
# Basic usage
agent-browser open <url>
agent-browser snapshot -i -c  # AI-oriented snapshot
agent-browser click @e1        # Click by element reference
\`\`\`

The current MCP tool can also be used, but agent-browser is simpler and faster.

Details: \`docs/OPTIONAL_PLUGINS.md\`"

    jq -nc --arg ctx "$CONTEXT" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        additionalContext: $ctx
      }
    }'
  else
    # Fall back to Python when jq is unavailable
    if command -v python3 >/dev/null 2>&1; then
      python3 - <<'PY'
import json
context = """💡 **It is recommended to try agent-browser first**

agent-browser is a browser automation tool optimized for AI agents.

```bash
# Basic usage
agent-browser open <url>
agent-browser snapshot -i -c  # AI-oriented snapshot
agent-browser click @e1        # Click by element reference
```

The current MCP tool can also be used, but agent-browser is simpler and faster.

Details: `docs/OPTIONAL_PLUGINS.md`"""
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "additionalContext": context
    }
}))
PY
    fi
  fi
fi

# Exit normally if agent-browser is not installed or after output is complete
exit 0
