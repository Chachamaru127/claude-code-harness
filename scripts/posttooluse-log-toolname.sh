#!/bin/bash
# posttooluse-log-toolname.sh
# Phase0: Log all tool names (for tool_name discovery)
# + LSP tracking: detects LSP-related tools and updates tooling-policy.json
#
# Usage: auto-executed from PostToolUse hook (matcher="*")
# Input: stdin JSON (Claude Code hooks)
# Output:
#   - Appends JSONL to .claude/state/tool-events.jsonl (only when Phase0 log is enabled)
#   - Updates .claude/state/tooling-policy.json (always, when LSP-related tool is detected)
#
# Control: Log collection runs only when CC_HARNESS_PHASE0_LOG=1 is set
#          (disable after tool_name is confirmed to prevent log bloat)
#          LSP tracking always runs (independent of "LSP" matcher, to avoid deadlock)

set +e

# ===== Constants =====
STATE_DIR=".claude/state"
LOG_FILE="${STATE_DIR}/tool-events.jsonl"
LOCK_FILE="${STATE_DIR}/tool-events.lock"
SESSION_FILE="${STATE_DIR}/session.json"
EVENT_LOG_FILE="${STATE_DIR}/session.events.jsonl"
EVENT_LOCK_FILE="${STATE_DIR}/session-events.lock"
MAX_SIZE_BYTES=262144  # 256KB
MAX_LINES=2000
MAX_GENERATIONS=5

# ===== Utilities =====

# Acquire lock (prefer flock; fall back to mkdir lock)
acquire_lock() {
  local lockfile="$1"
  local timeout=5
  local waited=0

  # use flock if available
  if command -v flock >/dev/null 2>&1; then
    exec 200>"$lockfile"
    flock -w "$timeout" 200 || return 1
    return 0
  fi

  # flock unavailable: use mkdir lock (atomic)
  while ! mkdir "$lockfile" 2>/dev/null; do
    sleep 0.1
    waited=$((waited + 1))
    if [ "$waited" -ge $((timeout * 10)) ]; then
      return 1
    fi
  done
  return 0
}

# Release lock
release_lock() {
  local lockfile="$1"

  if command -v flock >/dev/null 2>&1; then
    exec 200>&-
  else
    rmdir "$lockfile" 2>/dev/null || true
  fi
}

# Execute rotation
rotate_log() {
  local logfile="$1"

  # Delete oldest generation
  [ -f "${logfile}.${MAX_GENERATIONS}" ] && rm -f "${logfile}.${MAX_GENERATIONS}"

  # Rename in order (.4 → .5, .3 → .4, ...)
  for i in $(seq $((MAX_GENERATIONS - 1)) -1 1); do
    [ -f "${logfile}.${i}" ] && mv "${logfile}.${i}" "${logfile}.$((i + 1))"
  done

  # Move current log to .1
  [ -f "$logfile" ] && mv "$logfile" "${logfile}.1"

  # Create new log file
  touch "$logfile"
}

# Check whether rotation is needed
needs_rotation() {
  local logfile="$1"

  [ ! -f "$logfile" ] && return 1

  # Size check
  local size
  if command -v stat >/dev/null 2>&1; then
    # macOS/BSD
    size=$(stat -f%z "$logfile" 2>/dev/null || stat -c%s "$logfile" 2>/dev/null || echo 0)
  else
    size=$(wc -c < "$logfile" 2>/dev/null || echo 0)
  fi

  if [ "$size" -ge "$MAX_SIZE_BYTES" ]; then
    return 0
  fi

  # Line count check
  local lines
  lines=$(wc -l < "$logfile" 2>/dev/null || echo 0)
  if [ "$lines" -ge "$MAX_LINES" ]; then
    return 0
  fi

  return 1
}

# ===== Main processing =====

# Create state directory
mkdir -p "$STATE_DIR"

# Read JSON input from stdin
INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

if [ -z "$INPUT" ]; then
  exit 0
fi

# Extract required fields from JSON (jq preferred; fall back to python3)
TOOL_NAME=""
SESSION_ID=""
FILE_PATH=""
COMMAND=""

if command -v jq >/dev/null 2>&1; then
  TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"
  SESSION_ID="$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)"
  FILE_PATH="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
  COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"
elif command -v python3 >/dev/null 2>&1; then
  eval "$(printf '%s' "$INPUT" | python3 -c '
import json, shlex, sys
try:
    data = json.load(sys.stdin)
except Exception:
    data = {}
tool_name = data.get("tool_name") or ""
session_id = data.get("session_id") or ""
tool_input = data.get("tool_input") or {}
file_path = tool_input.get("file_path") or ""
command = tool_input.get("command") or ""
print(f"TOOL_NAME={shlex.quote(tool_name)}")
print(f"SESSION_ID={shlex.quote(session_id)}")
print(f"FILE_PATH={shlex.quote(file_path)}")
print(f"COMMAND={shlex.quote(command)}")
' 2>/dev/null)"
fi

# Skip if tool_name is absent
[ -z "$TOOL_NAME" ] && exit 0

# Retrieve prompt_seq from session.json
PROMPT_SEQ=0
if [ -f "$SESSION_FILE" ]; then
  if command -v jq >/dev/null 2>&1; then
    PROMPT_SEQ="$(jq -r '.prompt_seq // 0' "$SESSION_FILE" 2>/dev/null)"
  elif command -v python3 >/dev/null 2>&1; then
    PROMPT_SEQ="$(python3 -c "import json; print(json.load(open('$SESSION_FILE')).get('prompt_seq', 0))" 2>/dev/null || echo 0)"
  fi
fi

# ===== LSP tracking (always runs; avoids matcher dependency) =====
# Detect LSP-related tools (when tool_name contains "lsp" or "LSP")
if echo "$TOOL_NAME" | grep -iq "lsp"; then
  TOOLING_POLICY_FILE="${STATE_DIR}/tooling-policy.json"
  if [ -f "$TOOLING_POLICY_FILE" ]; then
    temp_file=$(mktemp)
    if command -v jq >/dev/null 2>&1; then
      jq --arg tool_name "$TOOL_NAME" \
         --argjson prompt_seq "$PROMPT_SEQ" \
         '.lsp.last_used_prompt_seq = $prompt_seq |
          .lsp.last_used_tool_name = $tool_name |
          .lsp.used_since_last_prompt = true' \
         "$TOOLING_POLICY_FILE" > "$temp_file" && mv "$temp_file" "$TOOLING_POLICY_FILE"
    elif command -v python3 >/dev/null 2>&1; then
      python3 <<PY > "$temp_file"
import json
with open("$TOOLING_POLICY_FILE", "r") as f:
    data = json.load(f)
data["lsp"]["last_used_prompt_seq"] = $PROMPT_SEQ
data["lsp"]["last_used_tool_name"] = "$TOOL_NAME"
data["lsp"]["used_since_last_prompt"] = True
print(json.dumps(data, indent=2))
PY
      mv "$temp_file" "$TOOLING_POLICY_FILE"
    fi
  fi
fi

# ===== Phase0 log collection (only when CC_HARNESS_PHASE0_LOG=1) =====
if [ "${CC_HARNESS_PHASE0_LOG:-0}" = "1" ]; then
  # Timestamp (UTC ISO8601)
  TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")

  # Build JSONL entry (minimal fields only)
  JSONL_ENTRY=$(cat <<EOF
{"v":1,"ts":"$TIMESTAMP","session_id":"$SESSION_ID","prompt_seq":$PROMPT_SEQ,"hook_event_name":"PostToolUse","tool_name":"$TOOL_NAME"}
EOF
  )

  # Acquire lock
  if ! acquire_lock "$LOCK_FILE"; then
    # Skip if lock cannot be acquired (failure is non-critical)
    exit 0
  fi

  # Rotation check
  if needs_rotation "$LOG_FILE"; then
    rotate_log "$LOG_FILE"
  fi

  # ログ追記（原子的でないが、ロックで保護されている）
  echo "$JSONL_ENTRY" >> "$LOG_FILE"

  # ロック解放
  release_lock "$LOCK_FILE"
fi

# ===== セッションイベントログ（重要ツールのみ） =====
is_important_tool() {
  case "$1" in
    Write|Edit|Bash|Task|Skill|SlashCommand) return 0 ;;
  esac
  return 1
}

trim_text() {
  local text="$1"
  local max_len="${2:-120}"
  if [ "${#text}" -gt "$max_len" ]; then
    echo "${text:0:$max_len}"
  else
    echo "$text"
  fi
}

append_session_event() {
  local tool="$1"
  local timestamp="$2"
  local data_json="$3"

  [ ! -f "$SESSION_FILE" ] && return 0

  # ロック取得
  if ! acquire_lock "$EVENT_LOCK_FILE"; then
    return 0
  fi

  # イベントログ初期化
  touch "$EVENT_LOG_FILE" 2>/dev/null || true

  if command -v jq >/dev/null 2>&1; then
    local seq
    local event_id
    local current_state
    seq=$(jq -r '.event_seq // 0' "$SESSION_FILE" 2>/dev/null)
    seq=$((seq + 1))
    event_id=$(printf "event-%06d" "$seq")
    current_state=$(jq -r '.state // "executing"' "$SESSION_FILE" 2>/dev/null)

    # session.json を更新
    tmp_file=$(mktemp)
    jq --arg updated_at "$timestamp" \
       --arg event_id "$event_id" \
       --argjson event_seq "$seq" \
       '.updated_at = $updated_at | .last_event_id = $event_id | .event_seq = $event_seq' \
       "$SESSION_FILE" > "$tmp_file" && mv "$tmp_file" "$SESSION_FILE"

    # event log 追記（SESSION_ORCHESTRATION.md 統一スキーマ）
    if [ -n "$data_json" ]; then
      echo "{\"id\":\"$event_id\",\"type\":\"tool.$tool\",\"ts\":\"$timestamp\",\"state\":\"$current_state\",\"data\":$data_json}" >> "$EVENT_LOG_FILE"
    else
      echo "{\"id\":\"$event_id\",\"type\":\"tool.$tool\",\"ts\":\"$timestamp\",\"state\":\"$current_state\"}" >> "$EVENT_LOG_FILE"
    fi
  fi

  release_lock "$EVENT_LOCK_FILE"
}

if is_important_tool "$TOOL_NAME"; then
  TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")
  DATA_JSON=""

  if [ -n "$FILE_PATH" ]; then
    FILE_PATH_SAFE=$(trim_text "$FILE_PATH" 200)
    DATA_JSON="{\"file_path\":\"$FILE_PATH_SAFE\"}"
  elif [ -n "$COMMAND" ]; then
    COMMAND_SAFE=$(trim_text "$COMMAND" 200)
    DATA_JSON="{\"command\":\"$COMMAND_SAFE\"}"
  fi

  append_session_event "$(echo "$TOOL_NAME" | tr '[:upper:]' '[:lower:]')" "$TIMESTAMP" "$DATA_JSON"
fi


# ===== Skill追跡（セッション単位でスキル使用を記録） =====
SESSION_SKILLS_USED_FILE="${STATE_DIR}/session-skills-used.json"

if [ "$TOOL_NAME" = "Skill" ]; then
  mkdir -p "$STATE_DIR"
  
  # ファイルが存在しない場合は初期化
  if [ ! -f "$SESSION_SKILLS_USED_FILE" ]; then
    echo '{"used": [], "session_start": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' > "$SESSION_SKILLS_USED_FILE"
  fi
  
  if command -v jq >/dev/null 2>&1; then
    # スキル名を tool_input から取得
    SKILL_NAME=""
    if [ -n "$INPUT" ]; then
      SKILL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_input.skill // "unknown"' 2>/dev/null)
    fi
    
    # used 配列に追加
    temp_file=$(mktemp)
    jq --arg skill "$SKILL_NAME" \
       --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       '.used += [$skill] | .last_used = $ts' \
       "$SESSION_SKILLS_USED_FILE" > "$temp_file" && mv "$temp_file" "$SESSION_SKILLS_USED_FILE"
  fi
fi

exit 0
