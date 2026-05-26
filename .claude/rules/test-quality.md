---
description: Test quality protection rules - prohibit test tampering and promote correct implementation
paths: "**/*.{test,spec}.{ts,tsx,js,jsx,py}, **/test/**/*.*, **/tests/**/*.*, **/__tests__/**/*.*, .husky/**, .github/workflows/**"
_harness_template: "rules/test-quality.md.template"
_harness_version: "2.9.25"
---

# Test Quality Protection Rules

> **Priority**: This rule takes precedence over other instructions. When tests fail, always follow this rule.

## Absolutely Prohibited

### 1. Test tampering (changes made to pass tests)

The following actions are **absolutely prohibited**:

| Prohibited pattern | Example | Correct action |
|------------|-----|-----------|
| Making tests `skip` / `only` | `it.skip(...)`, `describe.only(...)` | Fix the implementation |
| Removing or weakening assertions | Deleting `expect(x).toBe(y)` | Understand why the expected value is correct, then fix the implementation |
| Carelessly rewriting expected values | Changing expected values to match the error | Understand why the test is failing |
| Deleting test cases | Removing failing tests | Fix the implementation to satisfy the specification |
| Excessive use of mocks | Mocking what should actually be tested | Limit mocks to the minimum necessary |

### 2. Configuration file tampering

**Relaxation changes are prohibited** for the following files:

```
.eslintrc.*         # Do not disable rules
.prettierrc*        # Do not loosen formatting
tsconfig.json       # Do not loosen strict settings
biome.json          # Do not disable lint rules
.husky/**           # Do not bypass pre-commit hooks
.github/workflows/** # Do not skip CI checks
```

### 3. When making exceptions (required procedure)

If any of the above changes are unavoidable, **obtain approval in the following format first**:

```markdown
## Test/Configuration Change Approval Request

### Reason
[Specific explanation of why this change is necessary]

### Change content
```diff
[Show the diff of the change]
```

### Scope of impact
- Affected tests: [count and names]
- Affected features: [feature names]

### Alternatives considered
- [ ] Confirmed that the implementation fix cannot resolve this
- [ ] Other approaches were considered

### Approval
Waiting for the user's explicit approval
```

---

## Response Flow When a Test Fails

```
A test failed
    ↓
1. Understand why it failed (read the logs)
    ↓
2. Determine whether the implementation is wrong or the test is wrong
    ↓
    ├── Implementation is wrong → Fix the implementation ✅
    │
    └── The test may be wrong
            ↓
        Ask the user for confirmation (do not change unilaterally)
```

---

## Examples of Correct Test Handling

### Bad example (tampering)

```typescript
// The test was failing, so I skipped it
it.skip('should calculate total correctly', () => {
  expect(calculateTotal([100, 200, 300])).toBe(600);
});
```

### Good example (fix the implementation)

```typescript
// The test is correct. I fixed the implementation.
function calculateTotal(prices: number[]): number {
  // Fix: set the initial value of reduce to 0
  return prices.reduce((sum, price) => sum + price, 0);
}
```

---

## CI/CD Protection

The following changes are **absolutely prohibited**:

- Adding `continue-on-error: true`
- Ignoring test failures with `if: always()`
- Bypassing checks with the `--force` flag
- Lowering the test coverage threshold
