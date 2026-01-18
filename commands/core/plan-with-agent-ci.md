---
description: CI-only non-interactive planning (benchmark use)
description-en: CI-only non-interactive planning (benchmark use)
user-invocable: false
---

# /plan-with-agent-ci - CI-only Plan Creation

**Benchmark only**: Generates Plans.md non-interactively.

## Constraints (CI use)

- **AskUserQuestion prohibited**: Proceed without asking questions
- **WebSearch prohibited**: Proceed without external search
- **Confirmation prompts prohibited**: Proceed automatically to completion

## Input

Receive requirements (task prompt) as command arguments:

```
/plan-with-agent-ci <requirements text>
```

## Output

Generate/update `benchmarks/test-project/Plans.md`:

```markdown
## Task List

- [ ] Task 1 description `cc:TODO`
- [ ] Task 2 description `cc:TODO`
- [ ] Task 3 description `cc:TODO`
```

## Execution Steps

1. **Parse requirements**: Extract requirements from arguments
2. **Task decomposition**: Break down into implementable units (around 3-7)
3. **Generate Plans.md**: Write to `benchmarks/test-project/Plans.md`
4. **Completion output**: Report number of generated tasks

## Success Criteria

- Plans.md exists
- 3 or more tasks are listed with `cc:TODO` marker
- Each task has concrete implementable content

## On Failure

- Output error to log and exit (don't stop midway)
- Clearly state why Plans.md could not be generated
