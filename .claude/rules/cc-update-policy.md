---
description: Quality policy for following CC updates
globs: ["CLAUDE.md", "docs/CLAUDE-feature-table.md"]
---

# CC Update Follow Policy

Quality standards for updating the Feature Table when adopting a new version of Claude Code.

## Core Principle

Any addition to the Feature Table must be accompanied by either a **corresponding implementation change** or an **explicit classification as Category C (CC auto-inherit)**.

A PR must not be merged in a state where "a row was simply added to the Feature Table" with nothing else.

## 3-Category Classification

| Category | Definition | PR Merge |
|---------|------|----------|
| **(A) Has implementation** | A corresponding implementation change exists in hooks / scripts / agents / skills / core | Allowed |
| **(B) Documentation only** | Only the Feature Table was changed. No implementation. | **Not allowed** — a concrete implementation proposal is required |
| **(C) CC auto-inherit** | No Harness-side change needed because CC itself fixed it (performance improvement, bug fix, etc.) | Allowed (note "CC auto-inherit" in the Feature Table) |

## Rules

### 1. Every Feature Table addition must include an implementation or a classification

When adding a new row to the Feature Table, at least one of the following must be true:

- **(A)** A corresponding implementation file change is included in the same PR
- **(C)** The entry is explicitly marked as "CC auto-inherit" in the Feature Table

If neither applies, the entry is classified as Category B (documentation only).

### 2. Detecting Category B blocks the PR and requires an implementation proposal

If even one Category B entry exists:

- **Block** the PR from merging
- For each Category B entry, require a concrete **implementation proposal** that includes:
  - Explanation of the unique value Harness provides
  - The files to be changed and the specific changes
  - User experience improvement (before / after)

After the proposal is approved, create an additional commit with the implementation or a follow-up PR.

### 3. Adding a "value" column is recommended

Adding a "value" column to the Feature Table that makes the A / B / C classification visible is recommended.

```markdown
| Feature | Skill | Purpose | Value |
|---------|-------|---------|---------|
| PostCompact hook | hooks | Context re-injection | A: implemented |
| Streaming leak fix | all | Memory leak fix | C: CC auto-inherit |
```

This column enables:
- Immediately spotting any remaining Category B entries during review
- Each Feature Table entry self-documenting "why it's here"
- Referencing past decisions when integrating future CC updates

## Scope

This policy applies when changing the following files:

- The Feature Table section of `CLAUDE.md`
- `docs/CLAUDE-feature-table.md`

It does not apply to normal implementation PRs, documentation fixes, or release work.
