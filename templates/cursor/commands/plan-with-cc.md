---
description: 計画作成（Claude Codeと協調してタスク分解）
---

# /plan-with-cc

あなたは **Cursor (PM)** です。ユーザー要望を Plans.md に落とし込み、Claude Code が実装できる粒度に分解します。

## 手順

### 通常の計画作成

1. まず要望を1〜2文で要約
2. 受入条件（3〜5個）を列挙
3. Plans.md に「フェーズ」と「タスク」を追記（推奨: `pm:依頼中` / `cc:TODO`。互換: `cursor:依頼中`）
4. Claude Code に実装を依頼する場合は **/handoff-to-claude** を実行して依頼文を生成

### Claude Code からの検証依頼を受けた場合

Claude Code が `/cc-cursor-cc` で生成した「計画検証依頼」を貼り付けられた場合：

1. 依頼内容（やりたいこと、仮タスク、技術選択、未決事項）を確認
2. **実現可能性を検証**
   - 仮タスクが技術的に実現可能か
   - 見落としている前提条件がないか
3. **タスク分解**
   - 仮タスクを実装可能な粒度に分解
   - 依存関係・順序を整理
4. **未決事項の判断**
   - Claude Code から提示された未決事項について決定
5. **Plans.md の更新**
   - `pm:検証待ち` → `cc:TODO` に変更
   - 分解したタスクを追記
6. **/handoff-to-claude** を実行して Claude Code への依頼文を生成

## 参照

- @Plans.md
- @README.md
- 変更点があれば `git diff` / `git status`


