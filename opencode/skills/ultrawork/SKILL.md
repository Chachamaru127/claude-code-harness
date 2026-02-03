---
name: ultrawork
description: "Autonomously iterates until specified Plans.md range is complete - long-running /work with self-learning. Use when user mentions '/ultrawork', complete until done, finish all tasks, or autonomous execution. Do NOT load for: single tasks, reviews, or setup."
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash", "Task"]
argument-hint: "[natural language range] [--max-iterations N] [--codex] [--parallel N] [--worktree-base PATH]"
disable-model-invocation: true
---

# Ultrawork Skill

Plans.md の指定範囲を**完了まで自動的に反復実行**する。
`/work` の長期版として、Ralph Loop + Ultrawork のコンセプトを採用。

## Philosophy

> **「人間介入は失敗シグナル」**
>
> システムが正しく設計されていれば、ユーザーが介入する必要はない。
> 反復 > 完璧性。失敗はデータ。粘り強さが勝つ。

## Quick Reference

```bash
# 自然言語で範囲を指定
/ultrawork 認証機能からユーザー管理まで完了して
/ultrawork ログイン機能を終わらせて
/ultrawork Header, Footer, Sidebar を作って

# シンプルに全部
/ultrawork 全部やって
/ultrawork Plans.md 完了まで

# 前回の続きから
/ultrawork 続きやって
```

## /work との違い

| 特徴 | /work | /ultrawork |
|------|-------|------------|
| 実行範囲 | cc:TODO / pm:requested | **指定範囲の全タスク** |
| 反復 | 1回 | **完了まで自動反復** |
| 完了条件 | タスク実装完了 | **全タスク + ビルド + テスト + Review** |
| 自己学習 | なし | **前回の失敗から学習** |
| 用途 | 1-2タスク | **大規模な実装を放置実行** |

## Feature Details

| Feature | Reference |
|---------|-----------|
| **Execution Flow** | See [references/execution-flow.md](references/execution-flow.md) |
| **Self-Learning** | See [references/self-learning.md](references/self-learning.md) |
| **Security & Guards** | See [references/security-guards.md](references/security-guards.md) |
| **Session State** | See [references/session-state.md](references/session-state.md) |
| **Codex Mode** (Experimental) | See [references/codex-mode.md](references/codex-mode.md) |

## Completion Conditions

以下の**全て**を満たしたとき完了:

1. ✅ 指定範囲の全タスクが `cc:done`
2. ✅ 全体ビルド成功
3. ✅ 全テスト通過
4. ✅ harness-review で APPROVE
5. ✅ `review_status === "passed"`

## VibeCoder Hints

| What You Want | How to Say |
|---------------|------------|
| 全部終わらせて | `/ultrawork 全部やって` |
| この機能だけ | `/ultrawork ログイン機能を完了して` |
| ここからここまで | `/ultrawork 認証からユーザー管理まで` |
| 前回の続きから | `/ultrawork 続きやって` |
| もっと粘って | 「もっと粘って」「諦めないで」 |
