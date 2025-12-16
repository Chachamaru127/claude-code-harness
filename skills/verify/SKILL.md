---
name: verify
description: >
  Verifies builds, recovers from errors, and applies review fixes.
  Use when user mentions ビルド, build, 検証, verify, エラー復旧, error recovery, 指摘を適用, apply fixes.
  Triggers: ビルド, build, 検証, verify, エラー, error, 復旧, recovery, 指摘適用.
  Do not use for code review or implementation - use review, impl skills instead.
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
| ccp-verify-build | ビルド検証 |
| ccp-error-recovery | エラー復旧 |
| ccp-review-aggregate | レビュー結果の集約 |
| ccp-review-apply-fixes | レビュー指摘の適用 |

## ルーティング

- ビルド検証: ccp-verify-build/doc.md
- エラー復旧: ccp-error-recovery/doc.md
- レビュー集約: ccp-review-aggregate/doc.md
- 指摘適用: ccp-review-apply-fixes/doc.md

## 実行手順

1. ユーザーのリクエストを分類
2. 適切な小スキルの doc.md を読む
3. その内容に従って検証/復旧実行
