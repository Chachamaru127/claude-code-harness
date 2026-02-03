# Review & Integration Flow

Worker 成果物のレビューとマージ統合フロー。

## Overview

```
Worker 完了（品質ゲート通過）
    │
    ├─ 1. 成果物収集
    │     - worktree の commit 取得
    │     - diff 生成
    │
    ├─ 2. Claude Code レビュー
    │     - 差分レビュー
    │     - 修正指示（必要時）
    │
    ├─ 3. 修正ループ（最大2回）
    │     - Codex 再実行
    │     - 品質ゲート再チェック
    │
    ├─ 4. マージ
    │     - cherry-pick
    │     - 競合時: ユーザー判断
    │
    └─ 5. Plans.md 更新
          - タスクを cc:done に
```

## Output Format

Worker 成果物は以下の形式で収集:

### commit 形式（推奨）

```bash
# worktree でのコミット取得
cd ../worktrees/worker-1
git log -1 --format="%H"  # コミットハッシュ

# diff 取得
git diff HEAD~1..HEAD
```

### patch 形式（オプション）

```bash
# パッチファイル生成
git format-patch -1 HEAD -o ../patches/
```

## Review Flow

### Step 1: 差分レビュー

Claude Code が以下を確認:

| チェック項目 | 基準 |
|-------------|------|
| 実装の完全性 | タスク仕様を満たしているか |
| コード品質 | プロジェクトスタイルに準拠 |
| テストカバレッジ | 必要なテストが追加されているか |
| セキュリティ | 脆弱性が含まれていないか |

### Step 2: 修正指示

問題がある場合:

```
⚠️ レビュー結果: 修正が必要

1. [HIGH] ログイン処理にXSSの可能性
   - 該当: src/auth/login.ts:45
   - 修正: ユーザー入力をエスケープ

2. [MEDIUM] テストが不足
   - 該当: src/auth/login.test.ts
   - 修正: エラーケースのテスト追加
```

### Step 3: 修正ループ

```
修正指示
    ↓
Codex 再実行（修正指示を prompt に追加）
    ↓
品質ゲート
    ↓
再レビュー
    ↓
最大2回まで → 失敗時は手動対応
```

## Merge Strategy

### cherry-pick（デフォルト）

```bash
# メインブランチで実行
git cherry-pick <worker-commit-hash>

# 競合発生時
git cherry-pick --abort  # 中断
# → ユーザーに通知
```

### squash merge（オプション）

全 Worker 完了後に squash:

```bash
# 全 Worker のコミットを squash
git merge --squash worker-branch
git commit -m "feat: Phase X 完了"
```

### 競合時の対応

```
競合検出
    ↓
Orchestrator が通知
    ↓
ユーザーが判断:
  - 手動解決 → 続行
  - Worker 再実行 → 再試行
  - 中断 → 後で対応
```

**責任分界**:
- 競合検出: Orchestrator
- 解決判断: ユーザー
- 自動解決: 行わない（安全性優先）

## Plans.md Update

タスク完了時に自動更新:

```markdown
# Before
- [ ] **1. ログイン機能** `cc:WIP`

# After
- [x] **1. ログイン機能** `cc:done`
```

更新内容:
- `cc:WIP` → `cc:done`
- チェックボックス: `[ ]` → `[x]`

## Script Usage

```bash
./scripts/codex-worker-merge.sh \
  --worktree ../worktrees/worker-1 \
  --target-branch main \
  [--squash]
```

### オプション

| オプション | 説明 | デフォルト |
|-----------|------|-----------|
| `--worktree PATH` | Worker の worktree | 必須 |
| `--target-branch BRANCH` | マージ先ブランチ | main |
| `--squash` | squash merge を使用 | false |
| `--dry-run` | 実際にマージせず確認のみ | false |

### 出力形式

```json
{
  "status": "merged" | "conflict" | "failed",
  "commit_hash": "abc1234...",
  "conflicts": [],
  "plans_updated": true
}
```

## Related

- [quality-gates.md](./quality-gates.md) - 品質ゲート
- [worker-execution.md](./worker-execution.md) - Worker 実行フロー
- [parallel-strategy.md](./parallel-strategy.md) - 並列実行戦略
