# Error Handling

## Partial Failure in Parallel Execution

```
📊 Parallel Execution Complete (partial error)

├── [Agent 1] Create Header ✅ (25s)
├── [Agent 2] Create Footer ❌ Error
│   └── Cause: Import path not found
└── [Agent 3] Create Sidebar ✅ (22s)

⚠️ 1 task failed.

Options:
1. Retry failed task only
2. Check error details and fix manually
3. Rollback everything
```

**Response**:
1. Keep successful task results
2. Show failed task error details
3. Try auto-fix with `error-recovery` skill (max 3 times)

## All Tasks Failed

```
❌ Parallel Execution Failed

All tasks encountered errors.
There may be a common cause.

Error analysis:
- All tasks have `@/lib/supabase` import error
- Cause: supabase.ts not created

Recommended action:
1. Create dependency file first
2. Review execution order
```

## LSP Feature Utilization

### Before Implementation: Code Understanding

| LSP Feature | Use Case | Effect |
|-------------|----------|--------|
| **Go-to-definition** | Check existing function internals | Quickly grasp implementation patterns |
| **Find-references** | Pre-survey impact scope | Prevent unintended breaking changes |
| **Hover** | Check type info & docs | Implement with correct interfaces |

### During Implementation: Real-time Verification

| LSP Feature | Use Case | Effect |
|-------------|----------|--------|
| **Diagnostics** | Instant type/syntax error detection | Find issues before build |
| **Completions** | Correct API usage | Prevent typos & wrong arguments |

### After Implementation: Related Files Check

```
Run related files verification:
→ Detect function signature changes → check callers
→ Detect interface/type changes → check implementations
→ Detect export changes → check importers
→ Detect config changes → check related configs
```

**Example output**:
```
📋 Related Files Verification

⚠️ Files to check:
├─ src/api/auth.ts:45 (calls modified function)
├─ tests/user.test.ts:28 (test for modified code)
└─ docs/api.md (documentation may need update)

1. Confirmed, proceed
2. Check each file
3. Show LSP find-references
```
