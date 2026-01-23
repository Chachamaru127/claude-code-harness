---
description: Execute Plans.md tasks (Solo/2-Agent, parallel execution enabled)
description-en: Execute Plans.md tasks (Solo/2-Agent, parallel execution enabled)
---

# /work - Execute Plan

Executes the plan in Plans.md and generates actual code.
**Actively utilizes parallel execution** to efficiently complete tasks.

## VibeCoder Quick Reference

- "**Progress tasks in Plans.md**" → this command
- "**Build to where it works first**" → get to minimum working state first
- "**Do everything at once**" → process all at once with parallel execution
- "**Want to resume from where I left off**" → resume from in-progress (cc:WIP) or requested (pm:requested)
- "**Full cycle**" → `--full` mode (implement → review → commit)
- "**Resume session**" → `--resume <id|latest>` (restore history session)
- "**Fork session**" → `--fork <id|current> --reason "<text>"`

## Deliverables

- Implement Plans.md tasks **efficiently with parallel execution**
- When stuck, isolate cause → fix → re-verify loop
- **2-Agent mode**: Prioritize processing pm:requested tasks
- **--full mode**: Full automation of implement → self-review → cross-review → commit

---

## 🚀 --full Mode (Full Cycle Automation)

`/work --full` automatically runs "implement → self-review → improve → commit".

### Option List

| Option | Description | Default |
|--------|-------------|---------|
| `--full` | Full cycle execution | false |
| `--parallel N` | Parallel count | 1 |
| `--isolation` | lock / worktree | lock |
| `--commit-strategy` | task / phase / all | task |
| `--deploy` | Deploy after commit | false |
| `--max-iterations` | Improvement loop limit | 3 |
| `--skip-cross-review` | Skip Phase 2 | false |
| `--resume <id|latest>` | Resume session | - |
| `--fork <id|current>` | Fork session | - |
| `--reason "<text>"` | Fork reason (with --fork) | - |

### --isolation Option

| Value | Behavior | Recommended |
|-------|----------|-------------|
| `lock` | Same worktree + file lock | Small-medium tasks |
| `worktree` | git worktree isolation + pnpm space saving | Large tasks, true parallel builds |

### Session Resume/Fork

**セッション一覧の確認**:
```bash
# CLI: アーカイブディレクトリを確認
ls -la .claude/state/sessions/

# UI: harness-ui のWorkページでセッション一覧を確認
# → Session Archives テーブルから resume/fork コマンドをコピー可能
```

**再開/分岐コマンド**:
```bash
# Resume latest stopped session
/work --resume latest

# Resume specific session ID
/work --resume session-1700000000

# Fork from current session
/work --fork current --reason "Proceed with trial version separately"

# Fork from specific session
/work --fork session-1700000000 --reason "Try different approach"
```

**Check session state**:
```bash
# Current session state
cat .claude/state/session.json | jq '.state, .session_id'

# Event history
tail -20 .claude/state/session.events.jsonl
```

### --full Mode Flow

```
/work --full --parallel 3
    ↓
┌─────────────────────────────────────────────────────────┐
│ Phase 1: Parallel Implementation + Self-review          │
├─────────────────────────────────────────────────────────┤
│  [task-worker A] Implement→Related-check→Self-review→Fix│
│  [task-worker B] Implement→Related-check→Self-review→Fix│
│  [task-worker C] Implement→Related-check→Self-review→Fix│
│                                                         │
│  ※Related-check: Verify no missed file updates         │
│  Each worker loops autonomously until commit_ready      │
└─────────────────────────────────────────────────────────┘
    ↓ Wait for all "commit_ready"
┌─────────────────────────────────────────────────────────┐
│ Phase 2: Cross-review                                   │
├─────────────────────────────────────────────────────────┤
│  Codex available: Codex 8-parallel expert review       │
│  Codex not set: Fall back to normal review (review skill) │
│  ※Detects issues missed by self-review                 │
│  ※Additional issues → Return that task to Phase 1      │
└─────────────────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────────────────┐
│ Phase 3: Integrated Commit                              │
├─────────────────────────────────────────────────────────┤
│  ├── Conflict detection & resolution                    │
│  ├── Final related files verification                   │
│  ├── Final build verification                           │
│  └── Conventional Commit                                │
└─────────────────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────────────────┐
│ Phase 4: Deploy (--deploy only)                         │
└─────────────────────────────────────────────────────────┘
```

### --commit-strategy Behavior

| Value | Behavior |
|-------|----------|
| `task` | Individual commit on each task completion |
| `phase` | Batch commit on phase completion |
| `all` | 1 commit after all tasks + cross-review complete |

### Escalation

When task-worker can't resolve after 3 fixes, aggregate to parent and bulk confirm with user.

```
⚠️ Escalation (2 items)

Task A: Cannot convert type 'unknown' to 'User'
  → Suggestion: Check User type definition or add type guard

Task B: Test 'should validate email' failing
  → Suggestion: Fix regex pattern

How to proceed?
1. Apply suggestions and continue
2. Skip and move on
3. Fix manually
```

---

## 📐 --full Mode Detailed Implementation

### Phase 1: Dependency Graph Construction and Parallel Launch

**Dependency graph construction logic**:

```
Parse tasks from Plans.md:
    ↓
1. Extract target files per task
    ↓
2. Determine file dependencies
   ├── Same file edits → sequential
   ├── Has import dependency → sequential
   └── Independent → parallelizable
    ↓
3. Build dependency graph
    ↓
4. Determine parallel execution groups
```

**Judgment rules**:

| Condition | Judgment | Processing |
|-----------|----------|------------|
| Multiple tasks edit same file | Conflict | Sequential |
| Task A's output is Task B's input | Dependency | Execute A→B in order |
| Mutually independent | Parallelizable | Same group |

**task-worker launch**:

```
For each parallel group:
    ↓
Launch task-worker with Task tool:
  - subagent_type: "task-worker"
  - run_in_background: true
  - prompt: {
      task: "task description",
      files: ["target files"],
      max_iterations: 3,
      review_depth: "standard"
    }
    ↓
Collect launched task IDs
```

**Result collection**:

```
Wait for all task-worker completion:
    ↓
Collect results with TaskOutput:
  - status: commit_ready | needs_escalation | failed
  - changes: [{file, action}]
  - self_review: {quality, security, performance, compatibility}
    ↓
If needs_escalation, aggregate → bulk confirm with user
```

**Progress display**:

```
📊 Phase 1 Progress: 2/5 complete

├── [worker-1] Header.tsx ✅ commit_ready (35s)
├── [worker-2] Footer.tsx ✅ commit_ready (28s)
├── [worker-3] Sidebar.tsx ⏳ Self-reviewing...
├── [worker-4] Utils.ts ⏳ Implementing...
└── [worker-5] Types.ts 🔜 Waiting (depends: Utils.ts)
```

### Phase 2: Cross-review Execution

**Prerequisites**:
- All Phase 1 tasks returned `commit_ready`
- `--skip-cross-review` not specified

**Execution flow**:

```
Phase 1 completion judgment:
    ↓
Determine review mode:
  - Check .claude-code-harness.config.yaml
  - review.mode=codex AND review.codex.enabled=true → Codex mode
  - Otherwise → Fall back to normal review (default)
    ↓
Codex mode:
  - Codex 8-parallel expert review
  - Simultaneous review from 8 expert perspectives
    ↓
Normal review mode:
  - Execute review skill
  - Check security/performance/quality/accessibility
    ↓
Extract additional issues:
  - Return tasks with Critical/Major issues to Phase 1
  - Minor issues recorded only (can commit)
    ↓
No issues → Phase 3
```

**Review perspectives in Codex mode (8 parallel)**:

| # | Expert | Perspective |
|---|--------|-------------|
| 1 | Security | Vulnerabilities, auth, input validation |
| 2 | Performance | N+1, memory leaks, rendering |
| 3 | Maintainability | Readability, naming, structure |
| 4 | Compatibility | API compatibility, regression risk |
| 5 | Accessibility | a11y, keyboard navigation |
| 6 | Type Safety | Type definitions, any avoidance |
| 7 | Error Handling | Error handling, fallbacks |
| 8 | Best Practices | Framework conventions, patterns |

### Phase 3: Integrated Commit

**Conflict detection & resolution**:

```
For --isolation=lock:
  - Check file changes with git diff
  - If conflicts on same lines → warn → user confirmation

For --isolation=worktree:
  - Merge branches from each worktree
  - Try auto-resolution with 3-way merge
  - If unresolvable, request manual intervention
```

**Final build verification**:

```
pnpm build (or npm run build)
    ↓
Success → proceed to commit
Failure → Error analysis → Try auto-fix (max 3 times)
```

**Conventional Commit generation**:

```
Analyze change content:
    ↓
Select appropriate prefix:
  - feat: new feature
  - fix: bug fix
  - refactor: refactoring
  - docs: documentation
    ↓
Generate commit message:
  feat(components): add Header, Footer, Sidebar components

  - Add responsive Header with navigation
  - Add Footer with copyright and links
  - Add collapsible Sidebar for mobile

  Co-Authored-By: Claude <noreply@anthropic.com>
```

**Commit execution by strategy**:

| Strategy | Behavior | Good for |
|----------|----------|----------|
| `task` | Individual commit per task | Want fine-grained history |
| `phase` | Batch commit per phase | Want logical grouping |
| `all` | 1 commit after all complete | Want 1 commit per feature |

### Phase 4: Deploy (Optional)

**Prerequisites**:
- `--deploy` flag specified
- Phase 3 commit succeeded

**Safety gate**:

```
Pre-deploy checks:
    ↓
1. Detect production environment
   ├── Vercel: VERCEL_ENV=production
   ├── Netlify: CONTEXT=production
   └── Custom: DEPLOY_ENV=production
    ↓
2. Safety confirmation prompt
   ⚠️ Execute deploy to production?
   - Branch: main
   - Changed files: 5
   - Final test: ✅ Passed

   [y/N]
    ↓
3. Execute deploy
   └── Call deploy skill
```

**Deploy execution**:

```
Launch deploy skill with Skill tool:
  - skill: "claude-code-harness:deploy"
    ↓
Execute deploy command:
  ├── Vercel: vercel --prod
  ├── Netlify: netlify deploy --prod
  └── Custom: npm run deploy
    ↓
Verify result:
  - Deploy URL
  - Build time
  - Status
```

**Result report**:

```
🚀 Deploy Complete

| Item | Value |
|------|-------|
| Environment | production |
| URL | https://my-app.vercel.app |
| Build time | 45s |
| Status | ✅ Success |

Changes:
- feat(components): add Header, Footer, Sidebar
- 5 files changed, 320 insertions(+)
```

---

## ⚡ Parallel Execution First

This command **actively utilizes parallel execution**.

### Basic Policy

```
2+ independent tasks → Parallel execution (default)
Has dependencies → Sequential execution
```

### Parallel Execution Criteria

| Condition | Judgment | Example |
|-----------|----------|---------|
| Edit different files | ✅ Parallel | Header.tsx and Footer.tsx |
| Edit same file | ⚠️ Sequential | Append to same index.tsx |
| A's output is B's input | ⚠️ Sequential | Create API → Page using it |
| Independent checks | ✅ Parallel | lint, test, type-check |

### Execution Image

```
📋 Detected 5 tasks from Plans.md

Dependency analysis:
├── [Independent] Create Header
├── [Independent] Create Footer
├── [Independent] Create Sidebar
├── [Dependent] Create Layout ← Depends on Header, Footer, Sidebar
└── [Dependent] Create Page ← Depends on Layout

Execution plan:
🚀 Parallel group 1: Header, Footer, Sidebar (simultaneous)
   ↓
🔧 Sequential: Create Layout
   ↓
🔧 Sequential: Create Page

Estimated time: Sequential 5min → With parallel 2min30s (50% reduction)
```

---

## Auto-judgment Logic

Check Plans.md markers and operate in appropriate mode:

| Detected Marker | Operation Mode |
|-----------------|----------------|
| `pm:requested` / `cursor:requested` exists | 2-Agent (prioritize PM's request) |
| `cc:TODO` / `cc:WIP` only | Solo (autonomous) |

**Priority**: `pm:requested` > `cc:WIP` (continue) > `cc:TODO` (new)

### Auto-update Markers on Task Start

`/work` automatically transitions to **`cc:WIP`** on start:

```
pm:requested / cursor:requested / cc:TODO → cc:WIP (auto-update on start)
```

This integrates the "start task → update marker" functionality directly into `/work`.

---

## 🔧 Auto-invoke Skills (Required)

**This command must explicitly invoke the following skills with the Skill tool**:

| Skill | Purpose | When to Call |
|-------|---------|--------------|
| `impl` | Feature implementation (parent skill) | On task implementation |
| `verify` | Build verification & error recovery (parent skill) | On post-implementation verification |

**How to call**:
```
Use Skill tool:
  skill: "claude-code-harness:impl"      # Feature implementation
  skill: "claude-code-harness:verify"    # Build verification
```

**Child skills (auto-routing)**:
- `work-impl-feature` - Feature implementation
- `work-write-tests` - Test creation
- `verify-related-files` - Related files check (prevents missed updates)
- `verify-build` - Build verification
- `error-recovery` - Error recovery

> ⚠️ **Important**: Proceeding without calling skills won't record in usage statistics. Always call with Skill tool.

---

## 🔧 LSP Feature Utilization

Implementation work actively utilizes LSP (Language Server Protocol).

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

### After Implementation: Quality Check

```
Run LSP Diagnostics after implementation:
→ Verify no type errors
→ Detect unused variables & imports
→ Early detection of potential issues
```

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

### VibeCoder Phrases

| What You Want | How to Say |
|---------------|------------|
| Know function internals | "Show this function's definition" |
| Check where it's used | "Find references to this variable" |
| Run error check | "Run LSP diagnostics" |

Details: [docs/LSP_INTEGRATION.md](../../docs/LSP_INTEGRATION.md)

---

## Execution Flow

### Step 1: Check Plans.md and Parallelization Analysis

```bash
cat Plans.md
```

Extract current `cc:TODO` tasks and **analyze parallelization possibility**.

### Step 2: Present Execution Plan

> 🔧 **Execution Plan**
>
> **Parallel Execution Group**:
> | Task | Target File | Estimated Time |
> |------|-------------|----------------|
> | Create Header | src/components/Header.tsx | ~30s |
> | Create Footer | src/components/Footer.tsx | ~30s |
> | Create Sidebar | src/components/Sidebar.tsx | ~30s |
>
> **Sequential Execution (has dependencies)**:
> | Task | Depends On | Estimated Time |
> |------|------------|----------------|
> | Create Layout | Header, Footer, Sidebar | ~45s |
>
> **Total Estimated**: Sequential 2m15s → With parallel 1m15s
>
> Execute?

### Step 3: Parallel Execution with Task Tool

Use Claude Code's Task tool to **execute in background in parallel**.

```
🚀 Starting parallel execution...

├── [Agent 1] Creating Header... ⏳
├── [Agent 2] Creating Footer... ⏳
└── [Agent 3] Creating Sidebar... ⏳
```

**Important**:
- Launch Task tool with `run_in_background: true`
- Collect results with `TaskOutput`
- Up to 10 tasks simultaneously

### Step 4: Collect Results and Integration Report

```
📊 Parallel Execution Complete

├── [Agent 1] Create Header ✅ (25s)
│   └── src/components/Header.tsx created
├── [Agent 2] Create Footer ✅ (28s)
│   └── src/components/Footer.tsx created
└── [Agent 3] Create Sidebar ✅ (22s)
    └── src/components/Sidebar.tsx created

⏱️ Time: 28s (would be 75s sequential, 63% reduction)
```

### Step 5: Execute Sequential Tasks

Execute tasks with dependencies in order.

### Step 6: Update Plans.md and Completion Report

```markdown
# Plans.md Update
- [x] Create Header `cc:done`
- [x] Create Footer `cc:done`
- [x] Create Sidebar `cc:done`
- [x] Create Layout `cc:done`
```

---

## Integration Report Format

```markdown
## 📊 Task Execution Report

**Execution time**: 2025-12-15 10:30:00
**Task count**: 5 (3 parallel + 2 sequential)
**Duration**: 1m15s (would be 2m15s sequential, 44% reduction)

### Execution Results

| # | Task | Execution Type | Status | Duration |
|---|------|----------------|--------|----------|
| 1 | Create Header | Parallel | ✅ Success | 25s |
| 2 | Create Footer | Parallel | ✅ Success | 28s |
| 3 | Create Sidebar | Parallel | ✅ Success | 22s |
| 4 | Create Layout | Sequential | ✅ Success | 45s |
| 5 | Create Page | Sequential | ✅ Success | 30s |

### Changed Files

- `src/components/Header.tsx` (new)
- `src/components/Footer.tsx` (new)
- `src/components/Sidebar.tsx` (new)
- `src/components/Layout.tsx` (new)
- `src/app/page.tsx` (modified)

### Next Actions

- [ ] Verify operation (`npm run dev`)
- [ ] Run tests (`npm test`)
- [ ] Code review
```

---

## Error Handling

### Partial Failure in Parallel Execution

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

### All Tasks Failed

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

---

## Execution Pattern Collection

### Pattern 1: Multiple Components (Parallel)

```
Input: Create Header, Footer, Sidebar

→ All 3 tasks independent → Parallel execution
→ Launch 3 agents with Task tool
→ Summarize results in integration report
```

### Pattern 2: Quality Checks (Parallel)

```
Input: Run lint, test, type-check

→ All independent → Parallel execution
→ Results:
  ├── [Lint] ✅ Warnings: 2
  ├── [Test] ✅ 15/15 passed
  └── [Type] ✅ No errors
```

### Pattern 3: Dependency Chain (Mixed)

```
Input: Create API → Page → Tests

→ Has dependencies → Sequential execution
→ But API tests and page tests can be parallelized
```

---

## VibeCoder Hints

| What You Want | How to Say |
|---------------|------------|
| Do all in parallel | "do everything at once" "finish it quickly" |
| Know progress | "how far are we?" |
| Verify operation | "run it" |
| Move to next | "next task" |
| Do one at a time | "one at a time in order" |

---

## Notes

- **Simultaneous writes to same file are auto-avoided**
- **Over 10 tasks** are batch-split and executed
- Long-running tasks can be backgrounded with `Ctrl+B`
