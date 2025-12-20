---
name: verify
description: "Verifies builds, recovers from errors, and applies review fixes. Use when user mentions ビルド, build, 検証, verify, エラー復旧, error recovery, 指摘を適用, apply fixes, テスト実行. Do NOT load for: 実装作業, レビュー, セットアップ, 新機能開発."
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash"]
metadata:
  skillport:
    category: verify
    tags: [build, verify, error-recovery, fixes]
    alwaysApply: false
---

# Verify Skills

ビルド検証とエラー復旧を担当するスキル群です。

## 含まれる小スキル

| スキル | 用途 |
|--------|------|
| verify-build | ビルド検証 |
| error-recovery | エラー復旧 |
| review-aggregate | レビュー結果の集約 |
| review-apply-fixes | レビュー指摘の適用 |

## ルーティング

- ビルド検証: verify-build/doc.md
- エラー復旧: error-recovery/doc.md
- レビュー集約: review-aggregate/doc.md
- 指摘適用: review-apply-fixes/doc.md

## 実行手順

1. ユーザーのリクエストを分類
2. 適切な小スキルの doc.md を読む
3. その内容に従って検証/復旧実行

---

## 🔧 LSP 機能の活用

検証とエラー復旧では LSP（Language Server Protocol）を活用して精度を向上します。

### ビルド検証での LSP 活用

```
ビルド前チェック:

1. LSP Diagnostics を実行
2. エラー: 0件を確認 → ビルド実行
3. エラーあり → 先にエラーを修正
```

### エラー復旧での LSP 活用

| 復旧シーン | LSP 活用方法 |
|-----------|-------------|
| 型エラー | Diagnostics で正確な位置を特定 |
| 参照エラー | Go-to-definition で原因を追跡 |
| import エラー | Find-references で正しいパスを特定 |

### 検証フロー

```
📊 LSP 検証結果

Step 1: Diagnostics
  ├── エラー: 0件 ✅
  └── 警告: 2件 ⚠️

Step 2: ビルド
  └── 成功 ✅

Step 3: テスト
  └── 15/15 通過 ✅

→ 検証完了
```

詳細: [docs/LSP_INTEGRATION.md](../../docs/LSP_INTEGRATION.md)
