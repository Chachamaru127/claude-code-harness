---
name: ci-fix-failing-tests
description: "Guide for fixing tests that fail in CI. Use when a CI failure cause has been identified and you want to attempt automatic fixes."
allowed-tools: ["Read", "Edit", "Bash"]
---

# CI Fix Failing Tests

A skill for fixing tests that fail in CI.
Fixes either the test code or the production code.

---

## Inputs

- **Failed test information**: Test name, error message
- **Test file**: Source of the failing test
- **Code under test**: The implementation being tested

---

## Outputs

- **Fixed code**: Fix to the test or implementation
- **Confirmation that tests pass**

---

## Execution Steps

### Step 1: Identify failing tests

```bash
# Run tests locally
npm test 2>&1 | tail -50

# Test a specific file
npm test -- {{test-file}}
```

### Step 2: Classify error type

#### Type A: Assertion failure

```
Expected: "expected value"
Received: "actual value"
```

→ Implementation differs from expectation, or the test's expected value is wrong

#### Type B: Timeout

```
Timeout - Async callback was not invoked within the 5000ms timeout
```

→ Async operation is not completing, or is taking too long

#### Type C: Type error

```
TypeError: Cannot read properties of undefined
```

→ Accessing null/undefined, or initialization issue

#### Type D: Mock-related

```
expected mockFn to have been called
```

→ Mock not configured, or the call is not happening

### Step 3: Determine the fix strategy

```markdown
## Fix Strategy Decision

1. **If the test is correct** → Fix the implementation
2. **If the implementation is correct** → Fix the test
3. **If both need fixing** → Prioritize the implementation

Decision criteria:
- Which is correct per spec / requirements?
- What changed recently?
- Impact on other tests
```

### Step 4: Implement the fix

#### Fixing assertion failures

```typescript
// If the test's expected value is wrong
it('calculates correctly', () => {
  // Before fix
  expect(calculate(2, 3)).toBe(5)
  // After fix (if the spec requires multiplication)
  expect(calculate(2, 3)).toBe(6)
})

// If the implementation is wrong
// → Fix the implementation file
```

#### Fixing timeouts

```typescript
// Increase timeout
it('fetches data', async () => {
  // ...
}, 10000)  // Increased to 10 seconds

// Or use async/await correctly
it('fetches data', async () => {
  await waitFor(() => {
    expect(screen.getByText('Data')).toBeInTheDocument()
  })
})
```

#### Fixing mock-related issues

```typescript
// Add mock configuration
vi.mock('../api', () => ({
  fetchData: vi.fn().mockResolvedValue({ data: 'mock' })
}))

// Reset in beforeEach
beforeEach(() => {
  vi.clearAllMocks()
})
```

### Step 5: Verify after fix

```bash
# Re-run the failing test
npm test -- {{test-file}}

# Run all tests (regression check)
npm test
```

---

## Fix Patterns

### Updating snapshots

```bash
# Update snapshots
npm test -- -u

# Only specific test
npm test -- {{test-file}} -u
```

### Fixing async tests

```typescript
// Use findBy (auto-waits)
const element = await screen.findByText('Text')

// Use waitFor
await waitFor(() => {
  expect(mockFn).toHaveBeenCalled()
})
```

### Updating mock data

```typescript
// Update mocks to match implementation changes
const mockData = {
  id: 1,
  name: 'Test',
  createdAt: new Date().toISOString()  // New field
}
```

---

## Post-Fix Checklist

- [ ] Previously failing tests now pass
- [ ] Other tests are not broken
- [ ] Aligns with the implementation's intent
- [ ] Tests are not overly lax

---

## Completion Report Format

```markdown
## Tests Fixed

### What Was Fixed

| Test | Problem | Fix |
|------|---------|-----|
| `{{test name}}` | {{problem}} | {{fix applied}} |

### Verification Result

```
Tests: {{passed}} passed, {{total}} total
```

### Next Actions

"Commit it" or "Re-run CI"
```

---

## Notes

- **Do not delete tests**: Deletion is a last resort
- **Skipping is temporary only**: Permanent skips are prohibited
- **Identify the root cause**: Avoid surface-level fixes
