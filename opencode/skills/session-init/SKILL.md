---
name: session-init
description: "環境チェックとタスク状況概要でセッション初期化。Use when user mentions starting a session, beginning work, or status checks. Do NOT load for: implementation work, reviews, or mid-session tasks."
description-en: "Initializes session with environment checks and task status overview. Use when user mentions starting a session, beginning work, or status checks. Do NOT load for: implementation work, reviews, or mid-session tasks."
description-ja: "環境チェックとタスク状況概要でセッション初期化。Use when user mentions starting a session, beginning work, or status checks. Do NOT load for: implementation work, reviews, or mid-session tasks."
allowed-tools: ["Read", "Write", "Bash"]
user-invocable: false
---

# Session Init Skill

セッション開始時の環境確認と現在のタスク状況把握を行うスキル。

---

## トリガーフレーズ

このスキルは以下のフレーズで起動します：

- 「セッション開始」
- 「作業開始」
- 「今日の作業を始める」
- 「状況を確認して」
- 「何をすればいい？」
- "start session"
- "what should I work on?"

---

## 概要

Session Init スキルは、Claude Code セッション開始時に自動的に以下を確認します：

1. **Git 状態**: 現在のブランチ、未コミットの変更
2. **Plans.md**: 進行中タスク、依頼されたタスク
3. **AGENTS.md**: 役割分担、禁止事項の確認
4. **前回セッション**: 引き継ぎ事項の確認
5. **最新 snapshot**: 進捗スナップショットの要約と前回差分

---

## 実行手順

### Step 0: ファイル状態チェック（自動整理）

セッション開始前にファイルサイズをチェック：

```bash
# Plans.md の行数チェック
if [ -f "Plans.md" ]; then
  lines=$(wc -l < Plans.md)
  if [ "$lines" -gt 200 ]; then
    echo "⚠️ Plans.md が ${lines} 行です。「整理して」で整理を推奨"
  fi
fi

# session-log.md の行数チェック
if [ -f ".claude/memory/session-log.md" ]; then
  lines=$(wc -l < .claude/memory/session-log.md)
  if [ "$lines" -gt 500 ]; then
    echo "⚠️ session-log.md が ${lines} 行です。「セッションログを整理して」で整理を推奨"
  fi
fi
```

整理が必要な場合は提案を表示（作業には影響しない）。

### Step 0.5: 旧ローカルメモリ互換の扱い（任意）

現在の標準は Step 0.7 の Unified Harness Memory です。
旧ローカルメモリ互換の確認は原則不要で、特別な移行確認が必要な場合だけ個別に参照します。

> **注**: 通常運用ではこのステップをスキップし、共通DB の Resume Pack を唯一の再開導線として扱います。

### Step 0.7: Unified Harness Memory Resume Pack（必須）

Codex / Claude / OpenCode 共通DB（`~/.harness-mem/harness-mem.db`）から再開文脈を取得する。

必須呼び出し:

```text
harness_mem_resume_pack(project, session_id?, limit=5, include_private=false)
```

運用ルール:
- `project` は必ず現在プロジェクト名を指定
- `session_id` は `$CLAUDE_SESSION_ID` → `.claude/state/session.json` の `.session_id` の順で取得する
- `harness_mem_sessions_list(project, limit=1)` の先頭利用は read-only（resume確認）に限定し、`record_checkpoint` / `finalize_session` での書き込みには使わない
- 取得結果はセッション開始時コンテキストに注入
- 取得失敗時は `harness_mem_health()` で daemon 状態を確認し、失敗を明示して続行
- 復旧は `scripts/harness-memd doctor` → `scripts/harness-memd cleanup-stale` → `scripts/harness-memd start` の順で行う

### Step 1: 環境確認

以下を並列で実行：

```bash
# Git状態
git status -sb
git log --oneline -3
```

```bash
# Plans.md
cat Plans.md 2>/dev/null || echo "Plans.md not found"
```

```bash
# AGENTS.md の要点
head -50 AGENTS.md 2>/dev/null || echo "AGENTS.md not found"
```

### Step 2: タスク状況の把握

Plans.md から以下を抽出：

- `cc:WIP` - 前回から継続中のタスク
- `pm:依頼中` - PM から新規依頼されたタスク（互換: cursor:依頼中）
- `cc:TODO` - 未着手だが割り当て済みのタスク

### Step 3: 状況レポートの出力

```markdown
## 🚀 セッション開始

**日時**: {{YYYY-MM-DD HH:MM}}
**ブランチ**: {{branch}}
**セッションID**: ${CLAUDE_SESSION_ID}

---

### 📋 今日のタスク

**優先タスク**:
- {{pm:依頼中（互換: cursor:依頼中） または cc:WIP のタスク}}

**その他のタスク**:
- {{cc:TODO のタスク一覧}}

---

### ⚠️ 注意事項

{{AGENTS.md からの重要な制約・禁止事項}}

---

**作業を開始しますか？**
```

---

## 出力フォーマット

セッション開始時は、以下の情報を簡潔に提示：

| 項目 | 内容 |
|------|------|
| 現在のブランチ | `staging` など |
| 優先タスク | 最も重要な 1-2 件 |
| 注意事項 | 禁止事項の要約 |
| 次のアクション | 具体的な提案 |

---

## 関連コマンド

- `/work` - タスク実行（並列実行対応）
- `/sync-status` - Plans.md の進捗サマリー
- `/maintenance` - ファイルの自動整理

---

## 注意事項

- **AGENTS.md を必ず確認**: 役割分担を把握してから作業開始
- **Plans.md が無い場合**: `/harness-init` を案内
- **前回の作業が中断している場合**: 継続するか確認
