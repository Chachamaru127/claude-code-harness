---
name: session-memory
description: "Manages cross-session learning and memory persistence. Use when user asks about previous sessions, history, or to continue from before. Do NOT load for: implementation work, reviews, or ad-hoc information."
allowed-tools: ["Read", "Write", "Append"]
user-invocable: false
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
└── memory/
    ├── session-log.md      # セッションごとのログ
    ├── decisions.md        # 重要な決定事項
    ├── patterns.md         # 学んだパターン
    └── context.json        # プロジェクトコンテキスト
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

各セッション記録には `${CLAUDE_SESSION_ID}` 環境変数を活用してセッションIDを付与します。
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
> セッションごとに一意のIDが割り当てられ、ログの追跡や問題調査に役立ちます。

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
3. 未完了タスクを特定
4. コンテキストサマリーを生成

### セッション中

1. 重要な決定を `decisions.md` に記録
2. 新しいパターンを `patterns.md` に追加
3. ファイル生成を `session-log.md` に記録

### セッション終了時

1. セッションサマリーを生成
2. `context.json` を更新
3. 次回への引き継ぎ事項を記録

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

## 注意事項

- **自動保存**: `hooks/Stop` により、セッション終了時に `session-log.md` へ要約を自動追記する運用を推奨（未導入の場合は手動運用でOK）
- **プライバシー**: 機密情報は記録しない
- **Git方針**: `decisions.md`/`patterns.md`は共有推奨、`session-log.md`/`context.json`/`.claude/state/`はローカル推奨（詳細: `docs/MEMORY_POLICY.md`）
- **容量管理**: ログが大きくなったら「セッションログを整理して」を推奨
