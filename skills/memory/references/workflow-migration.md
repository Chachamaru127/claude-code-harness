---
name: migrate-workflow-files
description: "Migrate existing AGENTS.md/CLAUDE.md/Plans.md to the new format: review existing content, confirm carry-over items interactively, update with backup and task-preserving merge for Plans."
allowed-tools: ["Read", "Write", "Edit", "Bash"]
---

# Migrate Workflow Files (Interactive Merge)

## Purpose

Update the following files that are in use in an existing project to the new format
**while respecting the existing content**.

- `AGENTS.md`
- `CLAUDE.md`
- `Plans.md`

Key points:

- **Confirm carry-over information interactively** (nothing is silently discarded or overwritten)
- Always **create a backup** before making changes
- `Plans.md` follows the `merge-plans` policy to **preserve tasks while updating the structure**

---

## Prerequisites (Important)

This skill proceeds in the order **user agreement → backup → generation → diff review**
to balance "safety on first application" with "correct behavior (new format)".

---

## Inputs (auto-detected within this skill)

- `project_name`: estimated from `basename $(pwd)`
- `date`: `YYYY-MM-DD`
- Presence of existing files:
  - `AGENTS.md`
  - `CLAUDE.md`
  - `Plans.md`
- Reference templates for the new format:
  - `templates/AGENTS.md.template`
  - `templates/CLAUDE.md.template`
  - `templates/Plans.md.template`

---

## Execution Flow

### Step 0: Detection and Agreement (Required)

1. Use `Read` to confirm the existence of `AGENTS.md` / `CLAUDE.md` / `Plans.md`.
2. If they exist, confirm with the user:
   - **Whether migration (update to new format) is acceptable**
   - Important: migration **includes content reorganization** (some rearrangement or rephrasing may occur)

If the user says NO:

- Stop this skill (do not rewrite anything)
- Instead, suggest a safe operation such as "only safely merge `.claude/settings.json`"

### Step 1: Review Existing Content (Summarize)

`Read` each file and extract the following, presenting a brief summary:

- **AGENTS.md**: Role assignments, handoff procedures, prohibited actions, environment/prerequisites
- **CLAUDE.md**: Important constraints (prohibitions/permissions/branch policy), test procedures, commit conventions, operating rules
- **Plans.md**: Task structure, marker usage, current WIP/requested tasks

### Step 2: Confirm Carry-over Items (Interactive)

Based on the summary, ask the user which items to **keep/adjust** (5–10 questions is sufficient):

- Constraints that must absolutely be retained (e.g., no production deployment, specific directory restrictions, security requirements)
- Role assignment assumptions (Solo/2-agent)
- Branch policy (main/staging, etc.)
- Representative test/build commands
- Plans marker policy (align with existing rules if any)

### Step 3: Create Backup (Required)

Collect backups under `.claude-code-harness/backups/` inside the project
(often not wanted in git).

Example:

- `.claude-code-harness/backups/2025-12-13/AGENTS.md`
- `.claude-code-harness/backups/2025-12-13/CLAUDE.md`
- `.claude-code-harness/backups/2025-12-13/Plans.md`

Use `Bash` with `mkdir -p` and `cp`.

### Step 4: Generate New Format (Merge)

#### 4-1. Plans.md (task-preserving merge)

Execute per the `merge-plans` policy:

- Preserve existing 🔴🟡🟢📦 tasks
- Update the marker legend and last-modified info from the template side
- If parsing fails, keep the backup and adopt the template

#### 4-2. AGENTS.md / CLAUDE.md (template + carry-over block)

Use the template as the skeleton and **relocate the items confirmed in Step 2
to the appropriate places in the new format**.

Minimum policy:

- Do not remove existing "important rules"; keep them as a **"Project-specific rules (migrated)"** section
- Rewrite role assignments/flows to match the template format (preserve the meaning)

### Step 5: Diff Review and Completion

- Briefly summarize the changes via `git diff` (or file diff)
- Final check that critical points (permissions/prohibitions/task state) are as intended
- Fix any issues immediately

---

## Deliverables (Definition of Done)

- A **new-format version** of `AGENTS.md` / `CLAUDE.md` / `Plans.md` reflecting the existing content
- A backup remains under `.claude-code-harness/backups/`
- Plans tasks have not been lost (preserved)
