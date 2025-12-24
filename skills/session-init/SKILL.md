---
name: session-init
description: "Initializes session with environment check and task status overview. Use when user mentions セッション開始, 作業開始, 状況確認, what should I work on, start session. Do NOT load for: 実装作業, レビュー, セッション途中の作業."
allowed-tools: ["Read", "Write", "Bash"]
metadata:
  skillport:
    category: core
    tags: [session, init, startup, status]
    alwaysApply: false
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

---

## 実行手順

### Step 0: ファイル状態チェック（自動整理）

セッション開始前にファイルサイズをチェック：

```bash
# Plans.md の行数チェック
if [ -f "Plans.md" ]; then
  lines=$(wc -l < Plans.md)
  if [ "$lines" -gt 200 ]; then
    echo "⚠️ Plans.md が ${lines} 行です。/cleanup で整理を推奨"
  fi
fi

# session-log.md の行数チェック
if [ -f ".claude/memory/session-log.md" ]; then
  lines=$(wc -l < .claude/memory/session-log.md)
  if [ "$lines" -gt 500 ]; then
    echo "⚠️ session-log.md が ${lines} 行です。/cleanup sessions で整理を推奨"
  fi
fi
```

整理が必要な場合は提案を表示（作業には影響しない）。

### Step 0.5: Claude-mem 文脈確認（オプション）

Claude-mem が有効な場合、過去の文脈を自動表示：

```bash
# Claude-mem の状態チェック
if [ -f "$HOME/.claude-mem/settings.json" ]; then
  mode=$(cat ~/.claude-mem/settings.json | grep -o '"CLAUDE_MEM_MODE"[^,}]*' | cut -d'"' -f4)
  if [ "$mode" = "harness" ] || [ "$mode" = "harness--ja" ]; then
    echo "📚 Claude-mem (harness モード) が有効です"
  fi
fi
```

**Claude-mem 有効時に表示する内容**:

1. **過去のガードレール発動**:
   - `mem-search` で `guard` タイプの観測を検索
   - 「このプロジェクトでは過去 N 回テスト改ざんを防止」

2. **直近の作業サマリー**:
   - 最新のセッションサマリーを表示
   - 「前回: Feature X の設計完了」

3. **継続タスクの提案**:
   - Plans.md と組み合わせて次のアクションを提案

```markdown
## 📚 過去の文脈（Claude-mem）

**ガードレール履歴**:
- テスト改ざん防止: 2回

**前回のセッション**:
- Feature X 設計完了
- RBAC 採用を決定

**💡 継続推奨**: Plans.md の「Feature X 実装」から開始
```

> **注**: Claude-mem が未設定の場合、このステップはスキップされます。

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
- `/cleanup` - ファイルの自動整理

---

## 注意事項

- **AGENTS.md を必ず確認**: 役割分担を把握してから作業開始
- **Plans.md が無い場合**: `/harness-init` を案内
- **前回の作業が中断している場合**: 継続するか確認
