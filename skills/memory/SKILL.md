---
name: memory
description: "Manage SSOT, memory, and cross-tool memory search. Guardian of decisions.md and patterns.md. Use when user mentions memory, SSOT, decisions.md, patterns.md, merging, migration, SSOT promotion, sync memory, save learnings, memory search, harness-mem, past decisions, or record this. Do NOT load for: implementation work, reviews, ad-hoc notes, or in-session logging."
description-en: "Manage SSOT, memory, and cross-tool memory search. Guardian of decisions.md and patterns.md. Use when user mentions memory, SSOT, decisions.md, patterns.md, merging, migration, SSOT promotion, sync memory, save learnings, memory search, harness-mem, past decisions, or record this. Do NOT load for: implementation work, reviews, ad-hoc notes, or in-session logging."
description-ja: "SSOTと記憶を管理し、ツール横断の記憶検索を提供。decisions.mdとpatterns.mdの守護者です。Use when user mentions memory, SSOT, decisions.md, patterns.md, merging, migration, SSOT promotion, sync memory, save learnings, memory search, harness-mem, past decisions, or record this. Do NOT load for: implementation work, reviews, ad-hoc notes, or in-session logging."
allowed-tools: ["Read", "Write", "Edit", "Bash", "mcp__harness__harness_mem_*"]
argument-hint: "[ssot|sync|migrate|search|record]"
user-invocable: true
context: fork
---

# Memory Skills

Skills responsible for memory and SSOT management.

## Feature Details

| Feature | Details |
|---------|---------|
| **SSOT initialization** | See [references/ssot-initialization.md](${CLAUDE_SKILL_DIR}/references/ssot-initialization.md) |
| **Plans.md merging** | See [references/plans-merging.md](${CLAUDE_SKILL_DIR}/references/plans-merging.md) |
| **Migration processing** | See [references/workflow-migration.md](${CLAUDE_SKILL_DIR}/references/workflow-migration.md) |
| **Project spec sync** | See [references/sync-project-specs.md](${CLAUDE_SKILL_DIR}/references/sync-project-specs.md) |
| **Memory → SSOT promotion** | See [references/sync-ssot-from-memory.md](${CLAUDE_SKILL_DIR}/references/sync-ssot-from-memory.md) |

## Unified Harness Memory (shared DB)

For recording and searching shared across Claude Code / Codex / OpenCode, prefer `harness_mem_*` MCP.

- Search: `harness_mem_search`, `harness_mem_timeline`, `harness_mem_get_observations`
- Inject: `harness_mem_resume_pack`
- Record: `harness_mem_record_checkpoint`, `harness_mem_finalize_session`, `harness_mem_record_event`

## Relationship with Claude Code Auto-Memory (D22)

Harness SSOT memory (Layer 2) coexists with Claude Code's auto-memory (Layer 1).
Auto-memory implicitly records general learnings, while SSOT explicitly manages project-specific decisions.
When Layer 1 insights are important to the entire project, promote them to Layer 2 with `/memory ssot`.

Details: [D22: 3-layer memory architecture](../../.claude/memory/decisions.md#d22-3層メモリアーキテクチャ)

## Execution Steps

1. Classify the user's request
2. Read the appropriate reference file from "Feature Details" above
3. Execute according to its contents

## SSOT Promotion

Persists important learnings from the memory system (Claude-mem / Serena) into SSOT.

- "**Save what we learned**" → [references/sync-ssot-from-memory.md](${CLAUDE_SKILL_DIR}/references/sync-ssot-from-memory.md)
- "**Promote decisions to SSOT**" → [references/sync-ssot-from-memory.md](${CLAUDE_SKILL_DIR}/references/sync-ssot-from-memory.md)
