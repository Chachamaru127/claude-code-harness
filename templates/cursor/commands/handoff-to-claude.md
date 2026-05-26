---
description: Generate a work request prompt to hand off to Claude Code
---

# /handoff-to-claude

You are **Cursor (PM)**. Generate a work request to pass to Claude Code in a copy-and-paste-ready format.

## Input

- @Plans.md (to identify the target task)
- If possible: `git status -sb` and `git diff --name-only`

## Output (paste directly into Claude Code)

Output the following Markdown:

```markdown
/claude-code-harness:core:work
<!-- ultrathink: requests from PM are generally important tasks, always specify high effort -->
ultrathink

## Request
Please implement the following.

- Target tasks:
  - (list relevant tasks from Plans.md)

## Constraints
- Follow the existing code style
- Keep changes to the minimum necessary
- Provide test/build steps if available

## Acceptance Criteria
- (3–5 items)

## Evals (grading/verification)
Follow the "Evaluation (Evals)" section in Plans.md and proceed in a way that allows **outcome/transcript to be graded**.

- tasks (scenarios):
  - (example: specific input / steps / expected result)
- trials (count/aggregation):
  - (example: 3 runs, success rate + median)
- graders (scoring):
  - outcome:
    - (example: unit tests / typecheck / file state)
  - transcript:
    - (example: no prohibited actions / no unnecessary changes)
- execution command (if possible):
  - (example: `npm test`, `./tests/validate-plugin.sh`, etc.)

## References
- Related files (if any)

**After completing work**: run `/handoff-to-cursor` to report completion
```

