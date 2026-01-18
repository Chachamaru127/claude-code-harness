---
name: setup
description: "Sets up new projects and generates workflow files like CLAUDE.md, AGENTS.md, Plans.md. Use when user mentions setup, initialization, new projects, or workflow file generation. Do NOT load for: implementation work, reviews, build verification, or deployments."
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash"]
user-invocable: false
---

# Setup Skills

プロジェクトセットアップとワークフローファイル生成を担当するスキル群です。

## 機能詳細

| 機能 | 詳細 |
|------|------|
| **適応的セットアップ** | See [references/adaptive-setup.md](references/adaptive-setup.md) |
| **スキャフォールディング** | See [references/project-scaffolding.md](references/project-scaffolding.md) |
| **ワークフローファイル** | See [references/workflow-files.md](references/workflow-files.md) |
| **設定ファイル** | See [references/claude-settings.md](references/claude-settings.md) |
| **プロジェクト種別確認** | See [references/project-type-detection.md](references/project-type-detection.md) |

## 実行手順

1. ユーザーのリクエストを分類
2. 上記の「機能詳細」から適切な参照ファイルを読む
3. その内容に従ってセットアップ
