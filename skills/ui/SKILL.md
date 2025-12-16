---
name: ui
description: >
  Generates UI components and feedback forms.
  Use when user mentions コンポーネント, component, UI, ヒーロー, hero, フォーム, form, フィードバック, feedback, 問い合わせ.
  Triggers: コンポーネント, component, UI, ヒーロー, hero, フォーム, フィードバック.
  Do not use for authentication or deployment - use auth, deploy skills instead.
allowed-tools: ["Read", "Write", "Edit", "Bash"]
metadata:
  skillport:
    category: ui
    tags: [ui, component, form, feedback]
    alwaysApply: false
---

# UI Skills

UIコンポーネントとフォームの生成を担当するスキル群です。

## 含まれる小スキル

| スキル | 用途 |
|--------|------|
| component | UIコンポーネント生成 |
| feedback | フィードバックフォーム生成 |

## ルーティング

- コンポーネント生成: component/doc.md
- フィードバックフォーム: feedback/doc.md

## 実行手順

1. ユーザーのリクエストを分類
2. 適切な小スキルの doc.md を読む
3. その内容に従って生成
