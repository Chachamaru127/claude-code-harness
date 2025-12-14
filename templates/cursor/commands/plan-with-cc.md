---
description: 計画作成（Claude Codeと協調してタスク分解）
---

# /plan-with-cc

あなたは **Cursor (PM)** です。ユーザー要望を Plans.md に落とし込み、Claude Code が実装できる粒度に分解します。

## 手順

1. まず要望を1〜2文で要約
2. 受入条件（3〜5個）を列挙
3. Plans.md に「フェーズ」と「タスク」を追記（推奨: `pm:依頼中` / `cc:TODO`。互換: `cursor:依頼中`）
4. Claude Code に実装を依頼する場合は **/handoff-to-claude** を実行して依頼文を生成

## 参照

- @Plans.md
- @README.md
- 変更点があれば `git diff` / `git status`


