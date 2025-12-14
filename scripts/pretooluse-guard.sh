#!/bin/bash
# pretooluse-guard.sh
# Claude Code Hooks: PreToolUse guardrail for dangerous operations.
# - Deny writes/edits to protected paths (e.g., .git/, .env, keys)
# - Ask for confirmation for writes outside the project directory
# - Deny sudo, ask for confirmation for rm -rf / git push
#
# Input: stdin JSON from Claude Code hooks
# Output: JSON to control PreToolUse permission decisions

set +e

INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

[ -z "$INPUT" ] && exit 0

TOOL_NAME=""
FILE_PATH=""
COMMAND=""
CWD=""

if command -v jq >/dev/null 2>&1; then
  TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"
  FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
  COMMAND="$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"
  CWD="$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)"
elif command -v python3 >/dev/null 2>&1; then
  eval "$(echo "$INPUT" | python3 - <<'PY' 2>/dev/null
import json, shlex, sys
try:
    data = json.load(sys.stdin)
except Exception:
    data = {}
tool_name = data.get("tool_name") or ""
cwd = data.get("cwd") or ""
tool_input = data.get("tool_input") or {}
file_path = tool_input.get("file_path") or ""
command = tool_input.get("command") or ""
print(f"TOOL_NAME={shlex.quote(tool_name)}")
print(f"CWD={shlex.quote(cwd)}")
print(f"FILE_PATH={shlex.quote(file_path)}")
print(f"COMMAND={shlex.quote(command)}")
PY
)"
fi

[ -z "$TOOL_NAME" ] && exit 0

emit_decision() {
  local decision="$1"
  local reason="$2"

  if command -v jq >/dev/null 2>&1; then
    jq -nc --arg decision "$decision" --arg reason "$reason" \
      '{hookSpecificOutput:{hookEventName:"PreToolUse", permissionDecision:$decision, permissionDecisionReason:$reason}}'
    return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    DECISION="$decision" REASON="$reason" python3 - <<'PY'
import json, os
print(json.dumps({
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": os.environ.get("DECISION", ""),
    "permissionDecisionReason": os.environ.get("REASON", ""),
  }
}))
PY
    return 0
  fi

  # Fallback: omit reason to avoid JSON escaping issues.
  printf '%s' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"${decision}\"}}"
}

emit_deny() { emit_decision "deny" "$1"; }
emit_ask() { emit_decision "ask" "$1"; }

is_path_traversal() {
  local p="$1"
  [[ "$p" == ".." ]] && return 0
  [[ "$p" == "../"* ]] && return 0
  [[ "$p" == *"/../"* ]] && return 0
  [[ "$p" == *"/.." ]] && return 0
  return 1
}

is_protected_path() {
  local p="$1"
  case "$p" in
    .git|.git/*|*/.git|*/.git/*) return 0 ;;
    .gitignore|.gitattributes) return 0 ;;
    .env|.env.*|*/.env|*/.env.*) return 0 ;;
    secrets/*|*/secrets/*) return 0 ;;
    *.pem|*.key|*id_rsa*|*id_ed25519*|*/.ssh/*) return 0 ;;
  esac
  return 1
}

if [ "$TOOL_NAME" = "Write" ] || [ "$TOOL_NAME" = "Edit" ]; then
  [ -z "$FILE_PATH" ] && exit 0

  if is_path_traversal "$FILE_PATH"; then
    emit_deny "Blocked: path traversal in file_path ($FILE_PATH)"
    exit 0
  fi

  # If absolute and outside project cwd, ask for confirmation.
  if [ -n "$CWD" ] && [[ "$FILE_PATH" == /* ]] && [[ "$FILE_PATH" != "$CWD/"* ]]; then
    emit_ask "Confirm: writing outside project directory ($FILE_PATH)"
    exit 0
  fi

  # Normalize to relative when possible for pattern matching.
  REL_PATH="$FILE_PATH"
  if [ -n "$CWD" ] && [[ "$FILE_PATH" == "$CWD/"* ]]; then
    REL_PATH="${FILE_PATH#$CWD/}"
  fi

  if is_protected_path "$REL_PATH"; then
    emit_deny "Blocked: protected path ($REL_PATH)"
    exit 0
  fi

  exit 0
fi

if [ "$TOOL_NAME" = "Bash" ]; then
  [ -z "$COMMAND" ] && exit 0

  if echo "$COMMAND" | grep -Eiq '(^|[[:space:]])sudo([[:space:]]|$)'; then
    emit_deny "Blocked: sudo is not allowed via Claude Code hooks"
    exit 0
  fi

  if echo "$COMMAND" | grep -Eiq '(^|[[:space:]])git[[:space:]]+push([[:space:]]|$)'; then
    emit_ask "Confirm: git push requested ($COMMAND)"
    exit 0
  fi

  if echo "$COMMAND" | grep -Eiq '(^|[[:space:]])rm[[:space:]]+-rf([[:space:]]|$)'; then
    emit_ask "Confirm: rm -rf requested ($COMMAND)"
    exit 0
  fi

  exit 0
fi

exit 0


