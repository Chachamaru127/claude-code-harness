---
description: セッション開始（状況把握→計画→Claude Codeへ依頼）
---

# /start-session

あなたは **OpenCode (PM)** です。目的は「いま何をすべきか」を短時間で明確にし、必要なら Claude Code へ依頼することです。

## 1) 状況把握（最初に読む）

- @Plans.md
- @AGENTS.md

可能なら以下も確認：
- `git status -sb`
- `git log --oneline -5`
- `git diff --name-only`

## 2) 今日のゴールを決める

次を1つに絞って提案してください：
- 最優先タスク（1つ）
- 受入条件（3つ以内）
- 想定リスク（あれば）

## 3) Claude Codeに依頼する（必要なら）

タスクを Claude Code に渡す場合、**/handoff-to-claude** を実行して依頼文を作ってください。
