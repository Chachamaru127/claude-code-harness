# Parallel Execution Strategy

並列 Codex Worker 実行戦略。

## Overview

```
Claude Code (Orchestrator)
    │
    ├─ Worker A ─→ ../worktrees/worker-a ─→ タスク A
    ├─ Worker B ─→ ../worktrees/worker-b ─→ タスク B
    └─ Worker C ─→ ../worktrees/worker-c ─→ タスク C
    │
    └─ 全完了後 → マージ → Plans.md 更新
```

## Prerequisites

1. **タスクの独立性**: 担当ファイルが重複しないこと
2. **git worktree サポート**: Git 2.5+
3. **十分なディスク容量**: 各 worktree に必要な容量

## Worktree Management

### Creation

```bash
git worktree add ../worktrees/worker-${WORKER_ID} HEAD
git worktree list
```

### Cleanup

```bash
git worktree remove ../worktrees/worker-${WORKER_ID}
git worktree prune
```

### Naming Convention

```
../worktrees/worker-{id}/
../worktrees/worker-1/
../worktrees/worker-2/
```

## Parallel Execution Flow

### Step 1: タスク分析 & グループ化

タスクを担当ファイルの重複でグループ化:
- 重複なし → 同一グループ（並列可）
- 重複あり → 別グループ（sequential）

### Step 2: 並列実行

グループ内のタスクを並列実行:
1. Worktree 作成
2. ロック取得
3. Codex Worker 実行
4. 品質ゲート・マージ
5. ロック解放（マージ完了後）

### Step 3: マージ戦略

1. Worktree 内でコミット作成
2. コミットハッシュ取得
3. メインブランチに cherry-pick
4. 競合発生時 → ユーザー判断
5. Worktree 削除

## Configuration

### ultrawork --codex Options

```bash
# 基本（デフォルト並列数: 3）
/ultrawork --codex 全部やって

# 並列数を指定
/ultrawork --codex --parallel 5 全部やって

# シーケンシャル実行
/ultrawork --codex --parallel 1 ログイン機能を実装して
```

### Default Settings

```json
{
  "parallel": {
    "enabled": true,
    "max_workers": 3,
    "worktree_base": "../worktrees"
  }
}
```

## Error Handling

### Worker 失敗時

- エラーログ記録
- Worktree を保持（デバッグ用）
- 他の Worker は継続
- 失敗タスクは後で再実行

### 競合発生時

1. 競合を検出
2. 全 Worker を一時停止
3. ユーザーに通知
4. 手動解決 or 自動リトライ選択
5. 解決後、残りの Worker を再開

## Performance Considerations

### Disk Usage

各 worktree ≈ リポジトリサイズ - .git（.git は共有）

例: 100MB リポジトリ、3 Worker = 300MB 追加使用

### API Rate Limits

Codex API には rate limit あり。並列数を増やしすぎると throttle される可能性。

**推奨**: max_workers = 3

### Memory Usage

各 Worker プロセスが独立。大規模プロジェクトでは並列数を制限。

## Monitoring

### Progress Display

```
🚀 Parallel Execution Started
├─ Worker 1: ログイン機能 [████████░░] 80%
├─ Worker 2: API実装     [██████████] 100% ✅
└─ Worker 3: UI作成      [██░░░░░░░░] 20%

Completed: 1/3 | In Progress: 2 | Failed: 0
```

### Logs

保存先: `.claude/state/parallel-execution.log`

```
2026-02-02T10:00:00Z worker-1 started task-1
2026-02-02T10:05:00Z worker-2 completed task-2
2026-02-02T10:10:00Z worker-1 failed task-1 (lint error)
2026-02-02T10:15:00Z worker-1 retry task-1
```
