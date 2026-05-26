# Repository Inventory — Company AI Harness

**Created**: 2026-05-26  
**Branch**: `ai-harness/phase-0-1-cleanup`  
**Purpose**: Structured classification of every top-level path before cleanup. No files were moved or deleted to produce this document.

---

## Classification Key

| Label | Meaning |
|-------|---------|
| `keep` | Active, required for Claude Code runtime — do not touch |
| `modify` | Active but contains upstream branding, Japanese text, or out-of-scope references that need updating |
| `archive` | Already archived under `archive/` — no further action needed |
| `delete later` | Can be removed after validation; not actively used |
| `unknown` | Needs further review before a decision |

---

## Top-Level Files

| Path | Class | Notes |
|------|-------|-------|
| `README.md` | `modify` | Contains upstream Codex/OpenCode/Cursor surface table, Chachamaru marketplace links, `README_ja.md` link, upstream badge URLs. Phase 1 target. |
| `CHANGELOG.md` | `keep` | Active changelog. Contains upstream history — that is intentional; keep as historical record. |
| `CLAUDE.md` | `modify` | Primary harness guide. Contains some upstream-era rules and Japanese rule references; reviewed incrementally per phase. |
| `CONTRIBUTING.md` | `modify` | Points to upstream GitHub Issues and contributor flow. Needs internal fork language. |
| `IMPLEMENTATION_GUIDE.md` | `keep` | Accurate Go-first architecture guide. No upstream-only content. |
| `LICENSE.md` | `keep` | MIT upstream attribution — must not be removed. |
| `LICENSE.ja.md` | `keep` | Japanese MIT license — must not be removed. |
| `NOTICE.md` | `keep` | Upstream attribution notice — must not be removed. |
| `VERSION` | `keep` | Single source for version string. Keep in sync with `plugin.json` and `harness.toml`. |
| `harness.toml` | `keep` | Harness v4 config SSOT. Used by `bin/harness sync` to regenerate `settings.json`. |
| `go.work` | `keep` | Go workspace root — required for `go/` module. |
| `spec.md` | `keep` | Product contract for V2 work (Phase 72–76). Active SSOT. |
| `.claude-code-harness.config.yaml` | `keep` | User-level config schema. Active. |
| `claude-code-harness.config.example.json` | `keep` | Config example for onboarding. |
| `claude-code-harness.config.schema.json` | `keep` | JSON Schema for config validation. |
| `.gitattributes` | `keep` | Line-ending and diff attributes. |
| `.gitignore` | `keep` | Required. |

---

## Top-Level Directories

### `go/` — Go Native Engine
**Class: `keep`**

Core runtime: hook handler, session monitor, guardrail engine (R01–R13), breezing orchestration.

| Subpath | Class | Notes |
|---------|-------|-------|
| `go/cmd/harness/` | `keep` | Binary entrypoint |
| `go/internal/` | `keep` | Hook handlers, session, CI, guardrail, harnessmem, lifecycle, state |
| `go/pkg/` | `keep` | `config`, `hookproto` packages |
| `go/SPEC.md` | `keep` | Go engine spec (Phase 35 era, Japanese) — historical reference |
| `go/DESIGN.md` | `keep` | Go engine design doc |
| `go/Makefile` | `keep` | Build targets |
| `go/go.mod`, `go/go.sum` | `keep` | Module files |
| `go/test-e2e.sh` | `keep` | End-to-end test script |

**Risk**: Do not modify without running `go test ./...` and `./tests/validate-plugin.sh`.

---

### `bin/` — Pre-built Binaries
**Class: `keep`**

| File | Class | Notes |
|------|-------|-------|
| `bin/harness` | `keep` | Default binary (symlink or macOS ARM) — must exist for hooks to function |
| `bin/harness-darwin-arm64` | `keep` | macOS ARM build |
| `bin/harness-darwin-amd64` | `keep` | macOS Intel build |
| `bin/harness-linux-amd64` | `keep` | Linux CI build |
| `bin/harness-windows-amd64.exe` | `keep` | Windows build |

**Risk**: `bin/harness` is referenced in `hooks.json`, `monitors.json`, and `scripts/`. Deleting or renaming it breaks the entire hook pipeline.

---

### `.claude-plugin/` — Plugin Manifest
**Class: `keep`**

| File | Class | Notes |
|------|-------|-------|
| `.claude-plugin/plugin.json` | `keep` | Plugin metadata, skills path, version |
| `.claude-plugin/hooks.json` | `keep` | Hook registrations (PreToolUse, PostToolUse, SessionStart, etc.) |
| `.claude-plugin/settings.json` | `keep` | Generated from `harness.toml` via `bin/harness sync`; deny-listed by self-protection rule |
| `.claude-plugin/marketplace.json` | `modify` | Contains upstream marketplace metadata. Needs internal fork adaptation or removal. |

**Risk**: `settings.json` and `hooks.json` are the security perimeter. Deny rules must not shrink.

---

### `hooks/` — Hook Entry Shims
**Class: `keep`**

| File | Class | Notes |
|------|-------|-------|
| `hooks/hooks.json` | `keep` | Mirror/shim of `.claude-plugin/hooks.json` for legacy path resolution |
| `hooks/BEST_PRACTICES.md` | `keep` | Hook best practices reference |

---

### `skills/` — Slash Commands (Plugin Skills)
**Class: `keep` / `modify`**

All skill directories are active Claude Code plugin skills. Several contain Japanese `description` fields or upstream-specific trigger text that may need updating in Phase 1.

| Skill | Class | Notes |
|-------|-------|-------|
| `skills/harness-work/` | `keep` | Core implementation skill |
| `skills/harness-plan/` | `keep` | Planning skill |
| `skills/harness-review/` | `keep` | Review skill |
| `skills/harness-release/` | `keep` | Release skill |
| `skills/harness-setup/` | `keep` | Setup skill |
| `skills/harness-accept/` | `keep` | Plan acceptance skill |
| `skills/harness-plan-brief/` | `keep` | Plan brief HTML skill |
| `skills/harness-progress/` | `keep` | Progress check skill |
| `skills/harness-sync/` | `keep` | Sync/alignment skill |
| `skills/harness-loop/` | `keep` | Loop orchestration skill |
| `skills/breezing/` | `keep` | Parallel agent team skill |
| `skills/memory/` | `keep` | SSOT/memory management skill |
| `skills/session/` | `keep` | Session management skill |
| `skills/session-init/` | `keep` | Session init skill |
| `skills/session-control/` | `keep` | Session control skill |
| `skills/session-memory/` | `keep` | Session memory skill |
| `skills/session-state/` | `keep` | Session state skill |
| `skills/ci/` | `keep` | CI skill |
| `skills/maintenance/` | `keep` | Maintenance skill |
| `skills/cc-update-review/` | `keep` | CC update review skill |
| `skills/auth/` | `keep` | Auth helper skill |
| `skills/agent-browser/` | `keep` | Browser agent skill |
| `skills/crud/` | `keep` | CRUD scaffold skill |
| `skills/deploy/` | `keep` | Deployment skill |
| `skills/ui/` | `keep` | UI skill |
| `skills/principles/` | `keep` | Principles reference skill |
| `skills/routing-rules.md` | `keep` | Routing reference (flat file, not a skill dir) |
| `skills/gogcli-ops/` | `unknown` | Go CLI ops — verify if in use |
| `skills/generate-slide/` | `unknown` | Slide generation — verify if relevant for internal use |
| `skills/generate-video/` | `unknown` | Video generation — verify if relevant for internal use |
| `skills/notebookLM/` | `unknown` | NotebookLM integration — verify if relevant |
| `skills/vibecoder-guide/` | `modify` | Contains upstream vibecoder branding; review for internal relevance |
| `skills/workflow-guide/` | `keep` | Workflow guidance |

**Phase 1 action**: Audit all SKILL.md frontmatter `description` fields for Japanese text; translate to English per language policy.

---

### `agents/` — Agent Role Definitions
**Class: `keep` / `modify`**

| File | Class | Notes |
|------|-------|-------|
| `agents/worker.md` | `keep` | Worker contract (v4.3.0+, self-review rules) |
| `agents/reviewer.md` | `keep` | Reviewer contract |
| `agents/advisor.md` | `keep` | Advisor contract |
| `agents/scaffolder.md` | `keep` | Scaffolder contract |

All four contain Japanese-language sections (Phase 44 audit rules). These are valid operational rules — retain and translate incrementally in Phase 2.

---

### `scripts/` — Shell Scripts
**Class: `keep` / `modify`**

Active hook handlers and runtime utilities. Over 100 scripts total.

| Subpath | Class | Notes |
|---------|-------|-------|
| `scripts/hook-handlers/` | `keep` | Hook event handlers (notification, task-completed, session, etc.) — directly wired to `hooks.json` |
| `scripts/hooks/` | `keep` | Hook shim scripts |
| `scripts/lib/` | `keep` | Shared shell libraries (terminal-notify, etc.) |
| `scripts/ci/` | `keep` | CI helper scripts including `check-consistency.sh` |
| `scripts/i18n/` | `keep` | i18n locale utilities |
| `scripts/evidence/` | `keep` | Evidence collection scripts |
| `scripts/sandbox-test/` | `keep` | Sandbox test scripts |
| `scripts/pretooluse-guard.sh` | `keep` | Guard rail handler |
| `scripts/sync-version.sh` | `keep` | Version sync (bump for releases) |
| `scripts/validate-release-notes.sh` | `keep` | Release notes validator |
| `scripts/generate-skill-manifest.sh` | `keep` | Skill manifest generator |
| `scripts/sync-skill-mirrors.sh` | `modify` | Syncs skills to Codex/OpenCode mirrors — no-op for v1 but not harmful; review in Phase 1 |
| `scripts/check-codex.sh` | `modify` | Codex availability check — not used in v1; review for removal |
| `scripts/emit-agent-trace.js` | `keep` | Agent telemetry |
| `scripts/generate-agent-telemetry.js` | `keep` | Telemetry generation |
| `scripts/record-usage.js` | `keep` | Usage recording |
| `scripts/generate-sprint-contract.js` | `keep` | Sprint contract generation |
| `scripts/session-*.sh` | `keep` | Session lifecycle scripts (15+ files) |
| `scripts/plan-*.sh` | `keep` | Plan management scripts |
| `scripts/posttooluse-*.sh` | `keep` | PostToolUse handlers |
| `scripts/render-html.sh` | `keep` | HTML render for cognitive-load surfaces |
| `scripts/redact-by-*.sh` | `keep` | PII redaction (Layer 2) |
| `scripts/cross-project-audit-log.sh` | `keep` | Cross-project audit logging |
| `scripts/load-cross-project-groups.sh` | `keep` | Cross-project group loader |
| `scripts/final-scan-redaction.py` | `keep` | Layer 3 redaction |

---

### `tests/` — Validation Tests
**Class: `keep` / `modify`**

| Subpath | Class | Notes |
|---------|-------|-------|
| `tests/validate-plugin.sh` | `keep` | Primary CI gate — never break |
| `tests/validate-skills.sh` | `keep` | Skills validation |
| `tests/validate-plugin-v3.sh` | `delete later` | v3-era validator; superseded by v4 version |
| `tests/unit/` | `keep` | Unit tests |
| `tests/integration/` | `keep` | Integration tests |
| `tests/lib/` | `keep` | Test libraries |
| `tests/fixtures/` | `keep` | Test fixtures |
| `tests/_archived/` | `archive` | Already archived test files |
| `tests/test-codex-*.sh` | `archive` | Codex-specific tests; already archived under `archive/tests/` — these copies may be residual duplicates — verify |
| All other `tests/test-*.sh` | `keep` | Claude Code runtime tests |
| `tests/test-github-copilot-cli-candidate.sh` | `unknown` | GitHub Copilot CLI candidate test; verify relevance |
| `tests/test-antigravity-unknown-boundary.sh` | `unknown` | Antigravity boundary test; verify relevance |

**Risk**: `tests/validate-plugin.sh` is the canary. Run it before and after any cleanup.

---

### `docs/` — Documentation
**Class: `keep` / `modify` / `delete later`**

#### Core active docs (keep)
| Path | Notes |
|------|-------|
| `docs/PROJECT_SCOPE.md` | v1 scope SSOT — authoritative |
| `docs/FORK_NOTES.md` | Fork assumptions and archive rationale |
| `docs/CLAUDE-feature-table.md` | Feature table (CC version tracking) |
| `docs/CLAUDE-commands.md` | Command reference |
| `docs/CLAUDE-skill-catalog.md` | Skill catalog |
| `docs/CLAUDE_CODE_COMPATIBILITY.md` | CC version compatibility |
| `docs/long-running-harness.md` | Long-running task procedures |
| `docs/ARCHITECTURE.md` | Architecture overview |
| `docs/architecture/` | Architecture subdocs |
| `docs/onboarding/` | Onboarding docs (install, migration) |
| `docs/cognitive-load-surfaces.md` | Plan Brief/Progress/Accept HTML surfaces |
| `docs/cross-project-safety.md` | Cross-project safety policy |
| `docs/harness-mem-companion-contract.md` | harness-mem companion contract |
| `docs/harness-review-operating-model.md` | Review operating model |
| `docs/MEMORY_POLICY.md` | Memory policy |
| `docs/MIGRATION-v4.md` | v4 migration guide |
| `docs/sandbox-allowlist-recipe.md` | Sandbox allowlist SSOT |
| `docs/session-id-env-policy.md` | Session ID env policy |
| `docs/skill-orchestration-design-contract.md` | Skill orchestration contract |
| `docs/skill-telemetry-policy.md` | Skill telemetry policy |
| `docs/effort-level-policy.md` | Effort level policy |
| `docs/output-governance.md` | Output governance |
| `docs/plans/` | Plans docs (named-plans, briefs-manifest) |
| `docs/bootstrap-routing-contract.md` | Bootstrap routing contract |
| `docs/i18n-language-contract.md` | Language policy |
| `docs/upstream-update-snapshot-*.md` | CC version snapshots (10 files) — historical reference |

#### Docs referencing archived surfaces — ARCHIVED 2026-05-26 (AIH-011)
| Path | Status | Notes |
|------|--------|-------|
| `docs/CURSOR_INTEGRATION.md` | `archive` | Moved to `archive/non-claude/docs/` |
| `docs/codex-mcp-diagnostics.md` | `archive` | Moved to `archive/non-claude/docs/` |
| `docs/codex-permission-profiles-policy.md` | `archive` | Moved to `archive/non-claude/docs/` |
| `docs/codex-plugin-workflows-policy.md` | `archive` | Moved to `archive/non-claude/docs/` |
| `docs/codex-provider-setup-policy.md` | `archive` | Moved to `archive/non-claude/docs/` |
| `docs/codex-sandbox-execution-policy.md` | `archive` | Moved to `archive/non-claude/docs/` |
| `docs/hardening-parity.md` | `modify` | Kept active — Claude Code guardrail policy; Codex comparison sections are historical |
| `docs/distribution-scope.md` | `modify` | Distribution/marketplace scope; needs internal fork review |
| `docs/cc-2.1.99-2.1.110-impact.md` | `keep` | Upstream phase impact analysis (Japanese-heavy, historical reference) |
| `docs/cc-2.1.99-2.1.111-impact.md` | `keep` | Upstream phase impact analysis |

#### Marketing/social docs — ARCHIVED 2026-05-26 (AIH-011)
| Path | Status | Notes |
|------|--------|-------|
| `docs/social/` | `archive` | Moved to `archive/non-claude/docs/social/` |
| `docs/positioning-notes.md` | `archive` | Moved to `archive/non-claude/docs/` |
| `docs/release-copy-phase21.md` | `archive` | Moved to `archive/non-claude/docs/` |
| `docs/issue-105-response-draft.md` | `archive` | Moved to `archive/non-claude/docs/` |
| `docs/content-layout.md` | `modify` | Content layout for public README — review |
| `docs/claims-audit.md` | `unknown` | Support claims audit — review per phase |
| `docs/github-harness-plugin-benchmark.md` | `unknown` | GitHub plugin benchmark — review per phase |
| `docs/benchmark-rubric.md` | `unknown` | Benchmark rubric — review per phase |

#### Research/evidence docs (unknown — review per phase)
| Path | Notes |
|------|-------|
| `docs/research/` | Research notes including antigravity, Cursor, GitHub Copilot CLI adapter |
| `docs/evidence/` | Work evidence files |
| `docs/examples/` | Hook example JSON |

#### HTML artifacts (delete later)
| Path | Notes |
|------|-------|
| `docs/phase-73-*.html` | Phase 73 HTML artifacts — not needed for v1 operation |
| `docs/readme-visual-patterns.html` | Visual pattern HTML — not needed for v1 operation |

---

### `archive/` — Archived Non-Claude Surfaces
**Class: `archive`**

Reorganized on 2026-05-26 (AIH-011): all non-Claude runtime surfaces consolidated under `archive/non-claude/`.

| Path | Notes |
|------|-------|
| `archive/non-claude/codex/` | Codex CLI distribution (moved from `archive/codex/`) |
| `archive/non-claude/codex-plugin/` | Codex CLI plugin manifest (moved from `archive/codex-plugin/`) |
| `archive/non-claude/opencode/` | OpenCode distribution (moved from `archive/opencode/`) |
| `archive/non-claude/cursor/` | Cursor IDE config and rules (moved from `archive/cursor/`) |
| `archive/non-claude/skills/` | Cursor-specific skills — `cc-cursor-cc` (moved from `archive/skills/`) |
| `archive/non-claude/skills-codex/` | Codex mirror skills (moved from `archive/skills-codex/`) |
| `archive/non-claude/scripts/` | Codex companion and helper scripts (moved from `archive/scripts/`) |
| `archive/non-claude/tests/` | Codex/OpenCode test files (moved from `archive/tests/`) |
| `archive/non-claude/workflows/` | OpenCode workflow YAML (moved from `archive/workflows/`) |
| `archive/non-claude/docs/` | Docs covering non-Claude host surfaces only (archived 2026-05-26) |
| `archive/Plans.md` | Upstream project tracker (historical reference) |
| `archive/README.md` | Archive index |
| `archive/README_ja.md` | Upstream Japanese README |

### `archive/non-claude/docs/` — Archived Non-Claude Documentation
**Class: `archive`** — Archived 2026-05-26 as part of AIH-011

| Path | Original path | Reason |
|------|---------------|--------|
| `codex-mcp-diagnostics.md` | `docs/codex-mcp-diagnostics.md` | Codex MCP only |
| `codex-permission-profiles-policy.md` | `docs/codex-permission-profiles-policy.md` | Codex only |
| `codex-plugin-workflows-policy.md` | `docs/codex-plugin-workflows-policy.md` | Codex only |
| `codex-provider-setup-policy.md` | `docs/codex-provider-setup-policy.md` | Codex only |
| `codex-sandbox-execution-policy.md` | `docs/codex-sandbox-execution-policy.md` | Codex only |
| `CURSOR_INTEGRATION.md` | `docs/CURSOR_INTEGRATION.md` | Cursor only |
| `hardening-parity.md` | `docs/hardening-parity.md` | Claude vs Codex comparison — Codex archived |
| `social/` | `docs/social/` | Upstream social/marketing content |
| `positioning-notes.md` | `docs/positioning-notes.md` | Upstream product positioning |
| `release-copy-phase21.md` | `docs/release-copy-phase21.md` | Upstream release copy |
| `issue-105-response-draft.md` | `docs/issue-105-response-draft.md` | Draft response to upstream issue #105 |

**Policy**: Items here are frozen. Do not edit. Do not reference from active code.

---

### `templates/` — Project Templates
**Class: `keep` / `modify`**

| Path | Class | Notes |
|------|-------|-------|
| `templates/claude/` | `keep` | `settings.local.json.template`, `settings.security.json.template` |
| `templates/hooks/` | `keep` | Hook templates |
| `templates/html/` | `keep` | Plan brief / progress / accept HTML templates |
| `templates/memory/` | `keep` | Memory templates |
| `templates/modes/` | `keep` | Mode JSON templates (includes Japanese mode `harness--ja.json`) |
| `templates/rules/` | `keep` | Rule templates for new projects |
| `templates/state/` | `keep` | State config templates |
| `templates/CLAUDE.md.template` | `keep` | Project CLAUDE.md template |
| `templates/AGENTS.md.template` | `keep` | AGENTS.md template |
| `templates/Plans.md.template` | `keep` | Plans.md template |
| `templates/sandbox-settings.json.template` | `keep` | Sandbox settings SSOT |
| `templates/cursor/` | `modify` | Cursor command templates — v1 out of scope; safe to leave but not actively used |
| `templates/opencode/` | `modify` | OpenCode command templates — v1 out of scope; safe to leave but not actively used |
| `templates/template-registry.json` | `keep` | Template registry |

---

### `output-styles/` — Output Style Definitions
**Class: `modify`**

| File | Class | Notes |
|------|-------|-------|
| `output-styles/harness-ops.md` | `modify` | `description` field is Japanese — translate to English per language policy |

---

### `monitors/` — Monitor Definitions
**Class: `keep`**

| File | Notes |
|------|-------|
| `monitors/monitors.json` | Session monitor definition — active; references `bin/harness` |

---

### `.github/` — GitHub Config
**Class: `keep` / `modify`**

| Path | Class | Notes |
|------|-------|-------|
| `.github/workflows/validate-plugin.yml` | `keep` | Primary CI gate |
| `.github/workflows/release.yml` | `keep` | Release workflow |
| `.github/workflows/smoke-install.yml` | `keep` | Smoke install test |
| `.github/workflows/benchmark.yml` | `keep` | Benchmark workflow |
| `.github/workflows/codeql.yml` | `keep` | CodeQL security scan |
| `.github/workflows/scorecard.yml` | `keep` | OpenSSF Scorecard |
| `.github/workflows/opencode-compat.yml` | `modify` | Checks OpenCode mirror parity — not applicable for v1; disable or remove paths referencing archived surfaces |
| `.github/dependabot.yml` | `keep` | Dependency updates |
| `.github/actions/` | `keep` | Reusable GitHub Actions |

---

### `.claude/` — Claude Runtime State
**Class: `keep` / `modify`**

| Path | Class | Notes |
|------|-------|-------|
| `.claude/rules/` (23 files) | `keep` | Operational rules loaded into Claude context — all active |
| `.claude/memory/` | `keep` | SSOT memory files (decisions.md, patterns.md — gitignored per policy) |
| `.claude/output-styles/` | `keep` | Output style configs |
| `.claude/state/` | `keep` | Session state |
| `pre-commit` hook | `keep` | Git pre-commit hook |

---

### `.githooks/` — Git Hooks
**Class: `keep`**

Pre-commit and other git hooks installed via `scripts/install-git-hooks.sh`.

---

### `assets/` — Visual Assets
**Class: `modify`**

| Path | Class | Notes |
|------|-------|-------|
| `assets/readme-visuals-en/` | `keep` | English SVG visuals for README |
| `assets/readme-visuals-ja/` | `modify` | Japanese README visuals — not needed for v1 English README; safe to keep but not referenced |

---

### `benchmarks/` — Benchmarks
**Class: `unknown`**

| Path | Notes |
|------|-------|
| `benchmarks/breezing-bench/` | Breezing performance benchmark |
| `benchmarks/breezing-codex-test/` | Breezing Codex test — Codex surface; archived surface interaction |

Breezing is an active skill. `breezing-bench` may still be relevant for internal performance testing. `breezing-codex-test` references an archived surface.

---

## Plugin Install Files

The following files are directly involved in installing/loading the plugin and must not be deleted before validating the install path:

| File | Why critical |
|------|-------------|
| `.claude-plugin/plugin.json` | Plugin entry point — CC reads this first |
| `.claude-plugin/hooks.json` | Hook registrations |
| `.claude-plugin/settings.json` | Permissions and deny rules |
| `hooks/hooks.json` | Fallback hook path |
| `bin/harness` | Called by every hook handler |
| `skills/` | All skills loaded from plugin.json |
| `output-styles/harness-ops.md` | Output style referenced in plugin.json |
| `monitors/monitors.json` | Session monitor loaded at startup |

---

## Known Risks

| Risk | Severity | Mitigation |
|------|----------|-----------|
| `bin/harness` deleted or renamed | Critical | All hooks fail silently; no guardrails |
| `settings.json` deny rules reduced | Critical | Security perimeter weakened; self-protection blocks direct edit |
| `tests/validate-plugin.sh` broken | High | CI gate becomes blind; run before every cleanup step |
| Japanese text in skill descriptions | Medium | Auto-loading may misfire; Phase 1 audit required |
| `opencode-compat.yml` workflow still checks archived paths | Low | False CI failures if archived paths change; disable `paths:` filter or remove |
| `scripts/sync-skill-mirrors.sh` still runs | Low | Harmless no-op if mirror dirs are absent, but could error on missing paths |
| `archive/` material referenced from active code | Medium | Breaks at runtime; run `scripts/check-residue.sh` to detect |
| Upstream badges in `README.md` pointing to external repo | Low | Cosmetic; users who clone see upstream release badges |

---

## Proposed Cleanup Order

| Phase | Scope | Actions |
|-------|-------|---------|
| **Phase 1** | Skills language audit | Translate Japanese `description` fields in SKILL.md frontmatter to English. Audit `skills/vibecoder-guide/`, `skills/gogcli-ops/`, `skills/generate-slide/`, `skills/generate-video/`, `skills/notebookLM/`. |
| **Phase 2** | Agent language audit | Translate Japanese sections in `agents/*.md`. Verify Claude Code-specific correctness. |
| **Phase 3** | README and CLAUDE.md cleanup | Update `README.md` to remove/update upstream marketplace/Codex/OpenCode surface table. Update `CONTRIBUTING.md`. Remove/update Codex references in `CLAUDE.md`. |
| **Phase 4** | Docs cleanup | Move `docs/social/`, `docs/codex-*.md`, `docs/CURSOR_INTEGRATION.md`, `docs/*.html` to `archive/docs/`. Update or remove `docs/distribution-scope.md`, `docs/positioning-notes.md`. |
| **Phase 5** | GitHub workflow cleanup | Disable or remove `opencode-compat.yml`. Review whether `benchmark.yml` and `scorecard.yml` require external upstream access. |
| **Phase 6** | Templates cleanup | Review `templates/cursor/` and `templates/opencode/` for removal. Translate `output-styles/harness-ops.md` description. |
| **Phase 7** | Scripts cleanup | Remove or disable `scripts/check-codex.sh`, `scripts/sync-skill-mirrors.sh`. Audit any remaining Codex references in scripts. |
| **Phase 8** | Tests cleanup | Remove `tests/validate-plugin-v3.sh`. Verify `tests/test-github-copilot-cli-candidate.sh` and `tests/test-antigravity-unknown-boundary.sh` are safe to remove. |
| **Phase 9** | Benchmarks | Decide on `benchmarks/breezing-codex-test/` — remove Codex-specific parts or archive. |
| **Final** | Validation | Run `./tests/validate-plugin.sh`, `./scripts/ci/check-consistency.sh`, `./scripts/check-residue.sh`. Confirm `git diff --stat` shows only intended changes. |

---

## Validation Checklist

Before and after each cleanup phase:

```bash
# Structural validation
./tests/validate-plugin.sh

# Consistency check
./scripts/ci/check-consistency.sh

# Migration residue check
./scripts/check-residue.sh

# No unintended runtime changes
git diff --stat
```

---

*Generated by AIH-010 inventory task. Classification is based on `docs/PROJECT_SCOPE.md`, `docs/FORK_NOTES.md`, and direct inspection of all top-level paths.*
