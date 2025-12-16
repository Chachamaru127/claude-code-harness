---
name: ccp-core-read-repo-context
description: "リポジトリのコンテキスト（README, Plans.md, 既存コード）を読み取り理解する。セッション開始時、新しいタスク開始前、またはプロジェクト構造の理解が必要な場合に使用します。"
allowed-tools: ["Read", "Grep", "Glob"]
metadata:
  skillport:
    category: core
    tags: [context, analysis, repository]
    alwaysApply: false
---

# Read Repository Context

リポジトリの構造とコンテキストを把握するためのスキル。
作業開始前や、新しい機能の実装前に使用します。

---

## 入力

- **必須**: リポジトリのルートディレクトリへのアクセス
- **オプション**: 特定のファイルやディレクトリへのフォーカス指定

---

## 出力

リポジトリの理解を含む構造化されたコンテキスト情報

---

## 実行手順

### Step 1: 基本構造の把握

```bash
# ディレクトリ構造
ls -la
find . -maxdepth 2 -type d | head -20

# 主要ファイルの確認
cat README.md 2>/dev/null | head -50
cat package.json 2>/dev/null | head -20
```

### Step 2: ワークフローファイルの確認

```bash
# Plans.md の状態
cat Plans.md 2>/dev/null || echo "Plans.md not found"

# AGENTS.md の役割分担
cat AGENTS.md 2>/dev/null | head -100 || echo "AGENTS.md not found"

# CLAUDE.md の設定
cat CLAUDE.md 2>/dev/null | head -50 || echo "CLAUDE.md not found"
```

### Step 3: 技術スタックの特定

```bash
# フロントエンド
[ -f package.json ] && cat package.json | grep -E '"(react|vue|angular|next|nuxt)"'

# バックエンド
[ -f requirements.txt ] && head -10 requirements.txt
[ -f Gemfile ] && head -10 Gemfile
[ -f go.mod ] && head -10 go.mod

# 設定ファイル
[ -f tsconfig.json ] && echo "TypeScript project"
[ -f .eslintrc* ] && echo "ESLint configured"
[ -f tailwind.config.* ] && echo "Tailwind CSS"
```

### Step 4: Git 状態の確認

```bash
git status -sb
git log --oneline -5
git branch -a | head -10
```

---

## 出力フォーマット

```markdown
## 📁 リポジトリコンテキスト

### 基本情報
- **プロジェクト名**: {{name}}
- **技術スタック**: {{framework}} + {{language}}
- **現在のブランチ**: {{branch}}

### ワークフロー状態
- **Plans.md**: {{存在する/しない, タスク数}}
- **AGENTS.md**: {{存在する/しない}}
- **CLAUDE.md**: {{存在する/しない}}

### 直近の変更
{{最近のコミット3件}}

### 重要なファイル
{{認識すべき主要ファイル一覧}}
```

---

## 使用タイミング

1. **セッション開始時**: 現在の状態把握
2. **新機能実装前**: 既存コードとの整合性確認
3. **エラー調査時**: 関連ファイルの特定
4. **レビュー時**: 変更の影響範囲理解

---

## 注意事項

- **大規模リポジトリ**: ファイル数が多い場合は重要部分に絞る
- **秘密情報**: .env や secrets/ の内容は読まない
- **キャッシュ活用**: 同一セッション内では再読み込みを最小化
