---
name: principles
description: "Explicit helper for development principles, safety guidelines, and diff-aware editing rules. Do NOT load for: implementation, review, workflow coaching, or VibeCoder onboarding."
description-en: "Explicit helper for development principles, safety guidelines, and diff-aware editing rules. Do NOT load for: implementation, review, workflow coaching, or VibeCoder onboarding."
description-ja: "開発原則、安全ガイドライン、差分尊重の編集ルールを確認する明示補助スキル。実装、レビュー、進め方相談、VibeCoder案内には使わない。"
allowed-tools: ["Read"]
user-invocable: false
disable-model-invocation: true
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
