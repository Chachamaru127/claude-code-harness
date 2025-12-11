#!/bin/bash
# setup-2agent.sh
# 適応型2エージェント体制セットアップスクリプト
#
# Usage: ~/.claude/plugins/marketplaces/cursor-cc-marketplace/scripts/setup-2agent.sh [--analyze-only]
#
# Options:
#   --analyze-only  分析結果のみ表示（セットアップは実行しない）
#
# このスクリプトは /setup-2agent コマンドから呼び出されます。

set -e

PLUGIN_PATH="$HOME/.claude/plugins/marketplaces/cursor-cc-marketplace"
PLUGIN_VERSION=$(cat "$PLUGIN_PATH/VERSION")
TODAY=$(date +%Y-%m-%d)
PROJECT_NAME=$(basename "$(pwd)")
ANALYZE_ONLY=false

# オプション解析
if [ "$1" = "--analyze-only" ]; then
  ANALYZE_ONLY=true
fi

echo "🚀 cursor-cc-plugins 適応型セットアップ (v${PLUGIN_VERSION})"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ================================
# Phase 1: プロジェクト分析
# ================================
echo "🔍 [Phase 1] プロジェクト分析中..."
echo ""

ANALYSIS=$("$PLUGIN_PATH/scripts/analyze-project.sh" 2>/dev/null || echo "{}")

# 分析結果を表示
display_analysis() {
  # 技術スタック
  local techs=$(echo "$ANALYSIS" | jq -r '.technologies[]?' 2>/dev/null | tr '\n' ', ' | sed 's/,$//')
  local frameworks=$(echo "$ANALYSIS" | jq -r '.frameworks[]?' 2>/dev/null | tr '\n' ', ' | sed 's/,$//')
  local testing=$(echo "$ANALYSIS" | jq -r '.testing[]?' 2>/dev/null | tr '\n' ', ' | sed 's/,$//')

  echo "📦 検出した技術スタック:"
  if [ -n "$techs" ]; then
    echo "   言語: $techs"
  else
    echo "   言語: (検出なし)"
  fi
  if [ -n "$frameworks" ]; then
    echo "   フレームワーク: $frameworks"
  fi
  if [ -n "$testing" ]; then
    echo "   テスト: $testing"
  fi
  echo ""

  # コーディング規約
  local linters=$(echo "$ANALYSIS" | jq -r '.linters[]?' 2>/dev/null | tr '\n' ', ' | sed 's/,$//')
  local formatters=$(echo "$ANALYSIS" | jq -r '.formatters[]?' 2>/dev/null | tr '\n' ', ' | sed 's/,$//')
  local strict=$(echo "$ANALYSIS" | jq -r '.typescript_strict' 2>/dev/null)

  echo "📜 検出したコーディング規約:"
  if [ -n "$linters" ]; then
    echo "   Linter: $linters"
  fi
  if [ -n "$formatters" ]; then
    echo "   Formatter: $formatters"
  fi
  if [ "$strict" = "true" ]; then
    echo "   TypeScript: strict mode"
  fi
  if [ -z "$linters" ] && [ -z "$formatters" ]; then
    echo "   (検出なし - デフォルト規約を適用)"
  fi
  echo ""

  # 既存設定
  local claude_config=$(echo "$ANALYSIS" | jq -r '.claude_config[]?' 2>/dev/null | tr '\n' ', ' | sed 's/,$//')
  local cursor_config=$(echo "$ANALYSIS" | jq -r '.cursor_config[]?' 2>/dev/null | tr '\n' ', ' | sed 's/,$//')
  local cc_version=$(echo "$ANALYSIS" | jq -r '.cursor_cc_version' 2>/dev/null)

  echo "📁 既存の設定:"
  if [ -n "$claude_config" ]; then
    echo "   Claude: $claude_config"
  fi
  if [ -n "$cursor_config" ]; then
    echo "   Cursor: $cursor_config"
  fi
  if [ "$cc_version" != "none" ] && [ "$cc_version" != "null" ]; then
    echo "   cursor-cc-plugins: v$cc_version"
  fi
  if [ -z "$claude_config" ] && [ -z "$cursor_config" ]; then
    echo "   (新規セットアップ)"
  fi
  echo ""

  # 重要事項
  local patterns=$(echo "$ANALYSIS" | jq -r '.important_patterns[]?' 2>/dev/null | tr '\n' ', ' | sed 's/,$//')
  if [ -n "$patterns" ]; then
    echo "⚠️ 重要視されている事項:"
    echo "   $patterns"
    echo ""
  fi

  # Git 情報
  local conventional=$(echo "$ANALYSIS" | jq -r '.git.conventional_commits' 2>/dev/null)
  if [ "$conventional" = "true" ]; then
    echo "📝 コミット規約: Conventional Commits を検出"
    echo ""
  fi
}

display_analysis

# 分析のみの場合はここで終了
if [ "$ANALYZE_ONLY" = true ]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "分析完了。セットアップを実行するには --analyze-only なしで再実行してください。"
  exit 0
fi

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
echo "📁 [1/5] Cursor コマンドを配置..."
mkdir -p .cursor/commands
cp "$PLUGIN_PATH/templates/cursor/commands"/*.md .cursor/commands/
echo "  ✅ .cursor/commands/ (5ファイル)"

# ================================
# Claude Rules の配置
# ================================
echo "📁 [2/5] Claude Rules を配置..."
mkdir -p .claude/rules

for template in "$PLUGIN_PATH/templates/rules"/*.template; do
  if [ -f "$template" ]; then
    rule_name=$(basename "$template" .template)
    cp "$template" ".claude/rules/$rule_name"
    echo "  ✅ .claude/rules/$rule_name"
  fi
done

# ================================
# メモリ構造の初期化
# ================================
echo "📁 [3/5] メモリ構造を初期化..."
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
echo "📁 [4/5] バージョンファイルを作成..."
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
echo "🔍 [5/5] 検証チェックリスト..."
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

if [ $ERRORS -eq 0 ]; then
  echo "✅ セットアップ完了！ (v${PLUGIN_VERSION})"
  echo ""
  echo "📝 作成されたファイル:"
  echo "  - .cursor/commands/: 5ファイル"
  echo "  - .claude/rules/: 4ファイル (paths: 条件付き適用)"
  echo "  - .claude/memory/: 3ファイル"
  echo "  - .cursor-cc-version"
  echo ""
  echo "💡 次のステップ:"
  echo "  - AGENTS.md, CLAUDE.md, Plans.md を作成（Claude が対話で生成）"
  echo "  - Cursor で /start-session を実行"
else
  echo "⚠️ セットアップ完了（$ERRORS 個の警告あり）"
fi

exit $ERRORS
