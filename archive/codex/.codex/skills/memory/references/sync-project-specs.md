# Sync Project Specs Reference

**作業完了後に「Plans.md ちゃんと更新されてるかな？」と不安な時に実行します。**

## When to Use

| Situation | Command to Use |
|-----------|----------------|
| "How far along? What's next?" | `/sync-status` (use this first) |
| "Worked on it but forgot if I updated Plans.md" | **This command** |
| "Started from old template, format might be outdated" | **This command** |

> Tip: Usually `/sync-status` is sufficient. Use this for "just in case" or "format migration".

---

## Purpose

Aligns project specs/docs (e.g., `Plans.md`, `AGENTS.md`, `.claude/rules/*`) with latest claude-code-harness operations (**PM ↔ Impl**, `pm:*` markers, handoff commands).

## VibeCoder Phrases

- "**Worked on it but unsure if Plans.md is updated**" → this command
- "**Want to align old format files to latest**" → Unifies markers and descriptions
- "**Keep manual changes, fix only needed parts**" → Preserves existing text, applies only diffs

---

## Sync Targets (Only Existing Files)

- `Plans.md`
- `AGENTS.md`
- `CLAUDE.md` (only if has operation description)
- `.claude/rules/workflow.md`
- `.claude/rules/plans-management.md`

---

## Sync Content (Minimal Diff Policy)

### 1. Marker Normalization

- **Standard**: `pm:依頼中`, `pm:確認済`
- **Compatible**: `cursor:依頼中`, `cursor:確認済` (treated as synonyms)

### 2. State Transition Documentation

```
pm:依頼中 → cc:WIP → cc:完了 → pm:確認済
```

### 3. Handoff Routes Addition

- PM→Impl: `/handoff-to-impl-claude` (for PM Claude)
- Impl→PM: `/handoff-to-pm-claude`
- Cursor workflow: `/handoff-to-claude`, `/handoff-to-cursor`

### 4. Notification File Description

- `.claude/state/pm-notification.md` (compatible: `.claude/state/cursor-notification.md`)

---

## Execution Steps

### Step 1: Collect Current State (Required)

- Check target file existence and extract relevant sections
- Tally `Plans.md` marker occurrences (pm/cursor/cc)

### Step 2: Declare Change Policy (Required)

Tell user:
- Preserve existing text in principle (no destructive rewrites)
- Additions/replacements limited to "minimum necessary for operation"
- Changes shown as diffs, adjust if needed

### Step 3: Sync (Apply Diffs)

- **Plans.md**: Add `pm:*` to marker legend, note `cursor:*` as compatible
- **AGENTS.md**: Update roles to PM/Impl
- **rules/*.md**: Change `cursor:*` to `pm:*` standard + compatibility note
- **CLAUDE.md**: Add PM↔Impl routes if operation section exists

### Step 4: Finish (Required)

- Run `/sync-status` to verify markers
- Use `/remember` to lock "project-specific operations" if needed

---

## Parallel Execution

File reads can be parallelized:

| Process | Parallel |
|---------|----------|
| Plans.md read | ✅ Independent |
| AGENTS.md read | ✅ Independent |
| CLAUDE.md read | ✅ Independent |
| rules/*.md read | ✅ Independent |

Updates run serially for consistency.
