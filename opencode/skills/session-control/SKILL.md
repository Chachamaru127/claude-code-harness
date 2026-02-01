---
name: session-control
description: "Controls session resume/fork for /work based on flags. Internal use only from workflow. Do NOT load for: user session management, login state, app state handling."
allowed-tools: ["Read", "Bash", "Write", "Edit"]
user-invocable: false
---

# Session Control Skill

/work の `--resume` / `--fork` フラグに応じてセッション状態を切り替える。

## 機能詳細

| 機能 | 詳細 |
|------|------|
| **セッション再開/分岐** | See [references/session-control.md](references/session-control.md) |

## 実行手順

1. workflow から渡された変数を確認
2. `scripts/session-control.sh` を適切な引数で実行
3. `session.json` と `session.events.jsonl` の更新を確認
