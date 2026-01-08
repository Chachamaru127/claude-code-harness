---
name: review
description: "Reviews code for quality, security, performance, and accessibility issues. Use when user mentions レビュー, review, コードレビュー, セキュリティ, パフォーマンス, 品質チェック, セルフレビュー, PR, diff, 変更確認. Do NOT load for: 実装作業, 新機能開発, バグ修正, セットアップ."
allowed-tools: ["Read", "Grep", "Glob", "Bash", "Task"]
context: fork
metadata:
  skillport:
    category: review
    tags: [review, quality, security, performance, accessibility]
    alwaysApply: false
---

# Review Skills

コードレビューと品質チェックを担当するスキル群です。

## 含まれる小スキル

| スキル | 用途 |
|--------|------|
| review-changes | 変更内容のレビュー |
| review-quality | コード品質チェック |
| review-security | セキュリティレビュー |
| review-performance | パフォーマンスレビュー |
| review-accessibility | アクセシビリティチェック |

## ルーティング

ユーザーの意図に応じて適切な小スキルを選択:

- 一般的なレビュー: review-changes/doc.md
- 品質重視: review-quality/doc.md
- セキュリティ重視: review-security/doc.md
- パフォーマンス重視: review-performance/doc.md
- アクセシビリティ重視: review-accessibility/doc.md

## 実行手順

1. **品質判定ゲート**（Step 0）
2. ユーザーのリクエストを分類
3. **（Claude-mem 有効時）過去のレビュー指摘を検索**
4. 並列実行の判定（下記参照）
5. 適切な小スキルの doc.md を読む、または並列サブエージェント起動
6. 結果を統合してレビュー完了

### Step 0: 品質判定ゲート（レビュー重点領域の特定）

レビュー開始前に変更内容を分析し、重点領域を特定:

```
変更ファイル分析
    ↓
┌─────────────────────────────────────────┐
│           品質判定ゲート                 │
├─────────────────────────────────────────┤
│  判定項目:                              │
│  ├── カバレッジ不足？（テストなし）     │
│  ├── セキュリティ注意？（auth/api/）    │
│  ├── a11y 注意？（UI コンポーネント）   │
│  └── パフォーマンス注意？（DB/ループ）  │
└─────────────────────────────────────────┘
          ↓
    重点レビュー領域を決定
```

#### カバレッジ判定

| 状況 | 指摘内容 |
|------|---------|
| 新規ファイルにテストなし | 「テストが不足しています」 |
| 変更ファイルのテストが古い | 「テストの更新を検討してください」 |
| カバレッジ < 60% | 「カバレッジ向上を推奨」 |

#### セキュリティ重点レビュー

| パス | 追加チェック項目 |
|------|-----------------|
| auth/, api/ | OWASP Top 10 チェックリスト |
| 入力処理 | サニタイズ、バリデーション |
| DB クエリ | パラメータ化確認 |

#### a11y 重点レビュー

| パス | チェック項目 |
|------|------------|
| src/components/ | alt, aria, キーボード操作 |
| src/pages/ | 見出し構造, フォーカス管理 |

#### パフォーマンス重点レビュー

| パターン | 警告内容 |
|---------|---------|
| ループ内 DB クエリ | N+1 クエリの可能性 |
| 大規模データ処理 | ページネーション検討 |
| useEffect 乱用 | レンダリング最適化 |

#### 重点レビュー統合出力

```markdown
📊 品質判定結果 → 重点レビュー領域

| 判定 | 該当 | 対象ファイル |
|------|------|-------------|
| セキュリティ | ⚠️ | src/api/auth.ts |
| カバレッジ | ⚠️ | src/utils/helpers.ts (テストなし) |
| a11y | ✅ | - |
| パフォーマンス | ✅ | - |

→ セキュリティ・カバレッジを重点的にレビュー
```

### Step 2: 過去のレビュー指摘検索（Memory-Enhanced）

Claude-mem が有効な場合、レビュー開始前に過去の類似指摘を検索:

```
# mem-search で過去のレビュー指摘を検索
mem-search: type:review "{変更ファイルのパターン}"
mem-search: concepts:security "{セキュリティ関連のキーワード}"
mem-search: concepts:gotcha "{変更箇所に関連するキーワード}"
```

**表示例**:

```markdown
📚 過去のレビュー指摘（関連あり）

| 日付 | 指摘内容 | ファイル |
|------|---------|---------|
| 2024-01-15 | XSS脆弱性: innerHTML 使用禁止 | src/components/*.tsx |
| 2024-01-20 | N+1クエリ: prefetch 必須 | src/api/*.ts |

💡 今回のレビューで上記パターンを重点チェック
```

> **注**: Claude-mem が未設定の場合、このステップはスキップされます。

## 並列サブエージェント起動（推奨）

以下の条件を**両方**満たす場合、Task tool で code-reviewer を並列起動:

- レビュー観点 >= 2（例: セキュリティ + パフォーマンス）
- 変更ファイル >= 5

**起動パターン（1つのレスポンス内で複数の Task tool を同時呼び出し）:**

```
Task tool 並列呼び出し:
  #1: subagent_type="code-reviewer"
      prompt="セキュリティ観点でレビュー: {files}"
  #2: subagent_type="code-reviewer"
      prompt="パフォーマンス観点でレビュー: {files}"
  #3: subagent_type="code-reviewer"
      prompt="コード品質観点でレビュー: {files}"
```

**小規模な場合（条件を満たさない）:**
- 子スキル（doc.md）を順次読み込んで直列実行

---

## 🔧 LSP 機能の活用

レビューでは LSP（Language Server Protocol）を活用して精度を向上します。

### LSP をレビューに統合

| レビュー観点 | LSP 活用方法 |
|-------------|-------------|
| **品質** | Diagnostics で型エラー・未使用変数を自動検出 |
| **セキュリティ** | Find-references で機密データの流れを追跡 |
| **パフォーマンス** | Go-to-definition で重い処理の実装を確認 |

### LSP Diagnostics の出力例

```
📊 LSP 診断結果

| ファイル | エラー | 警告 |
|---------|--------|------|
| src/components/Form.tsx | 0 | 2 |
| src/utils/api.ts | 1 | 0 |

⚠️ 1件のエラーを検出
→ レビューで指摘事項に追加
```

### Find-references による影響分析

```
🔍 変更影響分析

変更: validateInput()

参照箇所:
├── src/pages/signup.tsx:34
├── src/pages/settings.tsx:56
└── tests/validate.test.ts:12

→ テストでカバー済み ✅
```

詳細: [docs/LSP_INTEGRATION.md](../../docs/LSP_INTEGRATION.md)

---

## VibeCoder 向け

```markdown
📝 コードチェックを依頼するときの言い方

1. **「チェックして」**
   - 全体的に問題がないか見てもらう

2. **「セキュリティ大丈夫？」**
   - 悪意ある攻撃に耐えられるかチェック

3. **「遅くない？」**
   - 速度に問題がないかチェック

4. **「誰でも使える？」**
   - 障害のある方でも使えるかチェック

💡 ヒント: 「全部チェックして」と言えば、
4つの観点すべてを自動で確認します
```
