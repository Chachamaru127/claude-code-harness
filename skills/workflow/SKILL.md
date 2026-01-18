---
name: workflow
description: "Manages workflow transitions including handoffs between PM and implementation roles, and auto-fixes review comments. Use when user mentions handoffs, reporting to PM, handing off to implementation, completion reports, or auto-fix. Do not use for 2-Agent setup—use 2agent skill instead."
allowed-tools: ["Read", "Write", "Edit", "Bash"]
---

# Workflow Skills

PM-実装役間のハンドオフとレビュー指摘の自動修正を担当するスキル群です。

## 機能詳細

| 機能 | 詳細 |
|------|------|
| **レビュー指摘自動修正** | See [references/auto-fixing.md](references/auto-fixing.md) |
| **PM→実装役ハンドオフ** | See [references/handoff-to-impl.md](references/handoff-to-impl.md) |
| **実装役→PM完了報告** | See [references/handoff-to-pm.md](references/handoff-to-pm.md) |

## 実行手順

1. ユーザーのリクエストを分類
2. 上記の「機能詳細」から適切な参照ファイルを読む
3. その内容に従って実行
