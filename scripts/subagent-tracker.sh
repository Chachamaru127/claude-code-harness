#!/usr/bin/env bash
# subagent-tracker.sh
# Claude Code 2.1.0 SubagentStart/SubagentStop フック用トラッカー
#
# 使用方法:
#   ./subagent-tracker.sh start   # サブエージェント開始時
#   ./subagent-tracker.sh stop    # サブエージェント終了時
#
# 環境変数（SubagentStop時に利用可能）:
#   AGENT_ID              - サブエージェントの識別子
#   AGENT_TRANSCRIPT_PATH - トランスクリプトファイルのパス

set -euo pipefail

# === 設定 ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/path-utils.sh" 2>/dev/null || true

# プロジェクトルートを検出
PROJECT_ROOT="${PROJECT_ROOT:-$(detect_project_root 2>/dev/null || pwd)}"

# ログディレクトリ
LOG_DIR="${PROJECT_ROOT}/.claude/logs"
SUBAGENT_LOG="${LOG_DIR}/subagent-history.jsonl"

# === ユーティリティ関数 ===

ensure_log_dir() {
  mkdir -p "${LOG_DIR}" 2>/dev/null || true
}

get_timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# === メイン処理 ===

action="${1:-}"

case "${action}" in
  start)
    ensure_log_dir

    # 環境変数から情報を取得（利用可能な場合）
    agent_id="${AGENT_ID:-unknown}"

    # ログエントリを作成
    log_entry=$(cat <<EOF
{"event":"subagent_start","timestamp":"$(get_timestamp)","agent_id":"${agent_id}"}
EOF
)

    # JSONL形式で追記
    echo "${log_entry}" >> "${SUBAGENT_LOG}" 2>/dev/null || true

    # 成功レスポンス（フックが期待するJSON形式）
    echo '{"decision":"approve","reason":"Subagent start tracked"}'
    ;;

  stop)
    ensure_log_dir

    # 環境変数から情報を取得
    agent_id="${AGENT_ID:-unknown}"
    transcript_path="${AGENT_TRANSCRIPT_PATH:-}"

    # トランスクリプトのサマリーを取得（存在する場合）
    transcript_summary=""
    if [[ -n "${transcript_path}" && -f "${transcript_path}" ]]; then
      # 最後の50行を取得してサマリー化
      transcript_summary=$(tail -50 "${transcript_path}" 2>/dev/null | head -c 500 || echo "")
      transcript_summary="${transcript_summary//\"/\\\"}"  # エスケープ
      transcript_summary="${transcript_summary//$'\n'/\\n}"  # 改行をエスケープ
    fi

    # ログエントリを作成
    log_entry=$(cat <<EOF
{"event":"subagent_stop","timestamp":"$(get_timestamp)","agent_id":"${agent_id}","transcript_path":"${transcript_path}","transcript_preview":"${transcript_summary:0:200}"}
EOF
)

    # JSONL形式で追記
    echo "${log_entry}" >> "${SUBAGENT_LOG}" 2>/dev/null || true

    # 成功レスポンス
    echo '{"decision":"approve","reason":"Subagent stop tracked"}'
    ;;

  *)
    echo '{"decision":"approve","reason":"Unknown action, skipping"}'
    ;;
esac

exit 0
