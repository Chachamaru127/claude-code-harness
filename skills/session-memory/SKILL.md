---
name: session-memory
description: "Internal sub-skill for cross-session handoff, durable learning, and memory persistence. Invoked by session/memory workflows only. Do NOT load for: implementation, review, ad-hoc notes, or SSOT editing."
allowed-tools: ["Read", "Write", "Edit", "Bash"]
user-invocable: false
disable-model-invocation: true
---

# Session Memory Skill

Manages learning and memory across sessions.
Records and retrieves past work, decisions, and learned patterns.

---

## Trigger Phrases

This skill is invoked automatically by the following phrases:

- "what did we do last time?", "continue from last session"
- "show me the history", "past work"
- "tell me about this project"

---

## Overview

This skill saves work history to `.claude/memory/` and enables knowledge continuity across sessions.

It also clarifies where important information should be stored (see `docs/MEMORY_POLICY.md` for details).

---

## Memory Structure

```
.claude/
├── memory/
│   ├── session-log.md      # Per-session log
│   ├── decisions.md        # Important decisions
│   ├── patterns.md         # Learned patterns
│   └── context.json        # Project context
└── state/
    └── agent-trace.jsonl   # Agent Trace (tool execution history)
```

### Recommended Usage (SSOT / Local Separation)

- **SSOT (recommended for sharing)**: `decisions.md` / `patterns.md`
  - Consolidates "decisions (Why)" and "reusable solutions (How)"
  - Each entry should have a **title + tags** (e.g. `#decision #db`) with an **Index** at the top
- **Local only (not shared)**: `session-log.md` / `context.json` / `.claude/state/`
  - Prone to noise and bloat; generally not tracked in Git (decide on a case-by-case basis)

---

## Automatically Recorded Information

### session-log.md

Each session record is stamped with the session ID from the runtime environment.
In Claude Code, `${CLAUDE_SESSION_ID}` is preferred; in Codex, the session / thread ID provided by the Codex runtime is preferred.
If neither is available, read `.session_id` from `.claude/state/session.json`, and as a last fallback generate a datetime-based ID.
This improves cross-session traceability.

```markdown
## Session: 2024-01-15 14:30 (session: abc123def)

### Tasks Completed
- [x] Implemented user authentication
- [x] Created login page

### Files Generated
- src/lib/auth.ts
- src/app/login/page.tsx

### Key Decisions
- Auth method: Adopted Supabase Auth

### Handoff to Next Session
- Logout feature not yet implemented
- Password reset also needed
```

> **Note**: `${CLAUDE_SESSION_ID}` is an environment variable set automatically by Claude Code.
> Because this variable may not exist in the Codex runtime, do not assume it is always present; fall back to the Codex runtime session / thread ID or `.claude/state/session.json`.

### decisions.md

```markdown
## Technology Choices

| Date | Decision | Reason |
|------|----------|--------|
| 2024-01-15 | Supabase Auth | Free tier available, easy setup |
| 2024-01-14 | Next.js App Router | Current best practice |

## Architecture

- Components: `src/components/`
- Utilities: `src/lib/`
- Type definitions: `src/types/`
```

### patterns.md

```markdown
## Project Patterns

### Component Naming
- PascalCase
- Examples: `UserProfile.tsx`, `LoginForm.tsx`

### API Endpoints
- `/api/v1/` prefix
- RESTful design

### Error Handling
- Wrap in try-catch
- Error messages in English
```

### context.json

```json
{
  "project_name": "my-blog",
  "created_at": "2024-01-14",
  "stack": {
    "frontend": "next.js",
    "backend": "next-api",
    "database": "supabase",
    "styling": "tailwind"
  },
  "current_phase": "Phase 2: Core Features",
  "last_session": "2024-01-15T14:30:00Z"
}
```

---

## Processing Flow

### At Session Start

1. Load `.claude/memory/context.json`
2. Review the previous session log
3. **Retrieve recent edit history from Agent Trace**
4. Identify incomplete tasks
5. Generate a context summary

**Using Agent Trace**:
```bash
# Get list of files edited in the previous session
tail -50 .claude/state/agent-trace.jsonl | jq -r '.files[].path' | sort -u

# Get project metadata
tail -1 .claude/state/agent-trace.jsonl | jq '.metadata'
```

### During Session

1. Record important decisions in `decisions.md`
2. Add new patterns to `patterns.md`
3. Record file generation in `session-log.md`

### At Session End

1. Generate a session summary
2. Update `context.json`
3. Record handoff items for the next session

---

## Memory Optimization (CC 2.1.49+)

Since Claude Code 2.1.49, memory usage on session resume has been reduced by **68%**.

### Recommended Workflow

```bash
# Use --resume for long-running work
claude --resume

# Split large tasks across sessions with resume
claude --resume "continue from here"
```

| Scenario | Recommendation |
|----------|----------------|
| Long implementation | Resume session every 1–2 hours |
| Large-scale refactor | Split by feature unit |
| Low-memory warning | Resume immediately with `--resume` |

> Memory efficiency has improved significantly — use session resume proactively.

### /recap — Check Status During Session (CC 2.1.108+)

The `/recap` command added in CC 2.1.108 (alias of `/rewind`) is used to quickly review what has been done so far in the current session.
It is most effective when used before resuming a previous session with `--resume`, or as a mid-point check during long work.

**Recommended timing**:

| Timing | Usage |
|--------|-------|
| Just before resuming with `--resume` | Use `/recap` to organize context, then run `claude --resume` |
| Before a Breezing Worker resumes | Check in-session progress with `/recap` before moving to the next task |
| Midpoint of long implementation (over 1 hour) | Use `/recap` to check status → manually append to `session-log.md` if needed |

```bash
# Typical usage flow
# 1. Check current work status
/recap

# 2. Optionally append to session-log.md, then resume the session
claude --resume
```

> `/recap` only covers the current session. To review previous session content, use `session-log.md` or context inheritance via `claude --resume`.

---

## Examples

### Continuing from Last Session

```
User: "continue from last session"

Claude Code:
📋 Previous Session (2024-01-15)

Completed tasks:
- User authentication
- Login page

Incomplete:
- Logout feature
- Password reset

Say "implement the logout feature" to continue.
```

### Checking Project Status

```
User: "tell me about this project"

Claude Code:
📁 Project: my-blog

Tech stack:
- Next.js + Tailwind CSS + Supabase

Current phase: Core Feature Development
Progress: 40% complete

Recent decisions:
- Adopted Supabase Auth
- Using App Router
```

---

## Relationship with Claude Code Auto-Memory (D22)

Claude Code 2.1.32+ has an "auto-memory" feature that automatically saves cross-session learning to `~/.claude/projects/<project>/memory/MEMORY.md`.

It coexists with the Harness memory system as a **3-layer architecture**:

| Layer | System | Content | Management |
|-------|--------|---------|------------|
| **Layer 1** | Claude Code auto-memory | General learning (avoiding mistakes, tool usage) | Implicit / automatic |
| **Layer 2** | Harness SSOT | Project-specific decisions and patterns | Explicit / manual |
| **Layer 3** | Agent Memory | Per-agent task learning | Agent-defined |

**When to use which**:
- If Layer 1 insights are important project-wide → promote to Layer 2 with `/memory ssot`
- Leave everyday learning to Layer 1 (do not disable it)
- When using Agent Teams, be careful about concurrent writes

Details: [D22: 3-Layer Memory Architecture](../../.claude/memory/decisions.md#d22-3層メモリアーキテクチャ)

---

## Notes

- **Auto-save**: Recommended to configure `hooks/Stop` to automatically append a summary to `session-log.md` at session end (manual operation is fine if not set up)
- **Privacy**: Do not record confidential information
- **Git policy**: `decisions.md`/`patterns.md` are recommended for sharing; `session-log.md`/`context.json`/`.claude/state/` are local-only (see `docs/MEMORY_POLICY.md`)
- **Size management**: If the log grows large, recommend running "clean up session log"
