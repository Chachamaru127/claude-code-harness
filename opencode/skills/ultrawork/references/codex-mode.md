# Codex Mode

> **Status: Experimental**
>
> この機能は実装済みですが、実験段階です。本番環境での使用前にテストを推奨します。

`/ultrawork --codex` で Codex Worker を使った並列実行モード。

## Overview

```
Claude Code (Orchestrator)
    │
    ├─ タスク分析 & グループ化
    │     - Plans.md からタスク取得
    │     - owns: アノテーションで担当ファイル特定
    │     - 重複なし → 並列グループ
    │     - 重複あり → 順次グループ
    │
    ├─ 並列実行
    │     ├─ Worker A ─→ ../worktrees/worker-a ─→ タスク A
    │     ├─ Worker B ─→ ../worktrees/worker-b ─→ タスク B
    │     └─ Worker C ─→ ../worktrees/worker-c ─→ タスク C
    │
    ├─ 品質ゲート
    │     - AGENTS_SUMMARY 証跡検証
    │     - lint / test 実行
    │     - 改ざん検出
    │
    └─ マージ & 完了
          - cherry-pick / merge
          - Plans.md 更新
          - Worktree クリーンアップ
```

## Usage

```bash
# 基本（並列数はデフォルト 3）
/ultrawork --codex 全部やって

# 並列数を指定
/ultrawork --codex --parallel 5 認証機能から完了して

# シーケンシャル実行（並列なし）
/ultrawork --codex --parallel 1 ログイン機能を実装
```

## Options

| オプション | 説明 | デフォルト |
|-----------|------|-----------|
| `--codex` | Codex Worker モードを有効化 | - |
| `--parallel N` | 並列 Worker 数 | 3 |
| `--worktree-base PATH` | Worktree 作成先 | `../worktrees` |

## Prerequisites

1. **Codex CLI**: `codex --version` >= 0.92.0
2. **MCP 登録**: `claude mcp list` に codex が含まれる
3. **Git worktree**: `git --version` >= 2.5.0

セットアップ確認:
```bash
./scripts/codex-worker-setup.sh --check-only
```

## Execution Flow

### Step 1: タスク分析

```json
{
  "tasks": [
    {"id": "task-1", "owns": ["src/auth/*"], "group": 1},
    {"id": "task-2", "owns": ["src/api/*"], "group": 1},
    {"id": "task-3", "owns": ["src/auth/*"], "group": 2}
  ],
  "groups": [
    {"id": 1, "parallel": true, "tasks": ["task-1", "task-2"]},
    {"id": 2, "parallel": false, "tasks": ["task-3"]}
  ]
}
```

### Step 2: Worktree 作成

```bash
git worktree add ../worktrees/worker-1 HEAD
git worktree add ../worktrees/worker-2 HEAD
```

### Step 3: ロック取得

```bash
./scripts/codex-worker-lock.sh acquire --path "src/auth/*" --worker worker-1
./scripts/codex-worker-lock.sh acquire --path "src/api/*" --worker worker-2
```

### Step 4: 並列 Worker 実行

各 Worker は独立した worktree で動作:

```bash
# Worker 1
./scripts/codex-worker-engine.sh --task "タスク1" --worktree ../worktrees/worker-1

# Worker 2 (並列)
./scripts/codex-worker-engine.sh --task "タスク2" --worktree ../worktrees/worker-2
```

MCP 呼び出し:
```json
{
  "prompt": "タスク内容 + AGENTS_SUMMARY 証跡出力指示",
  "base-instructions": "Rules 連結 + AGENTS.md 強制読み込み指示",
  "cwd": "/path/to/worktree",
  "approval-policy": "never",
  "sandbox": "workspace-write"
}
```

### Step 5: 証跡検証

各 Worker の出力に AGENTS_SUMMARY があることを確認:

```
AGENTS_SUMMARY: タスク1の実装を完了 | HASH:a1b2c3d4
```

- 正規表現: `/AGENTS_SUMMARY:\s*(.+?)\s*\|\s*HASH:([A-Fa-f0-9]{8})/`
- 証跡欠落 → 即失敗（再試行なし、手動対応）
- ハッシュ不一致 → 再試行（最大 3 回）

### Step 6: 品質ゲート

```bash
npm run lint
npm test
```

失敗時:
- lint エラー → 自動修正指示 → 再実行
- テスト失敗 → 修正指示 → 再実行（最大 3 回）
- 改ざん検出 → 即座に中断 → 手動対応

### Step 7: マージ

```bash
# Worktree でコミット
cd ../worktrees/worker-1
git add .
git commit -m "feat: タスク1の実装"

# メインブランチに cherry-pick
cd /original/repo
git cherry-pick <commit-hash>
```

### Step 8: クリーンアップ

```bash
./scripts/codex-worker-lock.sh release --path "src/auth/*" --worker worker-1
git worktree remove ../worktrees/worker-1
git worktree prune
```

## Error Handling

### Worker 失敗時

- エラーログ記録
- Worktree を保持（デバッグ用）
- 他の Worker は継続
- 失敗タスクは後で再実行

### 競合発生時

1. 競合を検出
2. ユーザーに通知
3. 手動解決 or 自動リトライ選択
4. 解決後、残りの Worker を再開

## Monitoring

### Progress Display

```
🚀 Parallel Execution Started (--codex mode)
├─ Worker 1: ログイン機能 [████████░░] 80%
├─ Worker 2: API実装     [██████████] 100% ✅
└─ Worker 3: UI作成      [██░░░░░░░░] 20%

Completed: 1/3 | In Progress: 2 | Failed: 0
```

### Log Files

- `.claude/state/parallel-execution.log` - 並列実行ログ
- `.claude/state/locks.log` - ロック操作ログ
- `.claude/state/codex-worker/` - 各 Worker のパラメータ

## Related

- [codex-worker skill](../../codex-worker/SKILL.md) - 単体 Worker 実行
- [parallel-strategy.md](../../codex-worker/references/parallel-strategy.md) - 並列戦略詳細
- [task-ownership.md](../../codex-worker/references/task-ownership.md) - ロック機構詳細
