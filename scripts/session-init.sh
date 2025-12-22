#!/bin/bash
# session-init.sh
# SessionStart Hook: セッション開始時の初期化処理
#
# 機能:
# 1. プラグインキャッシュの整合性チェックと同期
# 2. Skills Gate の初期化
# 3. Plans.md の状態表示

set -e

# カラー定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# スクリプトディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 注意: Claude Code はフックの stderr のみを表示するため、出力は stderr に
echo -e "${GREEN}📋 claude-code-harness: セッション初期化${NC}" >&2
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2

# ===== Step 1: プラグインキャッシュ同期 =====
if [ -f "$SCRIPT_DIR/sync-plugin-cache.sh" ]; then
  bash "$SCRIPT_DIR/sync-plugin-cache.sh" >&2
fi

# ===== Step 2: Skills Gate 初期化 =====
STATE_DIR=".claude/state"
SKILLS_CONFIG_FILE="${STATE_DIR}/skills-config.json"
SESSION_SKILLS_USED_FILE="${STATE_DIR}/session-skills-used.json"

mkdir -p "$STATE_DIR"

# session-skills-used.json をリセット（新セッション開始）
echo '{"used": [], "session_start": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' > "$SESSION_SKILLS_USED_FILE"

# skills-config.json の読み込みと表示
if [ -f "$SKILLS_CONFIG_FILE" ]; then
  if command -v jq >/dev/null 2>&1; then
    SKILLS_ENABLED=$(jq -r '.enabled // false' "$SKILLS_CONFIG_FILE" 2>/dev/null)
    SKILLS_LIST=$(jq -r '.skills // [] | join(", ")' "$SKILLS_CONFIG_FILE" 2>/dev/null)

    if [ "$SKILLS_ENABLED" = "true" ] && [ -n "$SKILLS_LIST" ]; then
      echo -e "🎯 Skills Gate: ${GREEN}有効${NC}" >&2
      echo "   利用可能: ${SKILLS_LIST}" >&2
      echo -e "   ${BLUE}💡 コード編集前にスキルを使用してください${NC}" >&2
    fi
  fi
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2

# ===== Step 3: Plans.md チェック =====
if [ -f "Plans.md" ]; then
  wip_count=$(grep -c "cc:WIP\|pm:依頼中\|cursor:依頼中" Plans.md 2>/dev/null || echo "0")
  todo_count=$(grep -c "cc:TODO" Plans.md 2>/dev/null || echo "0")

  echo -e "📄 Plans.md: ${GREEN}検出${NC}" >&2
  echo "   - 進行中タスク: ${wip_count}" >&2
  echo "   - 未着手タスク: ${todo_count}" >&2

  if [ "$wip_count" -gt 0 ]; then
    echo "" >&2
    echo -e "${YELLOW}⚡ 進行中のタスク:${NC}" >&2
    grep -B1 "cc:WIP\|pm:依頼中\|cursor:依頼中" Plans.md 2>/dev/null | grep -v "^--$" | head -10 >&2 || true
  fi
else
  echo -e "📄 Plans.md: ${YELLOW}未検出${NC}" >&2
  echo "   /harness-init でセットアップしてください" >&2
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2

exit 0
