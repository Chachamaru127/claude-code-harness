---
name: session-control
description: "Apply /work --resume/--fork flags by updating session state files."
allowed-tools: ["Read", "Bash", "Write", "Edit"]
---

# Session Control

## Input

Workflow variables:
- `resume_session_id` (string)
- `resume_latest` (boolean)
- `fork_session_id` (string)
- `fork_reason` (string)

## Execution

### 1) Determine arguments
- resume:
  - `resume_latest == true` → `--resume latest`
  - Otherwise, if `resume_session_id` is set → `--resume <id>`
- fork:
  - If `fork_session_id` is set → `--fork <id>`, otherwise `--fork current`
  - If `fork_reason` is set → `--reason "<text>"`

### 2) Run script
```bash
./scripts/session-control.sh --resume <id|latest>
./scripts/session-control.sh --fork <id|current> --reason "<text>"
```

## Expected Results
- `.claude/state/session.json` is updated
- `session.resume` or `session.fork` is appended to `.claude/state/session.events.jsonl`
- On error, the reason is written to stderr
