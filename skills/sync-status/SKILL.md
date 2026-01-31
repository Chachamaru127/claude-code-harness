---
name: sync-status
description: "Checks progress, updates Plans.md to match reality, and suggests next action. Use when user mentions '/sync-status', progress check, where am I at, or sync Plans.md."
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob"]
---

# Sync Status Skill

Checks current implementation status, detects differences with Plans.md, and suggests next action.

## Quick Reference

- "**How far have we progressed?**" → this skill
- "**What should I do next?**" → organize and suggest
- "**Check if Plans.md matches actual progress**" → detect and update

## Deliverables

1. **Progress check**: Consistency between implementation and Plans.md
2. **Difference update**: Update Plans.md markers to match reality
3. **Next action suggestion**: What to do next with priority

## Execution Flow

### Step 1: Gather Current Status (Parallel)

```bash
# Plans.md state
cat Plans.md

# Git change status
git status
git diff --stat HEAD~3

# Recent commit history
git log --oneline -10
```

### Step 2: Detect Differences

| Check Item | Detection Method |
|------------|------------------|
| Done but still `cc:WIP` | Commit history vs marker |
| Started but still `cc:TODO` | Changed files vs marker |
| `cc:done` but not committed | git status vs marker |

### Step 3: Update Plans.md

If differences detected, suggest and execute:

```
📝 Plans.md update needed

| Task | Current | After | Reason |
|------|---------|-------|--------|
| XX | cc:WIP | cc:done | Committed |

Update? (yes / no)
```

### Step 4: Output Progress Summary

```markdown
## 📊 Progress Summary

| Status | Count |
|--------|-------|
| 🔴 Not started (cc:TODO) | {{count}} |
| 🟡 In progress (cc:WIP) | {{count}} |
| 🟢 Done (cc:done) | {{count}} |

**Progress rate**: {{percent}}%
```

### Step 5: Suggest Next Action

```
🎯 What to do next

**Priority 1**: {{task}}
- Reason: {{requested / unblock}}

**Recommended**: /work, /harness-review
```

## Anomaly Detection

| Situation | Warning |
|-----------|---------|
| Multiple `cc:WIP` | ⚠️ Multiple tasks in progress |
| `pm:requested` not processed | ⚠️ Process PM's request first |
| Large gap | ⚠️ Task management not keeping up |
