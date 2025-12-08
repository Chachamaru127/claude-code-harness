# /setup-2agent - 2エージェント体制セットアップ

Cursor (PM) と Claude Code (Worker) の2エージェント体制を一発でセットアップします。
両方のエージェントに必要なファイルを自動生成します。

---

## このコマンドの特徴

- 🎯 **ワンコマンドセットアップ**: 必要なファイルを全て自動生成
- 📁 **Cursor側設定も生成**: `.cursor/` にPM用コマンドを配置
- 📋 **Plans.md 自動作成**: 初期タスクリスト付き
- 🔗 **連携準備完了**: すぐに2エージェント体制で作業開始可能

---

## 使い方

```
/setup-2agent
```

または自然言語で：
- 「2エージェント体制をセットアップして」
- 「Cursorと連携できるようにして」

---

## 生成されるファイル

### Claude Code 側

```
./
├── AGENTS.md           # 開発フロー概要（両エージェント共通）
├── CLAUDE.md           # Claude Code 専用設定
├── Plans.md            # タスク管理（共有）
└── .claude/
    └── memory/         # セッション記憶用
        ├── session-log.md
        ├── decisions.md
        └── patterns.md
```

### Cursor 側

```
.cursor/
└── commands/
    ├── assign-to-cc.md      # タスク依頼コマンド
    └── review-cc-work.md    # 完了レビューコマンド
```

---

## 実行フロー

### Phase 1: 現状確認

```bash
# 既存ファイルをチェック
[ -f AGENTS.md ] && echo "AGENTS.md: 既存"
[ -f Plans.md ] && echo "Plans.md: 既存"
[ -d .cursor ] && echo ".cursor/: 既存"
```

### Phase 2: AGENTS.md 生成

```markdown
# AGENTS.md - 2エージェント開発フロー

## 概要

このプロジェクトは2つのAIエージェントが協調して開発を進めます：

| エージェント | 役割 | 担当 |
|-------------|------|------|
| **Cursor (PM)** | プロジェクト管理 | 計画・レビュー・本番デプロイ |
| **Claude Code (Worker)** | 実装担当 | コーディング・テスト・stagingデプロイ |

## ワークフロー

1. Cursor でタスクを計画・依頼 (`/assign-to-cc`)
2. Claude Code で実装 (`/start-task`)
3. Claude Code から完了報告 (`/handoff-to-cursor`)
4. Cursor でレビュー・承認 (`/review-cc-work`)
5. 本番デプロイ（Cursor判断）

## コミュニケーション

- **Plans.md**: タスク状態の共有
- **マーカー**: `cursor:依頼中` → `cc:WIP` → `cc:完了` → `cursor:確認済`
```

### Phase 3: Plans.md 生成

```markdown
# Plans.md

## 📋 プロジェクト概要

**プロジェクト名**: {{PROJECT_NAME}}
**開始日**: {{DATE}}
**ステータス**: セットアップ完了

---

## 🔴 フェーズ1: 初期セットアップ `cc:完了`

- [x] 2エージェント体制セットアップ `cc:完了`
- [ ] 環境変数の設定 `cc:TODO`
- [ ] 基本構造の確認 `cc:TODO`

## 🟡 フェーズ2: 開発開始 `cc:TODO`

- [ ] 機能1の実装
- [ ] 機能2の実装

---

## 📝 備考

Cursor で `/assign-to-cc` を使ってタスクを依頼してください。
```

### Phase 4: Cursor コマンド配置

**重要: 以下の2ファイルを正確に作成すること**

```bash
mkdir -p .cursor/commands
```

#### 4-1: assign-to-cc.md を作成

`.cursor/commands/assign-to-cc.md` に以下の内容を書き込む:

```markdown
# /assign-to-cc - Claude Code へのタスク依頼

Claude Code（Worker）に作業を依頼するコマンド。

---

## 使い方

Cursor で以下のようにタスクを指定して実行：

\`\`\`
/assign-to-cc ユーザー認証機能を実装
\`\`\`

---

## 実行フロー

### Step 1: タスク内容の確認

ユーザーが指定したタスクを確認し、以下を整理：

- **タスク概要**: 何をするか
- **スコープ**: 変更対象ファイル・範囲
- **完了条件**: 明確な受け入れ基準

### Step 2: Plans.md への追加

\`\`\`markdown
## 🟡 未着手のタスク

- [ ] {{タスク名}} \`cursor:依頼中\`
  - 概要: {{タスク概要}}
  - スコープ: {{スコープ}}
  - 完了条件: {{完了条件}}
\`\`\`

### Step 3: Claude Code への依頼メッセージ生成

以下のフォーマットで依頼を作成：

\`\`\`markdown
## 📋 作業依頼

**タスク**: {{タスク名}}
**依頼日時**: {{YYYY-MM-DD HH:MM}}
**依頼者**: Cursor (PM)

---

### タスク概要

{{タスクの詳細説明}}

---

### 完了条件

- [ ] {{条件1}}
- [ ] {{条件2}}

---

**Claude Code で \`/start-task\` を実行して作業を開始してください。**
\`\`\`

---

## 注意事項

- タスクは具体的に記述する
- 複数タスクは分けて依頼する（1コマンド = 1タスク）
```

#### 4-2: review-cc-work.md を作成

`.cursor/commands/review-cc-work.md` に以下の内容を書き込む:

```markdown
# /review-cc-work - Claude Code 作業のレビュー

Claude Code（Worker）からの完了報告をレビューするコマンド。

---

## 使い方

Claude Code から完了報告を受け取ったら実行：

\`\`\`
/review-cc-work
\`\`\`

---

## 実行フロー

### Step 1: 完了報告の確認

Plans.md から \`cc:完了\` マーカーのタスクを抽出。

### Step 2: 変更内容の確認

\`\`\`bash
git log --oneline -5
git diff HEAD~5 --stat
\`\`\`

### Step 3: レビューチェックリスト

- [ ] 依頼した機能が実装されているか
- [ ] CI が通過しているか
- [ ] 既存機能に影響がないか

### Step 4: レビュー結果

> **レビュー結果を選択してください：**
>
> 1. ✅ **承認** - 問題なし、\`cursor:確認済\` に更新
> 2. 🔄 **修正依頼** - Claude Code に差し戻し

### 承認の場合

Plans.md のマーカーを \`cursor:確認済\` に更新。

### 修正依頼の場合

差し戻し理由を明記し、Claude Code に再依頼。

---

## 注意事項

- 承認後は本番デプロイの判断を忘れずに
```

#### 4-3: 作成確認

```bash
# 2ファイルが作成されたことを確認
ls -la .cursor/commands/
# 出力に以下が含まれること:
# - assign-to-cc.md
# - review-cc-work.md
```

### Phase 5: メモリ構造作成

```bash
mkdir -p .claude/memory
echo "# Session Log" > .claude/memory/session-log.md
echo "# Decisions" > .claude/memory/decisions.md
echo "# Patterns" > .claude/memory/patterns.md
```

---

## 完了メッセージ

```
✅ 2エージェント体制のセットアップが完了しました！

📁 生成されたファイル:
- AGENTS.md (開発フロー)
- CLAUDE.md (Claude Code設定)
- Plans.md (タスク管理)
- .cursor/commands/ (Cursorコマンド)
- .claude/memory/ (セッション記憶)

🚀 次のステップ:

【Cursor側】
1. `.cursor/commands/` のコマンドを確認
2. `/assign-to-cc` でタスクを依頼

【Claude Code側】
1. `/start-task` で作業開始
2. 完了後は `/handoff-to-cursor`

💡 困ったら「どうすればいい？」と聞いてください
```

---

## VibeCoder向け案内

| やりたいこと | どちらで言う | 言い方 |
|-------------|-------------|--------|
| タスクを依頼 | Cursor | 「〇〇を実装して」→ `/assign-to-cc` |
| 実装する | Claude Code | 「次のタスク」→ `/start-task` |
| 完了報告 | Claude Code | 「終わった」→ `/handoff-to-cursor` |
| レビュー | Cursor | 「確認して」→ `/review-cc-work` |

---

## 注意事項

- 既存の AGENTS.md, Plans.md がある場合は上書き確認
- Cursor のカスタムコマンドは `.cursor/commands/` に配置
- Plans.md は両エージェントで共有・編集
