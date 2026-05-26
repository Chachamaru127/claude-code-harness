# Existing User Migration

This guide helps users migrating to the Company AI Harness v1 fork from either:
- A previous version of the harness with Claude Code
- The upstream `claude-code-harness` repository

Migration is report-first. The default path is to inspect impact, preserve
backups, and avoid cleanup until a separate explicit confirmation gate exists.

> **Note**: Non-Claude runtime surfaces (Codex, OpenCode) were archived for v1.
> See `archive/non-claude/` for historical upstream material.
> Active migration only concerns Claude Code plugin state and harness-mem data.

## First Command

Run the report from a Harness checkout:

```bash
bin/harness doctor --migration-report
```

This command is non-destructive. It does not delete plugin caches, project
state, or harness-mem data.

## What The Report Checks

| Area | Impact | Compatibility rule | Rollback / backup |
|---|---|---|---|
| Claude plugin cache | Stale cached plugin versions can keep Claude Code on older Harness behavior. | Use Claude Code plugin manager commands; do not hand-delete cache entries as part of the report. | `/plugin update claude-code-harness` or uninstall/reinstall through the plugin manager. |
| Claude slash entries | Missing `harness-*` skill entries can make `/harness-plan` or `/harness-work` unavailable. | Missing entries are evidence of install drift, not proof that the host is unsupported. | Update or reinstall the plugin, then run `/harness-setup`. |
| harness-mem state | Memory continuity spans Claude Code sessions. | Do not delete the memory DB; the report does not read or delete DB contents. | Keep `~/.harness-mem/` and project `.harness-mem/state/`; use `harness mem doctor`, and only run purge with explicit confirmation. |

## Compatibility Contract

- Claude Code is the only supported runtime in v1.
- `not_observed != absent`: missing local evidence means the report could not
  observe a route, not that the capability is impossible.

## Safe Migration Order

1. Run `bin/harness doctor --migration-report`.
2. If Claude plugin cache or slash entries are stale, update through Claude Code
   plugin commands first.
3. If harness-mem state is observed, preserve it; do not purge during migration.

No destructive cleanup is part of the migration report.
