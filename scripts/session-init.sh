#!/bin/bash
# session-init.sh
# SessionStart Hook: セッション開始時の初期化処理
#
# 機能:
# - Plans.md の存在確認と表示
# - プロジェクト状態の簡易チェック
# - 環境変数の設定（CLAUDE_ENV_FILE経由）

set -e

# カラー定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}📋 claude-code-harness: セッション初期化${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Plans.md チェック
if [ -f "Plans.md" ]; then
  # 進行中タスク数をカウント
  wip_count=$(grep -c "cc:WIP\|pm:依頼中\|cursor:依頼中" Plans.md 2>/dev/null || echo "0")
  todo_count=$(grep -c "cc:TODO" Plans.md 2>/dev/null || echo "0")

  echo -e "📄 Plans.md: ${GREEN}検出${NC}"
  echo "   - 進行中タスク: ${wip_count}"
  echo "   - 未着手タスク: ${todo_count}"

  # 進行中タスクがあれば表示
  if [ "$wip_count" -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}⚡ 進行中のタスク:${NC}"
    grep -B1 "cc:WIP\|pm:依頼中\|cursor:依頼中" Plans.md 2>/dev/null | grep -v "^--$" | head -10 || true
  fi
else
  echo -e "📄 Plans.md: ${YELLOW}未検出${NC}"
  echo "   /harness-init でセットアップしてください"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 常に成功で終了
exit 0
