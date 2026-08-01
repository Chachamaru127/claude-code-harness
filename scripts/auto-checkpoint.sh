#!/bin/bash
# auto-checkpoint.sh
# Phase B-5 で呼ばれ、harness-mem の checkpoint API を叩いて永続化 +
# ローカル audit を書く。
#
# Usage: ./scripts/auto-checkpoint.sh task_id commit_hash sprint_contract_path review_result_path

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

# ── 環境変数 ───────────────────────────────────────────────────────────────────
# HARNESS_MEM_CLIENT: 旧 shell client (`scripts/harness-mem-client.sh`) へのパス。
# Phase 60 (v2.20.10) で managed-companion 移行した際に
# `scripts/harness-mem-client.sh` は claude-harness の配布から除外された。
# 現行アーキテクチャでは:
#   - 永続化は memory-bridge.sh 経由 (HTTP daemon API)
#   - 管理操作は `bin/harness mem ...` (Phase 60 contract)
# このパスは **テスト fixture 用** にのみ残されている:
#   - 既定 (env 未指定): 空文字 → API 呼び出しを skip し audit のみ
#   - HARNESS_MEM_CLIENT=/abs/path → fake client 等で record-checkpoint API を検証
# 詳細: docs/harness-mem-companion-contract.md
HARNESS_MEM_CLIENT="${HARNESS_MEM_CLIENT:-}"
# HARNESS_MEM_DISABLE: 1 のとき API 呼び出しをスキップ（フォールバック検証用）
HARNESS_MEM_DISABLE="${HARNESS_MEM_DISABLE:-0}"
# HARNESS_MEM_CLIENT_TIMEOUT_SEC: API 呼び出しタイムアウト秒数
export HARNESS_MEM_CLIENT_TIMEOUT_SEC="${HARNESS_MEM_CLIENT_TIMEOUT_SEC:-8}"
# CHECKPOINT_LOCK_TIMEOUT: flock/lockf 待機秒数
CHECKPOINT_LOCK_TIMEOUT="${CHECKPOINT_LOCK_TIMEOUT:-10}"

# ── 引数 ──────────────────────────────────────────────────────────────────────
if [ $# -lt 4 ]; then
  echo "Usage: $0 task_id commit_hash sprint_contract_path review_result_path" >&2
  exit 1
fi

TASK_ID="$1"
COMMIT_HASH="$2"
SPRINT_CONTRACT_PATH="$3"
REVIEW_RESULT_PATH="$4"

# ── 定数 ──────────────────────────────────────────────────────────────────────
STATE_DIR="${PROJECT_ROOT}/.claude/state"
LOCKS_DIR="${STATE_DIR}/locks"
LOCK_FILE="${LOCKS_DIR}/phase-b.lock"
CHECKPOINT_EVENTS_FILE="${STATE_DIR}/checkpoint-events.jsonl"
SESSION_EVENTS_FILE="${STATE_DIR}/session-events.jsonl"

# ── ユーティリティ ────────────────────────────────────────────────────────────
timestamp_iso8601() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

json_escape() {
  # 基本的な JSON 文字列エスケープ（python3 経由）
  printf '%s' "$1" | python3 -c 'import json,sys; sys.stdout.write(json.dumps(sys.stdin.read())[1:-1])' 2>/dev/null \
    || printf '%s' "$1" | sed 's/\\/\\\\/g;s/"/\\"/g;s/	/\\t/g'
}

read_json_file() {
  local path="$1"
  if [ -f "$path" ]; then
    # 改行を除去して 1 行にする
    tr -d '\n\r' < "$path" | tr -s ' '
  else
    printf '{}'
  fi
}

append_jsonl() {
  local file="$1"
  local record="$2"
  # ファイルが存在しない場合は作成
  mkdir -p "$(dirname "$file")"
  printf '%s\n' "$record" >> "$file"
}

# ── ロック実装（flock/lockf/mkdir フォールバック） ────────────────────────────
_LOCK_ACQUIRED=0
_LOCK_MUTEX_DIR="${LOCK_FILE}.dir"

acquire_lock() {
  local timeout="${CHECKPOINT_LOCK_TIMEOUT}"
  mkdir -p "${LOCKS_DIR}"

  if command -v flock >/dev/null 2>&1; then
    # Linux: flock -w timeout fd
    exec 9>"${LOCK_FILE}"
    if flock -w "${timeout}" 9; then
      _LOCK_ACQUIRED=1
      return 0
    else
      exec 9>&- 2>/dev/null || true
      return 1
    fi
  fi

  if command -v lockf >/dev/null 2>&1; then
    # macOS: lockf -t timeout -k file shell -c "..."
    # lockf はコマンドをラップする形式のため、FD ベースで使う
    # lockf -s -t N fd 形式でブロック待機
    exec 9>"${LOCK_FILE}"
    if lockf -s -t "${timeout}" 9; then
      _LOCK_ACQUIRED=2
      return 0
    else
      exec 9>&- 2>/dev/null || true
      return 1
    fi
  fi

  # フォールバック: mkdir による排他制御
  local waited=0
  while ! mkdir "${_LOCK_MUTEX_DIR}" 2>/dev/null; do
    sleep 0.2
    waited=$((waited + 1))
    if [ "${waited}" -ge $((timeout * 5)) ]; then
      return 1
    fi
  done
  _LOCK_ACQUIRED=3
  return 0
}

release_lock() {
  case "${_LOCK_ACQUIRED}" in
    1)
      # flock
      flock -u 9 2>/dev/null || true
      exec 9>&- 2>/dev/null || true
      ;;
    2)
      # lockf
      exec 9>&- 2>/dev/null || true
      ;;
    3)
      # mkdir フォールバック
      rmdir "${_LOCK_MUTEX_DIR}" 2>/dev/null || true
      ;;
  esac
  _LOCK_ACQUIRED=0
}

# ── メインロジック ─────────────────────────────────────────────────────────────
main() {
  mkdir -p "${LOCKS_DIR}"

  local timestamp
  timestamp="$(timestamp_iso8601)"

  local status="ok"
  local error_msg="null"

  # ── ロックを取得（タイムアウト CHECKPOINT_LOCK_TIMEOUT 秒） ──────────────
  if ! acquire_lock; then
    echo "[auto-checkpoint] ERROR: phase-b.lock の取得がタイムアウトしました (${CHECKPOINT_LOCK_TIMEOUT}s)" >&2
    # タイムアウトでも checkpoint-events.jsonl には失敗レコードを書く
    local timeout_record
    timeout_record="$(printf \
      '{"type":"checkpoint","status":"failed","task":"%s","commit":"%s","sprint_contract":"%s","review_result":"%s","timestamp":"%s","error":"lock_timeout"}' \
      "$(json_escape "${TASK_ID}")" \
      "$(json_escape "${COMMIT_HASH}")" \
      "$(json_escape "${SPRINT_CONTRACT_PATH}")" \
      "$(json_escape "${REVIEW_RESULT_PATH}")" \
      "${timestamp}")"
    append_jsonl "${CHECKPOINT_EVENTS_FILE}" "${timeout_record}"
    exit 1
  fi

  # ── ロック取得成功。EXIT 時に解放する ──────────────────────────────────────
  trap 'release_lock' EXIT

  # ── harness-mem API 呼び出し ──────────────────────────────────────────────
  local api_success=0
  local api_error=""

  if [ "${HARNESS_MEM_DISABLE}" = "1" ]; then
    api_success=0
    api_error="HARNESS_MEM_DISABLE=1"
  elif [ ! -x "${HARNESS_MEM_CLIENT}" ]; then
    api_success=0
    api_error="harness-mem-client not found or not executable: ${HARNESS_MEM_CLIENT}"
  else
    # session_id: 環境変数 CLAUDE_SESSION_ID から取得。なければ uuidgen
    local session_id
    session_id="${CLAUDE_SESSION_ID:-}"
    if [ -z "${session_id}" ]; then
      session_id="$(uuidgen 2>/dev/null \
        || cat /proc/sys/kernel/random/uuid 2>/dev/null \
        || printf 'fallback-%s' "${TASK_ID}")"
    fi

    # sprint_contract と review_result を読み込み
    local contract_content result_content
    contract_content="$(read_json_file "${SPRINT_CONTRACT_PATH}")"
    result_content="$(read_json_file "${REVIEW_RESULT_PATH}")"

    # content を JSON 文字列としてエスケープ
    local raw_content
    raw_content="$(printf '{"commit":"%s","sprint_contract":%s,"review_result":%s}' \
      "$(json_escape "${COMMIT_HASH}")" \
      "${contract_content}" \
      "${result_content}")"
    local content_escaped
    content_escaped="$(json_escape "${raw_content}")"

    # payload JSON を構築
    local payload
    payload="$(printf \
      '{"session_id":"%s","title":"Phase checkpoint: %s","content":"%s","platform":"claude-code","project":"claude-code-harness","tags":["checkpoint","phase-b","task:%s"]}' \
      "$(json_escape "${session_id}")" \
      "$(json_escape "${TASK_ID}")" \
      "${content_escaped}" \
      "$(json_escape "${TASK_ID}")")"

    # API 呼び出し
    local api_response=""
    if api_response="$("${HARNESS_MEM_CLIENT}" record-checkpoint "${payload}" 2>&1)"; then
      # ok フィールドが false でなければ成功扱い
      if grep -q '"ok":false' <<<"${api_response}"; then
        api_success=0
        api_error="$(printf '%s' "${api_response}" | grep -o '"error":"[^"]*"' | head -1 | sed 's/"error":"//;s/"//' || printf 'api_error')"
      else
        api_success=1
      fi
    else
      api_success=0
      api_error="${api_response:-api_call_failed}"
    fi
  fi

  # ── 失敗時: session-events.jsonl にデグレ出力 ────────────────────────────
  if [ "${api_success}" = "0" ]; then
    status="failed"
    error_msg="$(json_escape "${api_error}")"

    local session_event
    session_event="$(printf \
      '{"type":"checkpoint_failed","task":"%s","commit":"%s","timestamp":"%s","error":"%s"}' \
      "$(json_escape "${TASK_ID}")" \
      "$(json_escape "${COMMIT_HASH}")" \
      "${timestamp}" \
      "${error_msg}")"
    append_jsonl "${SESSION_EVENTS_FILE}" "${session_event}"

    echo "[auto-checkpoint] WARNING: harness-mem API 呼び出し失敗 — ${api_error}" >&2
  fi

  # ── 成功/失敗いずれでも checkpoint-events.jsonl に audit レコード追記 ─────
  local error_field
  if [ "${error_msg}" = "null" ]; then
    error_field="null"
  else
    error_field="\"${error_msg}\""
  fi

  local checkpoint_record
  checkpoint_record="$(printf \
    '{"type":"checkpoint","status":"%s","task":"%s","commit":"%s","sprint_contract":"%s","review_result":"%s","timestamp":"%s","error":%s}' \
    "${status}" \
    "$(json_escape "${TASK_ID}")" \
    "$(json_escape "${COMMIT_HASH}")" \
    "$(json_escape "${SPRINT_CONTRACT_PATH}")" \
    "$(json_escape "${REVIEW_RESULT_PATH}")" \
    "${timestamp}" \
    "${error_field}")"
  append_jsonl "${CHECKPOINT_EVENTS_FILE}" "${checkpoint_record}"

  if [ "${status}" = "failed" ]; then
    exit 1
  fi

  echo "[auto-checkpoint] OK: task=${TASK_ID} commit=${COMMIT_HASH}" >&2
  exit 0
}

main "$@"
