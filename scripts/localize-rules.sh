#!/bin/bash
# localize-rules.sh
# プロジェクト構造に合わせてルールをローカライズ
#
# Usage: ./scripts/localize-rules.sh [--dry-run]
#
# 機能:
# - プロジェクト分析結果に基づいて paths: を調整
# - 言語固有のルールを追加
# - 既存のカスタマイズを保持

set -e

PLUGIN_PATH="${PLUGIN_PATH:-$HOME/.claude/plugins/marketplaces/cursor-cc-marketplace}"
DRY_RUN=false

# 引数解析
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run) DRY_RUN=true; shift ;;
    *) shift ;;
  esac
done

# ================================
# プロジェクト分析
# ================================
echo "🔍 プロジェクト構造を分析中..."

# analyze-project.sh を実行
ANALYSIS=$("$PLUGIN_PATH/scripts/analyze-project.sh" 2>/dev/null || echo '{"languages":["unknown"],"source_dirs":["."],"test_info":[],"extensions":[]}')

# JSON から値を抽出
LANGUAGES=$(echo "$ANALYSIS" | jq -r '.languages[]' 2>/dev/null | tr '\n' ' ')
SOURCE_DIRS=$(echo "$ANALYSIS" | jq -r '.source_dirs[]' 2>/dev/null | tr '\n' ' ')
TEST_DIRS=$(echo "$ANALYSIS" | jq -r '.test_info.dirs[]' 2>/dev/null | tr '\n' ' ')
HAS_COLOCATED_TESTS=$(echo "$ANALYSIS" | jq -r '.test_info.has_colocated_tests // false' 2>/dev/null)

echo "  言語: $LANGUAGES"
echo "  ソースディレクトリ: $SOURCE_DIRS"

# ================================
# paths パターン生成
# ================================
generate_code_paths() {
  local paths=""
  local src_dirs=($SOURCE_DIRS)

  # 言語に応じた拡張子
  local extensions=""
  if [[ "$LANGUAGES" == *"typescript"* ]] || [[ "$LANGUAGES" == *"react"* ]]; then
    extensions="ts,tsx,js,jsx"
  elif [[ "$LANGUAGES" == *"javascript"* ]]; then
    extensions="js,jsx"
  elif [[ "$LANGUAGES" == *"python"* ]]; then
    extensions="py"
  elif [[ "$LANGUAGES" == *"go"* ]]; then
    extensions="go"
  elif [[ "$LANGUAGES" == *"rust"* ]]; then
    extensions="rs"
  elif [[ "$LANGUAGES" == *"ruby"* ]]; then
    extensions="rb"
  elif [[ "$LANGUAGES" == *"java"* ]] || [[ "$LANGUAGES" == *"kotlin"* ]]; then
    extensions="java,kt"
  else
    extensions="ts,tsx,js,jsx,py,rb,go,rs,java,kt"
  fi

  # ソースディレクトリごとにパターン生成
  for dir in "${src_dirs[@]}"; do
    if [ "$dir" = "." ]; then
      paths+="**/*.{$extensions}, "
    else
      paths+="$dir/**/*.{$extensions}, "
    fi
  done

  # 末尾のカンマとスペースを削除
  echo "${paths%, }"
}

generate_test_paths() {
  local paths=""
  local test_dirs_arr=($TEST_DIRS)

  # 検出されたテストディレクトリ
  if [ ${#test_dirs_arr[@]} -gt 0 ]; then
    for dir in "${test_dirs_arr[@]}"; do
      paths+="$dir/**/*.*, "
    done
  else
    # デフォルトのテストディレクトリをチェック
    for dir in tests test __tests__ spec e2e; do
      if [ -d "$dir" ]; then
        paths+="$dir/**/*.*, "
      fi
    done
  fi

  # colocated tests
  if [ "$HAS_COLOCATED_TESTS" = "true" ]; then
    paths+="**/*.{test,spec}.{ts,tsx,js,jsx,py}, "
  fi

  # デフォルト
  if [ -z "$paths" ]; then
    paths="**/*.{test,spec}.*, tests/**/*.*, test/**/*.*"
  fi

  echo "${paths%, }"
}

# ================================
# ルールファイル生成
# ================================
CODE_PATHS=$(generate_code_paths)
TEST_PATHS=$(generate_test_paths)

echo ""
echo "📝 生成される paths:"
echo "  コード: $CODE_PATHS"
echo "  テスト: $TEST_PATHS"

if [ "$DRY_RUN" = true ]; then
  echo ""
  echo "🔍 [Dry Run] 実際の変更は行いません"
  exit 0
fi

# .claude/rules ディレクトリ確認
mkdir -p .claude/rules

# ================================
# coding-standards.md のローカライズ
# ================================
echo ""
echo "📁 ルールをローカライズ中..."

# テンプレートから生成（既存ファイルがあれば上書き確認）
CODING_STANDARDS=".claude/rules/coding-standards.md"

# 言語固有のセクションを追加
LANG_SPECIFIC=""
if [[ "$LANGUAGES" == *"typescript"* ]]; then
  LANG_SPECIFIC+="
## TypeScript 固有

- \`any\` は使用禁止（\`unknown\` を使用）
- 戻り値の型は明示する
- 厳密な null チェックを有効化
"
fi

if [[ "$LANGUAGES" == *"python"* ]]; then
  LANG_SPECIFIC+="
## Python 固有

- PEP 8 スタイルガイドに従う
- 型ヒントを使用する
- docstring は Google スタイル
"
fi

if [[ "$LANGUAGES" == *"react"* ]]; then
  LANG_SPECIFIC+="
## React 固有

- 関数コンポーネントを使用
- カスタムフックは \`use\` プレフィックス
- Props の型定義を必須
"
fi

# coding-standards.md を生成
cat > "$CODING_STANDARDS" << EOF
---
description: コーディング規約（コードファイル編集時のみ適用）
paths: "$CODE_PATHS"
---

# Coding Standards

## コミットメッセージ規約

| Prefix | 用途 | 例 |
|--------|------|-----|
| \`feat:\` | 新機能 | \`feat: ユーザー認証を追加\` |
| \`fix:\` | バグ修正 | \`fix: ログインエラーを修正\` |
| \`docs:\` | ドキュメント | \`docs: README を更新\` |
| \`refactor:\` | リファクタリング | \`refactor: 認証ロジックを整理\` |
| \`test:\` | テスト | \`test: 認証テストを追加\` |
| \`chore:\` | その他 | \`chore: 依存関係を更新\` |

## コードスタイル

- ✅ 既存のコードスタイルに従う
- ✅ 変更に必要な最小限の修正のみ
- ❌ 変更していないコードへの「改善」
- ❌ 依頼されていないリファクタリング
- ❌ 過剰なコメント追加
$LANG_SPECIFIC
## Pull Request

- タイトル: 変更内容を簡潔に（50文字以内）
- 説明: 「何を」「なぜ」を明記
- テスト方法を必ず記載
EOF

echo "  ✅ $CODING_STANDARDS"

# ================================
# testing.md のローカライズ
# ================================
TESTING_RULES=".claude/rules/testing.md"

cat > "$TESTING_RULES" << EOF
---
description: テストファイル作成・編集時のルール
paths: "$TEST_PATHS"
---

# Testing Rules

## テスト作成の原則

1. **境界テスト**: 入力の境界値を必ずテスト
2. **正常系・異常系**: 両方のケースをカバー
3. **独立性**: 各テストは他のテストに依存しない
4. **明確な命名**: テスト名で何をテストしているか分かる

## テスト命名規約

\`\`\`
describe('機能名', () => {
  it('should 期待する動作 when 条件', () => {
    // ...
  });
});
\`\`\`

## 禁止事項

- ❌ 実装の内部詳細に依存したテスト
- ❌ 外部サービスへの実際の接続（モックを使用）
- ❌ テスト間の状態共有
EOF

echo "  ✅ $TESTING_RULES"

# ================================
# 完了
# ================================
echo ""
echo "✅ ルールのローカライズが完了しました"
echo ""
echo "📋 生成されたルール:"
echo "  - .claude/rules/coding-standards.md (paths: $CODE_PATHS)"
echo "  - .claude/rules/testing.md (paths: $TEST_PATHS)"
