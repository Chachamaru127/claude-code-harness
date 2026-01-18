#!/bin/bash
# session-state.sh
# セッション状態を強制的に遷移させる
#
# Usage: ./scripts/session-state.sh --state <state> --event <event> [--data <json>]
#
# 入力:
#   --state <state>  : 遷移先の状態 (idle, initialized, planning, executing, reviewing, verifying, escalated, completed, failed, stopped)
#   --event <event>  : 遷移トリガーのイベント (session.start, plan.ready, work.start, etc.)
#   --data <json>    : イベント付加データ (オプション)
#
# 出力:
#   成功時: exit 0
#   失敗時: stderr にエラー出力 + exit 1

set -euo pipefail

# ================================
# 定数
# ================================
STATE_DIR=".claude/state"
SESSION_FILE="$STATE_DIR/session.json"
EVENT_LOG_FILE="$STATE_DIR/session.events.jsonl"
LOCK_FILE="$STATE_DIR/session-state.lock"
CONFIG_FILE=".claude-code-harness.config.yaml"

# 有効な状態リスト (docs/SESSION_ORCHESTRATION.md の States と同期)
VALID_STATES=(idle initialized planning executing reviewing verifying escalated completed failed stopped)

# 遷移ルール (from:event -> to)
# フォーマット: "from_state:event_name:to_state"
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
  # エスカレーション
  "executing:escalation.requested:escalated"
  "reviewing:escalation.requested:escalated"
  "verifying:escalation.requested:escalated"
  "planning:escalation.requested:escalated"
  "escalated:escalation.resolved:initialized"
  # 停止 (任意の状態から)
  "*:session.stop:stopped"
  # 再開
  "stopped:session.resume:initialized"
  # 完了
  "completed:session.stop:stopped"
  "reviewing:work.all_complete:completed"
)

# ================================
# ヘルパー関数
# ================================

# 使用方法を表示
usage() {
  echo "Usage: $0 --state <state> --event <event> [--data <json>]" >&2
  echo "" >&2
  echo "Valid states: ${VALID_STATES[*]}" >&2
  echo "" >&2
  echo "Options:" >&2
  echo "  --state <state>   Target state" >&2
  echo "  --event <event>   Trigger event" >&2
  echo "  --data <json>     Optional JSON data for the event" >&2
  exit 1
}

# 状態の有効性チェック
is_valid_state() {
  local state="$1"
  for valid in "${VALID_STATES[@]}"; do
    if [[ "$valid" == "$state" ]]; then
      return 0
    fi
  done
  return 1
}

# 遷移ルールのチェック
is_valid_transition() {
  local from="$1"
  local event="$2"
  local to="$3"

  for rule in "${TRANSITION_RULES[@]}"; do
    local rule_from="${rule%%:*}"
    local rest="${rule#*:}"
    local rule_event="${rest%%:*}"
    local rule_to="${rest#*:}"

    # ワイルドカード対応（任意の状態から）
    if [[ "$rule_from" == "*" || "$rule_from" == "$from" ]]; then
      if [[ "$rule_event" == "$event" && "$rule_to" == "$to" ]]; then
        return 0
      fi
    fi
  done
  return 1
}

# ロック取得
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

# ロック解放
release_lock() {
  if command -v flock >/dev/null 2>&1; then
    exec 200>&-
  else
    rmdir "$LOCK_FILE.dir" 2>/dev/null || true
  fi
}

# 現在の状態を取得
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

# 最大リトライ数を取得
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

# リトライバックオフ秒数を取得 (SESSION_ORCHESTRATION.md準拠)
get_retry_backoff() {
  local retry_num="${1:-1}"
  local defaults=(5 15 30)

  if [ -f "$CONFIG_FILE" ]; then
    local backoff_line
    backoff_line=$(grep -E "retry_backoff_seconds:" "$CONFIG_FILE" 2>/dev/null | head -n 1 || true)
    if [ -n "$backoff_line" ]; then
      # YAML配列 [5, 15, 30] からパース
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

  # デフォルト値
  local idx=$((retry_num - 1))
  if [ "$idx" -ge 0 ] && [ "$idx" -lt ${#defaults[@]} ]; then
    echo "${defaults[$idx]}"
  else
    echo "${defaults[${#defaults[@]}-1]}"
  fi
}

# ================================
# メイン処理
# ================================

TARGET_STATE=""
EVENT_NAME=""
EVENT_DATA=""

# 引数解析
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

# 必須引数チェック
if [ -z "$TARGET_STATE" ] || [ -z "$EVENT_NAME" ]; then
  echo "Error: --state and --event are required" >&2
  usage
fi

# 状態の有効性チェック
if ! is_valid_state "$TARGET_STATE"; then
  echo "Error: Invalid state '$TARGET_STATE'" >&2
  echo "Valid states: ${VALID_STATES[*]}" >&2
  exit 1
fi

# ロック取得
if ! acquire_lock; then
  echo "Error: Failed to acquire lock" >&2
  exit 1
fi

# 現在の状態を取得
CURRENT_STATE=$(get_current_state)

# 遷移ルールのチェック
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

# タイムスタンプ
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# セッションファイルの更新
if [ -f "$SESSION_FILE" ]; then
  if command -v jq >/dev/null 2>&1; then
    # event_seq を増加
    EVENT_SEQ=$(jq -r '.event_seq // 0' "$SESSION_FILE" 2>/dev/null)
    EVENT_SEQ=$((EVENT_SEQ + 1))
    EVENT_ID=$(printf "event-%06d" "$EVENT_SEQ")

    # session.json を更新
    tmp_file=$(mktemp)
    jq --arg state "$TARGET_STATE" \
       --arg updated_at "$TIMESTAMP" \
       --arg event_id "$EVENT_ID" \
       --argjson event_seq "$EVENT_SEQ" \
       '.state = $state | .updated_at = $updated_at | .last_event_id = $event_id | .event_seq = $event_seq' \
       "$SESSION_FILE" > "$tmp_file" && mv "$tmp_file" "$SESSION_FILE"

    # イベントログに追記
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
  # セッションファイルがない場合は新規作成
  mkdir -p "$STATE_DIR" 2>/dev/null || true

  SESSION_ID="session-$(date +%s)"
  EVENT_SEQ=1
  EVENT_ID="event-000001"
  MAX_RETRIES=$(get_max_retries)

  # バックオフ秒数を配列として取得
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

  # イベントログに追記
  if [ -n "$EVENT_DATA" ]; then
    echo "{\"id\":\"$EVENT_ID\",\"type\":\"$EVENT_NAME\",\"ts\":\"$TIMESTAMP\",\"state\":\"$TARGET_STATE\",\"data\":$EVENT_DATA}" >> "$EVENT_LOG_FILE"
  else
    echo "{\"id\":\"$EVENT_ID\",\"type\":\"$EVENT_NAME\",\"ts\":\"$TIMESTAMP\",\"state\":\"$TARGET_STATE\"}" >> "$EVENT_LOG_FILE"
  fi
fi

release_lock

echo "State transition: $CURRENT_STATE -> $TARGET_STATE (via $EVENT_NAME)"
exit 0
