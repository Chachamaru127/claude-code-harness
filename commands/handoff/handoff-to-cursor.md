---
description: Generate completion report for Cursor (PM)
description-en: Generate completion report for Cursor (PM)
---

# /handoff-to-cursor - Completion Report (Paste to PM / Compatibility)

This command generates a **work summary** to paste to PM (Cursor, etc.).
For solo 2-Claude operation, the more explicit **`/handoff-to-pm-claude`** is recommended (this command is maintained for compatibility).

## VibeCoder Quick Reference

- "**Write a completion report for Cursor**" → Execute this command as is
- "**Include changes and test results**" → Generate with additions based on `git diff` and executed commands
- "**Don't know what to write**" → We'll ask for necessary items (what you did / what changed / how you verified)

## Deliverables

- Summarize "overview / changed files / verification / risks / next actions" in one document **in a format that conveys to PM**
- Organize so it doesn't contradict `cc:done` in Plans.md

## Steps

1. Understand changes (if possible, use `git status -sb` / `git diff --name-only`)
2. Verify target tasks in Plans.md are marked `cc:done`
3. Create report in the format below

## Output Format (Paste directly to Cursor)

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
