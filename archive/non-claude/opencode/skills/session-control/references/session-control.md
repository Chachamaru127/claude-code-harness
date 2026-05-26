---
name: session-control
description: "Apply /work --resume/--fork flags by updating session state files."
allowed-tools: ["Read", "Bash", "Write", "Edit"]
---

# Session Control

## 入力

workflow 変数:
- `resume_session_id` (string)
- `resume_latest` (boolean)
- `fork_session_id` (string)
- `fork_reason` (string)

## 実行

### 1) 引数の決定
- resume:
  - `resume_latest == true` → `--resume latest`
  - それ以外で `resume_session_id` があれば `--resume <id>`
- fork:
  - `fork_session_id` があれば `--fork <id>`、なければ `--fork current`
  - `fork_reason` があれば `--reason "<text>"`

### 2) スクリプト実行
```bash
./scripts/session-control.sh --resume <id|latest>
./scripts/session-control.sh --fork <id|current> --reason "<text>"
```

## 期待される結果
- `.claude/state/session.json` が更新される
- `.claude/state/session.events.jsonl` に `session.resume` または `session.fork` が追記される
- エラー時は stderr に理由が出力される
