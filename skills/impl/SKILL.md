---
name: impl
description: "Implements features and writes code based on Plans.md tasks. Use when user mentions 実装, implement, 機能追加, コードを書いて, 機能を作って, feature, coding, 新機能. Do not use for review or build verification."
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
| work-impl-feature | 機能の実装 |
| work-write-tests | テストコードの作成 |

## ルーティング

### 機能実装

work-impl-feature/doc.md を参照

### テスト作成

work-write-tests/doc.md を参照

## 実行手順

1. ユーザーのリクエストを分類
2. 適切な小スキルの doc.md を読む
3. その内容に従って実装

---

## 🔧 LSP 機能の活用

実装時には LSP（Language Server Protocol）を積極的に活用します。

### 実装前の調査

| LSP 機能 | 用途 |
|---------|------|
| **Go-to-definition** | 既存関数の実装パターンを確認 |
| **Find-references** | 変更の影響範囲を事前把握 |
| **Hover** | 型情報・API ドキュメントを確認 |

### 実装中の検証

| LSP 機能 | 用途 |
|---------|------|
| **Diagnostics** | 型エラー・構文エラーを即座に検出 |
| **Completions** | 正しい API を使用、タイポ防止 |

### 実装後の確認

```
実装完了時チェック:
1. LSP Diagnostics を実行
2. エラー: 0件を確認
3. 警告: 必要に応じて対応
```

詳細: [docs/LSP_INTEGRATION.md](../../docs/LSP_INTEGRATION.md)
