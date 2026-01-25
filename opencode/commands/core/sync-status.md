---
description: Check progress → update Plans.md → suggest next action
---

# /sync-status - Status Check, Plans.md Sync, Next Action Suggestion

**Checks current implementation status, detects and updates differences with Plans.md, then suggests what to do next.**

Run this at work milestones or when you think "where am I at?"

## VibeCoder Quick Reference

- "**How far have we progressed?**" → this command
- "**What should I do next?**" → organize status and suggest next action
- "**Check if Plans.md matches actual progress**" → detect differences and update

## Deliverables

1. **Progress check**: Check consistency between implementation status and Plans.md
2. **Difference update**: Update Plans.md markers to match reality
3. **Next action suggestion**: Present what to do next considering priority

---

## Execution Flow

### Step 1: Gather Current Status

```bash
# Current task state in Plans.md
cat Plans.md

# Git change status (what actually changed)
git status
git diff --stat HEAD~3  # Changes in last 3 commits

# Recent commit history
git log --oneline -10
```

### Step 2: Detect Differences Between Implementation and Plans.md

Check the following:

| Check Item | Detection Method |
|------------|------------------|
| Done but still `cc:WIP` | Commit history vs marker |
| Started but still `cc:TODO` | Changed files vs marker |
| Implemented task not in Plans.md | Commit messages vs task list |
| `cc:done` but not committed | git status vs marker |

### Step 3: Update Plans.md (if differences exist)

If differences detected, suggest and execute updates:

> 📝 **Plans.md update needed**
>
> | Task | Current | After Update | Reason |
> |------|---------|--------------|--------|
> | Implement XX | `cc:WIP` | `cc:done` | Committed |
> | Add YY | `cc:TODO` | `cc:WIP` | Files being changed |
>
> **Update?** (yes / no)

If "yes", update Plans.md.

### Step 4: Output Progress Summary

```markdown
## 📊 Progress Summary

**Updated**: {{YYYY-MM-DD HH:MM}}
**Branch**: {{current branch}}

---

### Task Status

| Status | Count |
|--------|-------|
| 🔴 Not started (`cc:TODO`) | {{count}} |
| 🟡 In progress (`cc:WIP`) | {{count}} |
| 🟢 Done (`cc:done`) | {{count}} |
| ✅ Verified (`pm:verified`) | {{count}} |
| ⏳ Requested (`pm:requested`) | {{count}} |
| 🚫 Blocked (`blocked`) | {{count}} |

**Progress rate**: {{done + verified}} / {{total tasks}} ({{percent}}%)

### Context Usage

> 💡 **Check via status line (Claude Code v2.1.6+)**:
> - `context_window.used_percentage`: Usage rate
> - `context_window.remaining_percentage`: Remaining

**Warning thresholds**:
- 🟢 0-50%: Plenty of room
- 🟡 50-70%: Caution
- 🔴 70%+: Recommend ending session
```

### Step 5: Suggest Next Action

Suggest optimal next action based on status:

> 🎯 **What to do next**
>
> **Priority 1**: {{highest priority task}}
> - Reason: {{requested / unblock / dependency, etc.}}
>
> **Priority 2**: {{next task}}
>
> ---
>
> **Recommended commands**:
> - `/work` - Start next task
> - `/handoff-to-pm-claude` - Report completion to PM (if tasks are done)
> - `/harness-review` - Request review (if at a milestone)
>
> ⚠️ Context usage is high. Consider ending session and starting new.
> (Shown when context usage is 70%+)

---

## Anomaly Detection

Warn when the following situations are detected:

| Situation | Warning |
|-----------|---------|
| Multiple `cc:WIP` exist | ⚠️ Working on multiple tasks simultaneously |
| `blocked` left for long time | ⚠️ Prioritize unblocking |
| `pm:requested` not processed | ⚠️ Process PM's request first |
| Large gap between Plans.md and implementation | ⚠️ Task management not keeping up |

---

## Notes

- **Confirm before update**: Show differences and ask for confirmation before updating Plans.md
- **Reference commit history**: Judge actual work content from commit history
- **Be specific about next action**: Clearly present "what to do"

---

## ⚡ Parallel Execution Decision Points

**Information gathering phase** benefits from parallel execution in this command.

### When to Execute in Parallel ✅

| Process | Parallelize |
|---------|-------------|
| Read Plans.md | ✅ Independent |
| Check git status | ✅ Independent |
| Check git log | ✅ Independent |
| Check git diff | ✅ Independent |

**Parallel execution effect**:
```
🚀 Starting information gathering...
├── [Plans.md] Reading... ⏳
├── [git status] Checking... ⏳
├── [git log] Getting... ⏳
└── [git diff] Analyzing... ⏳

→ Get 4 pieces of info simultaneously → time saved
```

### Sequential Processing

The following run sequentially due to dependencies:

```
Information gathering (parallel) → Difference detection (sequential) → Update proposal (sequential) → Next action (sequential)
```

### Auto-optimization

This command is **automatically optimized**:
- Information gathering: Parallel execution
- Analysis/update: Sequential execution (due to dependencies)
