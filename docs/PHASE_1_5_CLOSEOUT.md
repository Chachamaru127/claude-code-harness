# Phase 1.5 Closeout — Fork Cleanup Validation

**Date**: 2026-05-26  
**Branch**: `ai-harness/phase-0-1-cleanup`  
**Verdict**: GREEN — Phase 2 safety hardening may begin

---

## Commands Run

| # | Command | Result |
|---|---------|--------|
| 1 | `git status --short` | clean |
| 2 | `python3 -m json.tool .claude-plugin/plugin.json` | valid |
| 3 | `python3 -m json.tool hooks/hooks.json` | valid |
| 4 | `python3 -m json.tool .claude-plugin/hooks.json` | valid |
| 5 | `go test ./go/...` | PASS (after 1 test fix; see below) |
| 6 | `go build -o bin/harness ./go/cmd/harness` | PASS |
| 7 | `./bin/harness version` | `dev (Hokage)` |
| 8 | `./tests/validate-plugin.sh` | 83/83 PASS |
| 9 | `./tests/test-distribution-archive.sh` | OK |
| 10 | `./scripts/ci/check-consistency.sh` | all 14 checks PASS |
| 11 | `git diff --check` | clean (no whitespace issues) |

---

## Pass/Fail Table

| Check | Status | Notes |
|-------|--------|-------|
| plugin.json valid JSON | ✅ PASS | name: company-ai-harness, v4.12.3 |
| hooks/hooks.json valid JSON | ✅ PASS | |
| .claude-plugin/hooks.json valid JSON | ✅ PASS | synced from hooks/ |
| Go test suite | ✅ PASS | Fixed stale test (see below) |
| Go build | ✅ PASS | bin/harness builds cleanly |
| bin/harness version | ✅ PASS | `dev (Hokage)` |
| validate-plugin.sh (83 checks) | ✅ PASS | 0 failures, 0 warnings |
| distribution archive | ✅ PASS | |
| check-consistency.sh (14 checks) | ✅ PASS | 0 errors |
| whitespace check | ✅ PASS | |
| No active codex/opencode/cursor/copilot dep | ✅ PASS | see audit below |
| No active CI dep on archived runtimes | ✅ PASS | archived surfaces confirmed absent |
| Hooks don't reference archived paths | ✅ PASS | hooks delegate only to bin/harness |
| README: non-Claude surfaces marked archived | ✅ PASS | §"What v1 Does Not Support" |
| Japanese text scope | ✅ PASS | only in internal/historical docs |

---

## Test Fix Applied

**`go/cmd/harness/sync_test.go` — `TestSync_GeneratesPluginJSON`**

The sync engine was updated (prior to this branch) to emit `author` as
`{"name": "..."}` object per CC plugin validator contract.  
The test still expected a plain `"Chachamaru"` string, causing:

```
sync_test.go:125: plugin.json author = map[name:Chachamaru], want Chachamaru
```

Fix: updated assertion to expect `map[string]interface{}{"name": "Chachamaru"}`.
The implementation comment (`// CC plugin validator expects author as object, not string`)
confirms the object form is intentional.

---

## Active-Path Audit

### Archived runtime references in active code

Three active scripts hold directory roots for archived runtimes:

| Script | Reference | Risk |
|--------|-----------|------|
| `scripts/generate-skill-manifest.sh:43` | `skills-codex`, `codex/.codex/skills`, `opencode/skills` | Dead — dirs absent; silently skipped |
| `scripts/ci/check-consistency.sh:370` | `CODEX_MIRROR`, `OPENCODE_MIRROR` | Gated on `[ -d ... ]`; no-op when dirs absent |
| `scripts/ci/check-consistency.sh:466` | `validate-opencode.js` call | Gated on `OPENCODE_MIRROR` existing; skipped |

None produce active runtime calls. `check-consistency.sh §12` explicitly asserts
that `codex/`, `opencode/`, `.cursor/`, `.codex-plugin/` are **absent** at root level.

### Hooks

No hook references archived runtime paths. All hooks delegate to `bin/harness`.

### README

`README.md §"What v1 Does Not Support"` lists Codex CLI, OpenCode, Cursor, GitHub
Copilot CLI, and Antigravity as archived. Archived surfaces live under `archive/`.
`check-consistency.sh §12` validates this claim on every CI run.

### Japanese text scope

Japanese text remains in: `go/SPEC.md`, `go/DESIGN.md` (internal technical spec),
`LICENSE.ja.md` (localized license), `output-styles/`, `tests/README.md`,
`benchmarks/` fixtures, `.claude/rules/`, `docs/` — all internal, operational, or
historical. No Japanese in user-facing public docs (README, CHANGELOG entries for
public releases).

---

## Remaining Known Issues

None blocking Phase 2. Two cosmetic items for future cleanup:

1. `scripts/generate-skill-manifest.sh:43` roots array still contains dead paths
   (`skills-codex`, `codex/.codex/skills`, `opencode/skills`). Harmless but noisy.
   Candidate for Phase 2 or later dead-code sweep.

2. `tests/test-hokage-spin-off-readiness.sh` contains `require_fixed` assertions for
   `tests/test-codex-package.sh` and `node scripts/validate-opencode.js` — both refer
   to non-Claude surfaces. These are archived-surface smoke tests and do not affect
   the active validation suite.

---

## Phase 2 Clearance

**Phase 2 (safety hardening) may begin.**

All structural, build, and test gates are green. The fork is confirmed Claude-only v1
with no active runtime dependency on archived surfaces.

### Recommended First Phase 2 Task

**Tighten the Go guardrail rule set (R01–R13).**

The guardrail engine at `go/internal/guardrail/rules.go` carries the full protection
surface for the fork. Phase 2 should audit each rule's `deny/ask` threshold, confirm
the `R12` main-branch push gate matches the internal fork's branch naming conventions
(`main` only, `master` absent), and add any company-specific deny patterns identified
during Phase 1 cleanup.

Start with: `go/internal/guardrail/rules.go` + `go/internal/guardrail/rules_test.go`.
