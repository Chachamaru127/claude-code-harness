---
description: Validate brainstormed ideas with Cursor, update Plans.md, then handoff back to Claude Code
user-invocable: false
---

# /cc-cursor-cc - Plan Validation Round Trip

Supports the entire flow of sending brainstormed content from Claude Code to **Cursor (PM)** for feasibility validation, then returning to Claude Code after Cursor updates Plans.md.

## Quick Reference

- "**Validate the brainstormed content with Cursor**" → this command
- "**Want to check if the plan is realistic**" → feasibility check with Cursor
- "**Want PM (Cursor) to review**" → generate validation request

## Deliverables

- **Validation request for Cursor** - Output in format usable with `/plan-with-cc`
- **Plans.md preparation** - Organize brainstormed content as provisional tasks
- **Explicit handoff waiting state** - Clarify what Claude Code is waiting for

---

## ⚠️ Prerequisites

This command assumes **2-agent operation**.

| Role | Agent | Description |
|------|-------|-------------|
| **PM** | Cursor | Validate plans, update Plans.md |
| **Impl** | Claude Code | Brainstorming, implementation |

**If 2-agent setup is not done yet**: First run `/2agent` to set up.

---

## Execution Flow

### Step 1: Extract Brainstorming Context

**Extract the following from recent conversation**:

1. **Goal** (feature/purpose)
2. **Discussed technology choices** (language, framework, libraries)
3. **Decisions made** (agreements)
4. **Undecided items** (not yet decided)
5. **Concerns** (risks, issues)

**Confirm extracted content with user**:

> 📝 **Summarized the brainstorming content**
>
> **Goal**: {{summary}}
> **Technology choices**: {{tech stack}}
> **Decisions made**:
> - {{agreement1}}
> - {{agreement2}}
> **Undecided items**:
> - {{undecided1}}
> **Concerns**:
> - {{concern1}}
>
> Send this content to Cursor?

**Wait for response**

---

### Step 2: Add Provisional Tasks to Plans.md

Add brainstormed content as **provisional tasks** to Plans.md.

```markdown
## 🟠 Under Validation: {{Project Name}} `pm:awaiting-validation`

> ⚠️ This section contains brainstormed content from Claude Code.
> Please validate feasibility and break down tasks with Cursor (PM).

### Background
- (Background/purpose discussed in brainstorming)

### Provisional Tasks (To Validate)
- [ ] {{provisional-task1}} `awaiting-validation`
- [ ] {{provisional-task2}} `awaiting-validation`
- [ ] {{provisional-task3}} `awaiting-validation`

### Technology Choices (Draft)
- {{tech1}}: (selection reason)
- {{tech2}}: (selection reason)

### Undecided Items
- {{undecided1}} → **Requesting PM decision**
- {{undecided2}} → **Requesting PM decision**

### Concerns
- {{concern1}}
```

---

### Step 3: Generate Validation Request for Cursor

Generate **request text to copy-paste to Cursor** in the following format:

```markdown
---
## 📋 Plan Validation Request (Claude Code → Cursor)

Please validate the feasibility of content brainstormed in Claude Code.

### Validation Request Content

**Goal**:
{{summary}}

**Provisional tasks from brainstorming**:
1. {{provisional-task1}}
2. {{provisional-task2}}
3. {{provisional-task3}}

**Technology choices (draft)**:
- {{tech stack}}

**Undecided items (requesting PM decision)**:
- {{undecided1}}
- {{undecided2}}

**Concerns**:
- {{concern1}}

---

### ✅ Requesting Cursor (PM) to:

1. **Validate feasibility**
   - Are provisional tasks technically feasible?
   - Are there any overlooked prerequisites?

2. **Break down tasks**
   - Break down provisional tasks into implementable granularity
   - Organize dependencies and order

3. **Decide on undecided items**
   - Make decisions on the above undecided items

4. **Update Plans.md**
   - Change `pm:awaiting-validation` → `cc:TODO`
   - Add broken down tasks

---

### 📤 After Validation Complete

Once Plans.md update is complete, run `/handoff-to-claude` to
generate the request for Claude Code.

---
```

---

### Step 4: Guide User to Next Action

> ✅ **Generated validation request!**
>
> **Next steps**:
>
> 1. Copy & paste the above request to **Cursor**
> 2. Run `/plan-with-cc` in Cursor (or review directly)
> 3. Cursor updates Plans.md
> 4. Cursor runs `/handoff-to-claude`
> 5. Copy & paste the generated request to **Claude Code**
>
> **Waiting state**: Claude Code is waiting for handoff from Cursor.
>
> 💡 **Hint**: When validation in Cursor is complete, say "validation is done".

---

## Output Example

### Example: After brainstorming task management app

```
User: /cc-cursor-cc

Claude Code:
> 📝 Summarized the brainstorming content
>
> **Goal**: Notion-like task management app
> **Technology choices**: Next.js + Supabase + TailwindCSS
> **Decisions made**:
> - Kanban view is required
> - Tag feature is also needed
> **Undecided items**:
> - Is real-time sync needed?
> **Concerns**:
> - Drag & drop implementation might be complex

User: OK

Claude Code:
(Added provisional tasks to Plans.md)
(Generated validation request for Cursor)

> ✅ Generated validation request!
> Next steps: Paste to Cursor...
```

---

## Overall Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      Claude Code                            │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │ Brainstorm  │ →  │/cc-cursor-cc│ →  │Gen Request  │     │
│  └─────────────┘    └─────────────┘    └──────┬──────┘     │
│                                               │ Copy-paste │
└───────────────────────────────────────────────┼─────────────┘
                                                ↓
┌─────────────────────────────────────────────────────────────┐
│                        Cursor (PM)                          │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │/plan-with-cc│ →  │Update       │ →  │/handoff-to- │     │
│  │  validate   │    │Plans.md     │    │   claude    │     │
│  └─────────────┘    └─────────────┘    └──────┬──────┘     │
│                                               │ Copy-paste │
└───────────────────────────────────────────────┼─────────────┘
                                                ↓
┌─────────────────────────────────────────────────────────────┐
│                      Claude Code                            │
│  ┌─────────────┐    ┌─────────────┐                        │
│  │   /work     │ →  │ Implement   │                        │
│  └─────────────┘    └─────────────┘                        │
└─────────────────────────────────────────────────────────────┘
```

---

## Related Commands

| Command | Role | Agent |
|---------|------|-------|
| `/plan-with-agent` | Create plan in solo mode | Claude Code |
| `/plan-with-cc` | Validate and break down plan | Cursor |
| `/handoff-to-claude` | Generate request for Claude Code | Cursor |
| `/handoff-to-cursor` | Completion report to Cursor | Claude Code |
| `/work` | Task implementation | Claude Code |

---

## Notes

- **2-agent operation only**: Use `/plan-with-agent` for solo mode
- **Copy-paste required**: Currently, Claude Code and Cursor cannot directly connect, so manual copy-paste is required
- **Plans.md sync**: Ensure both are referencing the same Plans.md
