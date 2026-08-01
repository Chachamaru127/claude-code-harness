#!/usr/bin/env bash
# permission-denied-handler.sh
# PermissionDenied hook handler (v2.1.89+)
#
# auto mode classifier がコマンドを拒否した際に発火。
# 拒否イベントを telemetry に記録し、Breezing モードでは Lead への通知を含む。
# {retry: true} を返すことで、モデルにリトライ可能であることを伝えられる。
#
# Input:  stdin (JSON: { tool, input, denied_reason, session_id, agent_id, ... })
# Output: JSON (systemMessage for awareness, optional retry hint)
# Hook event: PermissionDenied

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# path-utils.sh の読み込み
if [ -f "${PARENT_DIR}/path-utils.sh" ]; then
  source "${PARENT_DIR}/path-utils.sh"
fi

# プロジェクトルートを検出
if declare -F detect_project_root > /dev/null 2>&1; then
  PROJECT_ROOT="${PROJECT_ROOT:-$(detect_project_root 2>/dev/null || pwd)}"
else
  PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
fi

# ステートディレクトリ（CLAUDE_PLUGIN_DATA 使用時はプロジェクト別にスコープ）
if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
  _project_hash="$(printf '%s' "${PROJECT_ROOT}" | { shasum -a 256 2>/dev/null || sha256sum 2>/dev/null || echo "default  -"; } | cut -c1-12)"
  [ -z "${_project_hash}" ] && _project_hash="default"
  STATE_DIR="${CLAUDE_PLUGIN_DATA}/projects/${_project_hash}"
else
  STATE_DIR="${PROJECT_ROOT}/.claude/state"
fi
LOG_FILE="${STATE_DIR}/permission-denied.jsonl"

# === ユーティリティ関数 ===

ensure_state_dir() {
  local state_parent
  state_parent="$(dirname "${STATE_DIR}")"

  # Security: refuse symlinked state paths
  if [ -L "${state_parent}" ] || [ -L "${STATE_DIR}" ]; then
    return 1
  fi

  mkdir -p "${STATE_DIR}" 2>/dev/null || true
  chmod 700 "${STATE_DIR}" 2>/dev/null || true

  [ -d "${STATE_DIR}" ] || return 1
  [ ! -L "${STATE_DIR}" ] || return 1
  return 0
}

# JSONL ローテーション（500 行超過時に 400 行に切り詰め）
rotate_jsonl() {
  local file="$1"

  # Security: refuse symlinked log or tmp files
  if [ -L "${file}" ] || [ -L "${file}.tmp" ]; then
    return 1
  fi

  local _lines
  _lines="$(wc -l < "${file}" 2>/dev/null)" || _lines=0
  if [ "${_lines}" -gt 500 ] 2>/dev/null; then
    tail -400 "${file}" > "${file}.tmp" 2>/dev/null && \
      mv "${file}.tmp" "${file}" 2>/dev/null || true
  fi
}

# === stdin から入力を読み取り ===
INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)" || true
fi

# ペイロードが空の場合はスキップ
if [ -z "${INPUT}" ]; then
  exit 0
fi

# === ステートディレクトリの確保 ===
if ! ensure_state_dir; then
  exit 0
fi

# === 拒否情報を抽出 ===
TOOL_NAME="unknown"
DENIED_REASON="unknown"
SESSION_ID="unknown"
AGENT_ID="unknown"
AGENT_TYPE="unknown"

if command -v jq > /dev/null 2>&1; then
  TOOL_NAME="$(printf '%s' "${INPUT}" | jq -r '.tool // .tool_name // "unknown"' 2>/dev/null || echo "unknown")"
  DENIED_REASON="$(printf '%s' "${INPUT}" | jq -r '.denied_reason // .reason // "unknown"' 2>/dev/null || echo "unknown")"
  SESSION_ID="$(printf '%s' "${INPUT}" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")"
  AGENT_ID="$(printf '%s' "${INPUT}" | jq -r '.agent_id // "unknown"' 2>/dev/null || echo "unknown")"
  AGENT_TYPE="$(printf '%s' "${INPUT}" | jq -r '.agent_type // "unknown"' 2>/dev/null || echo "unknown")"
elif command -v python3 > /dev/null 2>&1; then
  _parsed="$(printf '%s' "${INPUT}" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool', d.get('tool_name', 'unknown')))
    print(d.get('denied_reason', d.get('reason', 'unknown')))
    print(d.get('session_id', 'unknown'))
    print(d.get('agent_id', 'unknown'))
    print(d.get('agent_type', 'unknown'))
except:
    for _ in range(5): print('unknown')
" 2>/dev/null)" || _parsed=""
  if [ -n "${_parsed}" ]; then
    TOOL_NAME="$(echo "${_parsed}" | sed -n '1p')"
    DENIED_REASON="$(echo "${_parsed}" | sed -n '2p')"
    SESSION_ID="$(echo "${_parsed}" | sed -n '3p')"
    AGENT_ID="$(echo "${_parsed}" | sed -n '4p')"
    AGENT_TYPE="$(echo "${_parsed}" | sed -n '5p')"
  fi
fi

TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ")"

# === JSONL にログ記録 ===
log_entry=""
if command -v jq > /dev/null 2>&1; then
  log_entry="$(jq -nc \
    --arg event "permission_denied" \
    --arg timestamp "${TIMESTAMP}" \
    --arg session_id "${SESSION_ID}" \
    --arg agent_id "${AGENT_ID}" \
    --arg agent_type "${AGENT_TYPE}" \
    --arg tool "${TOOL_NAME}" \
    --arg reason "${DENIED_REASON}" \
    '{event:$event, timestamp:$timestamp, session_id:$session_id, agent_id:$agent_id, agent_type:$agent_type, tool:$tool, reason:$reason}')"
elif command -v python3 > /dev/null 2>&1; then
  log_entry="$(python3 -c "
import json, sys
print(json.dumps({
    'event': 'permission_denied',
    'timestamp': sys.argv[1],
    'session_id': sys.argv[2],
    'agent_id': sys.argv[3],
    'agent_type': sys.argv[4],
    'tool': sys.argv[5],
    'reason': sys.argv[6]
}, ensure_ascii=False))
" "${TIMESTAMP}" "${SESSION_ID}" "${AGENT_ID}" "${AGENT_TYPE}" "${TOOL_NAME}" "${DENIED_REASON}" 2>/dev/null)" || log_entry=""
fi

if [ -n "${log_entry}" ]; then
  # Security: refuse symlinked log file
  if [ -L "${LOG_FILE}" ]; then
    exit 0
  fi
  echo "${log_entry}" >> "${LOG_FILE}" 2>/dev/null || true
  rotate_jsonl "${LOG_FILE}"
fi

# === Breezing Worker の場合: Lead への通知 + retry 指示 ===
# Worker が拒否された場合、Lead に状況を伝えて代替手段を検討させる
# retry: true を返すことで、モデルがリトライ可能であることを伝える
_notification_text="[PermissionDenied] Worker のツール ${TOOL_NAME} が auto mode で拒否されました。理由: ${DENIED_REASON}。代替アプローチを検討するか、必要なら手動承認してください。"
_is_worker=false
if [ "${AGENT_TYPE}" = "worker" ] || [ "${AGENT_TYPE}" = "task-worker" ] || grep -qE ':worker$' <<<"${AGENT_TYPE}"; then
  _is_worker=true

  # broadcast ファイルに書き込み（Lead セッションが読み取れるように）
  _broadcast_script="${SCRIPT_DIR}/../session-broadcast.sh"
  if [ -f "${_broadcast_script}" ]; then
    bash "${_broadcast_script}" "${_notification_text}" >/dev/null 2>&1 || true
  fi

  # retry: true + systemMessage を返す
  if command -v jq > /dev/null 2>&1; then
    jq -nc \
      --arg msg "${_notification_text}" \
      '{"retry": true, "systemMessage": $msg}'
  else
    echo "{\"retry\": true, \"systemMessage\": \"${_notification_text//\"/\\\"}\"}"
  fi
fi

# Worker 以外の場合はそのまま通過（retry しない — ユーザーに判断を委ねる）
if [ "${_is_worker}" = "false" ]; then
  echo '{"decision":"approve","reason":"PermissionDenied logged"}'
fi

# stderr にも出力（デバッグ用）
echo "[PermissionDenied] agent=${AGENT_ID} type=${AGENT_TYPE} tool=${TOOL_NAME} reason=${DENIED_REASON}" >&2

exit 0
