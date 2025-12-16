---
name: memory
description: >
  Manages memory, SSOT files, and Plans.md operations.
  Use when user mentions メモリ, memory, SSOT, decisions.md, patterns.md, マージ, merge, Plans.md, 移行, migrate.
  Triggers: メモリ, memory, SSOT, decisions.md, patterns.md, マージ, 移行.
  Do not use for initial setup - use setup skill instead.
allowed-tools: ["Read", "Write", "Edit", "Bash"]
metadata:
  skillport:
    category: memory
    tags: [memory, ssot, plans, merge, migrate]
    alwaysApply: false
---

# Memory Skills

メモリとSSOT管理を担当するスキル群です。

## 含まれる小スキル

| スキル | 用途 |
|--------|------|
| ccp-init-memory-ssot | decisions.md, patterns.md 初期化 |
| ccp-merge-plans | Plans.md のマージ処理 |
| ccp-migrate-workflow-files | 旧形式からの移行 |

## ルーティング

- SSOT初期化: ccp-init-memory-ssot/doc.md
- Plans.mdマージ: ccp-merge-plans/doc.md
- 移行処理: ccp-migrate-workflow-files/doc.md

## 実行手順

1. ユーザーのリクエストを分類
2. 適切な小スキルの doc.md を読む
3. その内容に従って実行
