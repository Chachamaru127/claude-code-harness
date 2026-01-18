---
name: docs
description: "Generates documentation files including NotebookLM YAML and slide content. Use when user mentions documentation, YAML, NotebookLM, slides, or presentations. Do NOT load for: implementation work, code fixes, reviews, or deployments."
allowed-tools: ["Read", "Write", "Edit"]
---

# Docs Skills

ドキュメント生成を担当するスキル群です。

## 機能詳細

| 機能 | 詳細 |
|------|------|
| **NotebookLM YAML** | See [references/notebooklm-yaml.md](references/notebooklm-yaml.md) |
| **スライド YAML** | See [references/notebooklm-slides.md](references/notebooklm-slides.md) |

## 実行手順

1. ユーザーのリクエストを分類
2. 上記の「機能詳細」から適切な参照ファイルを読む
3. その内容に従って生成
