---
description: "[Optional] Promote important observations from memory systems (Claude-mem/Serena) to SSOT"
description-en: "[Optional] Promote important observations from memory systems (Claude-mem/Serena) to SSOT"
---

# /sync-ssot-from-memory - Memory → SSOT Promotion

Promote important observations recorded in memory systems (Claude-mem or Serena) to the project's SSOT:
`.claude/memory/decisions.md` and `.claude/memory/patterns.md`.

---

## VibeCoder Phrases

- "**Save what we learned for next time**" → this command
- "**Promote important decisions to SSOT**" → this command
- "**Organize decisions (why) and methods (how) separately**" → Reflect in decisions/patterns separately
- "**I don't know what to keep**" → Filter by importance and propose only candidates for SSOT

---

## Supported Memory Systems

| System | Detection Method | How to Get Observations |
|--------|------------------|------------------------|
| **Claude-mem** | Existence of `~/.claude-mem/settings.json` | `mem-search` skill |
| **Serena** | Existence of `.serena/memories/` | `mcp__serena__read_memory` |

Auto-detected at command execution, using available system.

---

## Steps

### Step 0: Memory System Detection

```bash
# Claude-mem check
if [ -f "$HOME/.claude-mem/settings.json" ]; then
  echo "📚 Claude-mem detected"
  MEMORY_SYSTEM="claude-mem"
fi

# Serena check
if [ -d ".serena/memories" ]; then
  echo "📚 Serena detected"
  MEMORY_SYSTEM="serena"
fi

# Prefer Claude-mem if both exist
```

**If neither exists**:
- Switch to manual input mode
- Ask user to paste observation content

---

### Step 1: Extract SSOT Promotion Candidates

**For Claude-mem**:

```
# Search important observations with mem-search
mem-search: type:decision
mem-search: type:discovery concepts:pattern
mem-search: type:bugfix concepts:gotcha
```

**For Serena**:

```
# Get Serena memory list
mcp__serena__list_memories

# Read target memories
# e.g.: *_decisions_*, *_investigation_*
```

---

### Step 2: Filter by Promotion Criteria

#### Decisions Candidates (Why) → `decisions.md`

| Observation Type | Concept | Promotion Criteria |
|------------------|---------|-------------------|
| `decision` | `why-it-exists`, `trade-off` | Technology selection, adoption/rejection reasons |
| `guard` | `test-quality`, `implementation-quality` | Guardrail activation reasons |
| `discovery` | `user-intent` | User requirements/constraints |

#### Patterns Candidates (How) → `patterns.md`

| Observation Type | Concept | Promotion Criteria |
|------------------|---------|-------------------|
| `bugfix` | `problem-solution` | Recurrence prevention patterns |
| `discovery` | `pattern`, `how-it-works` | Reusable solutions |
| `feature`, `refactor` | `pattern` | Implementation patterns |

#### Exclusions

- Work-in-progress rough notes (low confidence)
- Personal/confidential information
- One-time tasks (not reusable)

---

### Step 3: Reflect to SSOT (Deduplicate)

#### decisions.md Format

```markdown
## D{N}: {Title}

**Date**: YYYY-MM-DD
**Tags**: #decision #{related keywords}
**Observation ID**: #{original observation ID} (for duplicate prevention)

### Conclusion

{Adopted conclusion}

### Background

{Background that necessitated this decision}

### Options

1. {Option A}: {pros/cons}
2. {Option B}: {pros/cons}

### Adoption Reason

{Why this option was chosen}

### Impact

{Scope of this decision's impact}

### Review Conditions

{Situations when this decision should be reconsidered}
```

#### patterns.md Format

```markdown
## P{N}: {Title}

**Date**: YYYY-MM-DD
**Tags**: #pattern #{related keywords}
**Observation ID**: #{original observation ID} (for duplicate prevention)

### Problem

{What problem does this solve}

### Solution

{How to solve it}

### Application Conditions

{When to use this pattern}

### Non-Application Conditions

{When not to use this pattern}

### Example

{Code examples or specific steps}

### Notes

{Pitfalls and things to watch out for}
```

---

### Step 4: Change Summary

```markdown
## 📚 SSOT Promotion Results

### Added/Updated

| File | Item | Original Observation ID |
|------|------|------------------------|
| decisions.md | D12: RBAC Adoption | #9602 |
| patterns.md | P8: CORS Handling | #9584 |

### Pending (Needs Review)

| Observation ID | Title | Pending Reason |
|----------------|-------|----------------|
| #9590 | API Design Draft | Not finalized yet |

### Excluded

- Work-in-progress notes: 5 items
- Duplicates: 2 items
```

---

## Duplicate Prevention

Recording observation ID in SSOT entries prevents the same observation from being promoted multiple times.

```markdown
## D12: RBAC Adoption

**Observation ID**: #9602  ← This detects duplicates
```

---

## Fallback on Failure

If memory system is inaccessible:

1. Ask user to paste observation content
2. Apply same procedure to reflect to SSOT

```
> Cannot access memory system.
> Please paste the information you want to promote.
```

---

## Related

- `/harness-mem` - Claude-mem integration setup
- `mem-search` skill - Search past memories
- `.claude/memory/decisions.md` - Decisions (SSOT)
- `.claude/memory/patterns.md` - Reusable patterns (SSOT)
