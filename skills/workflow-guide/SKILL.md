---
name: workflow-guide
description: "Explicit helper for Cursor PM ↔ Claude Code two-agent workflow guidance. Do NOT load for: solo implementation, workflow setup, handoff execution, or general process coaching."
allowed-tools: ["Read"]
user-invocable: false
disable-model-invocation: true
---

# Workflow Guide Skill

Skill that provides guidance on the Cursor ↔ Claude Code two-agent workflow.

---

## Trigger Phrases

This skill is invoked by the following phrases:

- "explain the workflow"
- "how do I connect with Cursor?"
- "walk me through the process"
- "how should we proceed?"
- "how does the workflow work?"
- "explain 2-agent workflow"

---

## Overview

This skill explains the role assignments and collaboration method for Cursor (PM) and Claude Code (Worker).

---

## Two-Agent Workflow

### Role Assignment

| Agent | Role | Responsibilities |
|-------|------|-----------------|
| **Cursor** | PM (Project Manager) | Task assignment, review, production deploy decisions |
| **Claude Code** | Worker | Implementation, testing, CI fixes, staging deploy |

### Workflow Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    Cursor (PM)                          │
│  · Add tasks to Plans.md                                │
│  · Request work from Claude Code (/handoff-to-claude)   │
│  · Review completion reports                            │
│  · Decide on production deploys                         │
└─────────────────────┬───────────────────────────────────┘
                      │ Task request
                      ▼
┌─────────────────────────────────────────────────────────┐
│                  Claude Code (Worker)                   │
│  · Execute tasks with /work (parallel execution)        │
│  · Implement → test → commit                            │
│  · Auto-fix CI failures (up to 3 attempts)              │
│  · Report completion with /handoff-to-cursor            │
└─────────────────────┬───────────────────────────────────┘
                      │ Completion report
                      ▼
┌─────────────────────────────────────────────────────────┐
│                    Cursor (PM)                          │
│  · Review changes                                       │
│  · Verify staging behavior                              │
│  · Execute production deploy (after approval)           │
└─────────────────────────────────────────────────────────┘
```

---

## Task Management via Plans.md

### Marker Reference

| Marker | Meaning | Set by |
|--------|---------|--------|
| `pm:依頼中` | Requested by PM (compatible: cursor:依頼中) | PM (Cursor/PM Claude) |
| `cc:TODO` | Claude Code not yet started | Either |
| `cc:WIP` | Claude Code working | Claude Code |
| `cc:完了` | Claude Code complete | Claude Code |
| `pm:確認済` | PM confirmed (compatible: cursor:確認済) | PM (Cursor/PM Claude) |
| `cursor:依頼中` | (compatible) same as pm:依頼中 | Cursor |
| `cursor:確認済` | (compatible) same as pm:確認済 | Cursor |
| `blocked` | Blocked | Either |

### Task State Transitions

```
pm:依頼中 → cc:WIP → cc:完了 → pm:確認済
```

---

## Key Commands

### Claude Code Side

| Command | Purpose |
|---------|---------|
| `/harness-init` | Project setup |
| `/plan-with-agent` | Planning and task breakdown |
| `/work` | Execute tasks (parallel execution supported) |
| `/handoff-to-cursor` | Completion report (to Cursor PM) |
| `/sync-status` | Check current state |

### Skills (auto-invoked in conversation)

| Skill | Trigger example |
|-------|----------------|
| `handoff-to-pm` | "Report completion to PM" |
| `handoff-to-impl` | "Hand off to the implementer" |

### Cursor Side (reference)

| Command | Purpose |
|---------|---------|
| `/handoff-to-claude` | Request tasks from Claude Code |
| `/review-cc-work` | Review completion reports |

---

## CI/CD Rules

### Claude Code's Scope of Responsibility

- ✅ Up to staging deploy
- ✅ Auto-fix CI failures (up to 3 attempts)
- ❌ Production deploy is prohibited

### The 3-Attempt Rule

If CI fails 3 times in a row:
1. Stop auto-fixing
2. Generate an escalation report
3. Defer the decision to Cursor

---

## FAQ

### Q: What if Cursor is not available?

A: Even when working solo, it is recommended to manage tasks with Plans.md.
Perform production deploys manually and carefully.

### Q: What if a task is unclear?

A: Ask Cursor for clarification, or use `/sync-status` to organize the current state.

### Q: What if CI keeps failing?

A: Do not attempt more than 3 auto-fixes; escalate to Cursor instead.

---

## Related Documents

- AGENTS.md - Detailed role assignments
- CLAUDE.md - Claude Code-specific configuration
- Plans.md - Task management file
