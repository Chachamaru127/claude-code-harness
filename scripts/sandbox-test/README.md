# Sandbox Test

> Test directory for verifying `/work --full` behavior

## Purpose

This directory was created to verify the behavior of the `/work --full` command and the `task-worker` agent added in Claude harness v2.9.0.

## File Structure

| File | Description |
|---------|------|
| `greeting.ts` | Utility functions for testing |
| `greeting.test.ts` | Unit tests (Vitest) |
| `README.md` | This file |

## Running Tests

```bash
# If Vitest is installed
npx vitest run scripts/sandbox-test/

# Or
bun test scripts/sandbox-test/
```

## /work --full Test Results

This directory was generated with the following command:

```bash
/work --full --parallel 3
```

### Expected Behavior

1. **Phase 1**: 3 task-workers launch in parallel
   - task-worker #1: create `greeting.ts`
   - task-worker #2: create `greeting.test.ts`
   - task-worker #3: create `README.md`

2. **Phase 2**: Codex 8-way parallel cross-review (optional)

3. **Phase 3**: Conflict resolution → commit

## Related Documentation

- [/work --full documentation](../../docs/PARALLEL_FULL_CYCLE.md)
- [task-worker agent](../../agents/task-worker.md)
