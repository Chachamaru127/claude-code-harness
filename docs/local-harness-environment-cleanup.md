# Local Harness Environment Cleanup

Last updated: 2026-10-14

Scope: reduce duplicate Harness skills/plugins across Claude Code, Codex CLI,
and Cursor without destructive cleanup by default.

## Why Duplicates Happen

Three separate mechanisms can stack:

1. **Harness repo design**: source repo keeps Claude, Codex, and Cursor adapter
   metadata side by side.
2. **User home mirrors**: `~/.codex/skills`, Claude plugin cache, and old
   plugin versions can all expose the same skill names.
3. **Cursor compatibility import**: Cursor official docs load `.claude/skills`,
   `.codex/skills`, `~/.claude/skills`, and `~/.codex/skills` in addition to
   Cursor-native skill directories. Enabling Desktop import of Claude/Codex
   settings can reintroduce duplicates even after clean packages are installed.

Harness cannot force-disable Cursor Desktop compatibility import. Clean Mode
reduces duplicates by keeping one Harness route per host and archiving obvious
cross-host mirrors after user confirmation.

## Profiles

| Profile | When to use | Harness behavior |
|---------|-------------|------------------|
| `clean` (default) | You want one Harness per tool and fewer duplicate entries | Diagnose all origins; recommend archive/disable of non-primary routes |
| `compatibility` | You intentionally share Claude/Codex skills inside Cursor | Warn about duplicates; recommend explicit invocation (`$harness-plan`, `/harness:harness-plan`) |

## Recommended Primary Routes

| Host | Primary route | Avoid mixing with |
|------|---------------|-------------------|
| Claude Code | `harness@claude-code-harness-marketplace` plugin | `--plugin-dir .` while marketplace plugin is also enabled |
| Codex CLI | `harness@claude-code-harness-marketplace` plugin **or** curated `~/.codex/skills` mirror, not both | duplicate `harness-*` in global skills and plugin cache |
| Cursor | generated Cursor package / `.cursor-plugin` route | full `~/.codex/skills` Harness mirror + Claude plugin cache when Clean Mode is desired |

## Dry-Run Diagnosis

Run:

```bash
bash scripts/diagnose-harness-skill-duplication.sh
bash scripts/diagnose-harness-skill-duplication.sh --host cursor --profile clean
bash scripts/diagnose-harness-skill-duplication.sh --json
```

The script is **dry-run only**. It never deletes files or edits config.

## Existing installations before the rename

Follow [the plugin switching guide](onboarding/plugin-rename.md) before cleaning an old installation. The old ID is `claude-code-harness`; the new ID is `harness`. Check every scope and keep only one active route. The rename map moves settings keys, not plugin-owned databases.

For Cursor, disable the old local plugin using its manager before installing the new package. `setup-cursor.sh` installs to `~/.cursor/plugins/local/harness` and does not remove the old `local/claude-code-harness` copy. Archive an old copy only after confirming its origin and that it is inactive.

## Manual Cleanup Checklist (after diagnosis)

1. **Inventory**: note every `harness-*`, `breezing`, and `memory` skill path.
2. **Claude cache**: use the plugin manager to keep one active ID and version.
   The new cache is `~/.claude/plugins/cache/claude-code-harness-marketplace/harness/*`.
   The old ID has a separate cache. Do not delete either cache or plugin data
   to perform the rename; follow the switching guide first.
3. **Codex route**: choose plugin **or** global skills, then disable the other
   path (`[[skills.config]] enabled = false` or plugin `enabled = false`).
4. **Cursor Clean Mode**: archive Harness mirrors under `~/.codex/skills` and
   stale Claude cache copies if Cursor should show Cursor package skills only.
5. **Cursor Desktop import**: if Claude/Codex compatibility import stays ON,
   expect duplicate skill names; use Compatibility Mode guidance instead of
   assuming zero duplicates.

## Cursor Local Plugin Install

Official install route:

```bash
bash scripts/setup-cursor.sh --check   # build + validate only
bash scripts/setup-cursor.sh           # install to ~/.cursor/plugins/local/
```

Two Cursor-specific constraints break naive installs:

1. **Symlinks are rejected.** Cursor refuses a `~/.cursor/plugins/local/<name>`
   symlink whose target is outside that directory (logged as
   `loadUserLocalPlugin ... rejected: symlink target ... is outside ...`).
   Install with a real directory copy, not a symlink:

   ```bash
   DIST="$HOME/.local/share/claude-code-harness/cursor"
   bash scripts/build-host-plugin-dist.sh --host cursor --out "$DIST"
   bash scripts/setup-cursor.sh
   ```

2. **`user-invocable: true` skills are dropped.** Cursor does not surface skills
   flagged for the Claude Code slash-only convention. `scripts/build-host-plugin-dist.sh`
   rewrites them to `user-invocable: false` for the Cursor package so workflow
   skills (`breezing`, `harness-plan`, `harness-work`, ...) register as
   Agent-Decides skills invokable via `/skill-name`. Always install the
   generated Cursor package, not the raw repo skills.

After installing, run **Developer: Reload Window** in Cursor.

## Rollback

Restore only an intentionally disabled route after checking the active ID. Do not enable both old and new copies. New Claude builds may reject the old name, so restoring an old directory does not guarantee that route can run.

Before any manual archive:

```bash
ARCHIVE_ROOT="$HOME/.harness-skill-cleanup-archive/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$ARCHIVE_ROOT"
# move, do not delete
mv ~/.codex/skills/harness-plan "$ARCHIVE_ROOT/"  # example only
```

Restore by moving directories back from the archive root.

## Verification

After cleanup:

```bash
bash scripts/diagnose-harness-skill-duplication.sh --host cursor --profile clean
bash scripts/build-host-plugin-dist.sh --host cursor --out /tmp/harness-cursor-dist
bash tests/test-host-plugin-dist.sh
```

## Related Docs

- `docs/distribution-scope.md`
- `docs/CURSOR_INTEGRATION.md`
- `spec.md` Host Distribution Contract and Clean/Compatibility profiles
