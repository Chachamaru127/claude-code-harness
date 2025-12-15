#!/bin/bash
# setup-existing-project.sh
# 既存プロジェクトにclaude-code-harnessを適用するセットアップスクリプト
#
# Usage: ./scripts/setup-existing-project.sh [project_path]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_ROOT="$(dirname "$SCRIPT_DIR")"
PROJECT_PATH="${1:-.}"

# カラー出力
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Claude Code Harness - 既存プロジェクト適用${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# ================================
# Step 1: 前提条件チェック
# ================================

echo -e "${BLUE}[1/6] 前提条件チェック${NC}"
echo "----------------------------------------"

# プロジェクトディレクトリの存在確認
if [ ! -d "$PROJECT_PATH" ]; then
    echo -e "${RED}✗ プロジェクトディレクトリが見つかりません: $PROJECT_PATH${NC}"
    exit 1
fi

cd "$PROJECT_PATH"
PROJECT_PATH=$(pwd)
echo -e "${GREEN}✓${NC} プロジェクトディレクトリ: $PROJECT_PATH"

# セットアップ用メタ情報
PROJECT_NAME="$(basename "$PROJECT_PATH")"
SETUP_DATE_ISO="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
SETUP_DATE_SHORT="$(date +"%Y-%m-%d")"
HARNESS_VERSION="unknown"
if [ -f "$HARNESS_ROOT/VERSION" ]; then
    HARNESS_VERSION="$(cat "$HARNESS_ROOT/VERSION" | tr -d ' \n\r')"
fi

# テンプレート埋め用（後で analyze-project の結果で上書きされる場合あり）
LANGUAGE="unknown"

# Gitリポジトリかチェック
if [ ! -d ".git" ]; then
    echo -e "${YELLOW}⚠${NC}  Gitリポジトリではありません"
    read -p "Gitリポジトリを初期化しますか？ (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git init
        echo -e "${GREEN}✓${NC} Gitリポジトリを初期化しました"
    fi
else
    echo -e "${GREEN}✓${NC} Gitリポジトリです"
fi

# 未コミットの変更をチェック
if [ -d ".git" ]; then
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        echo -e "${YELLOW}⚠${NC}  未コミットの変更があります"
        echo ""
        echo -e "${YELLOW}推奨: セットアップ前にコミットしてください${NC}"
        echo ""
        read -p "続行しますか？ (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "セットアップを中止しました"
            exit 0
        fi
    else
        echo -e "${GREEN}✓${NC} 作業ツリーはクリーンです"
    fi
fi

echo ""

# ================================
# Step 2: 既存の仕様書・ドキュメント探索
# ================================

echo -e "${BLUE}[2/6] 既存ドキュメントの探索${NC}"
echo "----------------------------------------"

FOUND_DOCS=()
DOC_PATTERNS=(
    "README.md"
    "SPEC.md"
    "SPECIFICATION.md"
    "仕様書.md"
    "要件定義.md"
    "docs/spec.md"
    "docs/specification.md"
    "docs/requirements.md"
    "docs/proposal.md"
    "docs/提案書.md"
    "Plans.md"
    "PLAN.md"
    "計画.md"
)

for pattern in "${DOC_PATTERNS[@]}"; do
    if [ -f "$pattern" ]; then
        FOUND_DOCS+=("$pattern")
        echo -e "${GREEN}✓${NC} 発見: $pattern"
    fi
done

if [ ${#FOUND_DOCS[@]} -eq 0 ]; then
    echo -e "${YELLOW}⚠${NC}  既存の仕様書が見つかりませんでした"
else
    echo ""
    echo -e "${GREEN}${#FOUND_DOCS[@]} 個のドキュメントを発見しました${NC}"
fi

echo ""

# ================================
# Step 3: プロジェクト分析
# ================================

echo -e "${BLUE}[3/6] プロジェクト分析${NC}"
echo "----------------------------------------"

# analyze-project.shを実行
if [ -f "$HARNESS_ROOT/scripts/analyze-project.sh" ]; then
    ANALYSIS_RESULT=$("$HARNESS_ROOT/scripts/analyze-project.sh" "$PROJECT_PATH" 2>/dev/null || echo "{}")
    
    # 技術スタック表示（analyze-project.sh の出力: technologies/frameworks/testing）
    if command -v jq &> /dev/null; then
        TECHNOLOGIES=$(echo "$ANALYSIS_RESULT" | jq -r '.technologies[]?' 2>/dev/null || true)
        FRAMEWORKS=$(echo "$ANALYSIS_RESULT" | jq -r '.frameworks[]?' 2>/dev/null || true)
        TESTING=$(echo "$ANALYSIS_RESULT" | jq -r '.testing[]?' 2>/dev/null || true)

        # LANGUAGE の簡易推定（テンプレートの {{LANGUAGE}} 埋め用）
        LANGUAGE=$(echo "$ANALYSIS_RESULT" | jq -r '.technologies[0] // "unknown"' 2>/dev/null || echo "unknown")

        if [ -n "${TECHNOLOGIES}${FRAMEWORKS}${TESTING}" ]; then
            echo "検出結果:"
            if [ -n "$TECHNOLOGIES" ]; then
                echo "  technologies:"
                echo "$TECHNOLOGIES" | while read -r tech; do
                    [ -n "$tech" ] && echo -e "    ${GREEN}•${NC} $tech"
                done
            fi
            if [ -n "$FRAMEWORKS" ]; then
                echo "  frameworks:"
                echo "$FRAMEWORKS" | while read -r fw; do
                    [ -n "$fw" ] && echo -e "    ${GREEN}•${NC} $fw"
                done
            fi
            if [ -n "$TESTING" ]; then
                echo "  testing:"
                echo "$TESTING" | while read -r t; do
                    [ -n "$t" ] && echo -e "    ${GREEN}•${NC} $t"
                done
            fi
        fi
    fi
else
    echo -e "${YELLOW}⚠${NC}  プロジェクト分析スクリプトが見つかりません"
fi

echo ""

# ================================
# Step 4: ハーネス設定ファイルの作成
# ================================

echo -e "${BLUE}[4/6] ハーネス設定ファイルの作成${NC}"
echo "----------------------------------------"

# .claude-code-harness ディレクトリを作成
mkdir -p .claude-code-harness

# 既存ドキュメントへの参照を含む設定ファイルを作成（既存があれば上書きしない）
CONFIG_PATH=".claude-code-harness/config.json"
if [ -f "$CONFIG_PATH" ]; then
    echo -e "${YELLOW}⚠${NC}  設定ファイルは既に存在します（上書きしません）: $CONFIG_PATH"
else
    cat > "$CONFIG_PATH" << EOF
{
  "version": "$HARNESS_VERSION",
  "setup_date": "$SETUP_DATE_ISO",
  "project_type": "existing",
  "existing_documents": [
$(
    for doc in "${FOUND_DOCS[@]}"; do
        echo "    \"$doc\","
    done | sed '$ s/,$//'
)
  ],
  "harness_path": "$HARNESS_ROOT"
}
EOF

    echo -e "${GREEN}✓${NC} 設定ファイルを作成: $CONFIG_PATH"
fi

# 既存ドキュメントのサマリーを作成（既存があれば上書きしない）
if [ ${#FOUND_DOCS[@]} -gt 0 ]; then
    SUMMARY_PATH=".claude-code-harness/existing-docs-summary.md"
    if [ -f "$SUMMARY_PATH" ]; then
        echo -e "${YELLOW}⚠${NC}  既存ドキュメントサマリーは既に存在します（上書きしません）: $SUMMARY_PATH"
    else
        cat > "$SUMMARY_PATH" << EOF
# 既存ドキュメント一覧

このプロジェクトには以下の既存ドキュメントがあります：

EOF

        for doc in "${FOUND_DOCS[@]}"; do
            echo "## $doc" >> "$SUMMARY_PATH"
            echo "" >> "$SUMMARY_PATH"
            echo '```' >> "$SUMMARY_PATH"
            head -20 "$doc" >> "$SUMMARY_PATH"
            echo '```' >> "$SUMMARY_PATH"
            echo "" >> "$SUMMARY_PATH"
        done

        echo -e "${GREEN}✓${NC} 既存ドキュメントサマリーを作成: $SUMMARY_PATH"
    fi
fi

echo ""

# ================================
# Step 5: Project Rulesの作成
# ================================

echo -e "${BLUE}[5/6] Project Rules / ワークフローファイルの作成${NC}"
echo "----------------------------------------"

# .claude/rules ディレクトリを作成
mkdir -p .claude/rules

# テンプレートの簡易レンダリング（{{PROJECT_NAME}}/{{DATE}}/{{LANGUAGE}}）
escape_sed_repl() {
    # sed の置換文字列として安全にする（/ & | をエスケープ）
    printf '%s' "$1" | sed -e 's/[\/&|]/\\&/g'
}

render_template_if_missing() {
    local template_path="$1"
    local dest_path="$2"
    local label="$3"

    if [ -f "$dest_path" ]; then
        echo -e "${GREEN}✓${NC} ${label}: 既存（スキップ）"
        return 0
    fi
    if [ ! -f "$template_path" ]; then
        echo -e "${YELLOW}⚠${NC} ${label}: テンプレートが見つかりません: $template_path"
        return 0
    fi
    # ネストしたパスにも対応
    mkdir -p "$(dirname "$dest_path")" 2>/dev/null || true

    local project_esc date_esc lang_esc
    project_esc=$(escape_sed_repl "$PROJECT_NAME")
    date_esc=$(escape_sed_repl "$SETUP_DATE_SHORT")
    lang_esc=$(escape_sed_repl "$LANGUAGE")

    sed \
        -e "s|{{PROJECT_NAME}}|$project_esc|g" \
        -e "s|{{DATE}}|$date_esc|g" \
        -e "s|{{LANGUAGE}}|$lang_esc|g" \
        "$template_path" > "$dest_path"

    echo -e "${GREEN}✓${NC} ${label} を作成: $dest_path"
}

# 既存プロジェクト向けのProject Rulesを作成（既存があれば上書きしない）
RULES_PATH=".claude/rules/harness.md"
if [ -f "$RULES_PATH" ]; then
    echo -e "${YELLOW}⚠${NC}  Project Rules は既に存在します（上書きしません）: $RULES_PATH"
else
    cat > "$RULES_PATH" << EOF
# Claude Code Harness - Project Rules

このプロジェクトは **claude-code-harness** を使用しています。

## 既存プロジェクトへの適用

このプロジェクトは既存のコードベースに claude-code-harness を適用したものです。

### 既存の資産を尊重する

1. **既存のドキュメントを優先**
   - 既存の仕様書、README、計画書がある場合は、それらを最優先で参照する
   - `.claude-code-harness/existing-docs-summary.md` に既存ドキュメントの一覧がある

2. **既存のコードスタイルを維持**
   - 既存のコーディング規約、フォーマット設定を尊重する
   - 新規コードは既存コードのスタイルに合わせる

3. **段階的な改善**
   - 一度に全てを書き換えない
   - 既存の動作を壊さないよう注意する

## 利用可能なコマンド

### コア（Plan → Work → Review）
- `/plan-with-agent` - プロジェクト計画の作成・更新（既存ドキュメントを考慮）
- `/work` - 機能実装（並列実行対応、既存コードとの整合性を保つ）
- `/harness-review` - コードレビュー

### 品質/運用
- `/validate` - 納品前検証
- `/cleanup` - Plans.md等の自動整理
- `/sync-status` - 進捗確認→次アクション提案
- `/refactor` - 安全なリファクタリング

### 実装支援
- `/crud` - CRUD機能生成
- `/ci-setup` - CI/CD設定

### スキル（会話で自動起動）
- `component` - 「ヒーローを作って」→ UIコンポーネント実装
- `auth` - 「ログイン機能を付けて」→ 認証実装
- `payments` - 「Stripeで決済を」→ 決済統合
- `deploy-setup` - 「Vercelにデプロイしたい」→ デプロイ設定
- `analytics` - 「アクセス解析を入れて」→ アナリティクス統合
- `auto-fix` - 「指摘を修正して」→ 自動修正

## 既存プロジェクトでの注意点

1. **既存の仕様書を必ず確認**
   - コマンド実行前に既存ドキュメントを読む
   - 矛盾がある場合は確認する

2. **段階的な適用**
   - 小さな機能から始める
   - 動作確認を頻繁に行う

3. **バージョン管理**
   - こまめにコミットする
   - 大きな変更前にブランチを切る

## セットアップ情報

- セットアップ日: $SETUP_DATE_SHORT
- ハーネスバージョン: $HARNESS_VERSION
- 設定ファイル: `.claude-code-harness/config.json`
EOF

    echo -e "${GREEN}✓${NC} Project Rulesを作成: $RULES_PATH"
fi

echo ""

# ワークフローファイル（AGENTS/CLAUDE/Plans）を必要に応じて作成（既存があれば上書きしない）
TEMPLATE_DIR="$HARNESS_ROOT/templates"
render_template_if_missing "$TEMPLATE_DIR/AGENTS.md.template" "AGENTS.md" "AGENTS.md"
render_template_if_missing "$TEMPLATE_DIR/CLAUDE.md.template" "CLAUDE.md" "CLAUDE.md"
render_template_if_missing "$TEMPLATE_DIR/Plans.md.template" "Plans.md" "Plans.md"

echo ""

# ================================
# Step 5.5: プロジェクトメモリ（SSOT）の初期化
# ================================
echo -e "${BLUE}[5.5/6] プロジェクトメモリ（SSOT）の初期化${NC}"
echo "----------------------------------------"

# decisions/patterns は SSOT として共有推奨。session-log はローカル運用向け。
mkdir -p .claude/memory
render_template_if_missing "$TEMPLATE_DIR/memory/decisions.md.template" ".claude/memory/decisions.md" "decisions.md (SSOT)"
render_template_if_missing "$TEMPLATE_DIR/memory/patterns.md.template" ".claude/memory/patterns.md" "patterns.md (SSOT)"
render_template_if_missing "$TEMPLATE_DIR/memory/session-log.md.template" ".claude/memory/session-log.md" "session-log.md"

echo ""

# ================================
# Step 6: セットアップ完了
# ================================

echo -e "${BLUE}[6/6] セットアップ完了${NC}"
echo "----------------------------------------"

echo ""
echo -e "${GREEN}✅ セットアップが完了しました！${NC}"
echo ""
echo "次のステップ:"
echo ""
echo "1. 既存ドキュメントを確認:"
echo -e "   ${BLUE}cat .claude-code-harness/existing-docs-summary.md${NC}"
echo ""
echo "2. Claude Codeでプロジェクトを開く:"
echo -e "   ${BLUE}cd $PROJECT_PATH${NC}"
echo -e "   ${BLUE}claude${NC}"
echo -e "   ${YELLOW}（プラグインを未インストールで、このハーネスをローカルから直接読み込む場合）${NC}"
echo -e "   ${BLUE}claude --plugin-dir \"$HARNESS_ROOT\"${NC}"
echo ""
echo "3. 既存の仕様を確認してから計画を更新:"
echo -e "   ${BLUE}/plan${NC}"
echo ""
echo "4. 小さな機能から実装を開始:"
echo -e "   ${BLUE}/work${NC}"
echo ""
echo "5. こまめにレビュー:"
echo -e "   ${BLUE}/harness-review${NC}"
echo ""
echo "6. （任意）Cursor連携を有効化:"
echo -e "   ${BLUE}/setup-cursor${NC}"
echo ""

# .gitignoreに追加
if [ -f ".gitignore" ]; then
    if ! grep -q ".claude-code-harness" .gitignore; then
        echo "" >> .gitignore
        echo "# Claude Code Harness" >> .gitignore
        echo ".claude-code-harness/" >> .gitignore
        echo -e "${GREEN}✓${NC} .gitignoreに追加しました"
    fi

    # メモリ運用の推奨（重複追記しない）
    if ! grep -q "Claude Memory Policy" .gitignore; then
        echo "" >> .gitignore
        echo "# Claude Memory Policy (recommended)" >> .gitignore
        echo "# - Keep (shared SSOT): .claude/memory/decisions.md, .claude/memory/patterns.md" >> .gitignore
        echo "# - Ignore (local): .claude/state/, session-log.md, context.json, archives" >> .gitignore
        echo ".claude/state/" >> .gitignore
        echo ".claude/memory/session-log.md" >> .gitignore
        echo ".claude/memory/context.json" >> .gitignore
        echo ".claude/memory/archive/" >> .gitignore
        echo -e "${GREEN}✓${NC} .gitignoreにメモリ運用の推奨を追記しました（必要に応じて調整してください）"
    fi
fi

echo ""
echo -e "${YELLOW}⚠${NC}  重要: 変更をコミットすることを推奨します"
echo ""
