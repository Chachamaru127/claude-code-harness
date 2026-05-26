---
name: init-memory-ssot
description: "Initialize the project's SSOT memory (decisions/patterns) and optional session-log. Use during first-time setup or in projects where .claude/memory is not yet in place."
allowed-tools: ["Read", "Write"]
---

# Init Memory SSOT

Initializes the **SSOT** files under `.claude/memory/`.

- `decisions.md` (SSOT for important decisions)
- `patterns.md` (SSOT for reusable solutions)
- `session-log.md` (session log; local-only operation recommended)

Policy details: `docs/MEMORY_POLICY.md`

---

## Execution Steps

### Step 1: Check for Existing Files

- `.claude/memory/decisions.md`
- `.claude/memory/patterns.md`
- `.claude/memory/session-log.md`

Any that already exist are **not overwritten**.

### Step 2: Initialize from Templates (only if absent)

Templates:

- `templates/memory/decisions.md.template`
- `templates/memory/patterns.md.template`
- `templates/memory/session-log.md.template`

Replace `{{DATE}}` with today's date (e.g., `2025-12-13`) when generating.

### Step 3: Completion Report

- List of created files
- Git policy (`decisions/patterns` recommended for sharing; `session-log/.claude/state` recommended as local-only)
