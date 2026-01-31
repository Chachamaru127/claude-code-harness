---
name: work
description: "Executes Plans.md tasks with smart parallel detection and review loop. Use when user mentions '/work', execute plan, implement tasks, build features, or work on tasks. Do NOT load for: planning, reviews, setup, or deployment."
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash", "Task"]
argument-hint: "[--parallel N] [--sequential] [--ci] [--no-commit] [--resume id] [--fork id]"
disable-model-invocation: true
---

# Work Skill

Executes Plans.md tasks and generates actual code with smart parallel execution.

## Quick Reference

- "**Progress tasks in Plans.md**" → this skill
- "**Build to where it works first**" → get to minimum working state
- "**Do everything at once**" → automatic parallel execution
- "**Resume session**" → `--resume <id|latest>`
- "**Fork session**" → `--fork <id|current> --reason "<text>"`

## Usage

```bash
/work                    # Implement → Review → Fix → Commit (default)
/work --no-commit        # Skip auto-commit (manual commit)
/work --parallel 5       # Force 5 parallel workers
/work --sequential       # Force sequential (no parallel)
/work --ci               # CI-only non-interactive mode
/work --resume latest    # Resume latest stopped session
/work --fork current     # Fork from current session
```

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `--ci` | CI-only non-interactive mode | false |
| `--parallel N` | Force parallel count | auto |
| `--sequential` | Force no parallel | - |
| `--isolation` | lock / worktree | worktree |
| `--max-iterations` | Review fix loop limit | 3 |
| `--skip-review` | Skip review phase | false |
| `--no-commit` | Skip auto-commit | false |
| `--resume <id\|latest>` | Resume session | - |
| `--fork <id\|current>` | Fork session | - |
| `--reason "<text>"` | Fork reason (with --fork) | - |

## Default Flow

```
/work
    ↓
Phase 1: Parallel Implementation
    → task-workers implement in parallel
    → Each worker: implement → self-review
    ↓
Phase 2: Review Loop (harness-review)
    → APPROVE: proceed
    → REQUEST_CHANGES: fix → re-review
    ↓
Phase 3: Auto-commit
    → Commit changes (unless --no-commit)
    ↓
Phase 4: Handoff (2-Agent only)
    → Report to PM via /handoff-to-cursor
```

## Feature Details

| Feature | Reference |
|---------|-----------|
| **Execution Flow** | See [references/execution-flow.md](references/execution-flow.md) |
| **Parallel Execution** | See [references/parallel-execution.md](references/parallel-execution.md) |
| **Session Management** | See [references/session-management.md](references/session-management.md) |
| **Review Loop** | See [references/review-loop.md](references/review-loop.md) |
| **Auto-commit** | See [references/auto-commit.md](references/auto-commit.md) |
| **Error Handling** | See [references/error-handling.md](references/error-handling.md) |

## Smart Parallel Detection

| Condition | Parallel Count |
|-----------|:--------------:|
| 1 task | 1 |
| All tasks edit same file | 1 |
| 2-3 independent tasks | 2-3 |
| 4+ independent tasks | 3 (max) |

## Auto-invoke Skills

| Skill | Purpose | When to Call |
|-------|---------|--------------|
| `impl` | Feature implementation | On task implementation |
| `verify` | Build verification | On post-implementation verification |
| `harness-review` | Multi-perspective review | After implementation complete |

## Project Configuration

Override defaults via `.claude-code-harness.config.yaml`:

```yaml
work:
  auto_commit: false          # Disable auto-commit
  commit_on_pm_approve: true  # 2-Agent: defer commit until PM approves
```

## VibeCoder Hints

| What You Want | How to Say |
|---------------|------------|
| Do all in parallel | "do everything at once" |
| Know progress | "how far are we?" |
| Verify operation | "run it" |
| Do one at a time | "one at a time in order" |
