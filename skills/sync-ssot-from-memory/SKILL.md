---
name: sync-ssot-from-memory
description: "Promotes important observations from memory systems (Claude-mem, Serena) to SSOT (decisions.md, patterns.md). Use when user mentions SSOT promotion, sync memory, save learnings, or before Plans.md cleanup. Do NOT load for: ad-hoc notes, implementation work, or reviews."
allowed-tools: ["Read", "Write", "Edit", "Bash"]
argument-hint: "[--preview|--apply]"
---

# Sync SSOT from Memory

Promote important observations recorded in memory systems (Claude-mem or Serena) to the project's SSOT:
`.claude/memory/decisions.md` and `.claude/memory/patterns.md`.

## Quick Reference

- "**Save what we learned for next time**" → this skill
- "**Promote important decisions to SSOT**" → this skill
- "**Organize decisions (why) and methods (how) separately**" → Reflect in decisions/patterns separately

## Supported Memory Systems

| System | Detection | How to Get Observations |
|--------|-----------|------------------------|
| **Claude-mem** | `~/.claude-mem/settings.json` | `mcp__plugin_claude-mem_mcp-search__search` |
| **Serena** | `.serena/memories/` | `mcp__serena__read_memory` |

Auto-detected at execution, using available system.

## Execution Flow

### Step 0: Detect Memory System

```bash
# Claude-mem check
if [ -f "$HOME/.claude-mem/settings.json" ]; then
  MEMORY_SYSTEM="claude-mem"
fi

# Serena check
if [ -d ".serena/memories" ]; then
  MEMORY_SYSTEM="serena"
fi
```

### Step 1: Extract SSOT Promotion Candidates

**For Claude-mem**:
- Search for `type:decision`
- Search for `type:discovery concepts:pattern`
- Search for `type:bugfix concepts:gotcha`

**For Serena**:
- List and read relevant memories

### Step 2: Filter by Promotion Criteria

**Decisions Candidates (Why) → `decisions.md`**:
- Technology selection reasons
- Guardrail reasons
- User requirements/constraints

**Patterns Candidates (How) → `patterns.md`**:
- Recurrence prevention (bugfixes)
- Reusable solutions
- Implementation patterns

**Exclusions**:
- Work-in-progress rough notes
- Personal/confidential information
- One-time tasks (not reusable)

### Step 3: Reflect to SSOT

Add entries to `decisions.md` and `patterns.md` with:
- Unique ID (D{N} or P{N})
- Date, Tags, Observation ID
- Structured content (Conclusion, Background, Options, etc.)

### Step 4: Output Summary

```markdown
## SSOT Promotion Results

### Added/Updated
| File | Item | Observation ID |
|------|------|----------------|
| decisions.md | D{N}: {Title} | #{id} |
| patterns.md | P{N}: {Title} | #{id} |

### Excluded
- Work-in-progress: N items
- Duplicates: N items
```

## Fallback on Failure

If memory system is inaccessible, ask user to paste observation content manually.
