---
description: CI-only non-interactive implementation (benchmark use)
description-en: CI-only non-interactive implementation (benchmark use)
user-invocable: false
---

# /work-ci - CI-only Implementation Execution

**Benchmark only**: Implements tasks from Plans.md non-interactively.

## Constraints (CI use)

- **AskUserQuestion prohibited**: Proceed without asking questions
- **WebSearch prohibited**: Proceed without external search
- **Confirmation prompts prohibited**: Proceed automatically to completion
- **Build verification**: Run `npm test` / `npm run build` if possible

## Input

Read `benchmarks/test-project/Plans.md`.

## Execution Steps

1. **Read Plans.md**: Extract tasks with `cc:TODO` marker
2. **Implement sequentially**: Implement each task
   - Create/edit files
   - Create tests as needed
3. **Update markers**: Change completed tasks to `cc:done`
4. **Build verification**: Run `npm test` or `npm run build` (if possible)
5. **Completion output**: Report implementation result summary

## Output Format

```
## Implementation Result

### Completed Tasks
- [x] Task 1 `cc:done`
- [x] Task 2 `cc:done`

### Created/Changed Files
- src/utils/helper.ts (new)
- src/index.ts (modified)

### Build Result
- Tests: 5/5 passed
- Build: success
```

## Success Criteria

- 1 or more tasks are `cc:done`
- Implemented files exist
- Build/tests pass (if applicable)

## On Failure

- Output error to log and continue (don't stop midway)
- Leave failed tasks as `cc:TODO`
- Report final success/failure counts
