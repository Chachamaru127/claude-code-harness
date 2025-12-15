---
name: ccp-auto-fix
description: "レビュー指摘事項の自動修正。コードレビューで検出された問題を自動修正したい場合に使用します。"
allowed-tools: ["Read", "Write", "Edit", "Bash"]
metadata:
  skillport:
    category: optional
    tags: [auto-fix, review, refactor, quality]
    alwaysApply: false
---

# Auto-Fix Skill

`/harness-review`で検出された問題を自動的に修正するスキル。

---

## トリガーフレーズ

- 「レビュー指摘を自動修正して」
- 「指摘された問題を直して」
- 「セキュリティ問題を修正して」
- 「パフォーマンス問題を改善して」

---

## 機能

- セキュリティ脆弱性の修正
- パフォーマンス問題の改善
- コード品質の向上
- アクセシビリティ対応の追加

---

## 実行フロー

1. 直近のレビュー結果を読み込み
2. 修正可能な問題を特定
3. 修正内容をプレビュー
4. ユーザー承認後に修正を適用
5. 修正レポートを生成
