#!/bin/bash
# session-control.sh
# Update session state based on resume/fork flags from /work
#
# Usage:
#   ./scripts/session-control.sh --resume <id|latest>
#   ./scripts/session-control.sh --fork <id|current> --reason "<text>"

set -euo pipefail

STATE_DIR=".claude/state"
STATE_FILE="$STATE_DIR/session.json"
EVENT_LOG_FILE="$STATE_DIR/session.events.jsonl"
ARCHIVE_DIR="$STATE_DIR/sessions"

RESUME_TARGET=""
RESUME_LATEST="false"
FORK_TARGET=""
FORK_REASON=""

while [ $# -gt 0 ]; do
  case "$1" in
    --resume)
      RESUME_TARGET="${2:-}"
      shift 2
      ;;
    --fork)
      FORK_TARGET="${2:-}"
      shift 2
      ;;
    --reason)
      FORK_REASON="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

if [ -n "$RESUME_TARGET" ] && [ -n "$FORK_TARGET" ]; then
  echo "Both --resume and --fork are not allowed in the same call." >&2
  exit 1
fi

if [ "$RESUME_TARGET" = "latest" ]; then
  RESUME_LATEST="true"
  RESUME_TARGET=""
fi

mkdir -p "$STATE_DIR" "$ARCHIVE_DIR"
touch "$EVENT_LOG_FILE" 2>/dev/null || true

now_ts() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

gen_id() {
  uuidgen 2>/dev/null || echo "session-$(date +%s)"
}

gen_token() {
  uuidgen 2>/dev/null || echo "resume-$(date +%s)"
}

append_event() {
  local event_type="$1"
  local event_state="$2"
  local event_time="$3"
  local event_data="$4"

  if command -v jq >/dev/null 2>&1; then
    local seq
    local event_id
    seq=$(jq -r '.event_seq // 0' "$STATE_FILE" 2>/dev/null)
    seq=$((seq + 1))
    event_id=$(printf "event-%06d" "$seq")

    tmp_file=$(mktemp)
    jq --arg state "$event_state" \
       --arg updated_at "$event_time" \
       --arg event_id "$event_id" \
       --argjson event_seq "$seq" \
       '.state = $state | .updated_at = $updated_at | .last_event_id = $event_id | .event_seq = $event_seq' \
       "$STATE_FILE" > "$tmp_file" && mv "$tmp_file" "$STATE_FILE"

    if [ -n "$event_data" ]; then
      echo "{\"id\":\"$event_id\",\"type\":\"$event_type\",\"ts\":\"$event_time\",\"state\":\"$event_state\",\"data\":$event_data}" >> "$EVENT_LOG_FILE"
    else
      echo "{\"id\":\"$event_id\",\"type\":\"$event_type\",\"ts\":\"$event_time\",\"state\":\"$event_state\"}" >> "$EVENT_LOG_FILE"
    fi
  elif command -v python3 >/dev/null 2>&1; then
    event_id=$(python3 - <<PY 2>/dev/null
import json
try:
    data = json.load(open("$STATE_FILE"))
except Exception:
    data = {}
seq = int(data.get("event_seq", 0)) + 1
data["event_seq"] = seq
data["state"] = "$event_state"
data["updated_at"] = "$event_time"
data["last_event_id"] = f"event-{seq:06d}"
with open("$STATE_FILE", "w") as f:
    json.dump(data, f, indent=2)
print(f"event-{seq:06d}")
PY
)
    if [ -n "$event_data" ]; then
      echo "{\"id\":\"$event_id\",\"type\":\"$event_type\",\"ts\":\"$event_time\",\"state\":\"$event_state\",\"data\":$event_data}" >> "$EVENT_LOG_FILE"
    else
      echo "{\"id\":\"$event_id\",\"type\":\"$event_type\",\"ts\":\"$event_time\",\"state\":\"$event_state\"}" >> "$EVENT_LOG_FILE"
    fi
  else
    echo "{\"id\":\"event-000001\",\"type\":\"$event_type\",\"ts\":\"$event_time\",\"state\":\"$event_state\"}" >> "$EVENT_LOG_FILE"
  fi
}

pick_latest_session() {
  local latest_file
  latest_file=$(ls -t "$ARCHIVE_DIR"/*.json 2>/dev/null | head -n 1 || true)
  if [ -z "$latest_file" ]; then
    echo ""
    return
  fi
  basename "$latest_file" .json
}

resume_session() {
  local target_id="$1"
  local session_file="$ARCHIVE_DIR/${target_id}.json"
  local events_file="$ARCHIVE_DIR/${target_id}.events.jsonl"

  if [ ! -f "$session_file" ]; then
    echo "Resume target not found: $target_id" >&2
    exit 1
  fi

  cp "$session_file" "$STATE_FILE"
  if [ -f "$events_file" ]; then
    cp "$events_file" "$EVENT_LOG_FILE"
  else
    : > "$EVENT_LOG_FILE"
  fi

  append_event "session.resume" "initialized" "$(now_ts)" "{\"resume_target\":\"$target_id\"}"
}

fork_session() {
  local target_id="$1"
  local base_file="$STATE_FILE"

  if [ "$target_id" != "current" ] && [ -n "$target_id" ]; then
    local candidate="$ARCHIVE_DIR/${target_id}.json"
    if [ -f "$candidate" ]; then
      base_file="$candidate"
    else
      echo "Fork target not found: $target_id" >&2
      exit 1
    fi
  fi

  local new_id
  new_id="$(gen_id)"
  local new_token
  new_token="$(gen_token)"
  local now
  now="$(now_ts)"

  if command -v jq >/dev/null 2>&1; then
    tmp_file=$(mktemp)
    jq --arg session_id "$new_id" \
       --arg parent_id "$(jq -r '.session_id // ""' "$base_file" 2>/dev/null)" \
       --arg started_at "$now" \
       --arg updated_at "$now" \
       --arg token "$new_token" \
       '.session_id = $session_id |
        .parent_session_id = $parent_id |
        .state = "initialized" |
        .started_at = $started_at |
        .updated_at = $updated_at |
        .ended_at = null |
        .resumed_at = null |
        .resume_token = $token |
        .event_seq = 0 |
        .last_event_id = "" |
        .prompt_seq = 0 |
        .changes_this_session = []' \
       "$base_file" > "$tmp_file" && mv "$tmp_file" "$STATE_FILE"
  elif command -v python3 >/dev/null 2>&1; then
    python3 - <<PY
import json
from pathlib import Path
base = {}
try:
    base = json.load(open("$base_file"))
except Exception:
    pass
base["session_id"] = "$new_id"
base["parent_session_id"] = base.get("session_id", "")
base["state"] = "initialized"
base["started_at"] = "$now"
base["updated_at"] = "$now"
base["ended_at"] = None
base["resumed_at"] = None
base["resume_token"] = "$new_token"
base["event_seq"] = 0
base["last_event_id"] = ""
base["prompt_seq"] = 0
base["changes_this_session"] = []
Path("$STATE_FILE").write_text(json.dumps(base, indent=2))
PY
  else
    echo "jq or python3 required for fork." >&2
    exit 1
  fi

  : > "$EVENT_LOG_FILE"
  if [ -n "$FORK_REASON" ]; then
    append_event "session.fork" "initialized" "$now" "{\"parent_session_id\":\"$target_id\",\"reason\":\"$FORK_REASON\"}"
  else
    append_event "session.fork" "initialized" "$now" "{\"parent_session_id\":\"$target_id\"}"
  fi
}

if [ "$RESUME_LATEST" = "true" ]; then
  RESUME_TARGET="$(pick_latest_session)"
  if [ -z "$RESUME_TARGET" ]; then
    echo "No archived sessions found for --resume latest." >&2
    exit 1
  fi
fi

if [ -n "$RESUME_TARGET" ]; then
  resume_session "$RESUME_TARGET"
  exit 0
fi

if [ -n "$FORK_TARGET" ]; then
  fork_session "$FORK_TARGET"
  exit 0
fi

echo "No resume/fork target specified. Nothing to do." >&2
exit 1
