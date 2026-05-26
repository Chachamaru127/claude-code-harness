# Naming Cleanup Plan

Internal rename from upstream branding (`claude-code-harness` / Chachamaru127) to internal
project identity (`company-ai-harness` / Company AI Harness).

**Status**: Phase 1 + Phase 2 complete (commit `chore: rename fork to company ai harness`).
Phase 1 (display-only metadata) and Phase 2 (plugin ID atomic rename + hook validation update) were
applied together. Phase 3 (config file rename) and Phase 4 (Go module rename) are deferred.

---

## Target Identity

| Surface | Current (upstream) | Target (internal) |
|---------|-------------------|-------------------|
| Project display name | Claude Code Harness | Company AI Harness |
| Plugin / package ID | `claude-code-harness` | `company-ai-harness` |
| Marketplace name | `claude-code-harness-marketplace` | `company-ai-harness-marketplace` |
| CLI binary | `harness` | `harness` (unchanged) |
| Task prefix | _(none yet)_ | `AIH` |
| Author | Chachamaru / Chachamaru127 | _(internal team)_ |
| GitHub org | `Chachamaru127` | _(internal org)_ |
| Config file | `.claude-code-harness.config.yaml` | `.company-ai-harness.config.yaml` |
| Go module | `github.com/Chachamaru127/claude-code-harness/go` | _(internal module path)_ |

---

## Current Names Found

### 1. Manifests & config roots

| File | Field | Current value |
|------|-------|---------------|
| `.claude-plugin/plugin.json` | `name` | `claude-code-harness` |
| `.claude-plugin/plugin.json` | `description` | "Claude harness – A harness for solo developers (Vibecoders)…" |
| `.claude-plugin/plugin.json` | `author.name` | `Chachamaru` |
| `.claude-plugin/plugin.json` | `homepage` / `repository` | `github.com/Chachamaru127/claude-code-harness` |
| `.claude-plugin/marketplace.json` | `name` | `claude-code-harness-marketplace` |
| `.claude-plugin/marketplace.json` | `owner.name` | `Chachamaru` |
| `.claude-plugin/marketplace.json` | `plugins[0].name` | `claude-code-harness` |
| `.claude-plugin/marketplace.json` | `plugins[0].homepage` | `github.com/Chachamaru127/claude-code-harness` |
| `harness.toml` | `[project] name` | `claude-code-harness` |
| `harness.toml` | `[project] description` | same as plugin.json |
| `harness.toml` | `[project.author] name` | `Chachamaru` |
| `harness.toml` | `[project] homepage` / `repository` | `github.com/Chachamaru127/claude-code-harness` |

### 2. Hooks — the highest-risk location

**File**: `hooks/hooks.json` (every single hook entry — 25+ entries)

Every hook command embeds the `valid_root` shell function which hardcodes two things:

```bash
# (a) plugin.json name assertion
/usr/bin/grep -q '"name"[[:space:]]*:[[:space:]]*"claude-code-harness"' "$r/.claude-plugin/plugin.json"

# (b) marketplace cache fallback paths
"$HOME/.claude/plugins/marketplaces/claude-code-harness-marketplace"
"$HOME/.claude/plugins/cache/claude-code-harness-marketplace/claude-code-harness/"*

# (c) error message
echo "[claude-code-harness] plugin root not found; hook skipped"
```

> **Risk**: If `plugin.json "name"` is changed without updating every hook `valid_root` in the
> same commit, ALL hooks silently skip — guardrails, session monitor, memory bridge, everything.

### 3. Go source

| File | Reference type |
|------|---------------|
| `go/go.mod` | Module path: `github.com/Chachamaru127/claude-code-harness/go` |
| `go/cmd/harness/pre_compact.go:96` | `const configFile = ".claude-code-harness.config.yaml"` |
| `go/cmd/harness/migration_report.go:211,280,301,309,570` | Strings `"claude-code-harness"` in migration report logic |
| `go/internal/guardrail/protected_branch_policy.go:69` | `.claude-code-harness.config.yaml` path |
| `go/internal/session/monitor.go:741,810` | `.claude-code-harness.config.yaml` path |
| `go/internal/session/init.go:192` | Comment: `# [claude-code-harness] セッション初期化` |
| `go/internal/hookhandler/posttooluse_quality_pack.go:37,92,164` | `.claude-code-harness.config.yaml` path |
| `go/internal/hookhandler/userprompt_track_command.go:82,84` | Prefix check `"claude-code-harness:"` |
| All `go/` import paths | Module prefix `github.com/Chachamaru127/claude-code-harness/go/…` |

### 4. Scripts

| File | Reference type |
|------|---------------|
| `scripts/sync-plugin-cache.sh:18,26,44-46` | `grep "claude-code-harness"` + `PLUGIN_NAME` + `MARKETPLACE_NAME` constants |
| `scripts/session-state.sh` / `session-monitor.sh` / `check-codex.sh` / `stop-plans-reminder.sh` / … | `CONFIG_FILE=".claude-code-harness.config.yaml"` |
| `scripts/plans-format-migrate.sh:27` | `.claude-code-harness/backups/` backup dir |
| `scripts/analyze-project.sh:255-256` | `.claude-code-harness-version` file |
| `scripts/ci/check-version-bump.sh` / `check-consistency.sh` | Assorted `claude-code-harness` references |

### 5. Tests

| File | Reference type |
|------|---------------|
| `tests/test-sync-plugin-cache.sh:16-17` | Cache and marketplace directory paths |
| `tests/test-setup-language-rendering.sh:53,54,85,98,110,120,133,145,161` | Config filename + hooks description assertion |
| `tests/test-tool-first-onboarding.sh:81-82` | `/plugin install claude-code-harness@claude-code-harness-marketplace` command |
| `tests/test-release-version-sync.sh:155,170` | `github.com/Chachamaru127/claude-code-harness` in CHANGELOG URLs |
| `tests/test-usage-tracker-quiet.sh:25` | Skill name `"claude-code-harness:memory"` |
| `tests/test-public-plugin-inventory.sh:82` | `plugin details claude-code-harness` |
| `tests/validate-plugin.sh:3,47` | Comment + `CONFIG_FILE` env path |
| `tests/test-named-plans.sh:64,80` | `CONFIG_FILE=…/.claude-code-harness.config.yaml` |
| `tests/test-i18n-*.sh` | Config file schema and example paths |
| `tests/test-plans-status-markers.sh:162` | Config file creation |
| `tests/test-commit-guard.sh:182` | Config template path |

### 6. Templates

| File | Reference type |
|------|---------------|
| `templates/.claude-code-harness.config.yaml.template` | Config template (filename + content header) |
| `templates/.claude-code-harness-version.template` | Version tracking file template |
| `templates/locales/ja/.claude-code-harness.config.yaml.template` | Japanese locale config template |
| `templates/template-registry.json:166-180` | Registry mapping for both templates above |
| `templates/rules/quality-gates.md.template:162` | Config file name mention |
| `templates/hooks/auto-cleanup-hook.sh:9,17` | Config file reference |

### 7. README and docs

- `README.md`: title "Claude Code Harness", install commands referencing `claude-code-harness@claude-code-harness-marketplace`, badges pointing to upstream GitHub, `Chachamaru127` repo links
- `docs/FORK_NOTES.md`: upstream origin documented (intentional — historical reference)
- 18+ other docs files: `Chachamaru127` or `claude-code-harness` in GitHub URLs and narrative text

---

## Phase 1 — What Changes (Safe, Display-Only)

These changes have **zero runtime impact** because they affect only metadata fields and display
text, not names that any code or hook checks at runtime.

| Change | Files touched | Risk |
|--------|--------------|------|
| README title: "Claude Code Harness" → "Company AI Harness" | `README.md` | None |
| README install commands: remove upstream marketplace install, replace with internal note | `README.md` | None |
| README badges: remove upstream GitHub version badge | `README.md` | None |
| `harness.toml [project] description` | `harness.toml` | None |
| `harness.toml [project.author]` name/url → internal | `harness.toml` | None |
| `harness.toml [project] homepage` / `repository` → internal | `harness.toml` | None |
| `plugin.json description` → internal description | `.claude-plugin/plugin.json` | None |
| `plugin.json author` → internal | `.claude-plugin/plugin.json` | None |
| `plugin.json homepage` / `repository` → internal | `.claude-plugin/plugin.json` | None |
| `marketplace.json owner` → internal | `.claude-plugin/marketplace.json` | None |
| `marketplace.json plugins[0].author` / `homepage` → internal | `.claude-plugin/marketplace.json` | None |
| `hooks/hooks.json description` field (top-level string, not hook commands) | `hooks/hooks.json:2` | None |
| `CLAUDE.md`: update "Claude harness" display references if any | `CLAUDE.md` | None |

**Phase 1 does NOT touch**:
- `plugin.json "name"` field
- `marketplace.json "name"` field or `plugins[0].name`
- Any hook command strings in `hooks/hooks.json`
- `harness.toml [project] name`
- Any `.claude-code-harness.config.yaml` filename anywhere
- Any Go source
- Any scripts or tests

---

## What Must NOT Change Yet — Freeze List

These names are load-bearing at runtime. Changing them without a coordinated atomic update
breaks hooks, config loading, or the Go build.

| Name | Why frozen | Unblock condition |
|------|-----------|-------------------|
| `"name": "claude-code-harness"` in `plugin.json` | `valid_root` in every hook greps this exact string | Phase 2: atomic with hooks.json update |
| `"name": "claude-code-harness-marketplace"` in `marketplace.json` | Hook fallback path hardcodes this | Phase 2: atomic with hooks.json update |
| `"plugins[0].name": "claude-code-harness"` in `marketplace.json` | Part of marketplace lookup | Phase 2 |
| `"name": "claude-code-harness"` in `harness.toml` | Generates plugin.json via `harness sync` | Phase 2 |
| `.claude-code-harness.config.yaml` filename | Go source (`pre_compact.go`, `monitor.go`, `guardrail/`) + 10+ scripts hardcode it | Phase 3: needs Go recompile |
| `.claude-code-harness-version` filename | `scripts/analyze-project.sh` reads it | Phase 3 |
| `github.com/Chachamaru127/claude-code-harness/go` module path | All Go import paths depend on it | Phase 4: full module rename |
| `"claude-code-harness:"` skill name prefix in `userprompt_track_command.go:84` | Skill invocation tracking | Phase 2 (with plugin ID rename) |

---

## Risky References — Hook Root Validation

The single highest-risk item is the `valid_root` function embedded verbatim in **every hook
entry** of `hooks/hooks.json`. It performs three checks that encode the upstream plugin ID:

```
(a) grep -q '"name"...: "claude-code-harness"' plugin.json   ← plugin ID assertion
(b) $HOME/.claude/plugins/marketplaces/claude-code-harness-marketplace   ← fallback path
(c) $HOME/.claude/plugins/cache/claude-code-harness-marketplace/claude-code-harness/*  ← fallback
```

**Phase 2 constraint**: Renaming `plugin.json "name"` and `marketplace.json "name"` MUST be done
in a single commit that also updates all `valid_root` patterns in `hooks/hooks.json`. A partial
rename will cause all hooks to silently skip (exit 0) with no error surfaced to the user, which
means guardrails, session monitor, and memory bridge all stop working silently.

The `scripts/sync-plugin-cache.sh:18` also greps for `"claude-code-harness"` and must be updated
atomically with the plugin ID rename.

---

## Proposed Commit Order

| Commit | Message | Scope | Phase |
|--------|---------|-------|-------|
| This commit | `docs: plan internal naming cleanup` | `docs/NAMING_PLAN.md` only | 0 |
| Next | `docs: update display name and internal metadata` | README, harness.toml description/author, plugin.json/marketplace.json description/author/homepage | 1 |
| Later | `chore: rename plugin ID to company-ai-harness` | hooks.json (all valid_root), plugin.json name, marketplace.json name, harness.toml name, sync-plugin-cache.sh, userprompt_track_command.go prefix check | 2 |
| Later | `chore: rename config file to .company-ai-harness.config.yaml` | All Go source (pre_compact, monitor, guardrail), scripts (10+), tests (10+), templates (3 files + registry), recompile bin/ | 3 |
| Later | `chore: rename Go module path` | go.mod, all import paths in go/, recompile bin/ | 4 |

Phase 2, 3, and 4 must each be a single atomic commit. No partial renames.

---

## Validation for This Commit

```bash
git diff --stat
# Expected: only docs/NAMING_PLAN.md added
```
