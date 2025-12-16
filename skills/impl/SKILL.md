---
name: impl
description: >
  Implements features and writes code based on Plans.md tasks.
  Use when user mentions 実装, implement, 機能追加, コードを書いて, 機能を作って, feature, coding.
  Triggers: 実装, implement, 機能追加, コードを書いて, 新機能, feature.
  Do not use for review, testing verification, or build - use review, verify skills instead.
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash"]
metadata:
  skillport:
    category: impl
    tags: [implementation, coding, feature, development]
    alwaysApply: false
---

# Implementation Skills

機能実装とコーディングを担当するスキル群です。

## 含まれる小スキル

| スキル | 用途 |
|--------|------|
| ccp-work-impl-feature | 機能の実装 |
| ccp-work-write-tests | テストコードの作成 |

## ルーティング

### 機能実装

ccp-work-impl-feature/doc.md を参照

### テスト作成

ccp-work-write-tests/doc.md を参照

## 実行手順

1. ユーザーのリクエストを分類
2. 適切な小スキルの doc.md を読む
3. その内容に従って実装
