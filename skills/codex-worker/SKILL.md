---
name: codex-worker
description: "Delegates implementation tasks to Codex as a Worker. Use when user mentions 'Codex に実装させて', 'Codex Worker', 'Codex に作らせて', or '実装を依頼'. Do NOT load for: 'Codex レビュー', 'セカンドオピニオン', 'Codex の意見', 'Codex でレビュー', 'Codex セットアップ'."
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep", "Task"]
argument-hint: "[task description]"
---

# Codex Worker Skill

Claude Code を PM/Orchestrator として、Codex を Worker として実装を委譲するスキル。

## Philosophy

> **「Claude Code = 設計・レビュー、Codex = 実装」**
>
> 高レベルな判断は Claude Code、実装の細部は Codex に任せる分業体制。

## Quick Reference

- "**Codex に実装させて**" → this skill
- "**Codex Worker**" → this skill
- "**Codex に作らせて**" → this skill
- "**実装を依頼**" → this skill

## Do NOT Load For (誤発動防止)

以下のキーワードは `codex-review` スキルが担当します（description と完全一致）:

| トリガーワード | 正しいスキル | 理由 |
|---------------|-------------|------|
| "**Codex レビュー**" | `codex-review` | レビュー = 品質チェック |
| "**セカンドオピニオン**" | `codex-review` | 意見取得 ≠ 実装 |
| "**Codex の意見**" | `codex-review` | 意見 ≠ Worker |
| "**Codex でレビュー**" | `codex-review` | レビュー目的 |
| "**Codex セットアップ**" | `codex-review` | MCP 設定 |

## Feature Details

| Feature | Reference |
|---------|-----------|
| **Setup** | See [references/setup.md](references/setup.md) |
| **Worker Execution** | See [references/worker-execution.md](references/worker-execution.md) |
| **Task Ownership** | See [references/task-ownership.md](references/task-ownership.md) |
| **Parallel Strategy** | See [references/parallel-strategy.md](references/parallel-strategy.md) |
| **Quality Gates** | See [references/quality-gates.md](references/quality-gates.md) |
| **Review & Integration** | See [references/review-integration.md](references/review-integration.md) |

## Execution Flow

```
1. タスク受信
    ↓
2. base-instructions 生成
   - Rules 連結
   - AGENTS.md 強制読み込み指示
    ↓
3. git worktree 準備（並列時）
    ↓
4. mcp__codex__codex 呼び出し
   - prompt: タスク内容 + AGENTS_SUMMARY 証跡出力指示
   - cwd: worktree パス
   - approval-policy: never
   - sandbox: workspace-write
    ↓
5. 結果検証
   - AGENTS_SUMMARY 証跡確認
   - 不合格時: 合計3回試行
    ↓
6. Orchestrator レビュー
   - 品質ゲート（lint, test, 改ざん検出）
   - 修正指示 → 再実行ループ
    ↓
7. マージ・Plans.md 更新
```

## MCP Parameters (D20)

```json
{
  "prompt": "タスク内容 + AGENTS_SUMMARY 証跡出力指示",
  "base-instructions": "Rules 連結 + AGENTS.md 強制読み込み指示",
  "cwd": "/path/to/worktree",
  "approval-policy": "never",
  "sandbox": "workspace-write"
}
```

## AGENTS.md Compliance

Worker は実行開始時に以下を出力する必要がある:

```
AGENTS_SUMMARY: <1行要約> | HASH:<SHA256先頭8文字>
```

- 入力: AGENTS.md ファイル内容（BOM除去、全行LF正規化）
- アルゴリズム: SHA256、Hex小文字、先頭8文字
- 欠落時: 即失敗 → 手動対応

## 完了時の必須アクション

**重要**: Codex の作業が完了したら、Claude Code は必ず以下を実行すること。

### Plans.md 更新手順

1. **該当タスクを特定**
   - ユーザーの依頼内容と Plans.md のタスクを照合
   - 該当するタスク行を見つける

2. **ステータス更新**
   ```markdown
   # Before
   - [ ] **タスク名** `cc:WIP`

   # After
   - [x] **タスク名** `cc:done`
   ```
   - チェックボックス: `[ ]` → `[x]`
   - マーカー: `cc:WIP` → `cc:done`

3. **更新しない場合**
   - Plans.md が存在しない
   - 該当するタスクが見つからない
   - ユーザーが明示的に「Plans.md は更新しないで」と指示した場合

### 例外処理

タスクが Plans.md にない場合は、ユーザーに確認:

```
✅ Codex による実装が完了しました。

Plans.md に該当タスクが見つかりませんでした。
- タスクを追加しますか？
- または既存タスクを更新しますか？
```

## Related Skills

- `codex-review` - Codex によるレビュー・セカンドオピニオン
- `ultrawork` - `--codex` モードで Worker 並列実行
- `impl` - Claude Code 自身による実装
