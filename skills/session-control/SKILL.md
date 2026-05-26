---
name: session-control
description: "Controls session resume/fork(branch) for /work based on --resume/--fork flags. Updates session.json and session.events.jsonl. Internal workflow use only. Do NOT load for: user session management, login state, app state handling."
allowed-tools: ["Read", "Bash", "Write", "Edit"]
user-invocable: false
disable-model-invocation: true
---

# Session Control Skill

Switches session state based on the `--resume` / `--fork` flags passed to /work.

## Feature Details

| Feature | Details |
|---------|---------|
| **Session resume/fork** | See [references/session-control.md](${CLAUDE_SKILL_DIR}/references/session-control.md) |

## Execution Steps

1. Verify variables passed from the workflow
2. Run `scripts/session-control.sh` with the appropriate arguments
3. Confirm that `session.json` and `session.events.jsonl` have been updated
