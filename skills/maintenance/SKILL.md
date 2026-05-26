---
name: maintenance
description: "File cleanup and archiving. Tidies up bloated Plans.md, session-log.md, old logs, and state files. Trigger: /maintenance, cleanup, archive, organize, split session-log. Do NOT load for: implementation, review, release, new feature development."
description-en: "File cleanup and archiving. Tidies up bloated Plans.md, session-log.md, old logs, and state files. Trigger: /maintenance, cleanup, archive, organize, split session-log. Do NOT load for: implementation, review, release, new feature development."
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash"]
argument-hint: "[plans|session-log|logs|state|all] [--dry-run]"
user-invocable: true
effort: low
---

# Maintenance

A single-purpose skill for tidying up messy files. Invoke when the auto-cleanup-hook
issues a warning, or as routine housekeeping.

> **Prerequisite**: Before destructive operations (archive moves, line deletions), confirm
> that important information in Plans.md / session-log.md has been promoted to SSOT
> (decisions.md / patterns.md). If not yet synced, run `/memory sync` first.

## Quick Reference

| Subcommand | Target | Typical trigger |
|------------|--------|----------------|
| `maintenance plans` | Archive completed tasks from Plans.md | "Tidy Plans.md", "Move old tasks" |
| `maintenance session-log` | Split session-log.md by month | "Split session-log", "Log is too long" |
| `maintenance logs` | Delete old files under `.claude/logs/` | "Log cleanup", "Delete logs older than 30 days" |
| `maintenance state` | Trim `agent-trace.jsonl` / `harness-usage.json` | "Trace bloat", "Compress state" |
| `maintenance all` | Run all four above in order | "Clean everything", "Full cleanup" |

Adding `--dry-run` lists what would be done without executing. Free-form instructions (e.g.,
"also delete old archives", "keep only this session-log") are parsed in Step 1 and
reflected in the processing parameters from Step 2 onward.

## Execution Steps

1. **Parse user instructions**: extract subcommand + free-form text (exclusions, save location, day thresholds)
2. **SSOT sync check**: if `.claude/state/.ssot-synced-this-session` is absent,
   prompt for `/memory sync` (required only when touching Plans.md)
3. **Open reference file**: read `${CLAUDE_SKILL_DIR}/references/cleanup.md` and run the relevant section
4. **Report Before/After**: display line counts and deletion count on completion

## Subcommand Details

For execution steps, thresholds, and archive destinations per target, see [cleanup.md](./references/cleanup.md).

## Integration with auto-cleanup-hook

The PostToolUse hook (`scripts/auto-cleanup-hook.sh` / Go version `auto_cleanup_hook.go`)
detects line-count overflows in Plans.md, session-log.md, and CLAUDE.md, and returns the
feedback `Recommend running /maintenance to archive old tasks`.
When you see this warning, run the relevant subcommand.

## Notes

- **Do not move in-progress tasks**: `cc:WIP`, `pm:requested`, `cursor:requested` are excluded from archiving
- **Archive destination is fixed**: `.claude/memory/archive/` — confirm with the user before moving elsewhere
- **Backup**: before editing files over 200 lines, take a local backup with `cp <file> <file>.bak.$(date +%s)`
- **CLAUDE.md is warning-only**: do not auto-edit. Only propose splitting.

## Related Skills

- `memory` — SSOT promotion before tidying Plans.md (updates decisions.md / patterns.md)
- `harness-setup` — Periodic maintenance after initial setup can also be invoked via `harness-setup`
- `session-init` — Controls maintenance recommendation notifications at session start
