# Execution Flow

## Phase 1: Dependency Graph Construction and Parallel Launch

### Dependency graph construction logic

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

### Judgment rules

| Condition | Judgment | Processing |
|-----------|----------|------------|
| Multiple tasks edit same file | Conflict | Sequential |
| Task A's output is Task B's input | Dependency | Execute A→B in order |
| Mutually independent | Parallelizable | Same group |

### task-worker launch

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

### Result collection

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

### Progress display

```
📊 Phase 1 Progress: 2/5 complete

├── [worker-1] Header.tsx ✅ commit_ready (35s)
├── [worker-2] Footer.tsx ✅ commit_ready (28s)
├── [worker-3] Sidebar.tsx ⏳ Self-reviewing...
├── [worker-4] Utils.ts ⏳ Implementing...
└── [worker-5] Types.ts 🔜 Waiting (depends: Utils.ts)
```

## Phase 2: Cross-review Execution

### Prerequisites
- All Phase 1 tasks returned `commit_ready`
- `--skip-cross-review` not specified

### Execution flow

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

### Review perspectives in Codex mode (4 parallel per review type)

| Review Type | Experts |
|-------------|---------|
| **Code Review** | Security, Performance, Quality, Accessibility |
| **Plan Review** | Clarity, Feasibility, Dependencies, Acceptance |
| **Scope Review** | Scope-creep, Priority, Feasibility, Impact |

## Phase 3: Auto-commit

### Review OK判定

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

## Phase 4: Handoff (2-Agent only)

### Handoff 実行条件

```
Phase 3 (Auto-commit) 完了後:
    ↓
2-Agent mode (pm:requested / cursor:requested detected)?
  YES → Execute `/handoff-to-cursor` (completion report to PM)
  NO  → Solo mode: Skip handoff (workflow complete)
```

**順序（通常モード）**: Review OK → Auto-commit → Handoff

> ⚠️ **重要**: 通常モードでは Handoff は必ず auto-commit の後に実行する。
