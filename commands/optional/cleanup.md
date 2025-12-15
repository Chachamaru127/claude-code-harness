---
description: Plans.md / session-log.md 等の自動整理
---

# /cleanup - ファイルの自動整理

Plans.md、session-log.md 等の古いエントリを整理し、ファイルの肥大化を防ぎます。

---

## いつ使うべきか？

### このコマンドを使うタイミング

| シグナル | 対処 |
|---------|------|
| `⚠️ Plans.md が 200行を超えました` という警告が出た | `/cleanup plans` |
| `⚠️ session-log.md が肥大化しています` という警告が出た | `/cleanup sessions` |
| Plans.md のスクロールが長くて見づらい | `/cleanup plans` |
| 「完了タスクが多すぎて今やるべきことが分からない」 | `/cleanup plans` |
| プロジェクトを一区切りしたとき（リリース後など） | `/cleanup` |

### 使わなくていいケース

- Plans.md が 200行以下で読みやすい
- 警告メッセージが出ていない
- 完了タスクをまだ参照したい（アーカイブに移動されると見づらくなる）

---

## バイブコーダー向け（こう言えばOK）

- 「**Plans.md を整理して**」→ 完了タスクをアーカイブへ移して軽くします
- 「**ログが長いから短くして**」→ session-log を分割して読みやすくします
- 「**消していいか分からない**」→ 削除せず"移動/分割/アーカイブ"中心で安全に整理します

## できること（成果物）

- `Plans.md` / `.claude/memory/session-log.md` / `CLAUDE.md` などの **肥大化を抑える**
- バックアップを残しつつ、参照しやすい構造に整える

---

## 使い方

```
/cleanup              # 全ファイルをチェック＆整理
/cleanup --dry-run    # 実行せずプレビュー
/cleanup plans        # Plans.md のみ
/cleanup sessions     # session-log のみ
```

---

## 整理ルール

| ファイル | 条件 | アクション |
|---------|------|-----------|
| **Plans.md** | 完了から7日経過 | 📦 アーカイブセクションへ移動 |
| **Plans.md** | 200行超過 | 警告 + 整理提案 |
| **session-log.md** | 30日経過 | 月別ファイルに分割 |
| **session-log.md** | 500行超過 | 警告 + 分割提案 |
| **CLAUDE.md** | 100行超過 | 警告 + docs/ 分割提案 |

---

## 実行フロー

### Step 1: 現状確認

```bash
# ファイルサイズを確認
wc -l Plans.md .claude/memory/session-log.md CLAUDE.md 2>/dev/null

# 完了タスク数を確認
grep -c "\[x\]" Plans.md

# 7日以上前の完了タスクを確認
grep -E "\[x\].*\([0-9]{4}-[0-9]{2}-[0-9]{2}\)" Plans.md
```

### Step 2: レポート出力

```markdown
## 📊 ファイル状態レポート

| ファイル | 行数 | 上限 | 状態 |
|---------|------|------|------|
| Plans.md | {{lines}} | 200 | {{status}} |
| session-log.md | {{lines}} | 500 | {{status}} |
| CLAUDE.md | {{lines}} | 100 | {{status}} |

### Plans.md 詳細
- 進行中: {{wip_count}} 件
- 未着手: {{todo_count}} 件
- 完了: {{done_count}} 件
- アーカイブ対象: {{archive_target}} 件（7日以上前）
```

### Step 3: 整理実行（確認後）

```markdown
## ✅ 整理を実行しますか？

**実行される処理:**
1. Plans.md: {{archive_target}} 件のタスクをアーカイブへ移動
2. session-log.md: 30日以上前のログを月別ファイルに分割

**バックアップ先:**
- `.claude/memory/archive/Plans-{{DATE}}.md`
- `.claude/memory/archive/sessions/{{YYYY-MM}}.md`

「OK」または「実行して」で開始
「キャンセル」で中止
```

### Step 4: 実行結果

```markdown
## ✅ 整理完了

### Plans.md
- 移動前: {{before_lines}} 行
- 移動後: {{after_lines}} 行
- 削減: {{reduced}} 行 ({{percent}}%)
- アーカイブ: {{archived_count}} タスク

### session-log.md
- 分割: {{split_count}} エントリ
- 作成ファイル: `.claude/memory/archive/sessions/2025-01.md`

### バックアップ
- `.claude/memory/archive/Plans-2025-01-15.md`
```

---

## --dry-run オプション

実際の変更を行わず、何が実行されるかをプレビュー：

```
/cleanup --dry-run
```

出力例：

```
📋 **ドライラン結果（実際の変更は行いません）**

### Plans.md
- 移動対象: 8 タスク
- 削減予定: 約 50 行

### session-log.md
- 分割対象: 15 エントリ
- 作成予定: 2 ファイル

実行するには `/cleanup` を実行してください。
```

---

## 設定のカスタマイズ

`.claude-code-harness.config.yaml` で閾値を変更可能：

```yaml
cleanup:
  plans:
    archive_after_days: 14     # 7日 → 14日に変更
    max_lines: 300             # 200行 → 300行に変更
```

---

## 自動実行

### セッション開始時

`session-init` スキルから自動的にチェックが実行されます。
整理が必要な場合は提案が表示されます。

### ファイル書き込み時

PostToolUse Hook により、Plans.md への書き込み後に自動チェック。
閾値を超えた場合は警告が表示されます。

---

## 注意事項

- **進行中タスクは対象外**: `cc:WIP`、`pm:依頼中`（互換: `cursor:依頼中`）は移動しません
- **バックアップを自動作成**: 整理前に必ずバックアップされます
- **元に戻す**: バックアップから復元可能です

---

## 関連コマンド

| コマンド | 用途 |
|---------|------|
| `/sync-status` | 現在の状態を確認 |
| `/start-session` | セッション開始（自動チェック含む） |
