# Code Review Flow

## Summary

Collect the diff, inspect implementation, spec, Plans, regressions, and tests — then block only what must be blocked.

## Step 1: collect diff

Check the following:

```bash
git status --short
git diff --stat "${BASE_REF:-HEAD}"
git diff "${BASE_REF:-HEAD}"
git ls-files --others --exclude-standard
```

Untracked files do not appear in `git diff`.
Always include them in scope.

## Step 2: static scans

AI Residuals:

```bash
bash scripts/review-ai-residuals.sh --base "${BASE_REF:-HEAD}"
bash scripts/review-weak-supervision-report.sh
```

Candidates:

- `mockData`
- `dummy`
- `fake`
- `localhost`
- `TODO`
- `FIXME`
- `it.skip`
- `describe.skip`
- `test.skip`
- `expect(true).toBe(true)`

Finding a candidate alone is not grounds for `major`.
Judge in diff context: does it directly cause a production incident or misconfiguration?

## Step 3: eight review lenses

| Lens | What to check |
|---|---|
| Security | SQL injection, cross-site scripting, secret leak, permission bypass |
| Performance | N+1, needless heavy IO, blocking work |
| Quality | duplicate logic, unclear boundary, fragile parsing |
| Accessibility | labels, focus, contrast, keyboard path |
| AI Residuals | fake success, skipped tests, mock-only implementation |
| Spec Alignment | contradicts the spec source of truth |
| Plans Alignment | matches `Plans.md` task / DoD / Depends |
| Regression Safety | regressions in existing behavior, mirror, CLI/skill UX |

## TDD compliance

For tasks that require TDD, verify there is evidence of a failing test written first.
For docs-only or refactor-only work where TDD would be excessive, record a skip reason.

## Verdict

1. critical / major found → `REQUEST_CHANGES`
2. spec source of truth / `Plans.md` / regression gate fails → `REQUEST_CHANGES`
3. decision needed → `decision_needed`
4. minor / recommendation only → `APPROVE`
5. insufficient evidence → `REQUEST_CHANGES` or `decision_needed`

## Re-review after fixes

After `REQUEST_CHANGES`, always re-review after fixes.
If the same issue is raised twice consecutively, force a TeamAgent Debate.
