---
name: session-init
description: "Internal sub-skill for session startup checks, Plans.md status, git state, and harness-mem resume pack. Invoked by session/startup workflows only. Do NOT load for: implementation, reviews, or mid-session tasks."
allowed-tools: ["Read", "Write", "Bash", "mcp__harness__harness_mem_resume_pack", "mcp__harness__harness_mem_sessions_list", "mcp__harness__harness_mem_health"]
user-invocable: false
disable-model-invocation: true
---

# Session Init Skill

Checks the environment at session startup and establishes the current task status.

---

## Invocation Conditions

This skill is invoked internally from `session` / SessionStart workflows.
The user-facing entry point is `/session` or the standard session start flow.

Legacy trigger phrases:

- "start session"
- "begin work"
- "start today's work"
- "check the status"
- "what should I work on?"

---

## Overview

The Session Init skill automatically checks the following at the start of a Claude Code session:

1. **Git state**: Current branch, uncommitted changes
2. **Plans.md**: In-progress tasks, requested tasks
3. **AGENTS.md**: Role assignments, prohibited actions
4. **Previous session**: Handoff items to carry over
5. **Latest snapshot**: Progress snapshot summary and diff from last session

---

## Execution Steps

### Step 0: File State Check (auto-triage)

Check file sizes before starting the session:

```bash
# Check Plans.md line count
if [ -f "Plans.md" ]; then
  lines=$(wc -l < Plans.md)
  if [ "$lines" -gt 200 ]; then
    echo "⚠️ Plans.md has ${lines} lines. Recommend running 'clean up' to tidy it."
  fi
fi

# Check session-log.md line count
if [ -f ".claude/memory/session-log.md" ]; then
  lines=$(wc -l < .claude/memory/session-log.md)
  if [ "$lines" -gt 500 ]; then
    echo "⚠️ session-log.md has ${lines} lines. Recommend running 'clean up session log'."
  fi
fi
```

If cleanup is needed, display a suggestion (does not affect the current work).

### Step 0.5: Legacy Local Memory Compatibility (optional)

The current standard is Unified Harness Memory from Step 0.7.
Checking legacy local memory compatibility is generally unnecessary; only consult it when a specific migration check is required.

> **Note**: In normal operation, skip this step and treat the shared DB Resume Pack as the sole resume path.

### Step 0.7: Unified Harness Memory Resume Pack (required)

Retrieve the resume context from the shared DB for Codex / Claude / OpenCode (`~/.harness-mem/harness-mem.db`).

Required call:

```text
harness_mem_resume_pack(project, session_id?, limit=5, include_private=false)
```

Operating rules:
- Always specify the current project name for `project`
- Obtain `session_id` in order: `$CLAUDE_SESSION_ID` → `.session_id` in `.claude/state/session.json`
- Using the first result of `harness_mem_sessions_list(project, limit=1)` is limited to read-only (resume confirmation); do not use it for writes in `record_checkpoint` / `finalize_session`
- Inject retrieved results into the session startup context
- On retrieval failure, check daemon status with `harness_mem_health()`, log the failure explicitly, and continue
- Recovery order: `scripts/harness-memd doctor` → `scripts/harness-memd cleanup-stale` → `scripts/harness-memd start`

### Step 1: Environment Check

Run the following in parallel:

```bash
# Git state
git status -sb
git log --oneline -3
```

```bash
# Plans.md
cat Plans.md 2>/dev/null || echo "Plans.md not found"
```

```bash
# Key points from AGENTS.md
head -50 AGENTS.md 2>/dev/null || echo "AGENTS.md not found"
```

### Step 2: Determine Task Status

Extract the following from Plans.md:

- `cc:WIP` - Tasks continuing from the previous session
- `pm:依頼中` - Tasks newly requested by the PM (compatible: cursor:依頼中)
- `cc:TODO` - Tasks assigned but not yet started

### Step 3: Output Status Report

```markdown
## 🚀 Session Start

**Date/Time**: {{YYYY-MM-DD HH:MM}}
**Branch**: {{branch}}
**Session ID**: ${CLAUDE_SESSION_ID}

---

### 📋 Today's Tasks

**Priority Tasks**:
- {{Tasks marked pm:依頼中 (compatible: cursor:依頼中) or cc:WIP}}

**Other Tasks**:
- {{List of cc:TODO tasks}}

---

### ⚠️ Notes

{{Important constraints and prohibited actions from AGENTS.md}}

---

**Ready to begin?**
```

---

## Output Format

At session start, present the following information concisely:

| Item | Content |
|------|---------|
| Current branch | e.g. `staging` |
| Priority tasks | The 1–2 most important tasks |
| Notes | Summary of prohibited actions |
| Next action | A concrete suggestion |

---

## Related Commands

- `/work` - Execute tasks (parallel execution supported)
- `/sync-status` - Progress summary of Plans.md
- `/maintenance` - Automatic file cleanup

---

## Notes

- **Always check AGENTS.md**: Understand role assignments before starting work
- **If Plans.md is missing**: Direct the user to run `/harness-init`
- **If previous work was interrupted**: Confirm whether to continue
