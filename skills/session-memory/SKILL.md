---
name: ccp-session-memory
description: "セッション間の学習と記憶を管理するスキル"
metadata:
  skillport:
    category: core
    tags: [session, memory, history, context]
    alwaysApply: false
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

---

## 自動記録される情報

### session-log.md

```markdown
## セッション: 2024-01-15 14:30

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

- **自動保存**: 明示的に保存する必要はない
- **プライバシー**: 機密情報は記録しない
- **.gitignore**: `.claude/memory/` は Git に含めることを推奨
- **容量管理**: 古いログは自動でアーカイブ
