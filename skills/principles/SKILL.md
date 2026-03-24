---
name: principles
description: "Provides development principles, guidelines, and VibeCoder guidance. Use when user mentions principles, guidelines, safety, or diff-aware editing. Do not use for actual implementation—use the impl skill instead."
description-en: "Provides development principles, guidelines, and VibeCoder guidance. Use when user mentions principles, guidelines, safety, or diff-aware editing. Do not use for actual implementation—use the impl skill instead."
description-ja: "開発原則、ガイドライン、VibeCoder向けガイダンスを提供。Use when user mentions principles, guidelines, safety, or diff-aware editing. Do not use for actual implementation—use the impl skill instead."
allowed-tools: ["Read"]
user-invocable: false
---

# Principles Skills

開発原則とガイドラインを提供するスキル群です。

## 機能詳細

| 機能 | 詳細 |
|------|------|
| **基本原則** | See [references/general-principles.md](${CLAUDE_SKILL_DIR}/references/general-principles.md) |
| **差分編集** | See [references/diff-aware-editing.md](${CLAUDE_SKILL_DIR}/references/diff-aware-editing.md) |
| **コンテキスト読み取り** | See [references/repo-context-reading.md](${CLAUDE_SKILL_DIR}/references/repo-context-reading.md) |
| **VibeCoder** | See [references/vibecoder-guide.md](${CLAUDE_SKILL_DIR}/references/vibecoder-guide.md) |

## 実行手順

1. ユーザーのリクエストを分類
2. 上記の「機能詳細」から適切な参照ファイルを読む
3. その内容を参照・適用
