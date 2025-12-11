#!/bin/bash
# update-2agent.sh
# 2エージェント体制の更新を確実に実行するスクリプト
#
# Usage: ~/.claude/plugins/marketplaces/cursor-cc-marketplace/scripts/update-2agent.sh
#
# このスクリプトは /update-2agent コマンドから呼び出されます。
# Claude が手順を見落とすリスクを排除するため、ファイル操作を自動化します。

set -e

PLUGIN_PATH="$HOME/.claude/plugins/marketplaces/cursor-cc-marketplace"
PLUGIN_VERSION=$(cat "$PLUGIN_PATH/VERSION")
TODAY=$(date +%Y-%m-%d)
PROJECT_NAME=$(basename "$(pwd)")

echo "🔄 cursor-cc-plugins アップデート (v${PLUGIN_VERSION})"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ================================
# Phase 5: Cursor コマンドの更新
# ================================
echo "📁 [1/4] Cursor コマンドを更新..."
mkdir -p .cursor/commands
cp "$PLUGIN_PATH/templates/cursor/commands"/*.md .cursor/commands/
echo "  ✅ .cursor/commands/ (5ファイル)"

# ================================
# Phase 5.5: Claude Rules の更新
# ================================
echo "📁 [2/4] Claude Rules を更新..."
mkdir -p .claude/rules

for template in "$PLUGIN_PATH/templates/rules"/*.template; do
  if [ -f "$template" ]; then
    rule_name=$(basename "$template" .template)
    cp "$template" ".claude/rules/$rule_name"
    echo "  ✅ .claude/rules/$rule_name"
  fi
done

# ================================
# Phase 6: バージョンファイルの更新
# ================================
echo "📁 [3/4] バージョンファイルを更新..."

# 既存バージョンを取得
OLD_VERSION=$(grep "^version:" .cursor-cc-version 2>/dev/null | cut -d' ' -f2 || echo "none")

cat > .cursor-cc-version << EOF
# cursor-cc-plugins version tracking
# Updated by /update-2agent

version: ${PLUGIN_VERSION}
installed_at: ${TODAY}
last_setup_command: update-2agent
updated_from: ${OLD_VERSION}
EOF
echo "  ✅ .cursor-cc-version (${OLD_VERSION} → ${PLUGIN_VERSION})"

# ================================
# 検証チェックリスト
# ================================
echo ""
echo "🔍 [4/4] 検証チェックリスト..."
ERRORS=0

check_file() {
  if [ -f "$1" ]; then
    echo "  ✅ $1"
  else
    echo "  ❌ $1 (不足)"
    ERRORS=$((ERRORS + 1))
  fi
}

check_dir() {
  if [ -d "$1" ]; then
    echo "  ✅ $1/"
  else
    echo "  ❌ $1/ (不足)"
    ERRORS=$((ERRORS + 1))
  fi
}

# 必須ファイルの確認
check_dir ".cursor/commands"
check_file ".cursor/commands/start-session.md"
check_file ".cursor/commands/handoff-to-claude.md"
check_file ".cursor/commands/review-cc-work.md"
check_file ".cursor/commands/plan-with-cc.md"
check_file ".cursor/commands/project-overview.md"

check_dir ".claude/rules"
check_file ".claude/rules/workflow.md"
check_file ".claude/rules/coding-standards.md"

check_file ".cursor-cc-version"

# ================================
# 結果サマリー
# ================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $ERRORS -eq 0 ]; then
  echo "✅ アップデート完了！ (v${PLUGIN_VERSION})"
  echo ""
  echo "📝 更新内容:"
  echo "  - .cursor/commands/: 5ファイル"
  echo "  - .claude/rules/: 2ファイル"
  echo "  - .cursor-cc-version: ${OLD_VERSION} → ${PLUGIN_VERSION}"
else
  echo "⚠️ アップデート完了（$ERRORS 個の警告あり）"
fi

exit $ERRORS
