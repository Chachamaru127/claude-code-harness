---
description: Rules for editing shell scripts
paths: "scripts/**/*.sh"
---

# Shell Scripts Rules

Rules applied when editing shell scripts in the `scripts/` directory.

## Required Patterns

### 1. Header Format

```bash
#!/bin/bash
# script-name.sh
# One-line description of the script's purpose
#
# Usage: ./scripts/script-name.sh [arguments]

set -euo pipefail
```

### 2. JSON Output Format for Hook Scripts

Hook scripts (`*-hook.sh`, `stop-*.sh`, etc.) return results in JSON:

```bash
# On success
echo '{"decision": "approve", "reason": "explanation"}'

# On warning
echo '{"decision": "approve", "reason": "explanation", "systemMessage": "notification to user"}'

# On rejection
echo '{"decision": "deny", "reason": "reason"}'
```

### 3. Handling Environment Variables

```bash
# CLAUDE_PLUGIN_ROOT must always be verified
if [ -z "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  echo "Error: CLAUDE_PLUGIN_ROOT not set" >&2
  exit 1
fi

# PROJECT_ROOT fallback
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
```

## Prohibited

- ❌ Execution without `set -e`
- ❌ Unquoted variable expansion (`$VAR` → `"$VAR"`)
- ❌ Hardcoded absolute paths
- ❌ Changing working directory with `cd` (use relative paths)

## Windows Compatibility

Consider Git Bash / MSYS2 environments:

```bash
# Use / for path separators
local file_path="${dir}/${filename}"

# Automatically handled when going through run-script.js
```

## Testing

New scripts should be reference-verified by `tests/validate-plugin.sh`.
