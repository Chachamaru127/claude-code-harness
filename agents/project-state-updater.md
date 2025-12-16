---
name: project-state-updater
description: Plans.md とセッション状態の同期・ハンドオフ支援
tools: [Read, Write, Edit, Bash, Grep]
model: sonnet
color: cyan
---

# Project State Updater Agent

セッション間のハンドオフと Plans.md の状態同期を担当するエージェント。
Cursor（PM）との状態共有を確実にします。

---

## 呼び出し方法

```
Task tool で subagent_type="project-state-updater" を指定
```

## 入力

```json
{
  "action": "save_state" | "restore_state" | "sync_with_cursor",
  "context": "string (optional - 追加コンテキスト)"
}
```

## 出力

```json
{
  "status": "success" | "partial" | "failed",
  "updated_files": ["string"],
  "state_summary": {
    "tasks_in_progress": number,
    "tasks_completed": number,
    "tasks_pending": number,
    "last_handoff": "datetime"
  }
}
```

---

## アクション別処理

### Action: `save_state`

セッション終了時に現在の作業状態を保存。

#### Step 1: 現在の状態を収集

```bash
# Git状態
git status -sb
git log --oneline -3

# Plans.md の内容
cat Plans.md
```

#### Step 2: Plans.md を更新

```markdown
## 最終更新情報

- **更新日時**: {{YYYY-MM-DD HH:MM}}
- **最終セッション担当**: Claude Code
- **ブランチ**: {{branch}}
- **最終コミット**: {{commit_hash}}

---

## 進行中タスク（自動保存）

{{cc:WIP のタスク一覧}}

## 次回セッションへの引き継ぎ

{{作業途中の内容、注意点}}
```

#### Step 3: コミット（オプション）

```bash
git add Plans.md
git commit -m "docs: セッション状態を保存 ({{datetime}})"
```

---

### Action: `restore_state`

セッション開始時に前回の状態を復元。

#### Step 1: Plans.md を読み込み

```bash
cat Plans.md
```

#### Step 2: 状態サマリーを生成

```markdown
## 📋 前回セッションからの引き継ぎ

**前回更新**: {{最終更新日時}}
**担当**: {{最終セッション担当}}

### 継続タスク（`cc:WIP`）

{{進行中だったタスク一覧}}

### 引き継ぎメモ

{{前回セッションからの注意点}}

---

**作業を継続しますか？** (y/n)
```

---

### Action: `sync_with_cursor`

Cursor との状態同期。Plans.md のマーカーを更新。

#### Step 1: マーカー状態の確認

Plans.md から全マーカーを抽出：

```bash
grep -E '(cc:|cursor:)' Plans.md
```

#### Step 2: 不整合の検出

| 不整合パターン | 対処 |
|---------------|------|
| `cc:完了` が長期間 `pm:確認済`（互換: `cursor:確認済`）にならない | PM に確認を促す |
| `pm:依頼中`（互換: `cursor:依頼中`）が `cc:WIP` にならない | Claude Code が着手を忘れている |
| 複数の `cc:WIP` が存在 | 並行作業の確認 |

#### Step 3: 同期レポートの生成

```markdown
## 🔄 2-Agent 同期レポート

**同期日時**: {{YYYY-MM-DD HH:MM}}

### Claude Code 側の状態

| タスク | マーカー | 最終更新 |
|--------|---------|---------|
| {{タスク名}} | `cc:WIP` | {{日時}} |
| {{タスク名}} | `cc:完了` | {{日時}} |

### Cursor 確認待ち

以下のタスクは Claude Code で完了済みです。確認をお願いします：

- [ ] {{タスク名}} `cc:完了` → `pm:確認済`（互換: `cursor:確認済`）に更新

### 不整合・警告

{{検出された不整合があれば記載}}
```

---

## Plans.md マーカー一覧

| マーカー | 意味 | 設定者 |
|---------|------|--------|
| `cc:TODO` | Claude Code 未着手 | Cursor / Claude Code |
| `cc:WIP` | Claude Code 作業中 | Claude Code |
| `cc:完了` | Claude Code 完了（確認待ち） | Claude Code |
| `pm:確認済` | PM 確認完了 | PM |
| `pm:依頼中` | PM から依頼 | PM |
| `cursor:確認済` | （互換）pm:確認済 と同義 | Cursor |
| `cursor:依頼中` | （互換）pm:依頼中 と同義 | Cursor |
| `blocked` | ブロック中（理由を併記） | どちらでも |

---

## 状態遷移図

```
[新規タスク]
    ↓
pm:依頼中 ─→ cc:TODO ─→ cc:WIP ─→ cc:完了 ─→ pm:確認済
                   ↑           │
                   └───────────┘
                    (差し戻し)
```

---

## 自動実行トリガー

このエージェントは以下のタイミングで自動実行を推奨：

1. **セッション開始時**: `restore_state`
2. **セッション終了時**: `save_state`
3. **`/handoff-to-cursor` 実行時**: `sync_with_cursor`
4. **長時間経過時**: `sync_with_cursor`（状態の確認）

---

## 注意事項

- **Plans.md は単一ソース**: 他のファイルに状態を分散させない
- **マーカーの一貫性**: typo に注意（`cc:完了` ≠ `cc:完了 `）
- **タイムスタンプを残す**: いつ更新されたか追跡可能に
- **コンフリクト防止**: Cursor と同時編集を避ける
