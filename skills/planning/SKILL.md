---
name: planning
description: "Creates implementation plans from ideas and requirements, generating Plans.md ready for /work. Use when user mentions '/plan-with-agent', create a plan, organize tasks, feature planning, or TDD planning. Do NOT load for: implementation, reviews, or setup."
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash", "WebSearch", "Task"]
argument-hint: "[--ci]"
disable-model-invocation: true
---

# Planning Skill

Organizes ideas and requirements, converting them into executable tasks in Plans.md.

## Quick Reference

- "**Create a plan**" → this skill
- "**Turn what we talked about into a plan**" → extract from conversation
- "**Want to organize what to build**" → start with hearing
- "**Plan with TDD**" → force TDD adoption
- "**CI/benchmark**" → `--ci` mode

## Deliverables

- **Plans.md** - Task list executable with `/work` (required)
- **Feature priority matrix** - Required/Recommended/Optional classification

## Usage

```bash
/planning              # Interactive planning
/planning --ci         # CI mode (non-interactive)
```

## Mode-specific Usage

| Mode | Command | Description |
|------|---------|-------------|
| **Solo mode** | `/planning` | Claude Code alone: plan → execute → review |
| **2-agent mode** | `/plan-with-cc` (Cursor) | Plan with Cursor → Execute with Claude Code |

## Feature Details

| Feature | Reference |
|---------|-----------|
| **Execution Flow** | See [references/execution-flow.md](references/execution-flow.md) |
| **TDD Adoption** | See [references/tdd-adoption.md](references/tdd-adoption.md) |
| **Priority Matrix** | See [references/priority-matrix.md](references/priority-matrix.md) |

## Execution Flow Overview

1. **Step 0**: Check conversation context (extract from previous conversation or start fresh)
2. **Step 1**: Hearing what to build
3. **Step 2**: Increase resolution (max 3 questions)
4. **Step 3**: Technical research (WebSearch)
5. **Step 4**: Extract feature list
6. **Step 5**: Create priority matrix (Required/Recommended/Optional)
7. **Step 5.5**: TDD adoption judgment and test design
8. **Step 6**: Effort estimation (reference)
9. **Step 7**: Generate Plans.md with quality markers
10. **Step 8**: Guide next actions

## Auto-invoke Skills

| Skill | When to Call |
|-------|--------------|
| `setup` | **Call first** (executes adaptive setup) |
| `vibecoder-guide` | When user is non-technical |

## Quality Markers (Auto-assigned)

| Task Content | Marker | Effect |
|--------------|--------|--------|
| Auth/login feature | `[feature:security]` | Security checklist |
| UI component | `[feature:a11y]` | a11y check |
| Business logic | `[feature:tdd]` | TDD recommended |
| API endpoint | `[feature:security]` | Input validation |
| Bug fix | `[bugfix:reproduce-first]` | Reproduction test first |

## Next Actions

After planning:
- Start implementation with `/work`
- Or say "start from Phase 1"
- Adjust with "add {{feature}}" or "postpone {{feature}}"
