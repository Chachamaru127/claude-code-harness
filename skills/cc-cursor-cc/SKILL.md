---
name: cc-cursor-cc
description: "Validates brainstormed ideas with Cursor PM, updates Plans.md, then handoff back. Cursor ↔ Claude Code 2-Agent workflow support. Use when user mentions Cursor PM handoff, 2-agent plan validation, CC-Cursor round trip, or brainstorm review. Do NOT load for: implementation work, single-agent tasks, or direct coding."
description-en: "Validates brainstormed ideas with Cursor PM, updates Plans.md, then handoff back. Cursor ↔ Claude Code 2-Agent workflow support. Use when user mentions Cursor PM handoff, 2-agent plan validation, CC-Cursor round trip, or brainstorm review. Do NOT load for: implementation work, single-agent tasks, or direct coding."
description-ja: "Cursor PM でアイデアを検証し Plans.md を更新してバトンタッチ。Cursor ↔ Claude Code 2-Agent ワークフロー対応。Use when user mentions Cursor PM handoff, 2-agent plan validation, CC-Cursor round trip, or brainstorm review. Do NOT load for: implementation work, single-agent tasks, or direct coding."
allowed-tools: ["Read", "Write", "Edit", "Bash"]
user-invocable: false
---

# CC-Cursor-CC Skill (Plan Validation Round Trip)

Supports the flow of sending brainstormed content from Claude Code to **Cursor (PM)** for feasibility validation.

## Prerequisites

This skill assumes **2-agent operation**.

| Role | Agent | Description |
|------|-------|-------------|
| **PM** | Cursor | Validate plans, update Plans.md |
| **Impl** | Claude Code | Brainstorming, implementation |

## Execution Flow

### Step 1: Extract Brainstorming Context

Extract from recent conversation:
1. **Goal** (feature/purpose)
2. **Technology choices**
3. **Decisions made**
4. **Undecided items**
5. **Concerns**

### Step 2: Add Provisional Tasks to Plans.md

```markdown
## 🟠 Under Validation: {{Project}} `pm:awaiting-validation`

### Provisional Tasks (To Validate)
- [ ] {{task1}} `awaiting-validation`
- [ ] {{task2}} `awaiting-validation`

### Undecided Items
- {{item1}} → **Requesting PM decision**
```

### Step 3: Generate Validation Request for Cursor

Generate text to copy-paste to Cursor:

```markdown
## 📋 Plan Validation Request

**Goal**: {{summary}}

**Provisional tasks**:
1. {{task1}}
2. {{task2}}

### ✅ Requesting Cursor (PM) to:
1. Validate feasibility
2. Break down tasks
3. Decide undecided items
4. Update Plans.md (awaiting → cc:TODO)
```

### Step 4: Guide Next Action

1. Copy & paste request to **Cursor**
2. Run `/plan-with-cc` in Cursor
3. Cursor updates Plans.md
4. Cursor runs `/handoff-to-claude`
5. Copy & paste back to **Claude Code**

## Overall Flow

```
Claude Code (Brainstorm)
    ↓ /cc-cursor-cc
Cursor (PM validates & breaks down)
    ↓ /handoff-to-claude
Claude Code (/work implements)
```
