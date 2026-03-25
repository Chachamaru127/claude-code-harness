---
name: harness-plan
description: "Unified planning skill for Harness v3. Handles task planning, Plans.md management, and progress sync. Use when user mentions: create a plan, add tasks, update Plans.md, mark complete, check progress, sync status, where am I, harness-plan, harness-sync. Do NOT load for: implementation, code review, or release tasks."
description-ja: "Harness v3 統合プランニングスキル。タスク計画・Plans.md管理・進捗同期を担当。以下のフレーズで起動: 計画を作る、タスクを追加、Plans.md更新、完了マーク、進捗確認、harness-plan、harness-sync。実装・レビュー・リリースには使わない。"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob", "WebSearch", "Task"]
argument-hint: "[create|add|update|sync|sync --no-retro|--ci]"
effort: high
---

# Harness Plan (v3)

Harness v3 の統合プランニングスキル。
以下の3つの旧スキルを統合:

- `planning` (plan-with-agent) — アイデア → Plans.md への落とし込み
- `plans-management` — タスク状態管理・マーカー更新
- `sync-status` — Plans.md と実装の同期確認

## Quick Reference

| ユーザー入力 | サブコマンド | 動作 |
|------------|------------|------|
| "計画を作って" / "create a plan" | `create` | 対話型ヒアリング → Plans.md 生成 |
| "タスクを追加して" / "add a task" | `add` | Plans.md に新タスク追加 |
| "完了にして" / "mark complete" | `update` | タスクマーカーを cc:完了 に変更 |
| "今どこ？" / "check progress" | `sync` | 実装とPlans.mdを照合・同期 |
| `harness-sync` | `sync` | 進捗確認（独立 sync surface と同等） |
| `harness-plan create` | `create` | 計画作成 |

## サブコマンド詳細

### create — 計画作成

See [references/create.md](${CLAUDE_SKILL_DIR}/references/create.md)

アイデア・要件をヒアリングし、実行可能な Plans.md を生成する。

**フロー**:
1. 会話コンテキスト確認（直前の議論から抽出 or 新規ヒアリング）
2. 何を作るか聞く（max 3問）
3. 技術調査（WebSearch）
4. 機能リスト抽出
5. 優先度マトリクス（Required / Recommended / Optional）
6. TDD 採用判断（テスト設計）
7. Plans.md 生成（`cc:TODO` マーカー付き）
8. 次のアクション案内

**CI モード** (`--ci`):
ヒアリングなし。既存の Plans.md をそのまま利用してタスク分解のみ行う。

### add — タスク追加

Plans.md に新しいタスクを追加する。

```
harness-plan add タスク名: 詳細説明 [--phase フェーズ番号]
```

タスクは `cc:TODO` マーカーで追加される。

### update — マーカー更新

タスクのステータスマーカーを変更する。

```
harness-plan update [タスク名|タスク番号] [WIP|完了|blocked]
```

マーカー対応表:

| コマンド | マーカー |
|---------|---------|
| `WIP` | `cc:WIP` |
| `完了` / `done` | `cc:完了` |
| `blocked` | `blocked` |
| `TODO` | `cc:TODO` |

### sync — 進捗同期

実装状況と Plans.md を照合し、差分を検出・更新する。

See [references/sync.md](${CLAUDE_SKILL_DIR}/references/sync.md)

**フロー**:
1. Plans.md の現状取得
2. Plans.md フォーマット検出（v1: 3 カラム / v2: 5 カラム）
3. git status / git log から実装状況取得
4. エージェントトレース確認（`.claude/state/agent-trace.jsonl`）
5. Plans.md と実装の差分検出
6. 未更新マーカーの自動修正提案
7. 次のアクション提示

**レトロスペクティブ**（デフォルト ON）:
`cc:完了` タスクが 1 件以上あれば自動的に振り返りを実行する。
見積もり精度、ブロック原因パターン、スコープ変動を分析し、学びを記録。
`sync --no-retro` で明示的にスキップ可能。

## Plans.md フォーマット規約

### フォーマット

```markdown
# [プロジェクト名] Plans.md

作成日: YYYY-MM-DD

---

## Phase N: フェーズ名

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| N.1  | 説明 | テスト通過 | - | cc:TODO |
| N.2  | 説明 | lint エラー 0 | N.1 | cc:WIP |
| N.3  | 説明 | マイグレーション実行可能 | N.1, N.2 | cc:完了 |
```

**DoD（Definition of Done）**: 検証可能な完了条件を 1 行で記述。「いい感じ」「ちゃんと動く」は禁止。Yes/No で判定できる形にする。

**Depends**: タスク間の依存関係。`-`（依存なし）、タスク番号（`N.1`）、カンマ区切り（`N.1, N.2`）、フェーズ依存（`Phase N`）。

### マーカー一覧

| マーカー | 意味 |
|---------|------|
| `pm:依頼中` | PM から依頼済み |
| `cc:TODO` | 未着手 |
| `cc:WIP` | 作業中 |
| `cc:完了` | Worker 作業完了 |
| `pm:確認済` | PM レビュー完了 |
| `blocked` | ブロック中（理由を必ず記載） |

## 関連スキル

- `harness-sync` — 実装と Plans.md を同期する
- `harness-work` — 計画したタスクを実装する
- `harness-review` — 実装のレビュー
- `harness-setup` — プロジェクト初期化
