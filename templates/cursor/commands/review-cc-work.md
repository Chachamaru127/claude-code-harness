---
description: Review Claude Code's work and hand off approval/change requests
---

# /review-cc-work

You are **Cursor (PM)**. Receive the completion report from Claude Code (output of /handoff-to-cursor) and review the changes.

**Important**: After reviewing, generate a **Hand off to Claude** regardless of whether approving or requesting changes.

## Steps

### Step 1: Conduct Review

1. Understand the key points of changed files/diff (`git diff` or from completion report)
2. Judge against acceptance criteria
3. Check from quality, security, and performance perspectives
4. **Verify Evals**: Confirm that the verification based on "Evaluation (Evals)" in Plans.md (tests/logs/bench etc.) has been presented and the results are reasonable

### Step 2: Verdict

| Verdict | Condition | Next Action |
|---------|-----------|-------------|
| **approve** | Acceptance criteria are met | Change the relevant task in Plans.md to `pm:approved` → commit instruction → **stop here** (next task only if user explicitly requests) |
| **request_changes** | Changes are needed | Compile change instructions → generate handoff |

> **When Commit Pending**: If the completion report contains "Commit Status: Pending PM Approval", the approve handoff **must include a commit instruction** (see the approve template below).

### Step 3: Generate Handoff (required)

In either case, generate a handoff message to pass to Claude Code.

---

## Output Format

### Verdict Summary

```
## Review Result

**Verdict**: approve / request_changes
**Reason**:
- (1–3 points)

**Plans.md update**:
- `[Task name]` → changed to `pm:approved` (if approve)
```

### Hand off to Claude (always output)

#### If approve: commit and stop

**Default behavior**: On approve, commit the changes and stop. Only generate a handoff for the next task if the user explicitly requests it.

##### Approval only (default)

Approve → commit instruction → **stop here**. Do not automatically transition to the next task.

~~~markdown
/claude-code-harness:core:work
<!-- ultrathink: requests from PM are generally important tasks, always specify high effort -->
ultrathink

## Request

The previous task has been approved. Please commit the changes.

### Commit Instructions
- The previous changes are approved. Please commit them.
- Work is complete after committing.

### References
- Related files (if any)

After completing the commit, report via `/handoff-to-cursor`
~~~

##### Only when the user explicitly requests the next task

Only use the following template when the user explicitly says something like "move on to the next task" or "continue":

Analyze the next `cc:TODO` or `pm:requested` task from @Plans.md and generate:

~~~markdown
/claude-code-harness:core:work
ultrathink

## Request

The previous task has been approved. Please **commit the changes first**, then implement the next task.

### Commit Instructions
- The previous changes are approved. Please commit them before moving to the next task.

### Target Tasks
- (extract next task from Plans.md)

### Background
- Previous task completed and approved, so this task is now actionable
- (include dependencies if any)

### Constraints
- Follow the existing code style
- Keep changes to the minimum necessary
- Confirm tests/build pass

### Acceptance Criteria
- (3–5 items, specifically)

### References
- Related files (if any)

After completion, report via `/handoff-to-cursor`
~~~

#### If request_changes

Generate a handoff containing change instructions:

~~~markdown
/claude-code-harness:core:work
ultrathink

## Change Request

As a result of the review, the following changes are required.

### Target Tasks
- (relevant task from Plans.md)

### Issues Found
1. **[Severity: High/Medium/Low]** Issue description
   - Location: `filename:line number`
   - Expected fix: specific remediation

2. **[Severity: High/Medium/Low]** Issue description
   - Location:
   - Expected fix:

### Constraints
- Do not break existing tests
- Do not change anything outside the flagged locations

### Acceptance Criteria (after fix)
- All issues above are resolved
- Tests/build pass
- (additional conditions if any)

After completion, report via `/handoff-to-cursor`
~~~

---

## Workflow Diagram

```
Claude Code completion report
        ↓
  /review-cc-work
        ↓
   ┌────┴────┐
   ↓         ↓
approve   request_changes
   ↓         ↓
pm:approved  compile change instructions
   ↓         ↓
commit      generate handoff
   ↓         ↓
 stop        ↓
(next task   ↓
 only on     ↓
 explicit    ↓
 request)    ↓
   ↓         ↓
   └────┬────┘
        ↓
  Paste into Claude Code
        ↓
     /work execution
```
