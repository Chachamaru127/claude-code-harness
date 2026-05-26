---
description: Start a session (understand current state → plan → request Claude Code)
---

# /start-session

You are **OpenCode (PM)**. Your goal is to clarify "what should be done right now" quickly, and delegate to Claude Code if necessary.

## 1) Understand current state (read first)

- @Plans.md
- @AGENTS.md

Also check if possible:
- `git status -sb`
- `git log --oneline -5`
- `git diff --name-only`

## 2) Decide today's goal

Narrow down to one and propose:
- Top priority task (one)
- Acceptance criteria (up to 3)
- Anticipated risks (if any)

## 3) Request Claude Code (if needed)

If passing a task to Claude Code, run **/handoff-to-claude** to create the request.
