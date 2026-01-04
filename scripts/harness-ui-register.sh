#!/bin/bash
# harness-ui-register.sh
# SessionStart Hook: harness-ui にプロジェクトを自動登録
#
# 機能:
# - ハーネス初期化済みプロジェクトのみを harness-ui API に登録
# - harness-ui が起動していない場合は静かにスキップ
# - 非ハーネスプロジェクトは登録しない
#
# 環境変数:
# - HARNESS_UI_PORT: harness-ui のポート（デフォルト: 37778）

set -uo pipefail

# 設定
HARNESS_UI_PORT="${HARNESS_UI_PORT:-37778}"
HARNESS_UI_URL="http://localhost:${HARNESS_UI_PORT}"
API_ENDPOINT="${HARNESS_UI_URL}/api/projects"

# プロジェクトパス（現在のディレクトリ）
PROJECT_PATH="$(pwd)"
PROJECT_NAME="$(basename "$PROJECT_PATH")"

# フォーマット状態を保持するグローバル変数
FORMAT_STATUS=""
FORMAT_WARNING=""

# ハーネス初期化済みかチェック
# 条件: .claude-code-harness-version が存在（/harness-init で作成される公式マーカー）
#       または Plans.md にハーネス固有マーカーが含まれる（旧フォーマット含む）
is_harness_project() {
  FORMAT_STATUS="ok"
  FORMAT_WARNING=""

  # 公式マーカーファイル（最も信頼性が高い）
  if [ -f ".claude-code-harness-version" ]; then
    check_plans_format
    return 0
  fi

  # Plans.md のハーネス固有マーカーをチェック
  if [ -f "Plans.md" ]; then
    # 新フォーマット: cc:TODO, cc:WIP, cc:DONE, pm:依頼中 など
    if grep -qE "cc:(TODO|WIP|WORK|DONE|完了|blocked)|pm:(依頼中|確認済)|cursor:(依頼中|確認済)" "Plans.md" 2>/dev/null; then
      check_plans_format
      return 0
    fi
    # 旧フォーマット: cursor:WIP, cursor:完了（互換性のため登録は許可、警告表示）
    if grep -qE "cursor:(WIP|完了)" "Plans.md" 2>/dev/null; then
      FORMAT_STATUS="migration_needed"
      FORMAT_WARNING="Plans.md に旧フォーマット(cursor:WIP/完了)を検出。文脈に応じて cc:WIP/cc:完了 または pm:依頼中/pm:確認済 への移行を検討してください。"
      return 0
    fi
  fi

  return 1
}

# Plans.md フォーマットチェック（詳細）
check_plans_format() {
  if [ ! -f "Plans.md" ]; then
    return
  fi
  # 旧フォーマットマーカーの検出
  if grep -qE "cursor:(WIP|完了)" "Plans.md" 2>/dev/null; then
    FORMAT_STATUS="migration_needed"
    FORMAT_WARNING="Plans.md に旧フォーマット(cursor:WIP/完了)を検出。pm:依頼中/pm:確認済 への移行を推奨。"
  fi
}

# harness-ui が起動しているかチェック（タイムアウト 1 秒）
check_harness_ui() {
  curl -s --connect-timeout 1 --max-time 2 "${HARNESS_UI_URL}/api/status" >/dev/null 2>&1
}

# プロジェクトを登録
register_project() {
  local response
  response=$(curl -s --connect-timeout 2 --max-time 5 \
    -X POST \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"${PROJECT_NAME}\", \"path\": \"${PROJECT_PATH}\"}" \
    "${API_ENDPOINT}" 2>/dev/null)

  echo "$response"
}

# メイン処理
main() {
  # ハーネス初期化済みプロジェクトでない場合はスキップ
  if ! is_harness_project; then
    # 静かに終了（非ハーネスプロジェクトは対象外）
    cat <<EOF
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":""}}
EOF
    exit 0
  fi

  # harness-ui が起動していない場合はスキップ
  if ! check_harness_ui; then
    # 静かに終了（エラーではない）
    cat <<EOF
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":""}}
EOF
    exit 0
  fi

  # プロジェクトを登録
  local result
  result=$(register_project)

  # レスポンスをパース
  local project_id=""
  local project_name=""
  local message=""

  if command -v jq >/dev/null 2>&1; then
    # 成功した場合
    if echo "$result" | jq -e '.project' >/dev/null 2>&1; then
      project_name=$(echo "$result" | jq -r '.project.name // empty')
      message="[harness-ui] プロジェクト登録: ${project_name}"
    # 既に存在する場合（409 Conflict）
    elif echo "$result" | jq -e '.error' >/dev/null 2>&1; then
      # 既存プロジェクトはエラーではない（lastAccessedAt を更新するため GET→PUT）
      # 簡略化のため、ここでは登録成功として扱う
      message=""
    fi
  fi

  # 出力メッセージの構築（メッセージがある場合のみ）
  local output=""
  if [ -n "$message" ]; then
    output="$message"
  fi
  # フォーマット警告を追加
  if [ -n "$FORMAT_WARNING" ]; then
    if [ -n "$output" ]; then
      output="${output}\n${FORMAT_WARNING}"
    else
      output="$FORMAT_WARNING"
    fi
  fi

  # JSON エスケープ
  escape_json() {
    local str="$1"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    echo "$str"
  }

  local escaped_output
  escaped_output=$(escape_json "$output")

  cat <<EOF
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"${escaped_output}"}}
EOF
}

main "$@"
