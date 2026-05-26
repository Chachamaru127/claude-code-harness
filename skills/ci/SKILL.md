---
name: ci
description: "CI red? Call us. Pipeline fire brigade deploys. Use when user mentions CI failures, build errors, test failures, or pipeline issues. Do NOT load for: local builds, standard implementation work, reviews, or setup."
allowed-tools: ["Read", "Grep", "Bash", "Task", "Monitor"]
user-invocable: true
context: fork
argument-hint: "[analyze|fix|run]"
---

# CI/CD Skills

Skills for resolving issues with CI/CD pipelines.

---

## Trigger Conditions

- "CI is broken", "GitHub Actions failed"
- "Build error", "tests aren't passing"
- "Fix the pipeline"

---

## Feature Details

| Feature | Details | Trigger |
|---------|---------|---------|
| **Failure analysis** | See [references/analyzing-failures.md](${CLAUDE_SKILL_DIR}/references/analyzing-failures.md) | "Check the logs", "Investigate the cause" |
| **Test fixing** | See [references/fixing-tests.md](${CLAUDE_SKILL_DIR}/references/fixing-tests.md) | "Fix the tests", "Propose a fix" |

---

## Execution Steps

1. **Test vs. implementation verdict** (Step 0)
2. Classify the user's intent (analyze or fix)
3. Determine complexity (see below)
4. Read the appropriate reference file from "Feature Details" above, or launch the ci-cd-fixer sub-agent
5. Verify results and re-run if necessary

### Step 0: Test vs. Implementation Verdict (Quality Gate)

When CI fails, first triage the root cause:

```
CI failure report
    ↓
┌─────────────────────────────────────────┐
│        Test vs. Implementation          │
├─────────────────────────────────────────┤
│  Analyze the cause:                     │
│  ├── Implementation is wrong → fix impl │
│  ├── Test is outdated → confirm with user│
│  └── Environment issue → fix environment│
└─────────────────────────────────────────┘
```

#### Prohibited Actions (tampering prevention)

```markdown
Prohibited actions when CI fails

The following "solutions" are prohibited:

| Prohibited | Example | Correct approach |
|------------|---------|-----------------|
| Skipping tests | `it.skip(...)` | Fix the implementation |
| Removing assertions | Deleting `expect()` | Verify expected values |
| Bypassing CI checks | `continue-on-error` | Fix the root cause |
| Relaxing lint rules | `eslint-disable` | Fix the code |
```

#### Decision Flow

```markdown
CI is failing

**Decision needed**:

1. **Implementation is wrong** → Fix the implementation
2. **Test expectations are outdated** → Ask the user to confirm
3. **Environment issue** → Fix the environment configuration

Tampering with tests (skipping, deleting assertions) is prohibited

Which case applies?
```

#### When Approval Is Required

When test/configuration changes are unavoidable:

```markdown
## Test/Configuration Change Approval Request

### Reason
[Why this change is necessary]

### Changes
[Diff]

### Alternatives Considered
- [ ] Confirmed whether fixing the implementation would resolve this

Waiting for explicit user approval
```

### Using Git Log Extended Flags (CC 2.1.49+)

Use structured logs to identify the commit that caused CI failures.

#### Identifying the Offending Commit

```bash
# Analyze commits in structured format
git log --format="%h|%s|%an|%ad" --date=short -10

# Analyze chronology in topological order
git log --topo-order --oneline -20

# Link changed files to the cause
git log --raw --oneline -5
```

#### Common Use Cases

| Use | Flag | Effect |
|-----|------|--------|
| **Identifying failure cause** | `--format="%h|%s"` | Structured commit listing |
| **Chronological tracking** | `--topo-order` | Tracking considering merge order |
| **Understanding change impact** | `--raw` | Detailed file change display |
| **Merge-excluded analysis** | `--cherry-pick --no-merges` | Extract only real commits |

#### Sample Output

```markdown
CI Failure Cause Analysis

Recent commits (structured):
| Hash | Subject | Author | Date |
|------|---------|--------|------|
| a1b2c3d | feat: update API | Alice | 2026-02-04 |
| e4f5g6h | test: add tests | Bob | 2026-02-03 |

Changed files (--raw):
├── src/api/endpoint.ts (Modified) ← type error here
├── tests/api.test.ts (Modified)
└── package.json (Modified)

→ Commit a1b2c3d is likely the cause
  Type error: src/api/endpoint.ts:42
```

## Sub-Agent Integration

Launch ci-cd-fixer via the Task tool when any of the following conditions are met:

- The fix → re-run → fail loop has occurred **2 or more times**
- Or the error spans multiple files and is complex

**Launch pattern:**

```
Task tool:
  subagent_type="ci-cd-fixer"
  prompt="Diagnose and fix the CI failure. Error log: {error_log}"
```

ci-cd-fixer operates with safety first (default dry-run mode).
See `agents/ci-cd-fixer.md` for details.

---

## For VibeCoder (non-technical users)

```markdown
How to talk about CI failures

1. **"CI broke", "it went red"**
   - Automated tests are failing

2. **"Why is it failing?"**
   - I want you to investigate the cause

3. **"Fix it"**
   - Try to fix it automatically

Important: Faking fixes by tampering with tests is prohibited
   - No: delete tests, skip tests
   - Yes: fix the code correctly

If you think "the test might be wrong",
confirm first before deciding what to do
```
