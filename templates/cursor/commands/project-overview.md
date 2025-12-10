# /project-overview - プロジェクト全体の確認

プロジェクト全体の状況を確認し、次のアクションを提案します。

---

## 使い方

```
/project-overview
```

または自然言語で：
- 「プロジェクトの状況を教えて」
- 「全体を見直して」
- 「何ができてて、何が残ってる？」

---

## 実行フロー

### Step 1: プロジェクト情報の収集

```bash
# プロジェクト構造
find . -type f -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" | head -20

# 技術スタック
cat package.json 2>/dev/null | head -30

# Git 情報
git log --oneline -10
git branch -a

# タスク状況
cat Plans.md
```

### Step 2: プロジェクト概要レポート

```markdown
## 📊 プロジェクト概要

**プロジェクト名**: {{project_name}}
**確認日時**: {{datetime}}

---

### 🏗️ プロジェクト構成

**技術スタック:**
- フレームワーク: {{framework}}
- 言語: {{language}}
- 主要ライブラリ: {{libraries}}

**ディレクトリ構造:**
```
src/
├── components/   ({{count}}ファイル)
├── pages/        ({{count}}ファイル)
├── utils/        ({{count}}ファイル)
└── ...
```

---

### 📋 タスク状況

| 状態 | 件数 | 内容 |
|------|------|------|
| 🔴 進行中 | {{wip}} | {{wip_tasks}} |
| 🟡 未着手 | {{todo}} | {{todo_tasks}} |
| 🟢 完了 | {{done}} | 直近: {{recent_done}} |
| 📦 アーカイブ | {{archive}} | - |

---

### 📈 進捗サマリー

**完了率**: {{completion_rate}}%
**直近の活動**: {{recent_activity}}
**ブロッカー**: {{blockers}}

---

### 🚀 推奨アクション

{{recommendations}}
```

### Step 3: 推奨アクションの提案

状況に応じた提案:

| 状況 | 推奨アクション |
|------|---------------|
| 進行中タスクあり | Claude Code で継続作業 |
| 確認待ちタスクあり | `/review-cc-work` でレビュー |
| タスクなし | `/plan-with-cc` で計画 |
| ブロッカーあり | ブロッカーの解消を優先 |

---

## 出力例

```
📊 **プロジェクト概要** - my-awesome-app

### 技術スタック
- Next.js 14 + TypeScript
- Tailwind CSS
- Prisma + PostgreSQL

### タスク状況
| 状態 | 件数 |
|------|------|
| 🔴 進行中 | 1 |
| 🟡 未着手 | 4 |
| 🟢 完了 | 12 |

### 直近の完了タスク
- ユーザー認証機能 (昨日)
- データベース設計 (3日前)

### 進行中
- 「商品一覧ページの実装」- Claude Code が作業中

### 推奨アクション
1. 進行中タスクの完了を待つ
2. 完了後、`/review-cc-work` でレビュー
3. 次のタスク「カート機能」を依頼

---

💡 詳細を確認するには Plans.md を参照してください
```

---

## 関連コマンド

| コマンド | 用途 |
|---------|------|
| `/start-session` | セッション開始 |
| `/plan-with-cc` | 計画を立てる |
| `/assign-to-cc` | タスクを依頼 |
| `/review-cc-work` | 完了レビュー |
