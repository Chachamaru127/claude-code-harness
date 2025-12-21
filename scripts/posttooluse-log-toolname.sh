#!/bin/bash
# posttooluse-log-toolname.sh
# Phase0: 全ツール名をログに記録（tool_name ディスカバリ用）
# + LSP追跡: LSP関連ツールを検出して tooling-policy.json を更新
#
# Usage: PostToolUse hook から自動実行（matcher="*"）
# Input: stdin JSON (Claude Code hooks)
# Output:
#   - .claude/state/tool-events.jsonl にJSONL追記 (Phase0ログ有効時のみ)
#   - .claude/state/tooling-policy.json 更新 (LSP関連ツール検出時、常に)
#
# 制御: CC_HARNESS_PHASE0_LOG=1 がある時のみログ収集を実行
#       （tool_name確定後は無効化して、ログ肥大化を防ぐ）
#       LSP追跡は常に実行（matcher "LSP" に依存せず、詰みを防ぐ）

set +e

# ===== 定数 =====
STATE_DIR=".claude/state"
LOG_FILE="${STATE_DIR}/tool-events.jsonl"
LOCK_FILE="${STATE_DIR}/tool-events.lock"
SESSION_FILE="${STATE_DIR}/session.json"
MAX_SIZE_BYTES=262144  # 256KB
MAX_LINES=2000
MAX_GENERATIONS=5

# ===== ユーティリティ =====

# ロックを取得（flock優先、なければmkdirロック）
acquire_lock() {
  local lockfile="$1"
  local timeout=5
  local waited=0

  # flock が使えるなら flock を使う
  if command -v flock >/dev/null 2>&1; then
    exec 200>"$lockfile"
    flock -w "$timeout" 200 || return 1
    return 0
  fi

  # flock が無いなら mkdir ロック（原子的）
  while ! mkdir "$lockfile" 2>/dev/null; do
    sleep 0.1
    waited=$((waited + 1))
    if [ "$waited" -ge $((timeout * 10)) ]; then
      return 1
    fi
  done
  return 0
}

# ロックを解放
release_lock() {
  local lockfile="$1"

  if command -v flock >/dev/null 2>&1; then
    exec 200>&-
  else
    rmdir "$lockfile" 2>/dev/null || true
  fi
}

# ローテーション実行
rotate_log() {
  local logfile="$1"

  # 最古を削除
  [ -f "${logfile}.${MAX_GENERATIONS}" ] && rm -f "${logfile}.${MAX_GENERATIONS}"

  # 順にリネーム（.4 → .5, .3 → .4, ...）
  for i in $(seq $((MAX_GENERATIONS - 1)) -1 1); do
    [ -f "${logfile}.${i}" ] && mv "${logfile}.${i}" "${logfile}.$((i + 1))"
  done

  # 現行を .1 へ
  [ -f "$logfile" ] && mv "$logfile" "${logfile}.1"

  # 新しいログファイルを作成
  touch "$logfile"
}

# ローテーションが必要かチェック
needs_rotation() {
  local logfile="$1"

  [ ! -f "$logfile" ] && return 1

  # サイズチェック
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

  # 行数チェック
  local lines
  lines=$(wc -l < "$logfile" 2>/dev/null || echo 0)
  if [ "$lines" -ge "$MAX_LINES" ]; then
    return 0
  fi

  return 1
}

# ===== メイン処理 =====

# stateディレクトリ作成
mkdir -p "$STATE_DIR"

# stdin から JSON 入力を読み取る
INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

if [ -z "$INPUT" ]; then
  exit 0
fi

# JSON から必要なフィールドを抽出（jq優先、なければpython3）
TOOL_NAME=""
SESSION_ID=""

if command -v jq >/dev/null 2>&1; then
  TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"
  SESSION_ID="$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)"
elif command -v python3 >/dev/null 2>&1; then
  eval "$(echo "$INPUT" | python3 - <<'PY' 2>/dev/null
import json, shlex, sys
try:
    data = json.load(sys.stdin)
except Exception:
    data = {}
tool_name = data.get("tool_name") or ""
session_id = data.get("session_id") or ""
print(f"TOOL_NAME={shlex.quote(tool_name)}")
print(f"SESSION_ID={shlex.quote(session_id)}")
PY
)"
fi

# tool_name が無ければスキップ
[ -z "$TOOL_NAME" ] && exit 0

# prompt_seq を session.json から取得
PROMPT_SEQ=0
if [ -f "$SESSION_FILE" ]; then
  if command -v jq >/dev/null 2>&1; then
    PROMPT_SEQ="$(jq -r '.prompt_seq // 0' "$SESSION_FILE" 2>/dev/null)"
  elif command -v python3 >/dev/null 2>&1; then
    PROMPT_SEQ="$(python3 -c "import json; print(json.load(open('$SESSION_FILE')).get('prompt_seq', 0))" 2>/dev/null || echo 0)"
  fi
fi

# ===== LSP追跡（常に実行、matcher依存を回避） =====
# LSP関連ツールを検出（tool_nameに "lsp" または "LSP" が含まれる場合）
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

# ===== Phase0ログ収集（CC_HARNESS_PHASE0_LOG=1 の時のみ） =====
if [ "${CC_HARNESS_PHASE0_LOG:-0}" = "1" ]; then
  # タイムスタンプ（UTC ISO8601）
  TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")

  # JSONL エントリ作成（最小フィールドのみ）
  JSONL_ENTRY=$(cat <<EOF
{"v":1,"ts":"$TIMESTAMP","session_id":"$SESSION_ID","prompt_seq":$PROMPT_SEQ,"hook_event_name":"PostToolUse","tool_name":"$TOOL_NAME"}
EOF
  )

  # ロック取得
  if ! acquire_lock "$LOCK_FILE"; then
    # ロックが取れなければスキップ（失敗しても問題ない）
    exit 0
  fi

  # ローテーションチェック
  if needs_rotation "$LOG_FILE"; then
    rotate_log "$LOG_FILE"
  fi

  # ログ追記（原子的でないが、ロックで保護されている）
  echo "$JSONL_ENTRY" >> "$LOG_FILE"

  # ロック解放
  release_lock "$LOCK_FILE"
fi

exit 0
