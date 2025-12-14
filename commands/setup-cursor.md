---
description: Cursor連携のセットアップ（.cursor/commands 生成）
---

# /setup-cursor - Cursor連携の有効化

このコマンドは、**Cursor側のカスタムコマンド**（`.cursor/commands/*.md`）を生成し、2-agent運用（Cursor PM + Claude Code Worker）を開始できる状態にします。

## バイブコーダー向け（こう言えばOK）

- 「**CursorとClaude Codeで役割分担したい**」→ このコマンド
- 「**計画はCursor、実装はClaudeに任せたい**」→ 2-agent運用の導線を生成します
- 「**どっちで何をやるの？**」→ 役割と手順を“コマンドとして”用意します

## できること（成果物）

- Cursor側の `.cursor/commands/*.md` を生成して、PM運用（依頼/レビュー/ハンドオフ）を即開始できる
- SSOT（decisions/patterns）を整えて“次回も同じ品質で回る”状態を作る

あわせて、2-agent運用で必須になりやすい **SSOTメモリ（decisions/patterns）** も初期化することを推奨します（詳細: `docs/MEMORY_POLICY.md`）。

## 生成するファイル

- `.cursor/commands/start-session.md`
- `.cursor/commands/project-overview.md`
- `.cursor/commands/plan-with-cc.md`
- `.cursor/commands/handoff-to-claude.md`
- `.cursor/commands/review-cc-work.md`
- （推奨）`.claude/memory/decisions.md`（SSOT）
- （推奨）`.claude/memory/patterns.md`（SSOT）
- （任意）`.claude/memory/session-log.md`（ローカル推奨）

## 実行手順

1. `.cursor/commands/` を作成
2. 上記5ファイルを生成（このコマンド内の内容をそのまま書き込み）
3. （推奨）`.claude/memory/` を作成し、SSOTファイルを初期化
4. 生成後、Cursorを再起動してコマンドが表示されることを案内

### （推奨）メモリ（SSOT）の初期化

以下を **存在しない場合のみ** 作成します：

- `.claude/memory/decisions.md`（重要な意思決定のSSOT）
- `.claude/memory/patterns.md`（再利用できる解法のSSOT）
- `.claude/memory/session-log.md`（セッションログ。ローカル推奨）

テンプレートは `templates/memory/*.template` を使用し、`{{DATE}}` は当日の日付に置換します。

### （推奨）`.gitignore` の方針

`decisions.md` / `patterns.md` はコミット対象、`session-log.md` / `.claude/state/` はローカル推奨（詳細: `docs/MEMORY_POLICY.md`）。

## 生成内容（そのまま書き込み）

### `.cursor/commands/start-session.md`

```markdown
---
description: セッション開始（状況把握→計画→Claude Codeへ依頼）
---

# /start-session

あなたは **Cursor (PM)** です。目的は「いま何をすべきか」を短時間で明確にし、必要なら Claude Code へ依頼することです。

## 1) 状況把握（最初に読む）

- @Plans.md
- @AGENTS.md
- @CLAUDE.md

可能なら以下も確認：
- `git status -sb`
- `git log --oneline -5`
- `git diff --name-only`

## 2) 今日のゴールを決める

次を1つに絞って提案してください：
- 最優先タスク（1つ）
- 受入条件（3つ以内）
- 想定リスク（あれば）

## 3) Claude Codeに依頼する（必要なら）

タスクを Claude Code に渡す場合、**/handoff-to-claude** を実行して依頼文を作ってください。
```

### `.cursor/commands/project-overview.md`

```markdown
---
description: プロジェクト全体の概要を短く把握
---

# /project-overview

以下を短くまとめてください（箇条書き中心）。

## 入力

- @README.md
- @Plans.md
- @AGENTS.md
- @CLAUDE.md

可能なら：
- `git status -sb`
- `git log --oneline -10`

## 出力フォーマット

- **目的**: このプロジェクトが何を作っているか（1-2行）
- **現在地**: 今のフェーズ/未完了タスク（Plans.md基準）
- **技術**: 言語/主要フレームワーク/テスト手段（推測でOK）
- **次アクション**: 3つまで
```

### `.cursor/commands/plan-with-cc.md`

```markdown
---
description: 計画作成（Claude Codeと協調してタスク分解）
---

# /plan-with-cc

あなたは **Cursor (PM)** です。ユーザー要望を Plans.md に落とし込み、Claude Code が実装できる粒度に分解します。

## 手順

1. まず要望を1〜2文で要約
2. 受入条件（3〜5個）を列挙
3. Plans.md に「フェーズ」と「タスク」を追記（`cursor:依頼中` / `cc:TODO` を適切に付与）
4. Claude Code に実装を依頼する場合は **/handoff-to-claude** を実行して依頼文を生成

## 参照

- @Plans.md
- @README.md
- 変更点があれば `git diff` / `git status`
```

### `.cursor/commands/handoff-to-claude.md`

```markdown
---
description: Claude Codeへの作業依頼プロンプトを生成
---

# /handoff-to-claude

あなたは **Cursor (PM)** です。Claude Code に渡す依頼文を、コピー&ペーストできる形で生成してください。

## 入力

- @Plans.md（対象タスクを特定）
- 可能なら `git status -sb` と `git diff --name-only`

## 出力（そのままClaude Codeに貼る）

次の Markdown を出力してください：

```markdown
## 依頼
以下を実装してください。

- 対象タスク:
  - （Plans.md から該当タスクを列挙）

## 制約
- 既存のコードスタイルに従う
- 変更は必要最小限
- テスト/ビルド手順があれば提示

## 受入条件
- （3〜5個）

## 参考
- 関連ファイル（あれば）
```
```

### `.cursor/commands/review-cc-work.md`

```markdown
---
description: Claude Codeの作業をレビューし、次アクションを決める
---

# /review-cc-work

あなたは **Cursor (PM)** です。Claude Code からの完了報告（/handoff-to-cursor の出力）を受け取り、変更をレビューしてください。

## 手順

1. 変更ファイル/差分の要点を把握（必要なら `git diff`）
2. 受入条件に照らしてOK/NGを判断
3. 追加修正が必要なら、Plans.md を更新して再度依頼文を作る（/handoff-to-claude）

## 出力フォーマット

- **判定**: approve / request_changes
- **理由**: 1〜3点
- **次アクション**:
  - approve の場合: マージ/デプロイ/次タスク
  - request_changes の場合: 具体的な修正依頼（箇条書き）
```

## 注意

- 既存ファイルがある場合は **上書きせず**、差分案内のみ行うこと
- Cursor連携なしでも `/plan` `/work` `/harness-review` で完結可能


