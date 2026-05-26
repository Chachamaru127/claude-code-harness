---
name: state-transition
description: "Execute session state transitions using session-state.sh"
allowed-tools: [Read, Bash]
---

# State Transition

セッション状態の遷移を実行する。

## 入力

workflow 変数:
- `target_state` (string): 遷移先の状態
- `event_name` (string): トリガーイベント
- `event_data` (string, optional): イベント付加データ (JSON)

## 有効な状態

| 状態 | 説明 |
|------|------|
| `idle` | セッション未開始 |
| `initialized` | SessionStart 完了 |
| `planning` | Plan/Work の準備 |
| `executing` | /work 実行中 |
| `reviewing` | review 実行中 |
| `verifying` | build/test 実行中 |
| `escalated` | 人間確認待ち |
| `completed` | 成果物確定 |
| `failed` | 回復不能 |
| `stopped` | Stop hook 到達 |

## 代表的な遷移

| From | Event | To |
|------|-------|----|
| idle | session.start | initialized |
| initialized | plan.ready | planning |
| planning | work.start | executing |
| executing | work.task_complete | reviewing |
| reviewing | verify.start | verifying |
| verifying | verify.passed | completed |
| verifying | verify.failed | escalated |
| * | session.stop | stopped |
| stopped | session.resume | initialized |

## 実行

```bash
./scripts/session-state.sh --state <state> --event <event> [--data <json>]
```

### 例: 実行状態への遷移

```bash
./scripts/session-state.sh --state executing --event work.start
```

### 例: エスカレーション（データ付き）

```bash
./scripts/session-state.sh --state escalated --event escalation.requested \
  --data '{"reason":"Build failed 3 times","retry_count":3}'
```

## 期待される結果

- `.claude/state/session.json` の `state`, `updated_at`, `last_event_id`, `event_seq` が更新される
- `.claude/state/session.events.jsonl` にイベントが追記される
- 不正な遷移は stderr にエラー出力 + 非ゼロ終了

## エラーハンドリング

遷移が失敗した場合（不正な遷移など）:
1. 現在の状態と許可された遷移を stderr に出力
2. 非ゼロ終了コードを返す
3. 呼び出し元（workflow）でエスカレーション処理を行う
