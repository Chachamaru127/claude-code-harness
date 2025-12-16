---
name: principles
description: >
  Provides development principles, guidelines, and VibeCoder guidance.
  Use when user mentions 原則, principles, ガイドライン, guidelines, VibeCoder, 安全性, safety, 差分編集, diff-aware.
  Triggers: 原則, principles, ガイドライン, VibeCoder, 安全性, 差分編集.
  Do not use for actual implementation - use impl skill instead.
allowed-tools: ["Read"]
metadata:
  skillport:
    category: principles
    tags: [principles, guidelines, vibecoder, safety]
    alwaysApply: false
---

# Principles Skills

開発原則とガイドラインを提供するスキル群です。

## 含まれる小スキル

| スキル | 用途 |
|--------|------|
| ccp-core-general-principles | 開発の基本原則 |
| ccp-core-diff-aware-editing | 差分認識編集のガイド |
| ccp-core-read-repo-context | リポジトリコンテキスト読み取り |
| ccp-vibecoder-guide | VibeCoder 向けガイド |

## ルーティング

- 基本原則: ccp-core-general-principles/doc.md
- 差分編集: ccp-core-diff-aware-editing/doc.md
- コンテキスト読み取り: ccp-core-read-repo-context/doc.md
- VibeCoder: ccp-vibecoder-guide/doc.md

## 実行手順

1. ユーザーのリクエストを分類
2. 適切な小スキルの doc.md を読む
3. その内容を参照・適用
