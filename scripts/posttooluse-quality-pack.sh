#!/bin/bash
# posttooluse-quality-pack.sh
# Optional quality automation pack for PostToolUse (Write/Edit).
# - Prettier formatting (JS/TS)
# - TypeScript typecheck (tsc --noEmit)
# - console.log detection
#
# Behavior:
# - Disabled by default via .claude-code-harness.config.yaml
# - mode: warn (default) or run
#
# Output: additionalContext (PostToolUse)

set +e

CONFIG_FILE=".claude-code-harness.config.yaml"

read_quality_value() {
  local key="$1"
  local default="$2"
  local value=""

  if [ -f "$CONFIG_FILE" ]; then
    value=$(awk -v k="$key" '
      $0 ~ /^quality_pack:/ {in=1; next}
      in && $0 ~ /^[^[:space:]]/ {in=0}
      in && $1 == k":" {print $2; exit}
    ' "$CONFIG_FILE" 2>/dev/null)
  fi

  value="${value%\"}"
  value="${value#\"}"

  if [ -z "$value" ]; then
    value="$default"
  fi

  echo "$value"
}

normalize_bool() {
  case "$1" in
    true|false) echo "$1" ;;
    *) echo "$2" ;;
  esac
}

INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

TOOL_NAME=""
FILE_PATH=""
CWD=""

if [ -n "$INPUT" ]; then
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
fi

# Only run for Write/Edit with a file path
if [ "$TOOL_NAME" != "Write" ] && [ "$TOOL_NAME" != "Edit" ]; then
  exit 0
fi

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Normalize to relative path if possible
if [ -n "$CWD" ] && [[ "$FILE_PATH" == "$CWD/"* ]]; then
  FILE_PATH="${FILE_PATH#$CWD/}"
fi

# Skip non-code files or excluded paths
case "$FILE_PATH" in
  *.ts|*.tsx|*.js|*.jsx) ;;
  *) exit 0 ;;
esac

case "$FILE_PATH" in
  .claude/*|docs/*|templates/*|benchmarks/*|node_modules/*|.git/*)
    exit 0
    ;;
esac

QUALITY_ENABLED="$(normalize_bool "$(read_quality_value enabled false)" false)"
QUALITY_MODE="$(read_quality_value mode warn)"
QUALITY_PRETTIER="$(normalize_bool "$(read_quality_value prettier true)" true)"
QUALITY_TSC="$(normalize_bool "$(read_quality_value tsc true)" true)"
QUALITY_CONSOLE_LOG="$(normalize_bool "$(read_quality_value console_log true)" true)"

if [ "$QUALITY_ENABLED" != "true" ]; then
  exit 0
fi

FEEDBACK=""

append_feedback() {
  local msg="$1"
  if [ -z "$FEEDBACK" ]; then
    FEEDBACK="$msg"
  else
    FEEDBACK="${FEEDBACK}\n${msg}"
  fi
}

run_prettier() {
  if [ -x "./node_modules/.bin/prettier" ]; then
    ./node_modules/.bin/prettier --write "$FILE_PATH" >/dev/null 2>&1
    return $?
  fi
  return 127
}

run_tsc() {
  if [ ! -f "tsconfig.json" ]; then
    return 127
  fi
  if [ -x "./node_modules/.bin/tsc" ]; then
    ./node_modules/.bin/tsc --noEmit >/dev/null 2>&1
    return $?
  fi
  return 127
}

if [ "$QUALITY_PRETTIER" = "true" ]; then
  if [ "$QUALITY_MODE" = "run" ]; then
    if run_prettier; then
      append_feedback "🧹 Prettier: executed"
    else
      append_feedback "🧹 Prettier: skipped (prettier not found)"
    fi
  else
    append_feedback "🧹 Prettier: recommended (e.g. npx prettier --write \"$FILE_PATH\")"
  fi
fi

if [ "$QUALITY_TSC" = "true" ]; then
  if [ "$QUALITY_MODE" = "run" ]; then
    if run_tsc; then
      append_feedback "🧪 tsc --noEmit: executed"
    else
      append_feedback "🧪 tsc --noEmit: skipped (tsconfig/tsc not found)"
    fi
  else
    append_feedback "🧪 tsc --noEmit: recommended"
  fi
fi

if [ "$QUALITY_CONSOLE_LOG" = "true" ]; then
  if [ -f "$FILE_PATH" ]; then
    CONSOLE_LOG_COUNT=$(grep -n "console\.log" "$FILE_PATH" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$CONSOLE_LOG_COUNT" -gt 0 ]; then
      append_feedback "⚠️ console.log found: ${CONSOLE_LOG_COUNT} occurrence(s)"
    fi
  fi
fi

if [ -n "$FEEDBACK" ]; then
  FEEDBACK="🧰 Quality Pack (PostToolUse)\n${FEEDBACK}"
  if command -v jq >/dev/null 2>&1; then
    jq -nc --arg ctx "$FEEDBACK" \
      '{hookSpecificOutput:{hookEventName:"PostToolUse", additionalContext:$ctx}}'
  else
    echo '{"hookSpecificOutput":{"hookEventName":"PostToolUse"}}'
  fi
fi

exit 0
