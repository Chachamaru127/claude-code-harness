#!/bin/bash
# session-state.sh
# Forcibly transition session state
#
# Usage: ./scripts/session-state.sh --state <state> --event <event> [--data <json>]
#
# Input:
#   --state <state>  : Target state (idle, initialized, planning, executing, reviewing, verifying, escalated, completed, failed, stopped)
#   --event <event>  : Transition trigger event (session.start, plan.ready, work.start, etc.)
#   --data <json>    : Optional event payload (optional)
#
# Output:
#   On success: exit 0
#   On failure: error output to stderr + exit 1

set -euo pipefail

# ================================
# Constants
# ================================
STATE_DIR=".claude/state"
SESSION_FILE="$STATE_DIR/session.json"
EVENT_LOG_FILE="$STATE_DIR/session.events.jsonl"
LOCK_FILE="$STATE_DIR/session-state.lock"
CONFIG_FILE=".claude-code-harness.config.yaml"

# Valid state list (synced with States in docs/SESSION_ORCHESTRATION.md)
VALID_STATES=(idle initialized planning executing reviewing verifying escalated completed failed stopped)

# Transition rules (from:event -> to)
# Format: "from_state:event_name:to_state"
TRANSITION_RULES=(
  "idle:session.start:initialized"
  "initialized:plan.ready:planning"
  "planning:work.start:executing"
  "executing:work.task_complete:reviewing"
  "reviewing:review.start:reviewing"
  "reviewing:review.issue_found:executing"
  "executing:verify.start:verifying"
  "reviewing:verify.start:verifying"
  "verifying:verify.passed:completed"
  "verifying:verify.failed:escalated"
  # Escalation
  "executing:escalation.requested:escalated"
  "reviewing:escalation.requested:escalated"
  "verifying:escalation.requested:escalated"
  "planning:escalation.requested:escalated"
  "escalated:escalation.resolved:initialized"
  # Stop (from any state)
  "*:session.stop:stopped"
  # Resume
  "stopped:session.resume:initialized"
  # Completion
  "completed:session.stop:stopped"
  "reviewing:work.all_complete:completed"
)

# ================================
# Helper functions
# ================================

# Display usage
usage() {
  echo "Usage: $0 --state <state> --event <event> [--data <json>]" >&2
  echo "" >&2
  echo "Valid states: ${VALID_STATES[*]}" >&2
  echo "" >&2
  echo "Options:" >&2
  echo "  --state <state>   Target state" >&2
  echo "  --event <event>   Trigger event" >&2
  echo "  --data <json>     Optional JSON payload for the event" >&2
  exit 1
}

# Validate state
is_valid_state() {
  local state="$1"
  for valid in "${VALID_STATES[@]}"; do
    if [[ "$valid" == "$state" ]]; then
      return 0
    fi
  done
  return 1
}

# Check transition rule
is_valid_transition() {
  local from="$1"
  local event="$2"
  local to="$3"

  for rule in "${TRANSITION_RULES[@]}"; do
    local rule_from="${rule%%:*}"
    local rest="${rule#*:}"
    local rule_event="${rest%%:*}"
    local rule_to="${rest#*:}"

    # Wildcard support (from any state)
    if [[ "$rule_from" == "*" || "$rule_from" == "$from" ]]; then
      if [[ "$rule_event" == "$event" && "$rule_to" == "$to" ]]; then
        return 0
      fi
    fi
  done
  return 1
}

# Acquire lock
acquire_lock() {
  local timeout=5
  local waited=0

  mkdir -p "$STATE_DIR" 2>/dev/null || true

  if command -v flock >/dev/null 2>&1; then
    exec 200>"$LOCK_FILE"
    flock -w "$timeout" 200 || return 1
    return 0
  fi

  while ! mkdir "$LOCK_FILE.dir" 2>/dev/null; do
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
  if command -v flock >/dev/null 2>&1; then
    exec 200>&-
  else
    rmdir "$LOCK_FILE.dir" 2>/dev/null || true
  fi
}

# Get current state
get_current_state() {
  if [ ! -f "$SESSION_FILE" ]; then
    echo "idle"
    return
  fi

  if command -v jq >/dev/null 2>&1; then
    jq -r '.state // "idle"' "$SESSION_FILE" 2>/dev/null || echo "idle"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c "import json; print(json.load(open('$SESSION_FILE')).get('state', 'idle'))" 2>/dev/null || echo "idle"
  else
    echo "idle"
  fi
}

# Get maximum retry count
get_max_retries() {
  local default=3

  if [ -f "$CONFIG_FILE" ]; then
    local max_retries_line
    max_retries_line=$(grep -E "max_state_retries:" "$CONFIG_FILE" 2>/dev/null | head -n 1 || true)
    if [ -n "$max_retries_line" ]; then
      local val
      val=$(echo "$max_retries_line" | sed 's/.*: *//' | tr -d '"')
      if [[ "$val" =~ ^[0-9]+$ ]]; then
        echo "$val"
        return
      fi
    fi
  fi

  echo "$default"
}

# Get retry backoff seconds (compliant with SESSION_ORCHESTRATION.md)
get_retry_backoff() {
  local retry_num="${1:-1}"
  local defaults=(5 15 30)

  if [ -f "$CONFIG_FILE" ]; then
    local backoff_line
    backoff_line=$(grep -E "retry_backoff_seconds:" "$CONFIG_FILE" 2>/dev/null | head -n 1 || true)
    if [ -n "$backoff_line" ]; then
      # Parse YAML array [5, 15, 30]
      local arr
      arr=$(echo "$backoff_line" | sed 's/.*: *\[//' | sed 's/\].*//' | tr ',' ' ')
      local index=$((retry_num - 1))
      local i=0
      for val in $arr; do
        if [ "$i" -eq "$index" ]; then
          echo "${val// /}"
          return
        fi
        i=$((i + 1))
      done
    fi
  fi

  # Default values
  local idx=$((retry_num - 1))
  if [ "$idx" -ge 0 ] && [ "$idx" -lt ${#defaults[@]} ]; then
    echo "${defaults[$idx]}"
  else
    echo "${defaults[${#defaults[@]}-1]}"
  fi
}

# ================================
# Main
# ================================

TARGET_STATE=""
EVENT_NAME=""
EVENT_DATA=""

# Argument parsing
while [[ $# -gt 0 ]]; do
  case "$1" in
    --state)
      TARGET_STATE="$2"
      shift 2
      ;;
    --event)
      EVENT_NAME="$2"
      shift 2
      ;;
    --data)
      EVENT_DATA="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      ;;
  esac
done

# Required argument check
if [ -z "$TARGET_STATE" ] || [ -z "$EVENT_NAME" ]; then
  echo "Error: --state and --event are required" >&2
  usage
fi

# Validate state
if ! is_valid_state "$TARGET_STATE"; then
  echo "Error: Invalid state '$TARGET_STATE'" >&2
  echo "Valid states: ${VALID_STATES[*]}" >&2
  exit 1
fi

# Acquire lock
if ! acquire_lock; then
  echo "Error: Failed to acquire lock" >&2
  exit 1
fi

# Get current state
CURRENT_STATE=$(get_current_state)

# Check transition rule
if ! is_valid_transition "$CURRENT_STATE" "$EVENT_NAME" "$TARGET_STATE"; then
  release_lock
  echo "Error: Invalid transition from '$CURRENT_STATE' via '$EVENT_NAME' to '$TARGET_STATE'" >&2
  echo "Allowed transitions from '$CURRENT_STATE':" >&2
  for rule in "${TRANSITION_RULES[@]}"; do
    local rule_from="${rule%%:*}"
    if [[ "$rule_from" == "$CURRENT_STATE" || "$rule_from" == "*" ]]; then
      echo "  $rule" >&2
    fi
  done
  exit 1
fi

# Timestamp
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Update session file
if [ -f "$SESSION_FILE" ]; then
  if command -v jq >/dev/null 2>&1; then
    # Increment event_seq
    EVENT_SEQ=$(jq -r '.event_seq // 0' "$SESSION_FILE" 2>/dev/null)
    EVENT_SEQ=$((EVENT_SEQ + 1))
    EVENT_ID=$(printf "event-%06d" "$EVENT_SEQ")

    # Update session.json
    tmp_file=$(mktemp)
    jq --arg state "$TARGET_STATE" \
       --arg updated_at "$TIMESTAMP" \
       --arg event_id "$EVENT_ID" \
       --argjson event_seq "$EVENT_SEQ" \
       '.state = $state | .updated_at = $updated_at | .last_event_id = $event_id | .event_seq = $event_seq' \
       "$SESSION_FILE" > "$tmp_file" && mv "$tmp_file" "$SESSION_FILE"

    # Append to event log
    mkdir -p "$(dirname "$EVENT_LOG_FILE")" 2>/dev/null || true
    if [ -n "$EVENT_DATA" ]; then
      echo "{\"id\":\"$EVENT_ID\",\"type\":\"$EVENT_NAME\",\"ts\":\"$TIMESTAMP\",\"state\":\"$TARGET_STATE\",\"data\":$EVENT_DATA}" >> "$EVENT_LOG_FILE"
    else
      echo "{\"id\":\"$EVENT_ID\",\"type\":\"$EVENT_NAME\",\"ts\":\"$TIMESTAMP\",\"state\":\"$TARGET_STATE\"}" >> "$EVENT_LOG_FILE"
    fi
  elif command -v python3 >/dev/null 2>&1; then
    python3 - <<PY
import json
import os

session_file = "$SESSION_FILE"
event_log_file = "$EVENT_LOG_FILE"
target_state = "$TARGET_STATE"
event_name = "$EVENT_NAME"
timestamp = "$TIMESTAMP"
event_data_str = '''$EVENT_DATA'''

# Read and update session
with open(session_file, "r") as f:
    data = json.load(f)

event_seq = data.get("event_seq", 0) + 1
event_id = f"event-{event_seq:06d}"

data["state"] = target_state
data["updated_at"] = timestamp
data["last_event_id"] = event_id
data["event_seq"] = event_seq

with open(session_file, "w") as f:
    json.dump(data, f, indent=2)

# Append to event log
os.makedirs(os.path.dirname(event_log_file), exist_ok=True)
event_entry = {
    "id": event_id,
    "type": event_name,
    "ts": timestamp,
    "state": target_state
}
if event_data_str.strip():
    try:
        event_entry["data"] = json.loads(event_data_str)
    except:
        pass

with open(event_log_file, "a") as f:
    f.write(json.dumps(event_entry) + "\n")
PY
  else
    echo "Error: Neither jq nor python3 available" >&2
    release_lock
    exit 1
  fi
else
  # Create new session file if it does not exist
  mkdir -p "$STATE_DIR" 2>/dev/null || true

  SESSION_ID="session-$(date +%s)"
  EVENT_SEQ=1
  EVENT_ID="event-000001"
  MAX_RETRIES=$(get_max_retries)

  # Get backoff seconds as an array
  BACKOFF_1=$(get_retry_backoff 1)
  BACKOFF_2=$(get_retry_backoff 2)
  BACKOFF_3=$(get_retry_backoff 3)

  cat > "$SESSION_FILE" << EOF
{
  "session_id": "$SESSION_ID",
  "parent_session_id": null,
  "state": "$TARGET_STATE",
  "state_version": 1,
  "started_at": "$TIMESTAMP",
  "updated_at": "$TIMESTAMP",
  "resume_token": "",
  "event_seq": $EVENT_SEQ,
  "last_event_id": "$EVENT_ID",
  "fork_count": 0,
  "orchestration": {
    "max_state_retries": $MAX_RETRIES,
    "retry_backoff_seconds": [$BACKOFF_1, $BACKOFF_2, $BACKOFF_3]
  }
}
EOF

  # Append to event log
  if [ -n "$EVENT_DATA" ]; then
    echo "{\"id\":\"$EVENT_ID\",\"type\":\"$EVENT_NAME\",\"ts\":\"$TIMESTAMP\",\"state\":\"$TARGET_STATE\",\"data\":$EVENT_DATA}" >> "$EVENT_LOG_FILE"
  else
    echo "{\"id\":\"$EVENT_ID\",\"type\":\"$EVENT_NAME\",\"ts\":\"$TIMESTAMP\",\"state\":\"$TARGET_STATE\"}" >> "$EVENT_LOG_FILE"
  fi
fi

release_lock

echo "State transition: $CURRENT_STATE -> $TARGET_STATE (via $EVENT_NAME)"
exit 0
