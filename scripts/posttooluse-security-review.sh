#!/bin/bash
# posttooluse-security-review.sh
# PostToolUse hook: suggest security review on auth changes.

set +e

INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

[ -z "$INPUT" ] && exit 0

TOOL_NAME=""
FILE_PATH=""
CWD=""

if command -v jq >/dev/null 2>&1; then
  TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"
  FILE_PATH="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_response.filePath // empty' 2>/dev/null)"
  CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)"
elif command -v python3 >/dev/null 2>&1; then
  eval "$(printf '%s' "$INPUT" | python3 -c '
import json, shlex, sys
try:
    data = json.load(sys.stdin)
except Exception:
    data = {}
tool_name = data.get("tool_name") or ""
cwd = data.get("cwd") or ""
tool_input = data.get("tool_input") or {}
tool_response = data.get("tool_response") or {}
file_path = tool_input.get("file_path") or tool_response.get("filePath") or ""
print(f"TOOL_NAME={shlex.quote(tool_name)}")
print(f"CWD={shlex.quote(cwd)}")
print(f"FILE_PATH={shlex.quote(file_path)}")
' 2>/dev/null)"
fi

if [ "$TOOL_NAME" != "Write" ] && [ "$TOOL_NAME" != "Edit" ]; then
  exit 0
fi

[ -z "$FILE_PATH" ] && exit 0

# Normalize to relative when possible
REL_PATH="$FILE_PATH"
if [ -n "$CWD" ] && [[ "$FILE_PATH" == "$CWD/"* ]]; then
  REL_PATH="${FILE_PATH#$CWD/}"
fi

# Only trigger for auth-related changes
case "$REL_PATH" in
  src/auth.*|src/auth/*|src/**/auth.*|src/**/auth/*)
    ;;
  *)
    exit 0
    ;;
esac

MESSAGE="🛡️ Security review recommended\n\nA change to an authentication-related file was detected.\nPlease run a security review (e.g. /harness-review)."

if command -v jq >/dev/null 2>&1; then
  jq -nc --arg ctx "$MESSAGE" \
    '{hookSpecificOutput:{hookEventName:"PostToolUse", additionalContext:$ctx}}'
else
  echo '{"hookSpecificOutput":{"hookEventName":"PostToolUse"}}'
fi

exit 0
