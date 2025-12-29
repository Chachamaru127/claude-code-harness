#!/bin/bash

# Cursor × Claude-mem 記録検証スクリプト
# 使用例: ./verify-records.sh "テストメッセージ"

set -e

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

DB_PATH="${CLAUDE_MEM_DB:-$HOME/.claude-mem/claude-mem.db}"

# ヘルプメッセージ
function show_help() {
  cat << EOF
Cursor × Claude-mem 記録検証スクリプト

使用方法:
  $0 [オプション] [検索クエリ]

オプション:
  -h, --help              このヘルプを表示
  -t, --tool TOOL_NAME    ツール名で検索 (UserPrompt, Edit, SessionStop)
  -p, --project PROJECT   プロジェクト名でフィルタ
  -n, --limit N           結果の最大件数 (デフォルト: 10)
  -v, --verbose           詳細モード
  --stats                 統計情報を表示
  --recent                最近の記録を表示（デフォルト: 10件）

例:
  # クエリで検索
  $0 "テストメッセージ"

  # ツール名で検索
  $0 --tool UserPrompt

  # プロジェクト名でフィルタ
  $0 --project claude-code-harness

  # 最近の記録を表示
  $0 --recent

  # 統計情報を表示
  $0 --stats

EOF
}

# データベース存在チェック
function check_db() {
  if [ ! -f "$DB_PATH" ]; then
    echo -e "${RED}❌ データベースが見つかりません: $DB_PATH${NC}"
    echo "claude-mem がインストールされているか確認してください。"
    exit 1
  fi
}

# Worker 起動確認
function check_worker() {
  local port="${CLAUDE_MEM_WORKER_PORT:-37777}"
  if ! curl -s "http://127.0.0.1:${port}/health" > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Worker が起動していません${NC}"
    echo "  起動: claude-mem restart"
    return 1
  fi
  echo -e "${GREEN}✓ Worker 起動中${NC}"
  return 0
}

# 統計情報表示
function show_stats() {
  echo -e "${BLUE}=== Claude-mem 統計情報 ===${NC}"
  echo ""

  # 総記録数
  local total=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM observations;")
  echo -e "総記録数: ${GREEN}$total${NC}"

  # ツール別集計
  echo -e "\n${BLUE}ツール別:${NC}"
  sqlite3 "$DB_PATH" \
    "SELECT tool_name, COUNT(*) as count FROM observations
     GROUP BY tool_name
     ORDER BY count DESC;" | \
    while IFS='|' read -r tool count; do
      echo "  - $tool: $count"
    done

  # プロジェクト別集計
  echo -e "\n${BLUE}プロジェクト別:${NC}"
  sqlite3 "$DB_PATH" \
    "SELECT project, COUNT(*) as count FROM observations
     GROUP BY project
     ORDER BY count DESC
     LIMIT 5;" | \
    while IFS='|' read -r project count; do
      echo "  - $project: $count"
    done

  # 最新記録
  echo -e "\n${BLUE}最新記録:${NC}"
  local latest=$(sqlite3 "$DB_PATH" \
    "SELECT datetime(created_at / 1000, 'unixepoch', 'localtime')
     FROM observations
     ORDER BY created_at DESC LIMIT 1;")
  echo "  $latest"
}

# 最近の記録を表示
function show_recent() {
  local limit="${1:-10}"
  echo -e "${BLUE}=== 最近の記録 (${limit}件) ===${NC}"
  echo ""

  sqlite3 -header -column "$DB_PATH" \
    "SELECT
       id,
       tool_name as tool,
       substr(title, 1, 40) as title,
       project,
       datetime(created_at / 1000, 'unixepoch', 'localtime') as created
     FROM observations
     ORDER BY created_at DESC
     LIMIT $limit;"
}

# クエリで検索
function search_by_query() {
  local query="$1"
  local limit="${2:-10}"
  local project="$3"

  echo -e "${BLUE}=== 検索: \"$query\" ===${NC}"
  echo ""

  local where_clause="WHERE (title LIKE '%$query%' OR subtitle LIKE '%$query%')"
  if [ -n "$project" ]; then
    where_clause="$where_clause AND project = '$project'"
  fi

  local count=$(sqlite3 "$DB_PATH" \
    "SELECT COUNT(*) FROM observations $where_clause;")

  if [ "$count" -eq 0 ]; then
    echo -e "${YELLOW}検索結果なし${NC}"
    return 1
  fi

  echo -e "${GREEN}$count 件見つかりました${NC}\n"

  sqlite3 -header -column "$DB_PATH" \
    "SELECT
       id,
       tool_name as tool,
       substr(title, 1, 40) as title,
       project,
       datetime(created_at / 1000, 'unixepoch', 'localtime') as created
     FROM observations
     $where_clause
     ORDER BY created_at DESC
     LIMIT $limit;"
}

# ツール名で検索
function search_by_tool() {
  local tool_name="$1"
  local limit="${2:-10}"
  local project="$3"

  echo -e "${BLUE}=== ツール: $tool_name ===${NC}"
  echo ""

  local where_clause="WHERE tool_name = '$tool_name'"
  if [ -n "$project" ]; then
    where_clause="$where_clause AND project = '$project'"
  fi

  local count=$(sqlite3 "$DB_PATH" \
    "SELECT COUNT(*) FROM observations $where_clause;")

  if [ "$count" -eq 0 ]; then
    echo -e "${YELLOW}記録なし${NC}"
    return 1
  fi

  echo -e "${GREEN}$count 件見つかりました${NC}\n"

  sqlite3 -header -column "$DB_PATH" \
    "SELECT
       id,
       substr(title, 1, 40) as title,
       project,
       datetime(created_at / 1000, 'unixepoch', 'localtime') as created
     FROM observations
     $where_clause
     ORDER BY created_at DESC
     LIMIT $limit;"
}

# 詳細表示
function show_detail() {
  local id="$1"

  echo -e "${BLUE}=== 記録詳細 (ID: $id) ===${NC}"
  echo ""

  local exists=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM observations WHERE id = $id;")
  if [ "$exists" -eq 0 ]; then
    echo -e "${RED}❌ ID $id の記録が見つかりません${NC}"
    return 1
  fi

  sqlite3 "$DB_PATH" \
    "SELECT
       'ID: ' || id || '\n' ||
       'Tool: ' || tool_name || '\n' ||
       'Title: ' || title || '\n' ||
       'Project: ' || project || '\n' ||
       'Created: ' || datetime(created_at / 1000, 'unixepoch', 'localtime') || '\n' ||
       'Input: ' || tool_input || '\n' ||
       'Response: ' || COALESCE(tool_response, 'null')
     FROM observations
     WHERE id = $id;"
}

# メイン処理
function main() {
  local mode="query"
  local query=""
  local tool_name=""
  local project=""
  local limit=10
  local verbose=false

  # パラメータ解析
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        show_help
        exit 0
        ;;
      -t|--tool)
        mode="tool"
        tool_name="$2"
        shift 2
        ;;
      -p|--project)
        project="$2"
        shift 2
        ;;
      -n|--limit)
        limit="$2"
        shift 2
        ;;
      -v|--verbose)
        verbose=true
        shift
        ;;
      --stats)
        mode="stats"
        shift
        ;;
      --recent)
        mode="recent"
        shift
        ;;
      --detail)
        mode="detail"
        query="$2"
        shift 2
        ;;
      -*)
        echo -e "${RED}不明なオプション: $1${NC}"
        show_help
        exit 1
        ;;
      *)
        query="$1"
        shift
        ;;
    esac
  done

  # データベースチェック
  check_db

  # Worker チェック (verbose モードのみ)
  if [ "$verbose" = true ]; then
    check_worker
    echo ""
  fi

  # モード別実行
  case "$mode" in
    stats)
      show_stats
      ;;
    recent)
      show_recent "$limit"
      ;;
    tool)
      search_by_tool "$tool_name" "$limit" "$project"
      ;;
    detail)
      show_detail "$query"
      ;;
    query)
      if [ -z "$query" ]; then
        echo -e "${RED}検索クエリを指定してください${NC}"
        echo ""
        show_help
        exit 1
      fi
      search_by_query "$query" "$limit" "$project"
      ;;
  esac
}

# スクリプト実行
main "$@"
