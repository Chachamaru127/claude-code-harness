---
name: session-state
version: 1.0.0
description: "Manages session state transitions per SESSION_ORCHESTRATION.md. Internal use only. Do NOT load for: user session management, login state, app state handling."
allowed-tools: ["Read", "Bash"]
user-invocable: false
dependencies: []
---

# Session State Skill

セッション状態の遷移を管理する内部スキル。
`docs/SESSION_ORCHESTRATION.md` に定義された状態機械に従って遷移を検証・実行する。

## 機能詳細

| 機能 | 詳細 |
|------|------|
| **状態遷移** | See [references/state-transition.md](references/state-transition.md) |

## 使用タイミング

- `/work` フェーズ境界での状態更新
- エラー発生時の `escalated` 遷移
- セッション終了時の `stopped` 遷移
- セッション再開時の `initialized` 復帰

## 注意事項

- このスキルは内部使用専用です
- ユーザーが直接呼び出すことは想定していません
- 状態遷移ルールは `docs/SESSION_ORCHESTRATION.md` で定義
