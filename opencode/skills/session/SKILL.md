---
name: session
description: "Session management - initialization, memory persistence, state control. Auto-triggered on session start/resume."
allowed-tools: ["Read", "Write", "Bash", "Edit", "Append"]
user-invocable: false
---

# Session Skill

Manages session lifecycle: initialization, memory persistence, state transitions, and inter-session communication.

---

## Trigger Phrases

- "Start session" / "セッション開始"
- "What did we do last time?" / "前回何をした？"
- "Continue from before" / "前回の続きから"
- "What should I work on?" / "何をすればいい？"

---

## Capabilities

| Capability | Description |
|------------|-------------|
| **Init** | Environment checks, task status overview |
| **Memory** | Cross-session learning and persistence |
| **State** | Session state transitions (internal) |
| **Control** | Resume/fork handling (internal) |

---

## Session Init

On session start:

1. **Environment Check**
   - Git status (branch, uncommitted changes)
   - Plans.md (in-progress, requested tasks)
   - AGENTS.md (role, constraints)

2. **Claude-mem Context** (if enabled)
   - Past guardrail activations
   - Recent session summary
   - Continuation suggestions

3. **Status Report**
   ```markdown
   ## 🚀 Session Started

   **Branch**: main
   **Priority Tasks**: [list from Plans.md]
   **Warnings**: [from AGENTS.md]

   Ready to start?
   ```

---

## Session Memory

### Storage Structure

```
.claude/memory/
├── session-log.md    # Per-session logs
├── decisions.md      # Important decisions (SSOT)
├── patterns.md       # Learned patterns (SSOT)
└── context.json      # Project context
```

### What Gets Recorded

| File | Content | Git Track? |
|------|---------|------------|
| decisions.md | Technical decisions, why | Yes (SSOT) |
| patterns.md | Reusable patterns, how | Yes (SSOT) |
| session-log.md | Session activities | No (local) |
| context.json | Project metadata | No (local) |

---

## Session State (Internal)

State machine for workflow orchestration:

```
initialized → working → reviewing → completed
                ↓           ↓
            escalated ← escalated
```

Used by `/work` for phase transitions.

---

## Session Control (Internal)

Handles `--resume` and `--fork` flags from `/work`:

- **Resume**: Continue from previous session state
- **Fork**: Create new session from current state

---

## Related Commands

- `/sync-status` - Progress overview
- `/session list` - Active sessions
- `/session inbox` - Inter-session messages
