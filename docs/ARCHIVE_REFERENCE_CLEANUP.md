# Archive Reference Cleanup — v1 Audit

This document records the audit and cleanup of active references to archived non-Claude runtime
surfaces (`archive/non-claude/`). It was created as part of the Phase 0.1 cleanup to make
Company AI Harness Claude Code-only for v1.

## Summary

| Category | Files Audited | Issues Found | Actions Taken |
|----------|--------------|--------------|---------------|
| CI workflows | 2 | 2 | 1 removed, 1 cleaned |
| Active scripts | 2 | 4 | Removed Codex mirror checks, CURSOR link checks |
| Tests | 8+ | 6 | Removed/updated stale checks |
| Go runtime | 2 | 1 | Removed Codex/OpenCode migration detection |
| Config | 1 | 1 | Removed codex mode |
| Docs | 1 | 1 | Rewrote for Claude-only |

---

## Audit Table

### CI Workflows

| File | Surface(s) | Type | Action |
|------|-----------|------|--------|
| `.github/workflows/opencode-compat.yml` | OpenCode, Codex | ci-dep | **Removed** — entire workflow validated non-Claude mirror sync |
| `.github/workflows/validate-plugin.yml` (lines 66–108) | Codex | ci-dep | **Cleaned** — removed `npm install @openai/codex`, Node.js setup, and Codex adapter smoke test steps |

### Scripts

| File | Surface(s) | Type | Action |
|------|-----------|------|--------|
| `scripts/ci/check-consistency.sh` | Codex, OpenCode, Cursor | ci-dep | **Cleaned** — removed breezing Codex mirror check; removed CURSOR_INTEGRATION.md checks; removed README_ja.md checks (file deleted in fork); removed positioning-notes.md check (in archive only) |
| `tests/test-shell-lint.sh` | Codex, OpenCode | test-dep | **Cleaned** — removed non-existent `scripts/setup-codex.sh` and `scripts/setup-opencode.sh` from shellcheck targets |

### Tests

| File | Surface(s) | Type | Action |
|------|-----------|------|--------|
| `tests/test-support-claim-wording.sh` | Cursor | test-dep | **Cleaned** — removed `docs/CURSOR_INTEGRATION.md` from PUBLIC_FILES (file was already removed) |
| `tests/test-release-preflight-adapter-gates.sh` | OpenCode | test-dep | **Cleaned** — removed checks requiring `opencode-compat.yml` (workflow deleted) |
| `tests/test-existing-user-migration.sh` | Codex, OpenCode | test-dep | **Cleaned** — removed assertions for Codex/OpenCode strings from migration doc |
| `tests/test-antigravity-unknown-boundary.sh` | Antigravity | docs-guard | **Kept** — enforces `future/unsupported` label on research doc |
| `tests/test-github-copilot-cli-candidate.sh` | Copilot | docs-guard | **Kept** — enforces `candidate` label on research doc |
| `tests/test-distribution-archive.sh` | Codex, OpenCode, Cursor | dist-guard | **Kept** — correctly forbids archived prefixes from distribution archives |
| `tests/test-hokage-spin-off-readiness.sh` | Codex, OpenCode | docs-guard | **Kept as historical** — validates historical research doc content; no longer runs in CI (parent workflow removed) |
| `tests/test-named-plans.sh` | Codex | archive-dep | **Kept** — sources `archive/non-claude/scripts/codex-loop.sh` which EXISTS; tests Plans.md protocol behavior |
| `tests/test-plans-status-markers.sh` | Codex | archive-dep | **Kept** — sources `archive/non-claude/scripts/codex-loop.sh` which EXISTS; tests cc: status marker protocol |

### Go Runtime

| File | Surface(s) | Type | Action |
|------|-----------|------|--------|
| `go/cmd/harness/migration_report.go` | Codex, OpenCode | runtime-dep | **Cleaned** — removed Codex home scanning, OpenCode skill symlink detection, and associated helper functions |
| `go/cmd/harness/migration_report_test.go` | Codex, OpenCode | test-dep | **Cleaned** — removed Codex/OpenCode fixture setup and assertions |

### Config

| File | Surface(s) | Type | Action |
|------|-----------|------|--------|
| `.claude-code-harness.config.yaml` | Codex | stale-claim | **Cleaned** — removed `mode: codex`, `codex: {enabled}` block, `codex_model: gpt-5.4` |

### Docs

| File | Surface(s) | Type | Action |
|------|-----------|------|--------|
| `docs/onboarding/migration.md` | Codex, OpenCode | stale-claim | **Rewritten** — Claude Code-only v1 migration guide; archived surface note added |
| `docs/CURSOR_INTEGRATION.md` | Cursor | docs-only | **Already removed** (file was gone before this audit) |
| `CHANGELOG.md` | All | historical | **Kept** — changelog preserves full history including pre-fork upstream work |
| `docs/research/` (cursor, copilot, antigravity docs) | Multiple | historical-research | **Kept** — research docs with `candidate`/`future/unsupported` labels; guard tests verify these labels |
| `.claude/rules/codex-cli-only.md` | Codex | rule-doc | **Kept** — documents why Codex MCP is blocked; history in rules is appropriate |
| `.claude/memory/archive/` | All | archived-plans | **Kept** — historical plan archives; not active surfaces |

---

## Deferred Items

These items were identified but deferred for future cleanup phases:

| Item | Reason | Future Action |
|------|--------|--------------|
| `tests/test-named-plans.sh` archive dependency | `archive/non-claude/scripts/codex-loop.sh` is preserved; tests pass. Refactoring to use Go binary would be cleaner. | Extract Plans.md parsing functions to an active `scripts/lib/plans-status.sh` |
| `tests/test-plans-status-markers.sh` archive dependency | Same as above | Same as above |
| `scripts/ci/check-consistency.sh` — cursor template check | `templates/cursor/` still exists at active path | Decide whether cursor templates serve Claude Code users; if not, archive |
| `scripts/release-preflight.sh` — adapter gate logic | Functions exist but are only triggered when archived mirror dirs exist; safe for now | Remove adapter gate logic in a later phase |
| `scripts/lib/codex-worker-common.sh` | Active path, Codex-specific content | Archive or repurpose if worker patterns are reused |
| `agents/worker.md` — Codex references | Historical Codex companion references in worker prompts | Audit and clean agent prompts in a dedicated phase |

---

## Validation Checklist

After cleanup, the following validations were performed:

- [x] No active CI workflow depends on `archive/non-claude/`
- [x] No active test references non-existent script paths
- [x] `go/cmd/harness/migration_report.go` compiles without Codex/OpenCode symbols
- [x] `.claude-code-harness.config.yaml` no longer claims Codex mode
- [x] `docs/onboarding/migration.md` no longer claims Codex/OpenCode support
- [x] `archive/non-claude/README.md` created with archive status disclaimer
- [ ] `go test ./...` — requires Go toolchain (run in CI)
- [ ] `./tests/validate-plugin.sh` — run locally when possible
- [ ] `bash scripts/ci/check-consistency.sh` — run locally when possible
