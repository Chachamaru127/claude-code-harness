---
_harness_template: rules/skill-hierarchy.md
_harness_version: 2.6.1
---

# Skill Hierarchy Guidelines

## Overview

Skills in claude-code-harness follow a **two-layer structure**: **parent skills (categories)** and **child skills (specific functionality)**.

```
skills/
├── impl/                      # Parent skill (SKILL.md)
│   ├── SKILL.md              # Category overview and routing
│   └── work-impl-feature/    # Child skill
│       └── doc.md            # Concrete steps
├── harness-review/
│   ├── SKILL.md
│   ├── code-review/
│   │   └── doc.md
│   └── security-review/
│       └── doc.md
...
```

## Required Rules

### 1. After reading a parent skill, also read the child skill

After launching a parent skill via the Skill tool, **always Read the child skill (doc.md) that matches the user's intent**.

```
✅ Correct flow:
1. Launch "impl" via the Skill tool → retrieve SKILL.md content
2. Determine the user's intent (e.g., feature implementation)
3. Read work-impl-feature/doc.md with the Read tool
4. Follow the steps in doc.md

❌ Incorrect:
1. Launch "impl" via the Skill tool
2. Read only SKILL.md and start working (child skill ignored)
```

### 2. How to choose a child skill

| User's intent | Skill to launch | Child skill to read |
|--------------|----------------|---------------------|
| "Implement this feature" | impl | work-impl-feature/doc.md |
| "Review this code" | harness-review | code-review/doc.md |
| "Security check" | harness-review | security-review/doc.md |
| "Run the build" | verify | build-verify/doc.md |

### 3. When multiple child skills apply

Ask the user, or select the single most relevant one to start.

---

## Why This Matters

- Parent SKILL.md contains only "overview and routing"
- Child doc.md contains "concrete steps, checklists, and pattern collections"
- Skipping the child skill results in incomplete work

---

## Integration with PostToolUse Hook

A reminder is automatically displayed after using the Skill tool.
Read the relevant child skill from the displayed list.
