---
name: review
description: >
  Reviews code for quality, security, performance, and accessibility issues.
  Use when user mentions レビュー, review, コードレビュー, セルフレビュー, 品質チェック, quality, security check, performance, accessibility.
  Triggers: レビュー, review, 品質, セキュリティ, パフォーマンス, アクセシビリティ, PR, diff, 変更確認.
  Do not use for implementation or build verification - use impl, verify skills instead.
allowed-tools: ["Read", "Grep", "Glob", "Bash"]
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
| ccp-review-changes | 変更内容のレビュー |
| ccp-review-quality | コード品質チェック |
| ccp-review-security | セキュリティレビュー |
| ccp-review-performance | パフォーマンスレビュー |
| ccp-review-accessibility | アクセシビリティチェック |

## ルーティング

ユーザーの意図に応じて適切な小スキルを選択:

- 一般的なレビュー: ccp-review-changes/doc.md
- 品質重視: ccp-review-quality/doc.md
- セキュリティ重視: ccp-review-security/doc.md
- パフォーマンス重視: ccp-review-performance/doc.md
- アクセシビリティ重視: ccp-review-accessibility/doc.md

## 実行手順

1. ユーザーのリクエストを分類
2. 並列実行の判定（下記参照）
3. 適切な小スキルの doc.md を読む、または並列サブエージェント起動
4. 結果を統合してレビュー完了

## 並列サブエージェント起動（推奨）

以下の条件を**両方**満たす場合、Task tool で code-reviewer を並列起動:

- レビュー観点 >= 2（例: セキュリティ + パフォーマンス）
- 変更ファイル >= 5

**起動パターン（1つのレスポンス内で複数の Task tool を同時呼び出し）:**

```
Task tool 並列呼び出し:
  #1: subagent_type="claude-code-harness:code-reviewer"
      prompt="セキュリティ観点でレビュー: {files}"
  #2: subagent_type="claude-code-harness:code-reviewer"
      prompt="パフォーマンス観点でレビュー: {files}"
  #3: subagent_type="claude-code-harness:code-reviewer"
      prompt="コード品質観点でレビュー: {files}"
```

**小規模な場合（条件を満たさない）:**
- 子スキル（doc.md）を順次読み込んで直列実行
