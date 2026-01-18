---
description: CI-only non-interactive review (benchmark use)
description-en: CI-only non-interactive review (benchmark use)
user-invocable: false
---

# /harness-review-ci - CI-only Review Execution

**Benchmark only**: Reviews changes non-interactively and outputs in machine-gradable format.

## Constraints (CI use)

- **AskUserQuestion prohibited**: Proceed without asking questions
- **WebSearch prohibited**: Proceed without external search
- **Confirmation prompts prohibited**: Proceed automatically to completion
- **Fix application prohibited**: Report review results only (do not apply fixes)

## Input

Detect changed files under `benchmarks/test-project/`.

## Output Format (for machine grading)

**Required**: Include `Severity:` line for each issue.

```
## Review Result

### Summary
- Files Reviewed: 5
- Total Issues: 3
- Critical: 0
- High: 1
- Medium: 2
- Low: 0

### Issues

#### Issue 1
- File: src/utils/helper.ts
- Line: 25
- Severity: High
- Category: Security
- Description: SQL injection vulnerability in query construction
- Suggestion: Use parameterized queries

#### Issue 2
- File: src/index.ts
- Line: 42
- Severity: Medium
- Category: Quality
- Description: Missing error handling for async operation
- Suggestion: Add try-catch block

#### Issue 3
- File: src/components/Form.tsx
- Line: 15
- Severity: Medium
- Category: Accessibility
- Description: Button missing aria-label
- Suggestion: Add aria-label for screen readers

### Pass/Fail
- Result: PASS
- Reason: No critical issues found
```

## Severity Definitions

| Severity | Criteria |
|----------|----------|
| Critical | Security vulnerabilities, data loss risk |
| High | Serious bugs, performance issues |
| Medium | Code quality, best practice violations |
| Low | Style, minor improvements |

## Success Criteria

- Review results are output
- Each issue has Severity assigned
- Summary section has aggregation
- Pass/Fail judgment exists

## Grading Logic

- **PASS**: Critical is 0 AND High is 2 or less
- **FAIL**: Critical is 1 or more, OR High is 3 or more

## On Failure

- Output error to log and exit
- Report "No files to review" if no review targets
