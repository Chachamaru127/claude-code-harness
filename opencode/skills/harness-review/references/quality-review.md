---
name: review-quality
description: "コード品質（可読性、保守性、ベストプラクティス）をチェックするスキル。コードレビューが要求された場合、リファクタリング後、または複雑なロジックの実装後に使用します。"
allowed-tools: ["Read", "Grep", "Glob", "Bash"]
---

# Review Quality

コードの品質（可読性、保守性、ベストプラクティス）をチェックするスキル。

---

## 目的

以下の観点でコード品質を評価：
- 可読性（命名、構造、コメント）
- 保守性（モジュール性、依存関係）
- ベストプラクティス準拠
- コーディング規約準拠

---

## 入力

| 項目 | 説明 |
|------|------|
| `files` | チェック対象ファイルのリスト |
| `code_content` | ファイルの内容 |
| `eslint_output` | ESLint/Linter の出力（あれば） |

---

## 出力

| 項目 | 説明 |
|------|------|
| `quality_issues` | 検出された問題のリスト |
| `quality_score` | 品質スコア (A-F) |

---

## チェック項目

### 1. 可読性

| チェック | 問題 | 改善 |
|---------|------|------|
| 命名 | `x`, `tmp`, `data` などの曖昧な名前 | 意味のある名前に変更 |
| 関数の長さ | 50行以上の関数 | 小さな関数に分割 |
| ネスト深度 | 4段階以上のネスト | 早期リターン、関数抽出 |
| マジックナンバー | 直書きの数値 | 定数化 |

### 2. 保守性

| チェック | 問題 | 改善 |
|---------|------|------|
| 重複コード | 同じロジックの繰り返し | 共通関数に抽出 |
| 密結合 | 直接的な依存関係 | 依存性注入、インターフェース |
| グローバル状態 | グローバル変数の多用 | スコープの限定 |
| 未使用コード | 使われていない変数・関数 | 削除 |

### 3. ベストプラクティス

| チェック | 問題 | 改善 |
|---------|------|------|
| エラーハンドリング | 空の catch ブロック | 適切なエラー処理 |
| 型安全性 | any 型の多用 | 適切な型定義 |
| 非同期処理 | コールバック地獄 | async/await |
| テスタビリティ | テストしにくい構造 | 依存性注入 |

---

## スコアリング

| スコア | 基準 |
|--------|------|
| A | クリーンコード、問題なし |
| B | 軽微な改善余地 |
| C | 中程度の問題あり |
| D | 可読性・保守性に問題 |
| F | 深刻な品質問題 |

---

## 出力例

```markdown
## コード品質レビュー結果

**スコア**: B

### 検出された問題

| 重大度 | ファイル | 行 | 問題 |
|--------|---------|-----|------|
| 中 | src/services/user.ts | 45 | 関数が長すぎる (78行) |
| 低 | src/utils/helpers.ts | 12 | 未使用の import |
| 低 | src/api/posts.ts | 89 | マジックナンバー使用 |

### 推奨改善

1. **長い関数の分割**
   - `processUserData` 関数を以下に分割:
     - `validateUserInput()`
     - `formatUserData()`
     - `saveUser()`

2. **未使用コードの削除**
   - `import { unused } from './utils'` を削除

3. **定数化**
   ```typescript
   // Before
   if (retryCount > 3) { ... }

   // After
   const MAX_RETRY_COUNT = 3;
   if (retryCount > MAX_RETRY_COUNT) { ... }
   ```
```

---

### 4. クロスプラットフォーム

| チェック | 問題 | 重大度 | 改善 |
|---------|------|--------|------|
| レスポンシブ未対応 | 固定幅（`width: 1200px`）、viewport meta 未設定 | 中 | `max-width` + メディアクエリ |
| スクロールバー問題 | `100vw` 使用による横スクロール | 低 | `100%` または `calc(100vw - スクロールバー幅)` |
| 長文入力未対応 | overflow/truncate 未設定で UI 崩れ | 低 | `overflow-hidden`, `text-overflow: ellipsis` |
| フォント未指定 | system-ui/font-family 未設定 | 低 | システムフォントスタック指定 |
| タッチターゲット | 小さすぎるボタン（< 44px） | 中 | 最小 44x44px |

**検出パターン**:
```css
/* ❌ 問題: 固定幅 */
.container { width: 1200px; }

/* ✅ 改善: レスポンシブ */
.container { max-width: 1200px; width: 100%; }

/* ❌ 問題: 100vw（スクロールバーで崩れる） */
.full-width { width: 100vw; }

/* ✅ 改善 */
.full-width { width: 100%; }
```

### 5. Web 基盤チェック

| チェック | 問題 | 重大度 | 改善 |
|---------|------|--------|------|
| favicon 未設定 | ブラウザタブにアイコンなし | 低 | `<link rel="icon">` 追加 |
| apple-touch-icon 未設定 | iOS ホーム画面追加時のアイコンなし | 低 | `<link rel="apple-touch-icon">` 追加 |
| 404/5xx ページ | デフォルトエラーページ | 低 | カスタムエラーページ作成 |
| lang 属性未設定 | `<html>` に lang なし | 低 | `<html lang="ja">` 追加 |
| charset 未設定 | 文字化けリスク | 低 | `<meta charset="UTF-8">` 追加 |

**検出パターン**:
```html
<!-- ❌ 問題: 基本設定なし -->
<html>
<head>
  <title>My App</title>
</head>

<!-- ✅ 改善: 基本設定あり -->
<html lang="ja">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link rel="icon" href="/favicon.ico">
  <link rel="apple-touch-icon" href="/apple-touch-icon.png">
  <title>My App</title>
</head>
```

### 6. LocalStorage / Cookie 管理

| チェック | 問題 | 重大度 | 改善 |
|---------|------|--------|------|
| 有効期限なし | 永続的なデータ保存 | 低 | 適切な有効期限設定（7日推奨） |
| サードパーティ Cookie 依存 | ブロックされる可能性 | 中 | ファーストパーティへ移行 |
| 機密情報の保存 | LocalStorage にトークン等 | 中 | HttpOnly Cookie へ移行 |

---

## 注意事項

- プロジェクトの既存スタイルを尊重する
- 過度な改善提案は避ける
- 優先度を付けて報告する
- フレームワーク固有の機能を考慮する（Next.js App Router, Remix, etc.）
