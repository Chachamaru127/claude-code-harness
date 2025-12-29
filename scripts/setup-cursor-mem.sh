#!/bin/bash

# Cursor × Claude-mem セットアップスクリプト
# 使用例: ./scripts/setup-cursor-mem.sh [--global|--local] [--skip-test] [--force]

set -e

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# オプション
MCP_SCOPE=""
SKIP_TEST=false
FORCE=false

# パース
while [[ $# -gt 0 ]]; do
  case "$1" in
    --global)
      MCP_SCOPE="global"
      shift
      ;;
    --local)
      MCP_SCOPE="local"
      shift
      ;;
    --skip-test)
      SKIP_TEST=true
      shift
      ;;
    --force)
      FORCE=true
      shift
      ;;
    -h|--help)
      cat << EOF
Cursor × Claude-mem セットアップスクリプト

使用方法:
  $0 [オプション]

オプション:
  --global       グローバル設定を使用（全プロジェクトで有効）
  --local        プロジェクトローカル設定を使用（このプロジェクトのみ）
  --skip-test    テストをスキップ
  --force        既存ファイルを上書き
  -h, --help     このヘルプを表示

例:
  $0                  # 対話的にスコープを選択
  $0 --global         # グローバル設定で実行
  $0 --local --force  # ローカル設定、既存ファイルを上書き

EOF
      exit 0
      ;;
    *)
      echo -e "${RED}不明なオプション: $1${NC}"
      exit 1
      ;;
  esac
done

echo -e "${CYAN}🚀 Cursor × Claude-mem セットアップを開始...${NC}"
echo ""

# Step 1: Worker 起動確認
echo -e "${BLUE}1️⃣ Worker 起動確認...${NC}"
WORKER_PORT="${CLAUDE_MEM_WORKER_PORT:-37777}"
WORKER_HOST="${CLAUDE_MEM_WORKER_HOST:-127.0.0.1}"

if ! curl -s "http://${WORKER_HOST}:${WORKER_PORT}/health" > /dev/null 2>&1; then
  echo -e "${RED}❌ Worker が起動していません${NC}"
  echo "   以下のコマンドで Worker を起動してください:"
  echo ""
  echo -e "   ${CYAN}claude-mem restart${NC}"
  echo ""
  exit 1
fi
echo -e "${GREEN}✅ Worker 起動中${NC}"
echo ""

# Step 2: MCP 設定スコープの確認と選択
echo -e "${BLUE}2️⃣ MCP 設定スコープの確認...${NC}"

GLOBAL_MCP="$HOME/.cursor/mcp.json"
LOCAL_MCP=".cursor/mcp.json"

# 既存設定の確認
if [ -z "$MCP_SCOPE" ]; then
  if [ -f "$GLOBAL_MCP" ] && grep -q "claude-mem" "$GLOBAL_MCP" 2>/dev/null; then
    echo -e "${GREEN}✅ グローバル MCP 設定済み${NC}"
    MCP_SCOPE="global"
  elif [ -f "$LOCAL_MCP" ] && grep -q "claude-mem" "$LOCAL_MCP" 2>/dev/null; then
    echo -e "${GREEN}✅ プロジェクトローカル MCP 設定済み${NC}"
    MCP_SCOPE="local"
  else
    # 未設定の場合、ユーザーに選択を促す
    echo ""
    echo -e "${YELLOW}📋 MCP 設定スコープを選択してください:${NC}"
    echo ""
    echo -e "${CYAN}1. グローバル設定${NC} (~/.cursor/mcp.json) - ${GREEN}推奨${NC}"
    echo "   すべてのプロジェクトで claude-mem が利用可能"
    echo ""
    echo -e "${CYAN}2. プロジェクトローカル設定${NC} (.cursor/mcp.json)"
    echo "   このプロジェクトのみで claude-mem を使用"
    echo ""

    read -p "選択 (1 or 2, デフォルト: 1): " choice
    case "$choice" in
      2)
        MCP_SCOPE="local"
        echo -e "${CYAN}選択: プロジェクトローカル設定${NC}"
        ;;
      *)
        MCP_SCOPE="global"
        echo -e "${CYAN}選択: グローバル設定${NC}"
        ;;
    esac
    echo ""

    # MCP 設定の追加
    echo -e "${BLUE}MCP 設定を追加中...${NC}"

    # claude-mem-mcp スクリプトのパスを取得
    SCRIPT_PATH=$(find ~/.claude/plugins/cache -name "claude-mem-mcp" -type f 2>/dev/null | grep claude-code-harness | head -1)

    if [ -z "$SCRIPT_PATH" ]; then
      echo -e "${RED}❌ claude-mem-mcp スクリプトが見つかりません${NC}"
      echo "   claude-code-harness プラグインがインストールされているか確認してください"
      exit 1
    fi

    MCP_CONFIG=$(cat <<EOF
  "claude-mem": {
    "type": "stdio",
    "command": "$SCRIPT_PATH",
    "cwd": "\${workspaceFolder}",
    "env": {
      "CLAUDE_MEM_PROJECT_CWD": "\${workspaceFolder}"
    }
  }
EOF
)

    if [ "$MCP_SCOPE" = "global" ]; then
      TARGET_FILE="$GLOBAL_MCP"
      mkdir -p "$HOME/.cursor"
    else
      TARGET_FILE="$LOCAL_MCP"
      mkdir -p .cursor
    fi

    # JSON に追加
    if [ -f "$TARGET_FILE" ]; then
      # 既存ファイルがある場合
      if grep -q "mcpServers" "$TARGET_FILE"; then
        # mcpServers が既にある場合、手動追加を促す
        echo -e "${YELLOW}⚠️  既存の MCP 設定ファイルがあります: $TARGET_FILE${NC}"
        echo ""
        echo "以下を手動で追加してください:"
        echo ""
        echo "$MCP_CONFIG"
        echo ""
        echo "追加後、このスクリプトを再実行してください。"
        exit 0
      else
        # mcpServers がない場合、新規作成
        echo '{' > "$TARGET_FILE"
        echo '  "mcpServers": {' >> "$TARGET_FILE"
        echo "$MCP_CONFIG" >> "$TARGET_FILE"
        echo '  }' >> "$TARGET_FILE"
        echo '}' >> "$TARGET_FILE"
      fi
    else
      # 新規作成
      cat > "$TARGET_FILE" <<EOF
{
  "mcpServers": {
$MCP_CONFIG
  }
}
EOF
    fi

    echo -e "${GREEN}✅ MCP 設定を追加しました: $TARGET_FILE${NC}"
  fi
else
  echo -e "${CYAN}MCP スコープ: $MCP_SCOPE${NC}"
fi
echo ""

# Step 3: hooks.json 生成
echo -e "${BLUE}3️⃣ hooks.json 生成...${NC}"
if [ ! -f ".cursor/hooks.json" ] || [ "$FORCE" = true ]; then
  if [ ! -f ".cursor/hooks.json.example" ]; then
    echo -e "${RED}❌ .cursor/hooks.json.example が見つかりません${NC}"
    echo "   プロジェクトルートで実行していることを確認してください"
    exit 1
  fi

  mkdir -p .cursor
  cp .cursor/hooks.json.example .cursor/hooks.json
  echo -e "${GREEN}✅ hooks.json を生成しました${NC}"
else
  echo -e "${YELLOW}⚠️  hooks.json は既に存在します（スキップ）${NC}"
  echo "   上書きする場合は --force オプションを使用してください"
fi
echo ""

# Step 4: .cursorrules 生成
echo -e "${BLUE}4️⃣ .cursorrules 生成...${NC}"
if [ ! -f ".cursorrules" ] || [ "$FORCE" = true ]; then
  if [ ! -f ".cursorrules.example" ]; then
    echo -e "${RED}❌ .cursorrules.example が見つかりません${NC}"
    exit 1
  fi

  cp .cursorrules.example .cursorrules
  echo -e "${GREEN}✅ .cursorrules を生成しました${NC}"
else
  echo -e "${YELLOW}⚠️  .cursorrules は既に存在します（スキップ）${NC}"
  echo "   上書きする場合は --force オプションを使用してください"
fi
echo ""

# Step 5: 簡易テスト
if [ "$SKIP_TEST" = false ]; then
  echo -e "${BLUE}5️⃣ 簡易テスト実行...${NC}"

  # Worker API にテスト記録を送信
  TEST_SESSION_ID="test-$(date +%s)"
  TEST_RESULT=$(curl -s -X POST "http://${WORKER_HOST}:${WORKER_PORT}/api/sessions/observations" \
    -H "Content-Type: application/json" \
    -d "{
      \"claudeSessionId\": \"$TEST_SESSION_ID\",
      \"tool_name\": \"SetupTest\",
      \"tool_input\": \"Cursor setup test\",
      \"tool_response\": \"Success\",
      \"cwd\": \"$(pwd)\"
    }" 2>&1)

  if echo "$TEST_RESULT" | grep -q "error"; then
    echo -e "${RED}❌ テスト失敗${NC}"
    echo "エラー: $TEST_RESULT"
    exit 1
  fi

  echo -e "${GREEN}✅ テスト成功${NC}"
else
  echo -e "${YELLOW}⚠️  テストをスキップしました${NC}"
fi
echo ""

# Step 6: 成功メッセージ
echo -e "${GREEN}🎉 セットアップ完了！${NC}"
echo ""
echo -e "${CYAN}次のステップ:${NC}"
echo ""
echo "1. ${BLUE}Cursor を再起動してください${NC}"
echo "   フックと MCP サーバーを有効化するために必要です"
echo ""
echo "2. ${BLUE}動作確認${NC}"
echo "   - Cursor でプロンプトを送信してみてください"
echo "   - ファイルを編集してみてください"
echo ""
echo "3. ${BLUE}記録の確認${NC}"
echo "   以下のコマンドで記録を確認できます:"
echo ""
echo -e "   ${CYAN}sqlite3 ~/.claude-mem/claude-mem.db \\${NC}"
echo -e "   ${CYAN}  \"SELECT tool_name, title FROM observations ORDER BY created_at DESC LIMIT 5;\"${NC}"
echo ""
echo "   または検証スクリプトを使用:"
echo ""
echo -e "   ${CYAN}./tests/cursor-mem/verify-records.sh --recent${NC}"
echo ""
echo -e "${BLUE}詳細なドキュメント:${NC} docs/guides/cursor-mem-integration.md"
echo ""
