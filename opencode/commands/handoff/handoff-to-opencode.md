---
description: Generate completion report for OpenCode (PM)
---

# /handoff-to-opencode - Completion Report (Paste to OpenCode PM)

This command generates a **work summary** to paste to OpenCode PM.
For Cursor PM, use **`/handoff-to-cursor`** instead.

## VibeCoder Quick Reference

- "**Write a completion report for OpenCode**" → Execute this command
- "**OpenCode PM に報告**" → このコマンドを実行
- "**PM に完了報告**" → このコマンドを実行

## Deliverables

- Summarize "overview / changed files / verification / risks / next actions" in one document **in a format that conveys to PM**
- Organize so it doesn't contradict `cc:done` in Plans.md

## Steps

1. Understand changes (if possible, use `git status -sb` / `git diff --name-only`)
2. Verify target tasks in Plans.md are marked `cc:done`
3. Create report in the format below

## Output Format (Paste directly to OpenCode)

```markdown
## Completion Report

### Overview
- (What was done, 1-3 lines)

### Changed Files
- (File list)

### Verification / Tests
- (Verification performed, recommended commands)

### Risks / Notes
- (If any)

### Next Action Suggestions
- (1-3 options for PM to choose from)
```
