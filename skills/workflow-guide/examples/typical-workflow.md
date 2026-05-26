# Typical Workflow Examples

Real-world flow of the two-agent workflow.

---

## Example 1: New Feature Development

### Phase 1: PM (Cursor) creates a task

```markdown
# Plans.md

## 🟡 Pending Tasks

- [ ] User profile editing feature `pm:依頼中`
  - Edit name, email, and avatar image
  - With validation
  - Save change history
```

**PM says**: "Claude Code, please implement the profile editing feature."

---

### Phase 2: Claude Code begins work

```bash
# Run in Claude Code
/work
```

**Claude Code actions**:
1. Read Plans.md
2. Detect `pm:依頼中` task
3. Update marker to `cc:WIP`
4. Begin implementation
5. Quality review with `/harness-review`
6. Fix any findings → re-review (loop, up to 3 times)
7. Review OK → Auto-commit

```markdown
# Plans.md (after update)

## 🔴 In-Progress Tasks

- [ ] User profile editing feature `cc:WIP`
  - Edit name, email, and avatar image
  - With validation
  - Save change history
  - Related files:
    - `src/components/ProfileForm.tsx`
    - `src/lib/api/profile.ts`
```

---

### Phase 3: Claude Code reports completion (2-Agent mode only)

After Review OK and Auto-commit, in 2-Agent mode run `/handoff-to-cursor` to report to the PM.

> **Handoff is not needed in Solo mode** — /work is complete once Review OK → Auto-commit.

```bash
# Run in Claude Code (2-Agent mode only)
/handoff-to-cursor
```

**Generated report**:

```markdown
## 📋 Completion Report: User Profile Editing Feature

### What was implemented
- ProfileForm component created
- Profile API endpoint
- Validation with Zod
- Change history table added

### Changed files
- src/components/ProfileForm.tsx (+150 lines)
- src/lib/api/profile.ts (+80 lines)
- src/lib/validations/profile.ts (+25 lines)
- prisma/schema.prisma (+10 lines)

### Review result
✅ harness-review APPROVE (no Critical/High findings)

### Test result
✅ All tests passed (12/12)

### Next actions
- [ ] Verify behavior in staging environment
- [ ] Design review
```

---

### Phase 4: PM confirms

```markdown
# Plans.md (after PM update)

## 🟢 Completed Tasks

- [x] User profile editing feature `pm:確認済` (2024-01-15)
```

---

## Example 2: Urgent Bug Fix

### Urgent request from PM

```markdown
## 🟡 Pending Tasks

- [ ] 🔥 [URGENT] Fix login error `pm:依頼中`
  - Symptom: certain users cannot log in
  - Error: "Invalid token format"
  - Priority: highest
```

### Claude Code response

1. Pick up the task with `/work`
2. Investigate error logs
3. Identify root cause and fix
4. Add tests
5. Review with `/harness-review` (fix findings → re-review if needed)
6. Review OK → Auto-commit
7. Report completion with `/handoff-to-cursor` (2-Agent mode only; skip in Solo)

---

## Example 3: Auto-Fix on CI Failure

### CI fails

```
GitHub Actions: ❌ Build failed
- TypeScript error in src/utils/date.ts:45
```

### Claude Code auto-response

1. Detect the error
2. Fix the type error
3. Re-commit and push

**If all 3 attempts fail**:

```markdown
## ⚠️ CI Escalation

3 fix attempts were made but the issue could not be resolved.

### Fixes tried
1. Added type annotations → failed
2. Updated type definition file → failed
3. Adjusted tsconfig → failed

### Probable cause
The type definitions for an external library may be outdated

### Recommended actions
- [ ] Update @types/xxx to the latest version
- [ ] Check the library version itself
```

---

## Example 4: Parallel Task Execution

### Multiple tasks exist

```markdown
## 🟡 Pending Tasks

- [ ] Refactor header component `cc:TODO`
- [ ] Refactor footer component `cc:TODO`
- [ ] Add tests: utility functions `cc:TODO`
```

### When /work is run

Claude Code determines whether parallel execution is possible:
- Independent tasks → parallel execution
- Tasks with dependencies → sequential execution

```
🚀 Starting parallel execution
├─ Agent 1: Header refactor
├─ Agent 2: Footer refactor
└─ Agent 3: Add tests
```
