# Sync SSOT from Memory Reference

Promote important observations recorded in memory systems (Harness Memory or Serena) to the project's SSOT:
`.claude/memory/decisions.md` and `.claude/memory/patterns.md`.

---

## VibeCoder Phrases

- "**Save what we learned for next time**" → this command
- "**Promote important decisions to SSOT**" → this command
- "**Organize decisions (why) and methods (how) separately**" → Reflect in decisions/patterns separately
- "**I don't know what to keep**" → Filter by importance and propose only candidates

---

## Supported Memory Systems

| System | Detection | How to Get Observations |
|--------|-----------|------------------------|
| **Harness Memory** | `harness_mem_*` MCP available | `harness_mem_search` / `harness_mem_timeline` |
| **Serena** | `.serena/memories/` | `mcp__serena__read_memory` |

Auto-detected at execution, using available system.

---

## Step 0: Memory System Detection

```bash
# Harness Memory check
if command -v harness_mem_search >/dev/null 2>&1; then
  MEMORY_SYSTEM="harness-mem"
fi

# Serena check
if [ -d ".serena/memories" ]; then
  MEMORY_SYSTEM="serena"
fi
```

**If neither exists**: Switch to manual input mode.

---

## Step 1: Extract SSOT Promotion Candidates

**For Harness Memory**:
```
mem-search: type:decision
mem-search: type:discovery concepts:pattern
mem-search: type:bugfix concepts:gotcha
```

**For Serena**:
```
mcp__serena__list_memories
mcp__serena__read_memory (target memories)
```

---

## Step 2: Filter by Promotion Criteria

### Decisions Candidates (Why) → `decisions.md`

| Observation Type | Concept | Criteria |
|------------------|---------|----------|
| `decision` | `why-it-exists`, `trade-off` | Technology selection reasons |
| `guard` | `test-quality`, `implementation-quality` | Guardrail reasons |
| `discovery` | `user-intent` | User requirements/constraints |

### Patterns Candidates (How) → `patterns.md`

| Observation Type | Concept | Criteria |
|------------------|---------|----------|
| `bugfix` | `problem-solution` | Recurrence prevention |
| `discovery` | `pattern`, `how-it-works` | Reusable solutions |
| `feature`, `refactor` | `pattern` | Implementation patterns |

### Exclusions

- Work-in-progress rough notes (low confidence)
- Personal/confidential information
- One-time tasks (not reusable)

---

## Step 3: Reflect to SSOT (Deduplicate)

### decisions.md Format

```markdown
## D{N}: {Title}

**Date**: YYYY-MM-DD
**Tags**: #decision #{keywords}
**Observation ID**: #{original ID}

### Conclusion
{Adopted conclusion}

### Background
{Why this decision was needed}

### Options
1. {Option A}: {pros/cons}
2. {Option B}: {pros/cons}

### Adoption Reason
{Why this option}

### Impact
{Scope of impact}

### Review Conditions
{When to reconsider}
```

### patterns.md Format

```markdown
## P{N}: {Title}

**Date**: YYYY-MM-DD
**Tags**: #pattern #{keywords}
**Observation ID**: #{original ID}

### Problem
{What problem this solves}

### Solution
{How to solve}

### Application Conditions
{When to use}

### Non-Application Conditions
{When not to use}

### Example
{Code or steps}

### Notes
{Pitfalls to watch}
```

---

## Step 4: Change Summary

```markdown
## 📚 SSOT Promotion Results

### Added/Updated
| File | Item | Observation ID |
|------|------|----------------|
| decisions.md | D12: RBAC | #9602 |
| patterns.md | P8: CORS | #9584 |

### Pending (Needs Review)
| ID | Title | Reason |
|----|-------|--------|
| #9590 | API Draft | Not finalized |

### Excluded
- Work-in-progress: 5 items
- Duplicates: 2 items
```

---

## Duplicate Prevention

Recording observation ID in SSOT entries prevents repeated promotion.

---

## Fallback on Failure

If memory system is inaccessible:
1. Ask user to paste observation content
2. Apply same procedure

```
> Cannot access memory system.
> Please paste the information you want to promote.
```
