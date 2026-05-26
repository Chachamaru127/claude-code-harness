---
name: session-memory
description: "Internal sub-skill for cross-session handoff, durable learning, and memory persistence. Invoked by session/memory workflows only. Do NOT load for: implementation, review, ad-hoc notes, or SSOT editing."
description-en: "Internal sub-skill for cross-session handoff, durable learning, and memory persistence. Invoked by session/memory workflows only. Do NOT load for: implementation, review, ad-hoc notes, or SSOT editing."
description-ja: "セッション間引き継ぎ、永続学習、memory persistence を扱う内部サブスキル。session/memory 系からのみ呼ぶ。実装、レビュー、単発メモ、SSOT編集には使わない。"
allowed-tools: ["Read", "Write", "Edit", "Bash"]
user-invocable: false
disable-model-invocation: true
---

# Session Memory Skill

セッション間の学習と記憶を管理するスキル。
過去の作業内容、決定事項、学んだパターンを記録・参照します。

---

## トリガーフレーズ

このスキルは以下のフレーズで自動起動します：

- 「前回何をした？」「前回の続きから」
- 「履歴を見せて」「過去の作業」
- 「このプロジェクトについて教えて」
- "what did we do last time?", "continue from before"

---

## 概要

このスキルは `.claude/memory/` に作業履歴を保存し、
セッション間での知識の継続を実現します。

あわせて、重要な情報は「どこに残すべきか」を明確にします（詳細: `docs/MEMORY_POLICY.md`）。

---

## メモリ構造

```
.claude/
├── memory/
│   ├── session-log.md      # セッションごとのログ
│   ├── decisions.md        # 重要な決定事項
│   ├── patterns.md         # 学んだパターン
│   └── context.json        # プロジェクトコンテキスト
└── state/
    └── agent-trace.jsonl   # Agent Trace（ツール実行履歴）
```

### 推奨運用（SSOT/ローカル分離）

- **SSOT（共有推奨）**: `decisions.md` / `patterns.md`  
  - 「決定（Why）」と「再利用できる解法（How）」を集約する
  - 各エントリは **タイトル + タグ**（例: `#decision #db`）を付け、先頭に **Index** を置く
- **ローカル推奨**: `session-log.md` / `context.json` / `.claude/state/`  
  - ノイズ/肥大化しやすいため、基本は Git 管理しない（必要なら個別に判断）

---

## 自動記録される情報

### session-log.md

各セッション記録には、実行環境から取得できるセッションIDを付与します。
Claude Code では `${CLAUDE_SESSION_ID}` を優先し、Codex では Codex runtime が渡す session / thread ID を優先します。
どちらも取得できない場合は `.claude/state/session.json` の `.session_id` を読み、最後の fallback として日時ベースのIDを生成します。
これにより、セッション間のトレーサビリティが向上します。

```markdown
## セッション: 2024-01-15 14:30 (session: abc123def)

### 実行したタスク
- [x] ユーザー認証機能の実装
- [x] ログインページの作成

### 生成したファイル
- src/lib/auth.ts
- src/app/login/page.tsx

### 重要な決定
- 認証方式: Supabase Auth を採用

### 次回への引き継ぎ
- ログアウト機能が未実装
- パスワードリセットも必要
```

> **Note**: `${CLAUDE_SESSION_ID}` は Claude Code が自動設定する環境変数です。
> Codex 側ではこの変数が存在しない場合があるため、固定前提にせず、Codex runtime の session / thread ID または `.claude/state/session.json` を使います。

### decisions.md

```markdown
## 技術選定

| 日付 | 決定事項 | 理由 |
|------|---------|------|
| 2024-01-15 | Supabase Auth | 無料枠あり、セットアップ簡単 |
| 2024-01-14 | Next.js App Router | 最新のベストプラクティス |

## アーキテクチャ

- コンポーネント: `src/components/`
- ユーティリティ: `src/lib/`
- 型定義: `src/types/`
```

### patterns.md

```markdown
## このプロジェクトのパターン

### コンポーネント命名
- PascalCase
- 例: `UserProfile.tsx`, `LoginForm.tsx`

### API エンドポイント
- `/api/v1/` プレフィックス
- RESTful 設計

### エラーハンドリング
- try-catch で囲む
- エラーメッセージは日本語
```

### context.json

```json
{
  "project_name": "my-blog",
  "created_at": "2024-01-14",
  "stack": {
    "frontend": "next.js",
    "backend": "next-api",
    "database": "supabase",
    "styling": "tailwind"
  },
  "current_phase": "フェーズ2: コア機能",
  "last_session": "2024-01-15T14:30:00Z"
}
```

---

## 処理フロー

### セッション開始時

1. `.claude/memory/context.json` を読み込み
2. 前回のセッションログを確認
3. **Agent Trace から直近の編集履歴を取得**
4. 未完了タスクを特定
5. コンテキストサマリーを生成

**Agent Trace 活用**:
```bash
# 前回の編集ファイル一覧を取得
tail -50 .claude/state/agent-trace.jsonl | jq -r '.files[].path' | sort -u

# プロジェクト情報を取得
tail -1 .claude/state/agent-trace.jsonl | jq '.metadata'
```

### セッション中

1. 重要な決定を `decisions.md` に記録
2. 新しいパターンを `patterns.md` に追加
3. ファイル生成を `session-log.md` に記録

### セッション終了時

1. セッションサマリーを生成
2. `context.json` を更新
3. 次回への引き継ぎ事項を記録

---

## メモリ最適化（CC 2.1.49+）

Claude Code 2.1.49 以降、セッション再開時のメモリ使用量が **68% 削減** されました。

### 推奨ワークフロー

```bash
# 長時間作業は --resume を活用
claude --resume

# 大規模タスクは分割してセッション再開
claude --resume "続きから"
```

| シナリオ | 推奨 |
|---------|------|
| 長時間実装 | 1-2時間ごとにセッション再開 |
| 大規模リファクタ | 機能単位でセッション分割 |
| メモリ不足警告 | 即座に `--resume` で再開 |

> メモリ効率が大幅に改善されたため、セッション再開を積極的に活用してください。

### /recap — セッション中の状況確認（CC 2.1.108+）

CC 2.1.108 で追加された `/recap` コマンド（`/rewind` のエイリアス）は、現在のセッション内で
これまでに何をしたかを素早く振り返るために使用します。
`--resume` で別セッションに戻る前や、長時間作業の途中確認に組み合わせると効果的です。

**推奨タイミング**:

| タイミング | 使い方 |
|---------|------|
| `--resume` で再開する直前 | `/recap` でコンテキストを整理してから `claude --resume` |
| Breezing の Worker 再開前 | セッション内の進捗を `/recap` で確認してから次タスクへ |
| 長時間実装 (1時間超) の中間点 | `/recap` で状況確認 → 必要なら `session-log.md` に手動追記 |

```bash
# 典型的な使用フロー
# 1. 現在の作業状況を確認
/recap

# 2. 必要に応じて session-log.md に手動追記後、セッションを再開
claude --resume
```

> `/recap` はセッション内の振り返りのみ。前回セッションの内容は `session-log.md` または
> `claude --resume` でのコンテキスト継承で確認する。

---

## 使用例

### 前回の続きから開始

```
ユーザー: 「前回の続きから」

Claude Code:
📋 前回のセッション（2024-01-15）

完了したタスク:
- ユーザー認証機能
- ログインページ

未完了:
- ログアウト機能
- パスワードリセット

「ログアウト機能を作って」と言えば続きを実装します。
```

### プロジェクトの状況確認

```
ユーザー: 「このプロジェクトについて教えて」

Claude Code:
📁 プロジェクト: my-blog

技術スタック:
- Next.js + Tailwind CSS + Supabase

現在のフェーズ: コア機能開発
進捗: 40% 完了

最近の決定:
- Supabase Auth を採用
- App Router を使用
```

---

## Claude Code 自動メモリとの関係（D22）

Claude Code 2.1.32+ には「自動メモリ」機能があり、`~/.claude/projects/<project>/memory/MEMORY.md` にセッション間の学習を自動保存します。

Harness のメモリシステムとは**3層アーキテクチャ**として共存します:

| 層 | システム | 内容 | 管理 |
|----|---------|------|------|
| **Layer 1** | Claude Code 自動メモリ | 汎用的な学習（ミス回避、ツール使い方） | 暗黙的・自動 |
| **Layer 2** | Harness SSOT | プロジェクト固有の決定事項・パターン | 明示的・手動 |
| **Layer 3** | Agent Memory | エージェント別のタスク学習 | エージェント定義 |

**使い分け**:
- Layer 1 の知見がプロジェクト全体に重要 → `/memory ssot` で Layer 2 に昇格
- 日常的な学習は Layer 1 に任せる（無効化しない）
- Agent Teams 使用時は並列書き込みに注意

詳細: [D22: 3層メモリアーキテクチャ](../../.claude/memory/decisions.md#d22-3層メモリアーキテクチャ)

---

## 注意事項

- **自動保存**: `hooks/Stop` により、セッション終了時に `session-log.md` へ要約を自動追記する運用を推奨（未導入の場合は手動運用でOK）
- **プライバシー**: 機密情報は記録しない
- **Git方針**: `decisions.md`/`patterns.md`は共有推奨、`session-log.md`/`context.json`/`.claude/state/`はローカル推奨（詳細: `docs/MEMORY_POLICY.md`）
- **容量管理**: ログが大きくなったら「セッションログを整理して」を推奨
