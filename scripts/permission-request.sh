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
  TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"
  COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"
elif command -v python3 >/dev/null 2>&1; then
  eval "$(printf '%s' "$INPUT" | python3 -c '
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
' 2>/dev/null)"
fi

# Auto-approve Edit/Write as equivalent to bypassPermissions
# (supplements Claude Code behavior that shows prompts even in bypassPermissions mode)
if [ "$TOOL_NAME" = "Edit" ] || [ "$TOOL_NAME" = "Write" ]; then
  printf '%s' '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}'
  exit 0
fi

[ "$TOOL_NAME" != "Bash" ] && exit 0
[ -z "$COMMAND" ] && exit 0

# Retrieve CWD from hook input for allowlist lookups
CWD=""
if command -v jq >/dev/null 2>&1; then
  CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)"
elif command -v python3 >/dev/null 2>&1; then
  CWD="$(printf '%s' "$INPUT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("cwd",""))' 2>/dev/null)"
fi

# Check if package manager auto-approval is allowed for the current project.
# Looks for .claude/config/allowed-pkg-managers.json in the project root.
# Format: { "allowed": true }
# If the file doesn't exist or allowed != true, npm/pnpm/yarn auto-approval is skipped.
is_pkg_manager_allowed() {
  local allowlist_file="${CWD:-.}/.claude/config/allowed-pkg-managers.json"
  [ ! -f "$allowlist_file" ] && return 1

  local allowed="false"
  if command -v jq >/dev/null 2>&1; then
    allowed=$(jq -r '.allowed // false' "$allowlist_file" 2>/dev/null || echo "false")
  elif command -v python3 >/dev/null 2>&1; then
    allowed=$(python3 -c '
import json,sys
try:
    with open(sys.argv[1]) as f: data=json.load(f)
    print("true" if data.get("allowed") is True else "false")
except: print("false")
' "$allowlist_file" 2>/dev/null || echo "false")
  fi

  [ "$allowed" = "true" ]
}

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

  # Read-only git commands (always safe, no allowlist needed)
  echo "$cmd" | grep -Eiq '^git[[:space:]]+(status|diff|log|branch|rev-parse|show|ls-files)([[:space:]]|$)' && return 0

  # JS/TS test & verification commands — only auto-approve if allowlisted
  # Rationale: package.json scripts can run arbitrary commands, so we require
  # explicit opt-in via .claude/config/allowed-pkg-managers.json
  if echo "$cmd" | grep -Eiq '^(npm|pnpm|yarn)[[:space:]]+(test|run[[:space:]]+(test|lint|typecheck|build|validate)|lint|typecheck|build)([[:space:]]|$)'; then
    is_pkg_manager_allowed && return 0
    return 1
  fi

  # Python tests (no package.json risk)
  echo "$cmd" | grep -Eiq '^(pytest|python[[:space:]]+-m[[:space:]]+pytest)([[:space:]]|$)' && return 0

  # Go / Rust tests (no package.json risk)
  echo "$cmd" | grep -Eiq '^(go[[:space:]]+test|cargo[[:space:]]+test)([[:space:]]|$)' && return 0

  return 1
}

if is_safe "$COMMAND"; then
  printf '%s' "{\"hookSpecificOutput\":{\"hookEventName\":\"PermissionRequest\",\"decision\":{\"behavior\":\"allow\"}}}"
fi

exit 0


