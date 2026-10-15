# Existing User Migration

Phase 73 keeps existing users on the same tool-first boundary as new users, but
migration is report-first. The default path is to inspect impact, preserve
backups, and avoid cleanup until a separate explicit confirmation gate exists.

## First Command

Run the report from a Harness checkout:

```bash
bin/harness doctor --migration-report
```

This command is non-destructive. It does not delete plugin caches, local skills,
OpenCode files, symlinks, project state, or harness-mem data.

## What The Report Checks

| Area | Impact | Compatibility rule | Rollback / backup |
|---|---|---|---|
| Claude plugin cache | Stale cached plugin versions can keep Claude Code on older Harness behavior. | Use Claude Code plugin manager commands; do not hand-delete cache entries as part of the report. | `/plugin update harness` or uninstall/reinstall through the plugin manager. |
| Claude slash entries | Missing `harness-*` skill entries can make `/harness-plan` or `/harness-work` unavailable. | Missing entries are evidence of install drift, not proof that the host is unsupported. | Update or reinstall the plugin, then run `/harness-setup`. |
| Codex local skills | Duplicate frontmatter names or old aliases can route Codex to stale skills. | `scripts/setup-codex.sh --user` remains the safe fallback even after direct plugin smoke exists. | Backups live under `${CODEX_HOME:-$HOME/.codex}/backups/setup-codex`. |
| Codex symlinks | Old symlink installs can break when the source checkout moves or on Windows. | Current setup prefers copied skill directories. | Re-run `scripts/setup-codex.sh --user`; restore inspected backups only if needed. |
| OpenCode files | Existing `.opencode/skills`, commands, plugins, and `AGENTS.md` may be replaced by setup. | OpenCode stays `internal-compatible`; runtime parity is not claimed. | Timestamped backups such as `.opencode/skills.backup.<timestamp>` and `.opencode/plugins/harness-bootstrap.mjs.backup.<timestamp>`. |
| harness-mem state | Memory continuity can span Claude Code and Codex sessions. | `memory DB を削除しない`; the report does not read or delete DB contents. | Keep `~/.harness-mem/` and project `.harness-mem/state/`; use `harness mem doctor`, and only run purge with explicit confirmation. |

## Compatibility Contract

- Claude Code, Codex CLI, Cursor, and Grok are public `supported` routes (H8 pin).
- OpenCode remains `internal-compatible`.
- Codex app, Hermes Agent, and GitHub Copilot CLI remain `candidate`.
- Antigravity CLI remains `future/unsupported`.
- `not_observed != absent`: missing local evidence means the report could not
  observe a route, not that the capability is impossible.

## Safe Migration Order

1. Run `bin/harness doctor --migration-report`.
2. If Claude plugin cache or slash entries are stale, update through Claude Code
   plugin commands first.
3. If Codex duplicate skills or symlinks are reported, run
   `scripts/setup-codex.sh --user` and inspect `${CODEX_HOME}/backups/setup-codex`.
4. If OpenCode files are reported, run `scripts/setup-opencode.sh` and inspect
   timestamped backups before restoring anything.
5. If harness-mem state is observed, preserve it; do not purge during adapter
   migration.

No destructive cleanup is part of Phase 73.1.9.

For the old Claude plugin ID, follow [the rename guide](plugin-rename.md). Updating the old ID does not switch its name.
