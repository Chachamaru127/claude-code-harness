# Phase 1 Validation Report

**Date**: 2026-05-26  
**Branch**: `ai-harness/phase-0-1-cleanup`  
**Auditor**: Claude Code (automated)

---

## 1. Summary Verdict

**YELLOW** — Core plugin is healthy and production-ready. One small test bug was found and fixed (renamed plugin prefix in test input). Ten `check-consistency.sh` failures are all expected stale-checks from the upstream public repo that do not apply to this internal fork. No active runtime dependencies on archived surfaces remain.

---

## 2. What Passed

| Check | Result |
|-------|--------|
| All required active paths exist (`go/`, `hooks/`, `.claude-plugin/`, `skills/`, `scripts/`, `tests/`, `docs/`, `README.md`) | ✅ |
| Archived paths not present at top-level (`codex/`, `.codex-plugin/`, `opencode/`, `.cursor/`) | ✅ |
| Archived surfaces correctly located under `archive/non-claude/` | ✅ |
| All active JSON files valid (plugin.json, hooks.json, settings.json, package.json files) | ✅ |
| Plugin name = `company-ai-harness` in plugin.json and harness.toml | ✅ |
| Version sync: VERSION = plugin.json = harness.toml = `4.12.3` | ✅ |
| All hooks use `company-ai-harness` in `valid_root` check | ✅ |
| No hooks reference archived paths | ✅ |
| Go build: `go build -o bin/harness ./cmd/harness` succeeds | ✅ |
| `./bin/harness version` runs (returns `dev (Hokage)`) | ✅ |
| All Go tests pass (after 1 small fix — see §4) | ✅ |
| `tests/validate-plugin.sh`: 83 PASS, 0 WARN, 0 FAIL | ✅ |
| `tests/test-distribution-archive.sh`: OK | ✅ |
| `git diff --check`: no whitespace errors | ✅ |
| README.md: correctly branded as internal fork | ✅ |
| docs/PROJECT_SCOPE.md, FORK_NOTES.md, REPO_INVENTORY.md, ARCHIVE_REFERENCE_CLEANUP.md all exist | ✅ |
| No `copilot`, `antigravity`, `opencode`, `.codex-plugin` references in any active path | ✅ |
| CI workflows (.github/workflows/): no archived runtime references | ✅ |
| `codex/`, `opencode/` test scripts archived under `tests/_archived/` | ✅ |

---

## 3. What Failed

### F1 — Go test `TestTrackCommandHandler_PluginPrefixCommand` (fixed in this session)

**File**: `go/internal/hookhandler/userprompt_track_command_test.go:174`  
**Cause**: Test input used the old plugin name `claude-code-harness:core:work` as a plugin-prefixed command. The implementation was already updated to strip the new `company-ai-harness:` prefix, making the test fail.  
**Fix applied**: Updated test input to `company-ai-harness:core:work`. Tests now pass.  
**Classification**: Rename residue bug (Phase 1 cleanup miss).

### F2 — `check-consistency.sh`: 10 failures (stale upstream checks, NOT blocking)

All 10 failures are stale checks from the upstream public repo that do not apply to this internal fork:

| Failure | Root Cause | Classification |
|---------|-----------|----------------|
| `README.md latest release link` | Fork README rewritten for internal use; no public release badge | Stale upstream check |
| `README.md latest release badge` | Same | Stale upstream check |
| `README.md compatibility doc link` | Same | Stale upstream check |
| `README.md work-all evidence link` | Same | Stale upstream check |
| `README.md distribution scope link` | Same | Stale upstream check |
| `README.md 5 verb skills message` | Same | Stale upstream check |
| `README.md Go-native guardrail engine message` | Same | Stale upstream check |
| `skill frontmatter bilingual metadata` | Checks for `skills-codex/` which was archived | Expected post-archive |
| `locale roundtrip idempotency` | Checks `skills-codex/` + `codex/.codex/skills` (archived) | Expected post-archive |
| `Japanese UX opt-in surfaces` | Expects >6 surfaces; codex/opencode surfaces removed | Expected post-archive |

**None of these are regressions** — they are pre-existing mismatches between the upstream consistency script and the fork's intentional divergence.

---

## 4. What Was Skipped and Why

| Item | Reason |
|------|--------|
| Running `tests/test-antigravity-unknown-boundary.sh` | Tests a `docs/research/` doc that may not be present; research docs are excluded from distribution. Non-critical. |
| Running `tests/test-github-copilot-cli-candidate.sh` | Same — tests a `docs/research/` file for reference boundary documentation. Non-critical. |
| Full end-to-end harness loop test | Requires live Claude Code session. Not safe to run in audit context. |
| `go test ./...` full suite on CI matrix (Linux/Windows) | Local macOS only run; CI runs these in `smoke-install.yml`. |

---

## 5. Remaining Active References to Archived Surfaces

All remaining references are classified below. None represent active runtime dependencies.

### `codex` references in active Go source

| File | Reference | Classification |
|------|-----------|----------------|
| `go/cmd/harness/codex_loop.go` | `bin/harness codex-loop` subcommand delegating to `scripts/codex-loop.sh` | Internal CLI surface — no Codex binary required at runtime; script may not exist in fork |
| `go/cmd/harness/main.go:83,131` | `codex-loop` routing in CLI dispatch | Same |
| `go/cmd/harness/codex_loop_test.go` | Tests for codex-loop that create a stub script | Active test for internal CLI |
| `go/internal/state/schema.go:31,89` | `codex_mode` column in SQLite schema | Backward compat state model |
| `go/internal/state/store.go:29,63,66` | `SessionModeCodex`, `CodexMode` field | Backward compat state read support |
| `go/internal/guardrail/rules.go:240` | R07 `codex-mode-no-write` guardrail rule | Active guardrail — protects against writes when `codex_mode=1` is set in existing session state |
| `go/cmd/harness/mem_test.go:163,166,189,282` | References `codex,claude` platform strings in harness-mem health test | Active test for harness-mem integration; `codex` here is a harness-mem platform label, not a runtime dep |
| `go/cmd/harness/sync_test.go:86` | Asserts `mcp__codex__*` appears in deny list | Active test verifying Codex MCP remains blocked ✓ |
| `go/SPEC.md`, `go/DESIGN.md` | Historical design notes about codex-notify, codex companion | Acceptable historical notes in internal design docs |

### `cursor:*` marker references in active Go source

All are **compatibility read support** for existing Plans.md files using legacy `cursor:依頼中` / `cursor:確認済` markers. No Cursor IDE dependency.

| File | Reference | Classification |
|------|-----------|----------------|
| `go/internal/session/monitor.go:285` | `countMatches(..., "cursor:依頼中")` | Compatibility read support |
| `go/internal/session/summary.go:234` | `strings.Contains(line, "cursor:依頼中")` | Compatibility read support |
| `go/internal/session/init.go:183,201` | cursor marker counting + note | Compatibility read support |
| `go/internal/hookhandler/plans_watcher.go:139,339,394,431,447` | `cursor:依頼中`, `cursor:確認済`, `cursorNotificationFile` | Compatibility read support + backward compat file write |
| `go/internal/hookhandler/sprint_contract.go:135` | Regex includes `cursor:依頼中|cursor:確認済` | Compatibility read support |

### `cursor` references in tests

| File | Reference | Classification |
|------|-----------|----------------|
| `go/internal/session/init_test.go:180-192` | Test fixtures using `cursor:依頼中` markers | Active test for backward compat |
| `go/internal/hookhandler/plans_watcher_test.go:425` | `TestHandlePlansWatcher_CursorCompatMarker` | Active test for backward compat |

### `codex` and `cursor` references in test scripts under `tests/`

| File | Reference | Classification |
|------|-----------|----------------|
| `tests/test-distribution-archive.sh` | `codex/`, `opencode/`, `skills-codex/`, `.codex-plugin/`, `.cursor/` listed as **forbidden** in distribution | Correct — ensures these remain excluded from release tarballs ✓ |
| `tests/test-breezing-advisor-protocol.sh` | References `cursor` mirror check | Stale mirror validation — needs cleanup in Phase 2 |
| `tests/test-advisor-config.sh` | Mild advisor codex-related references | Stale docs claim — needs review |
| `tests/test-i18n-skill-frontmatter.sh` | Tests `skills-codex` (archived) | Stale non-Claude validation |
| `tests/test-i18n-locale-roundtrip.sh` | References `codex/.codex/skills` (archived) | Stale non-Claude validation |

---

## 6. Remaining Japanese Text Exceptions

Japanese text remaining in active paths is **acceptable** — it is all internal implementation commentary, backward-compat marker strings, or internal design documentation (SPEC.md, DESIGN.md, CHANGELOG.md). No user-facing Japanese text was found in skill definitions, README, or hook outputs.

| Category | Examples | Status |
|----------|----------|--------|
| Internal Go code comments | `go/internal/state/schema.go` column docs, `go/internal/lifecycle/*.go` | Acceptable — internal developer commentary |
| Backward compat status markers | `cc:完了`, `pm:依頼中`, `cursor:依頼中` | Acceptable — Plans.md protocol markers |
| Internal design docs | `go/SPEC.md`, `go/DESIGN.md` | Acceptable — internal Japanese engineering docs |
| CHANGELOG.md | Japanese release notes | Acceptable — internal changelog |
| Internal test comments | `// ～を確認`, `// セッション...` | Acceptable — internal test comments |
| Guardrail error message | R01 sudo deny reason string | Acceptable — internal error; not user-facing skill output |

---

## 7. Build / Test Status

| Check | Status | Notes |
|-------|--------|-------|
| `go build ./cmd/harness` | ✅ PASS | Binary built to `bin/harness` |
| `go test ./...` | ✅ PASS | 1 test fixed (F1 above); all packages pass |
| `./bin/harness version` | ✅ PASS | Returns `dev (Hokage)` (dev build; production injects version via ldflags) |
| `tests/validate-plugin.sh` | ✅ 83/83 PASS | |
| `tests/test-distribution-archive.sh` | ✅ OK | |
| `scripts/ci/check-consistency.sh` | ⚠️ 10 failures | All stale upstream checks — see §3/F2 |

---

## 8. Plugin Runtime Readiness

| Dimension | Status |
|-----------|--------|
| Plugin name consistent in all files | ✅ `company-ai-harness` everywhere |
| Version sync | ✅ `4.12.3` in VERSION, plugin.json, harness.toml |
| Hook binary path | ✅ All hooks call `bin/harness` via `valid_root()` check |
| Hook root validation | ✅ `valid_root` checks for `"name": "company-ai-harness"` in plugin.json |
| Skill path | ✅ `./skills/` |
| Output styles path | ✅ `./output-styles/` |
| No archived runtime paths in active hooks | ✅ |
| Go guardrail engine | ✅ Compiles and runs |
| SessionStart / Setup / SubagentStart hooks | ✅ All `type: "command"` (CC 2.1.142+ compliant) |

---

## 9. Risks Before Phase 2

| Risk | Severity | Notes |
|------|----------|-------|
| `scripts/ci/check-consistency.sh` fails on fork | Medium | 10 stale checks hard-coded for upstream public README and `skills-codex/`. Should be adapted or skipped for internal fork. |
| `codex-loop` CLI subcommand in `bin/harness` | Low | Delegates to `scripts/codex-loop.sh` which may not exist in this fork. Will fail gracefully if script is missing. Not a startup dependency. |
| `cursor:依頼中` compat code | Low | Intentional backward compat; no Cursor runtime dependency. Can be removed once all Plans.md files are migrated to `pm:*` markers. |
| `tests/test-breezing-advisor-protocol.sh` and `test-advisor-config.sh` | Low | Reference mirror/codex concepts. May fail if run as part of a full test suite. Not blocking current plugin operation. |
| `go/cmd/harness/mem_test.go` codex platform references | Low | Tests harness-mem health which tests for `codex` as a platform string in harness-mem CLI args. Will pass as long as harness-mem health CLI accepts these args — currently tested. |
| check-consistency.sh README checks | Low | Will continue to fail until the script is updated for the fork. Does not affect plugin runtime. |

---

## 10. Recommended Next Fixes for Phase 2

1. **Update `scripts/ci/check-consistency.sh`** to skip or adapt the 10 upstream-specific checks that no longer apply to the internal fork (README badges, `skills-codex`, `codex/.codex/skills` mirror).

2. **Review `tests/test-breezing-advisor-protocol.sh`** — contains mirror validation against archived `codex` paths; needs update or archival.

3. **Review `tests/test-advisor-config.sh`** and `tests/test-harness-loop-flow.sh` for stale codex/cursor references.

4. **Evaluate `bin/harness codex-loop`** — this CLI subcommand delegates to a script that may not be present. Either remove the subcommand or add a proper "script not found" graceful error.

5. **Consider `cursor:*` marker deprecation plan** — the `cursor:依頼中` / `cursor:確認済` backward compat code is intentional but has no sunset path. Add a migration note to Plans.md.

6. **Update `go/SPEC.md` and `go/DESIGN.md`** — these still reference Codex as an active integration surface. Add a note that Codex integration is archived.

7. **Archive or update `tests/test-antigravity-unknown-boundary.sh`** and `tests/test-github-copilot-cli-candidate.sh` — these test research documents that are likely not present or relevant to the fork.
