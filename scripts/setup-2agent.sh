#!/bin/bash
# setup-2agent.sh
# 2エージェント体制の初回セットアップを確実に実行するスクリプト
#
# Usage: ~/.claude/plugins/marketplaces/cursor-cc-marketplace/scripts/setup-2agent.sh
#
# このスクリプトは /setup-2agent コマンドから呼び出されます。

set -e

PLUGIN_PATH="$HOME/.claude/plugins/marketplaces/cursor-cc-marketplace"
PLUGIN_VERSION=$(cat "$PLUGIN_PATH/VERSION")
TODAY=$(date +%Y-%m-%d)
PROJECT_NAME=$(basename "$(pwd)")

echo "🚀 cursor-cc-plugins セットアップ (v${PLUGIN_VERSION})"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ================================
# 既存ファイルチェック
# ================================
if [ -f ".cursor-cc-version" ]; then
  INSTALLED_VERSION=$(grep "^version:" .cursor-cc-version | cut -d' ' -f2)
  echo "⚠️ 既存のセットアップを検出 (v${INSTALLED_VERSION})"
  echo "   更新する場合は /update-2agent を使用してください"
  echo ""
  read -p "強制的に上書きしますか？ (y/N): " confirm
  if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "中止しました"
    exit 0
  fi
fi

# ================================
# Cursor コマンドの配置
# ================================
echo "📁 [1/6] Cursor コマンドを配置..."
mkdir -p .cursor/commands
cp "$PLUGIN_PATH/templates/cursor/commands"/*.md .cursor/commands/
echo "  ✅ .cursor/commands/ (5ファイル)"

# ================================
# Claude Rules の配置（ローカライズ）
# ================================
echo "📁 [2/6] Claude Rules を配置 & ローカライズ..."
mkdir -p .claude/rules

# まず workflow.md と plans-management.md をコピー（ローカライズ不要）
for template in workflow.md.template plans-management.md.template; do
  if [ -f "$PLUGIN_PATH/templates/rules/$template" ]; then
    rule_name=$(basename "$template" .template)
    cp "$PLUGIN_PATH/templates/rules/$template" ".claude/rules/$rule_name"
    echo "  ✅ .claude/rules/$rule_name (テンプレート)"
  fi
done

# coding-standards.md と testing.md はローカライズ
echo "  🔍 プロジェクト構造を分析中..."
if "$PLUGIN_PATH/scripts/localize-rules.sh" > /dev/null 2>&1; then
  echo "  ✅ .claude/rules/coding-standards.md (ローカライズ済)"
  echo "  ✅ .claude/rules/testing.md (ローカライズ済)"
else
  # ローカライズ失敗時はテンプレートをコピー
  for template in coding-standards.md.template testing.md.template; do
    if [ -f "$PLUGIN_PATH/templates/rules/$template" ]; then
      rule_name=$(basename "$template" .template)
      cp "$PLUGIN_PATH/templates/rules/$template" ".claude/rules/$rule_name"
      echo "  ⚠️ .claude/rules/$rule_name (テンプレート - ローカライズ失敗)"
    fi
  done
fi

# ================================
# メモリ構造の初期化
# ================================
echo "📁 [3/6] メモリ構造を初期化..."
mkdir -p .claude/memory

if [ ! -f ".claude/memory/session-log.md" ]; then
  cat > .claude/memory/session-log.md << EOF
# Session Log

セッション間で共有する作業ログ。

---

## ${TODAY}

- 2エージェント体制セットアップ完了
EOF
  echo "  ✅ .claude/memory/session-log.md"
fi

if [ ! -f ".claude/memory/decisions.md" ]; then
  cat > .claude/memory/decisions.md << EOF
# Decisions

プロジェクトで決定された重要な設計・方針の記録。

---

## 設計決定

（まだ記録なし）

## 方針決定

（まだ記録なし）
EOF
  echo "  ✅ .claude/memory/decisions.md"
fi

if [ ! -f ".claude/memory/patterns.md" ]; then
  cat > .claude/memory/patterns.md << EOF
# Patterns

プロジェクトで発見・採用したパターンの記録。

---

## コーディングパターン

（まだ記録なし）

## 問題解決パターン

（まだ記録なし）
EOF
  echo "  ✅ .claude/memory/patterns.md"
fi

# ================================
# バージョンファイルの作成
# ================================
echo "📁 [4/6] バージョンファイルを作成..."
cat > .cursor-cc-version << EOF
# cursor-cc-plugins version tracking
# Created by /setup-2agent

version: ${PLUGIN_VERSION}
installed_at: ${TODAY}
last_setup_command: setup-2agent
EOF
echo "  ✅ .cursor-cc-version"

# ================================
# 検証チェックリスト
# ================================
echo ""
echo "🔍 [5/6] 検証チェックリスト..."
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

check_dir ".cursor/commands"
check_file ".cursor/commands/start-session.md"
check_file ".cursor/commands/handoff-to-claude.md"
check_file ".cursor/commands/review-cc-work.md"
check_file ".cursor/commands/plan-with-cc.md"
check_file ".cursor/commands/project-overview.md"

check_dir ".claude/rules"
check_file ".claude/rules/workflow.md"
check_file ".claude/rules/coding-standards.md"
check_file ".claude/rules/plans-management.md"
check_file ".claude/rules/testing.md"

check_dir ".claude/memory"
check_file ".claude/memory/session-log.md"
check_file ".claude/memory/decisions.md"
check_file ".claude/memory/patterns.md"

check_file ".cursor-cc-version"

# ================================
# 結果サマリー
# ================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "📊 [6/6] ローカライズ情報..."

# プロジェクト分析結果を表示
if [ -f ".claude/rules/coding-standards.md" ]; then
  DETECTED_PATHS=$(grep "^paths:" .claude/rules/coding-standards.md 2>/dev/null | head -1 | sed 's/paths: *//' | tr -d '"')
  if [ -n "$DETECTED_PATHS" ]; then
    echo "  📂 検出されたソースパス: ${DETECTED_PATHS:0:60}..."
  fi
fi

if [ $ERRORS -eq 0 ]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "✅ セットアップ完了！ (v${PLUGIN_VERSION})"
  echo ""
  echo "📝 作成されたファイル:"
  echo "  - .cursor/commands/: 5ファイル"
  echo "  - .claude/rules/: 4ファイル (プロジェクトにローカライズ済)"
  echo "  - .claude/memory/: 3ファイル"
  echo "  - .cursor-cc-version"
  echo ""
  echo "💡 次のステップ:"
  echo "  - AGENTS.md, CLAUDE.md, Plans.md を作成（Claude が対話で生成）"
  echo "  - Cursor で /start-session を実行"
  echo ""
  echo "🔧 ルールを再ローカライズ: /localize-rules"
else
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "⚠️ セットアップ完了（$ERRORS 個の警告あり）"
fi

exit $ERRORS
