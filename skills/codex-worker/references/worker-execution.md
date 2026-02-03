# Worker Execution Flow

Codex Worker の実行フロー詳細。

## Overview

```
Claude Code (Orchestrator)
    │
    ├─ 1. タスク分析
    │     - Plans.md からタスク取得
    │     - 依存関係確認
    │     - 担当ファイル特定
    │
    ├─ 2. base-instructions 生成
    │     - Rules ファイル連結
    │     - AGENTS.md 読み込み指示
    │     - 証跡出力要求
    │
    ├─ 3. Worktree 準備（並列時）
    │     - git worktree add
    │     - ロック取得
    │
    ├─ 4. Codex Worker 呼び出し
    │     → Step 4 詳細参照（JSON形式）
    │
    ├─ 5. 結果検証
    │     - AGENTS_SUMMARY 証跡確認
    │     - 証跡欠落: 即失敗（手動対応）
    │     - ハッシュ不一致: 再実行（最大3回）
    │
    ├─ 6. 品質ゲート
    │     - lint チェック
    │     - テスト実行
    │     - 改ざん検出
    │
    └─ 7. マージ・完了
          - cherry-pick / merge
          - Plans.md 更新
          - ロック解放
```

## Step Details

### Step 1: タスク分析

タスク情報の構造:
```json
{
  "id": "task-1",
  "description": "ログイン機能の実装",
  "owns": ["src/auth/*", "src/pages/login.tsx"],
  "dependencies": [],
  "marker": "cc:TODO"
}
```

### Step 2: base-instructions 生成

1. `.claude/rules/` 配下の全 `.md` ファイルを収集
2. 連結して Rules セクションを作成
3. AGENTS.md 読み込み指示を追加:

```
最初に AGENTS.md を読み、以下の形式で証跡を出力してください:
AGENTS_SUMMARY: <1行要約> | HASH:<SHA256先頭8文字>

証跡を出力せずに作業を開始しないでください。
```

### Step 3: Worktree 準備

並列実行時のみ:
```bash
git worktree add ../worktrees/worker-task-1 HEAD
cd ../worktrees/worker-task-1
```

### Step 4: Codex Worker 呼び出し

MCP 経由で Codex を呼び出し:

```json
{
  "prompt": "タスク内容 + AGENTS_SUMMARY 証跡出力指示",
  "base-instructions": "Rules 連結 + AGENTS.md 強制読み込み指示",
  "cwd": "/path/to/worktree",
  "approval-policy": "never",
  "sandbox": "workspace-write"
}
```

各パラメータの詳細は D20 (`.claude/memory/decisions.md`) を参照。

### Step 5: 結果検証

AGENTS_SUMMARY 証跡を検証:
- 正規表現: `/AGENTS_SUMMARY:\s*(.+?)\s*\|\s*HASH:([A-Fa-f0-9]{8})/`
- ハッシュ: AGENTS.md の SHA256 先頭8文字と照合
- **証跡欠落**: 即失敗 → 手動対応（再試行なし）
- **ハッシュ不一致**: 最大3回試行 → 失敗時は手動対応

### Step 6: 品質ゲート

| ゲート | チェック内容 | 失敗時 |
|--------|-------------|--------|
| lint | `npm run lint` | 自動修正指示 → 再実行 |
| test | `npm test` | 修正指示 → 再実行（最大3回） |
| tamper | 改ざん検出 | 即座に中断 → 手動対応 |

### Step 7: マージ・完了

1. Worktree でコミット作成
2. メインブランチに cherry-pick
3. Worktree 削除
4. ロック解放

## Error Handling

### 証跡検証失敗

**証跡欠落（AGENTS_SUMMARY 行が存在しない）**:
- 即失敗 → 手動対応（再試行なし）
- Worker が AGENTS.md を読み込んでいない可能性

**ハッシュ不一致**:
1. 初回実行
2. 「AGENTS_SUMMARY を必ず出力してください」と再指示
3. より明確な指示で再実行
4. 3回目失敗 → 手動対応

### 品質ゲート失敗

| 失敗タイプ | 対応 |
|-----------|------|
| lint エラー | 自動修正指示 → 再実行 |
| テスト失敗 | 修正指示 → 再実行（最大3回） |
| 改ざん検出 | 即座に中断 → 手動対応 |

### マージ競合

Orchestrator が検出 → ユーザー判断を仰ぐ
自動解決は行わない（安全性優先）
