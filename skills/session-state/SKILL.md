---
name: session-state
description: "Manages session state transitions per SESSION_ORCHESTRATION.md. Controls state updates at /work phase boundaries, escalated transitions on error, and initialized restoration on session resume. Internal workflow use only. Do NOT load for: user session management, login state, app state handling."
allowed-tools: ["Read", "Bash"]
user-invocable: false
disable-model-invocation: true
---

# Session State Skill

Internal skill for managing session state transitions.
Validates and executes transitions according to the state machine defined in `docs/SESSION_ORCHESTRATION.md`.

## Feature Details

| Feature | Details |
|---------|---------|
| **State transitions** | See [references/state-transition.md](${CLAUDE_SKILL_DIR}/references/state-transition.md) |

## When to Use

- State updates at `/work` phase boundaries
- `escalated` transition on error
- `stopped` transition at session end
- `initialized` restoration on session resume

## Notes

- This skill is for internal use only
- It is not intended to be invoked directly by users
- State transition rules are defined in `docs/SESSION_ORCHESTRATION.md`
