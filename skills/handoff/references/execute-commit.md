---
name: execute-commit
description: "Execute git commit based on commit_strategy (task/phase/all). Uses commit-judgment-logic to determine if commit is ready."
allowed-tools: ["Read", "Bash", "Grep"]
---

# Execute Commit

`commit_strategy`に応じて適切なタイミングで`git commit`を実行するスキル。

---

## 入力

- **commit_strategy**: `task` / `phase` / `all`
- **worker_results**: Phase1のtask-worker実行結果
- **review_result**: Phase2のレビュー結果（オプション）
- **changed_files**: 変更されたファイルのリスト

---

## 出力

```json
{
  "committed": true,
  "commit_hash": "abc1234",
  "commit_message": "feat(components): add Header, Footer, Sidebar components",
  "files_committed": 5,
  "strategy_used": "phase"
}
```

---

## commit_strategy別の動作

### `task`（デフォルト）

各タスク完了時に個別commit（`run-task-workers`で実行）：

```bash
# 各task-workerがcommit_readyを返した時点でcommit
git add src/components/Header.tsx
git commit -m "feat(components): add Header component"
```

**実行タイミング**: Phase1の各task-worker完了時（このスキルでは実行しない）

### `phase`

レビュー完了後にまとめてcommit：

```bash
# Phase2完了時（クロスレビュー後）
git add src/components/Header.tsx src/components/Footer.tsx src/components/Sidebar.tsx
git commit -m "feat(components): add Header, Footer, Sidebar components"
```

**実行タイミング**: Phase2完了後（Phase3開始時）

### `all`

全レビュー完了後に1回だけcommit：

```bash
# Phase3開始時（Phase1+Phase2の全変更）
git add .
git commit -m "feat(components): add Header, Footer, Sidebar components

- Add responsive Header with navigation
- Add Footer with copyright and links
- Add collapsible Sidebar for mobile

Co-Authored-By: Claude <noreply@anthropic.com>"
```

**実行タイミング**: Phase3完了時（Phase4開始前）

---

## 実行手順

### Step 1: commit_strategyの確認

```bash
# ワークフロー変数から取得
# commit_strategy: "task" | "phase" | "all"
```

### Step 2: コミット準備の確認

#### 2.1: 変更ファイルの確認

```bash
# git statusで変更ファイルを確認
git status --short

# 変更があることを確認
if [ -z "$(git status --porcelain)" ]; then
  echo "変更がありません。コミットをスキップします。"
  exit 0
fi
```

#### 2.2: レビュー結果の確認（Phase2実行時）

`commit-judgment-logic.md`を参照して、コミット可能か判定：

```markdown
判定基準:
- APPROVE: Critical: 0, High: 0, Medium: ≤3 → コミット OK
- REQUEST CHANGES: Critical: 0, High: ≥1 または Medium: >3 → 自動修正 → 再判定
- REJECT: Critical: ≥1 → 手動対応必要（コミット不可）
```

**参照**: [`commit-judgment-logic.md`](../../harness-review/references/commit-judgment-logic.md)

### Step 3: Conventional Commit メッセージの生成

変更内容を分析して適切なプレフィックスを選択：

```bash
# 変更ファイルからタイプを推定
# feat: 新機能（新規ファイル）
# fix: バグ修正（既存ファイルの修正）
# refactor: リファクタリング
# docs: ドキュメント
# test: テスト追加
# chore: その他

# 例: 新規コンポーネントファイル → feat
# 例: 既存ファイルの修正 → fix
```

**メッセージフォーマット**:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**例**:

```
feat(components): add Header, Footer, Sidebar components

- Add responsive Header with navigation
- Add Footer with copyright and links
- Add collapsible Sidebar for mobile

Co-Authored-By: Claude <noreply@anthropic.com>
```

### Step 4: git add の実行

```bash
# commit_strategy=all の場合
git add .

# commit_strategy=phase の場合（Phase1の変更のみ）
git add src/components/Header.tsx src/components/Footer.tsx src/components/Sidebar.tsx

# commit_strategy=task の場合（各タスクの変更のみ）
git add src/components/Header.tsx
```

### Step 5: git commit の実行

```bash
git commit -m "{{commit_message}}"
```

### Step 6: 結果の確認

```bash
# コミットハッシュを取得
COMMIT_HASH=$(git rev-parse --short HEAD)

# コミットされたファイル数を取得
FILES_COMMITTED=$(git diff --name-only HEAD~1 | wc -l)
```

---

## エラーハンドリング

### コミット前のビルド検証

```bash
# 最終ビルド検証
npm run build || pnpm build || bun run build

# 失敗時はエラーを返す（コミットしない）
if [ $? -ne 0 ]; then
  echo "ビルドエラー: コミットを中止します"
  exit 1
fi
```

### コンフリクト検出（isolation=worktree時）

`isolation_mode=worktree`の場合、Phase3直前にworktreeブランチをマージ：

```bash
# merge-worktreesスキルでマージ済みを前提
# ここではマージ後の状態でcommitを実行
```

---

## 使用例

### 例1: commit_strategy=task

**Phase1完了時（各task-worker完了時）**:

```bash
# task-worker-1完了時
git add src/components/Header.tsx
git commit -m "feat(components): add Header component"

# task-worker-2完了時
git add src/components/Footer.tsx
git commit -m "feat(components): add Footer component"
```

### 例2: commit_strategy=phase

**Phase1完了時（全task-worker完了後）**:

```bash
git add src/components/Header.tsx src/components/Footer.tsx src/components/Sidebar.tsx
git commit -m "feat(components): add Header, Footer, Sidebar components

- Add responsive Header with navigation
- Add Footer with copyright and links
- Add collapsible Sidebar for mobile"
```

### 例3: commit_strategy=all

**Phase3完了時（全フェーズ完了後）**:

```bash
git add .
git commit -m "feat(components): add Header, Footer, Sidebar components

- Add responsive Header with navigation
- Add Footer with copyright and links
- Add collapsible Sidebar for mobile

Reviewed-by: Codex (4 experts)
Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## 注意事項

- **commit-judgment-logicの参照**: レビュー結果がある場合、必ず`commit-judgment-logic.md`の判定基準を確認する
- **Conventional Commits準拠**: コミットメッセージはConventional Commits形式に従う
- **ビルド検証**: コミット前に必ずビルドが成功することを確認する
- **worktreeマージ**: `isolation_mode=worktree`時は、マージ完了後にcommitを実行する
