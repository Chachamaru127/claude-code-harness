#!/bin/bash
# permission-request.sh
# Claude Code Hooks: PermissionRequest auto-approval for safe commands.
#
# Input: stdin JSON from Claude Code hooks
# Output: JSON to allow safe permissions automatically (Bash only)

set +e

INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

[ -z "$INPUT" ] && exit 0

TOOL_NAME=""
COMMAND=""

if command -v jq >/dev/null 2>&1; then
  TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"
  COMMAND="$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"
elif command -v python3 >/dev/null 2>&1; then
  eval "$(echo "$INPUT" | python3 - <<'PY' 2>/dev/null
import json, shlex, sys
try:
    data = json.load(sys.stdin)
except Exception:
    data = {}
tool_name = data.get("tool_name") or ""
tool_input = data.get("tool_input") or {}
command = tool_input.get("command") or ""
print(f"TOOL_NAME={shlex.quote(tool_name)}")
print(f"COMMAND={shlex.quote(command)}")
PY
)"
fi

[ "$TOOL_NAME" != "Bash" ] && exit 0
[ -z "$COMMAND" ] && exit 0

is_safe() {
  local cmd="$1"

  # Security hardening:
  # Refuse to auto-approve if the command looks like a compound shell expression
  # (pipes, redirections, variable expansion, command substitution, etc.).
  # This is intentionally conservative: if it looks complex, require manual approval.
  if [[ "$cmd" == *$'\n'* || "$cmd" == *$'\r'* ]]; then
    return 1
  fi
  echo "$cmd" | grep -Eq '[;&|<>`$]' && return 1

  # Read-only git commands
  echo "$cmd" | grep -Eiq '^git[[:space:]]+(status|diff|log|branch|rev-parse|show|ls-files)([[:space:]]|$)' && return 0

  # JS/TS test & verification commands
  echo "$cmd" | grep -Eiq '^(npm|pnpm|yarn)[[:space:]]+(test|run[[:space:]]+(test|lint|typecheck|build)|lint|typecheck|build)([[:space:]].*)?$' && return 0

  # Python tests
  echo "$cmd" | grep -Eiq '^(pytest|python[[:space:]]+-m[[:space:]]+pytest)([[:space:]]|$)' && return 0

  # Go / Rust tests
  echo "$cmd" | grep -Eiq '^(go[[:space:]]+test|cargo[[:space:]]+test)([[:space:]]|$)' && return 0

  return 1
}

if is_safe "$COMMAND"; then
  printf '%s' "{\"hookSpecificOutput\":{\"hookEventName\":\"PermissionRequest\",\"decision\":{\"behavior\":\"allow\"}}}"
fi

exit 0


