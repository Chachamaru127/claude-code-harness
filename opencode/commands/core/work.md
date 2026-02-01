---
description: Execute Plans.md tasks (Solo/2-Agent, parallel execution enabled)
---

# /work - Execute Plan

Executes the plan in Plans.md and generates actual code.
**Actively utilizes parallel execution** to efficiently complete tasks.

## VibeCoder Quick Reference

- "**Progress tasks in Plans.md**" → this command
- "**Build to where it works first**" → get to minimum working state first
- "**Do everything at once**" → automatic parallel execution
- "**Want to resume from where I left off**" → resume from in-progress (cc:WIP) or requested (pm:requested)
- "**Resume session**" → `--resume <id|latest>` (restore history session)
- "**Fork session**" → `--fork <id|current> --reason "<text>"`

## Deliverables

- Implement Plans.md tasks **efficiently with smart parallel execution**
- When stuck, isolate cause → fix → re-verify loop
- **2-Agent mode**: Prioritize processing pm:requested tasks
- **Review loop**: implement → harness-review → fix until OK → auto-commit

---

## 🚀 Default Behavior

`/work` runs implement → review → fix → commit by default:

```bash
/work                    # Implement → Review → Fix → Commit (default)
/work --no-commit        # Skip auto-commit (manual commit)
/work --parallel 5       # Force 5 parallel workers
/work --sequential       # Force sequential (no parallel)
```

### Project-level Configuration

Override default via `.claude-code-harness.config.yaml`:

```yaml
work:
  auto_commit: false  # Disable auto-commit for this project
  commit_on_pm_approve: true  # 2-Agent: defer commit until PM approves
```

### Smart Parallel Detection

| Condition | Parallel Count |
|-----------|:--------------:|
| 1 task | 1 |
| All tasks edit same file | 1 |
| 2-3 independent tasks | 2-3 |
| 4+ independent tasks | 3 (max) |

---

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `--ci` | CI-only non-interactive mode | false |
| `--parallel N` | Force parallel count | auto |
| `--sequential` | Force no parallel | - |
| `--isolation` | lock / worktree | worktree |
| `--max-iterations` | Review fix loop limit | 3 |
| `--skip-review` | Skip review phase | false |
| `--no-commit` | Skip auto-commit (manual commit) | false |
| `--resume <id|latest>` | Resume session | - |
| `--fork <id|current>` | Fork session | - |
| `--reason "<text>"` | Fork reason (with --fork) | - |

### --ci Mode

CI-only non-interactive execution:
- AskUserQuestion: do not use
- WebSearch: do not use
- Confirmation prompts: do not wait
- Continue to completion automatically

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

### Default Flow

**Review→Fix ループは Solo/2-Agent 共通**。Handoff は 2-Agent モードのみ実行。

```
/work --parallel 3
    ↓
┌─────────────────────────────────────────────────────────┐
│ Phase 1: Parallel Implementation                        │
├─────────────────────────────────────────────────────────┤
│  [task-worker A] Implement → Related-check              │
│  [task-worker B] Implement → Related-check              │
│  [task-worker C] Implement → Related-check              │
│                                                         │
│  ※Related-check: Verify no missed file updates         │
│  Each worker completes implementation                   │
└─────────────────────────────────────────────────────────┘
    ↓ Wait for all implementations complete
┌─────────────────────────────────────────────────────────┐
│ Phase 2: Review Loop (harness-review)  [Solo/2-Agent]   │
├─────────────────────────────────────────────────────────┤
│  Execute harness-review (context-aware)                 │
│    ├── Codex available: 4-parallel expert review       │
│    └── Otherwise: standard review                       │
│                                                         │
│  ※NG (Critical/High issues) → Fix → Re-review          │
│  ※Loop continues until OK (max --max-iterations)       │
└─────────────────────────────────────────────────────────┘
    ↓ Review OK (APPROVE: no Critical/High issues)
┌─────────────────────────────────────────────────────────┐
│ Phase 3: Auto-commit (default)         [Solo/2-Agent]   │
├─────────────────────────────────────────────────────────┤
│  ✅ All tasks implemented and reviewed                  │
│  📝 Auto-commit with generated message                  │
│                                                         │
│  Skip with: --no-commit or config auto_commit: false    │
│                                                         │
│  ⏸️ commit_on_pm_approve: true (2-Agent only):           │
│    → Skip commit, mark as "pending_pm_approval"         │
│    → Handoff includes commit instruction for PM         │
└─────────────────────────────────────────────────────────┘
    ↓ Commit complete (or skipped / deferred)
┌─────────────────────────────────────────────────────────┐
│ Phase 4: Handoff (2-Agent only)                         │
├─────────────────────────────────────────────────────────┤
│  2-Agent mode (pm:requested detected):                  │
│    → Execute `/handoff-to-cursor` to report to PM       │
│    → If commit_on_pm_approve: include commit-pending    │
│      flag in handoff report                             │
│                                                         │
│  Solo mode:                                             │
│    → Skip (no handoff needed)                           │
└─────────────────────────────────────────────────────────┘
```

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

## 📐 Detailed Implementation

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
Phase 1 completion:
    ↓
Execute harness-review (context-aware):
  - Check .claude-code-harness.config.yaml
  - review.mode=codex AND review.codex.enabled=true → Codex mode
  - Otherwise → standard harness-review
    ↓
Codex mode:
  - Codex 4-parallel expert review (per review type)
  - Simultaneous review from 4 expert perspectives
    ↓
Standard review mode:
  - Execute harness-review skill
  - Check security/performance/quality/accessibility
    ↓
Review judgment:
  - Critical/High issues → Fix implementation → Re-review (loop)
  - OK (no Critical/High) → Complete
    ↓
Loop until OK or max iterations reached
```

**Review perspectives in Codex mode (4 parallel per review type)**:

| Review Type | Experts |
|-------------|---------|
| **Code Review** | Security, Performance, Quality, Accessibility |
| **Plan Review** | Clarity, Feasibility, Dependencies, Acceptance |
| **Scope Review** | Scope-creep, Priority, Feasibility, Impact |

### Phase 3: Auto-commit

**Review OK判定**:

```
harness-review result:
    ↓
APPROVE (no Critical/High issues):
  → Auto-commit (unless --no-commit or config auto_commit: false)
    ↓
REQUEST_CHANGES (has Critical/High issues):
  → Fix issues → Re-run review (loop)
    ↓
Max iterations reached:
  → Report remaining issues → Request manual intervention
```

**Auto-commit behavior**:

```
Check auto-commit setting:
  1. --no-commit flag → Skip commit
  2. .claude-code-harness.config.yaml work.auto_commit: false → Skip commit
  3. .claude-code-harness.config.yaml work.commit_on_pm_approve: true
     AND 2-Agent mode → Defer commit (pending PM approval)
  4. Otherwise → Auto-commit with generated message
```

**commit_on_pm_approve モード** (2-Agent 専用):

```
commit_on_pm_approve: true AND 2-Agent mode:
    ↓
Skip commit → Record pending state
    ↓
Handoff to PM with commit-pending flag:
  "変更はレビュー済みですが、未コミットです。
   approve 時にコミット指示を含めてください。"
    ↓
PM approves → Handoff includes commit instruction
    ↓
Next /work invocation: Detect "approved + commit pending"
    → Execute commit before starting new tasks
```

> **Solo モードでは無視**: `commit_on_pm_approve` は 2-Agent モードでのみ有効。Solo モードでは通常の `auto_commit` 設定に従う。

**Completion report (with auto-commit)**:

```
✅ /work Complete

| Item | Status |
|------|--------|
| Tasks | 5/5 implemented |
| Review | APPROVE |
| Iterations | 2 |
| Commit | abc1234 |

Changed files:
- src/components/Header.tsx (new)
- src/components/Footer.tsx (new)
- src/components/Sidebar.tsx (new)

Committed: feat: add Header, Footer, Sidebar components
```

**Completion report (with --no-commit)**:

```
✅ /work Complete

| Item | Status |
|------|--------|
| Tasks | 5/5 implemented |
| Review | APPROVE |
| Iterations | 2 |
| Commit | Skipped (--no-commit) |

Changed files:
- src/components/Header.tsx (new)
- src/components/Footer.tsx (new)
- src/components/Sidebar.tsx (new)

Next steps:
1. Review changes: git diff
2. Commit when ready: git add . && git commit
```

**Completion report (with commit_on_pm_approve, 2-Agent)**:

```
✅ /work Complete (commit pending PM approval)

| Item | Status |
|------|--------|
| Tasks | 5/5 implemented |
| Review | APPROVE |
| Iterations | 2 |
| Commit | ⏸️ Pending PM approval |

Changed files:
- src/components/Header.tsx (new)
- src/components/Footer.tsx (new)
- src/components/Sidebar.tsx (new)

## Commit Status: Pending PM Approval

変更はハーネスレビュー済みですが、コミットを保留しています。
PM が approve した場合、次回 /work 実行時にコミットされます。
```

### Phase 4: Handoff (2-Agent only)

**Review OK 判定条件** (Solo/2-Agent 共通):

| 判定 | 条件 | アクション |
|------|------|-----------|
| APPROVE | Critical/High の指摘なし | → Phase 3 (commit) → Phase 4 (handoff) |
| REQUEST_CHANGES | Critical/High の指摘あり | → Fix → Re-review (loop) |

**Handoff 実行条件**:

```
Phase 3 (Auto-commit) 完了後:
    ↓
2-Agent mode (pm:requested / cursor:requested detected)?
  YES → Execute `/handoff-to-cursor` (completion report to PM)
        → If commit_on_pm_approve: add commit-pending section
  NO  → Solo mode: Skip handoff (workflow complete)
```

**順序（通常モード）**: Review OK → Auto-commit → Handoff

> ⚠️ **重要**: 通常モードでは Handoff は必ず auto-commit の後に実行する。commit 前に handoff すると、PM がレビューする変更が未コミットになり不整合が生じる。

**順序（commit_on_pm_approve モード）**: Review OK → Skip commit → Handoff (with commit-pending)

> `commit_on_pm_approve: true` の場合、意図的にコミットを保留して Handoff する。PM が approve した後の次回 `/work` 実行時にコミットが実行される。

**Handoff レポートの commit-pending セクション**:

```
## Commit Status: Pending PM Approval

変更はハーネスレビュー済みですが、`commit_on_pm_approve` 設定により
コミットを保留しています。

approve の場合: ハンドオフに以下を含めてください:
  「前回の変更を承認します。コミットしてから次のタスクに進んでください。」

request_changes の場合: 通常通り修正指示を記載してください。
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

### Pre-task: Pending Commit Check (commit_on_pm_approve)

`/work` 起動時、前回の保留コミットがあるか確認する:

```
/work start:
    ↓
Check: PM approved + commit pending?
  (Handoff message contains "承認" + uncommitted changes exist)
    ↓
YES → Execute pending commit first
    → Then proceed to next task
    ↓
NO  → Proceed normally
```

> この処理により、PM 承認 → コミット → 次タスク実装 の流れが自然に繋がる。

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

#### ⚠️ Background Agent Permission Pre-approval (v2.1.20+)

Claude Code v2.1.20 以降、background agent は起動前にツール権限の承認を求めます。
並列 task-worker が複数起動する際に毎回権限プロンプトが出ると UX が低下するため、
`.claude/settings.json` の `permissions.allow` で事前承認することを推奨します。

**推奨設定**（プロジェクトの `.claude/settings.json` に手動で追加）:

```json
{
  "permissions": {
    "allow": [
      "Read",
      "Write",
      "Edit",
      "Bash(npm run:*)",
      "Bash(pnpm:*)",
      "Bash(git diff:*)",
      "Bash(git status:*)",
      "Grep",
      "Glob"
    ]
  }
}
```

> 💡 task-worker は `Read`, `Write`, `Edit`, `Bash`, `Grep`, `Glob` を使用します。
> これらを事前承認しておくことで、並列起動時の権限プロンプトを回避できます。
>
> ⚠️ **セキュリティ注意**: `Read`, `Write`, `Edit` を無条件に許可するとプロンプトインジェクション等のリスクが高まります。
> 信頼できるプロジェクトでのみ設定し、必要に応じて対象をパス制限（例: `Write(src/*)`）することを検討してください。

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

### Commit (auto-commit enabled)

```
Committed: feat: implement Header, Footer, Sidebar, Layout, Page components

Hash: abc1234
```

### Next Actions (if --no-commit)

- [ ] Verify operation (`npm run dev`)
- [ ] Run tests (`npm test`)
- [ ] Review changes (`git diff`)
- [ ] Commit when ready (`git add . && git commit`)
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
