# Cursor-Mem 使用例集

このドキュメントでは、CursorからClaude-memを活用する実践的な使用例を紹介します。

## 📖 目次

- [ユースケース1: 過去の決定を確認](#ユースケース1-過去の決定を確認)
- [ユースケース2: レビュー中の気付きを記録](#ユースケース2-レビュー中の気付きを記録)
- [ユースケース3: 引き継ぎ事項の記録](#ユースケース3-引き継ぎ事項の記録)
- [ユースケース4: パターンの検索と再利用](#ユースケース4-パターンの検索と再利用)
- [ユースケース5: バグ修正履歴の確認](#ユースケース5-バグ修正履歴の確認)

---

## ユースケース1: 過去の決定を確認

### シナリオ
認証方式の選定理由を確認したい。なぜJWTではなくSupabase Authを選んだのか？

### Cursor操作（Composer）

```
ユーザー: 「認証方式の選定理由を教えて」

Composer:
1. MCPツール `mcp__claude-mem__search` を使用
2. パラメータ:
   {
     "query": "認証 JWT Supabase 選定",
     "limit": 5
   }
```

### 期待される結果

```json
{
  "results": [
    {
      "id": 12345,
      "type": "decision",
      "content": "Supabase Authを採用。理由: RLSとの統合、セッション管理の簡素化、スケーラビリティ。JWT単体では認可ロジックが複雑化する懸念。",
      "tags": ["auth", "decision", "supabase"],
      "created_at": "2024-12-15T10:30:00Z"
    }
  ]
}
```

### フォローアップ

特定の観測IDで詳細を取得：

```
Composer:
MCPツール `mcp__claude-mem__get_observation` を使用
パラメータ: { "id": 12345 }
```

---

## ユースケース2: レビュー中の気付きを記録

### シナリオ
コードレビュー中に重要なパターンを発見。将来の参考のために記録しておきたい。

### Cursor操作（Composer）

```
ユーザー: 「このRLSポリシーのパターンを記録しておいて」

Composer:
MCPツール `mcp__claude-mem__add_observations` を使用
パラメータ:
{
  "observations": [
    {
      "type": "pattern",
      "content": "RLSポリシーは常にuser_idで絞り込むパターンを採用。auth.uid() = user_id の条件を全テーブルに適用。",
      "tags": ["source:cursor", "review", "pattern", "rls", "security"]
    }
  ]
}
```

### 記録内容の例

| フィールド | 値 |
|-----------|---|
| **type** | pattern |
| **content** | RLSポリシーのベストプラクティス |
| **tags** | source:cursor, review, pattern, rls, security |
| **timestamp** | 自動記録 |

---

## ユースケース3: 引き継ぎ事項の記録

### シナリオ
PMとして作業完了後、実装担当（Claude Code）への引き継ぎ事項を記録。

### Cursor操作（Composer）

```
ユーザー: 「バックエンドのエラーハンドリングを統一する必要があることを記録」

Composer:
MCPツール `mcp__claude-mem__create_entities` を使用
パラメータ:
{
  "entities": [
    {
      "name": "backend-error-handling-todo",
      "entityType": "task",
      "observations": [
        {
          "type": "handoff",
          "content": "バックエンドのエラーハンドリングを統一する必要あり。現在、APIルート毎に異なるエラーフォーマットが混在。標準化して503エラーの処理を改善。",
          "tags": ["source:cursor", "handoff", "backend", "error-handling", "todo"]
        }
      ]
    }
  ]
}
```

### Claude Code側での確認

```bash
# Claude Code で検索
mcp__claude-mem__search
→ query: "handoff backend error"
→ 引き継ぎ事項を取得
```

---

## ユースケース4: パターンの検索と再利用

### シナリオ
以前実装したフォームバリデーションのパターンを再利用したい。

### Cursor操作（Composer）

```
ユーザー: 「フォームバリデーションのパターンを教えて」

Composer:
1. MCPツール `mcp__claude-mem__search` を使用
2. パラメータ:
   {
     "query": "form validation pattern best-practice",
     "limit": 3
   }
```

### 期待される結果

```json
{
  "results": [
    {
      "id": 23456,
      "type": "pattern",
      "content": "Zod + React Hook Form パターン: スキーマ定義を共有し、フロント/バックで再利用。zodResolver でバリデーションロジックを統一。",
      "tags": ["pattern", "validation", "zod", "react-hook-form"],
      "files": ["src/schemas/userSchema.ts", "src/hooks/useUserForm.ts"]
    }
  ]
}
```

### 実装時の活用

1. パターンを確認
2. 関連ファイルを参照
3. 同様のアプローチで新機能を実装

---

## ユースケース5: バグ修正履歴の確認

### シナリオ
類似のバグに遭遇。過去に同じ問題を解決していないか確認したい。

### Cursor操作（Composer）

```
ユーザー: 「CORS エラーの過去の修正履歴を確認」

Composer:
MCPツール `mcp__claude-mem__search` を使用
パラメータ:
{
  "query": "CORS error fix bug",
  "limit": 5
}
```

### 期待される結果

```json
{
  "results": [
    {
      "id": 34567,
      "type": "bug",
      "content": "CORS エラー修正: Supabase の CORS 設定が不足。storage.buckets テーブルに allowed_origins を追加。",
      "tags": ["bug", "cors", "supabase", "storage"],
      "created_at": "2024-11-20T14:00:00Z",
      "related_files": ["supabase/migrations/20241120_add_cors.sql"]
    }
  ]
}
```

### 修正への活用

1. 過去の修正内容を確認
2. 関連ファイル（migration）を参照
3. 同じアプローチを適用

---

## 🔄 統合ワークフロー例

### PM（Cursor）→ 実装（Claude Code）の流れ

#### Step 1: Cursorでレビュー & 記録

```
# Cursor Composer
「このコンポーネントの設計パターンを記録」
→ mcp__claude-mem__add_observations
→ タグ: source:cursor, review, pattern, component
```

#### Step 2: Claude Codeで参照 & 実装

```
# Claude Code
「コンポーネント設計のパターンを確認」
→ mcp__claude-mem__search
→ query: "component pattern review"
→ Cursorで記録されたパターンを取得
→ 同じパターンで実装
```

#### Step 3: 実装完了を記録

```
# Claude Code
実装完了後、自動で記録
→ mcp__claude-mem__add_observations
→ タグ: source:claude-code, implementation, complete
```

#### Step 4: Cursorで検証

```
# Cursor Composer
「実装状況を確認」
→ mcp__claude-mem__timeline
→ 最近の実装記録を時系列で取得
```

---

## 💡 ベストプラクティス

### タグの付け方

| 状況 | 推奨タグ |
|------|---------|
| Cursorから記録 | `source:cursor` |
| 設計判断 | `type:decision, design` |
| レビュー結果 | `type:review, code-quality` |
| 実装パターン | `type:pattern, best-practice` |
| バグ修正 | `type:bug, fix` |
| 引き継ぎ | `type:handoff, todo` |

### 検索のコツ

1. **具体的なキーワード**: `"auth JWT"` より `"auth supabase jwt decision"` の方が精度が高い
2. **タグフィルタ**: 検索後にタグで絞り込み
3. **時系列検索**: `timeline` ツールで最近の記録を取得
4. **関連ファイル**: ファイルパスで関連する記録を発見

### 記録のコツ

1. **Why を記録**: 「何をしたか」より「なぜそうしたか」を重視
2. **タグを充実**: 将来の検索性を高める
3. **関連ファイルを紐付け**: 実装との結び付きを明確に
4. **定期的な整理**: 重要な記録にマーカーを付ける

---

## 🔗 関連リソース

- [SKILL.md](./SKILL.md) - スキルの詳細説明
- [統合ガイド](../../docs/guides/cursor-mem-integration.md) - セットアップ手順
- [Claude-mem 公式ドキュメント](https://github.com/thedotmack/claude-mem)
