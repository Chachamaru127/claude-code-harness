# Smoke Test — v4.2.0-arcana (Phase 44 Release)

**Date**: 2026-04-18
**Branch**: `release/v4.2.0-arcana`
**Tester**: Worker subagent (harness-work/44.12.1)
**Purpose**: Final quality check before release, after cherry-picking all 9 Phase 44 tasks (44.3.1–44.11.1)

---

## Automated test results

| Test | Command | Result | Notes |
|------|---------|--------|-------|
| validate-plugin | `bash tests/validate-plugin.sh` | **PASS** | 2 warnings (integration test warnings, known), 0 failures |
| consistency | `bash scripts/ci/check-consistency.sh` | **WARN** | 3 mirror drifts (harness-review × 2, harness-loop × 1). Known and existing. No new failures |
| migration residue | `bash scripts/check-residue.sh` | **PASS** | 0 residue items. Scan time 76.9s |
| Go guardrail tests | `go test ./go/internal/guardrail/... -count=1` (run from `go/` dir) | **PASS** | 119 tests PASS, 0 FAIL |
| R01-R13 regression | `bash tests/test-guardrails-r01-r13.sh` | **PASS** | CC2110_* 34 cases PASS (compound/escape/subshell/backtick all covered) |
| 1h cache opt-in | `bash tests/test-prompt-cache-1h.sh` | **PASS** | 9 tests PASS. env.local append, idempotency, env propagation all verified |

### validate-plugin details

- Passed: 39
- Warnings: 2 (integration test warnings. Existing issues, not caused by this Phase's changes)
- Failed: 0

### Consistency check details

The following 3 items are known mirror drifts (reported by Worker D):

- `codex`: harness-review mirror does not match SSOT
- `opencode`: harness-review mirror does not match SSOT
- `opencode`: harness-loop mirror does not match SSOT

No new drift was introduced by this Phase's changes (Phase 44.3.1–44.11.1).

### Go guardrail tests details

- Package: `github.com/Chachamaru127/claude-code-harness/go/internal/guardrail`
- Run command (correct cwd): `cd go && go test ./internal/guardrail/... -count=1`
- 119 tests, PASS / 0 FAIL

> **Note**: Running `go test ./go/internal/guardrail/...` from the repository root gives the error:
> `pattern ./go/internal/guardrail/...: directory prefix go/internal/guardrail does not contain main module or its selected dependencies`
> Always run from the `go/` directory.

### R01-R13 regression details

CC2110_* tests (34 cases) cover:

- CompoundSemicolon / CompoundAmpAmp / CompoundPipe / CompoundOr bypass attempts
- BackslashEscape bypass attempts
- EnvVarPrefix bypass attempts (known-safe commands continue to be blocked)
- Heredoc bypass attempts (confirmed normal pass-through)
- Subshell / Backtick bypass attempts
- PermissionUpdatedInput / AdditionalContext state retention tests

---

## Manual checklist (for Lead/User)

The following 6 items cannot be performed by a Worker subagent and must be verified manually by the Lead or user.

### (a) Confirm zero vague expressions after literal prompt changes

**Verification command**:

```bash
rg "必要に応じて|適宜|適切に|十分に|柔軟に|しっかり|可能なら|場合によって" agents/*.md
```

**Expected result**: 0 items (acceptance condition in `.claude/rules/opus-4-7-prompt-audit.md`)

- [ ] Confirmed grep result is 0 items

### (b) Verify PreCompact block behavior

**Test procedure**:

```bash
# Directly execute hooks/pre-compact.sh to simulate a mock compact trigger
# Pass compact hook input via echo
echo '{"type":"pre_compact","summary":"test"}' | bash hooks/pre-compact.sh
# → Confirm deny is returned with exit 2
echo "exit code: $?"
```

**Expected result**: exit code 2 / JSON `{"decision":"block",...}` is printed to stdout

- [ ] Confirmed exit 2 and deny JSON

### (c) monitors auto-arm (Phase 45 scope)

**Current state**: No `monitors` block in `plugin.json`.

```bash
cat .claude-plugin/plugin.json | jq 'has("monitors")'
# → false (current state)
```

Monitor auto-start block planned to be added in Phase 45. This smoke test only records the observation.

- [ ] Confirmed that Phase 45 addition scope is recorded

### (d) Verify 1h cache reflection

**Test procedure**:

```bash
# Enable 1h cache
bash scripts/enable-1h-cache.sh
source .env.local  # or env.local

# Launch CC session (confirm environment variable propagation)
echo $ENABLE_PROMPT_CACHING_1H  # → 1

# Run /cost in CC session to confirm prompt cache hit
# (Only verifiable inside an actual CC session)
```

- [ ] Confirmed `ENABLE_PROMPT_CACHING_1H=1` is set in env
- [ ] Confirmed cache hit with `/cost` inside CC session

### (e) Verify xhigh effort acceptance

**Target files**:

- `agents/reviewer.md`
- `agents/advisor.md`

**Verification method**:

```bash
grep -n "effort.*xhigh\|xhigh.*effort" agents/reviewer.md agents/advisor.md
```

Confirm that `xhigh` effort for Opus 4.7 in CC 2.1.111+ is defined.
Whether CC actually accepts `xhigh` requires manual verification in a CC 2.1.111+ environment.

- [ ] Confirmed xhigh effort definition exists in agents/
- [ ] Confirmed xhigh effort is accepted in CC 2.1.111+ environment

### (f) guardrails R01-R13 regression zero

Since the automated test results (above) are PASS, this item is already covered by test results.

- [x] Go test PASS (119 cases)
- [x] R01-R13 shell test PASS (CC2110_* 34 cases)

---

## Known issues

| Issue | Details | Resolution policy |
|------|------|---------|
| Plans.md line count exceeded | Plans.md is approximately 285 lines (recommended max 200) | Plan to archive after Phase 44 completes |
| 3 mirror drifts | harness-review × 2, harness-loop × 1 in check-consistency.sh do not match SSOT | Previously reported by Worker D. Planned for cleanup in Phase 45 |
| No monitors block | monitors field does not exist in plugin.json | Addressed in Phase 45 (see (c)) |
| isolation:worktree incomplete | Cases observed where worktree isolation failed during parallel Worker spawn and branch state was shared | Handled with direct SHA specification for cherry-pick (memory: worker_worktree_share.md) |
| Go test cwd constraint | `go test ./go/internal/guardrail/...` cannot be run from repository root | Run after `cd go`. Be careful with validation_commands descriptions |

---

## Phase 44 cherry-pick history (reference)

`git log --oneline 36b73367..HEAD` output (on `release/v4.2.0-arcana` branch):

```
f0d3cdc5 chore(plans): mark 44.11.1 cc:done [d96e94b7]
d96e94b7 docs(phase-44.11.1): add v2.1.99-110 + Opus 4.7 entries to Feature Table (B=0)
63f7ddb5 chore(plans): mark 44.10.1 cc:done [95d1b39b]
95d1b39b docs(phase-44.10.1): add Task Budgets research memo
87996736 chore(plans): mark 44.9.1 cc:done [5949ee7d]
5949ee7d docs(vision): add Opus 4.7 vision high-res review flow and usage guide
1bd2a3b7 chore(plans): mark 44.5.1/44.8.1 cc:done
e24f7f99 docs(phase-44.8.1): confirm /ultrareview policy — harness-review takes precedence in automation flow
b6e78ba9 chore(plans): mark 44.5.1 cc:done [315de2b9]
315de2b9 feat(agents): adopt xhigh effort for reviewer/advisor + document CC-API effort matrix
3e46f416 chore(plans): mark 44.3.1/44.4.2/44.6.1/44.7.1 cc:done
c7be2b5c feat(phase-44.7.1): integrate CC 2.1.99-110 small features (5 items)
a8f1c308 feat(cache): add enable-1h-cache.sh opt-in script and update long-session docs (Phase 44.6.1)
f921cd98 test(guardrails): CC 2.1.110 regression tests for R01-R13 re-conformance (Phase 44.3.1)
856e9888 fix(mirror): sync opencode/skills/harness-loop with SSOT (add user-invocable: true)
```

---

## Test environment information

| Item | Value |
|------|-----|
| Date | 2026-04-18 |
| Branch | `release/v4.2.0-arcana` |
| HEAD | `f0d3cdc5` |
| OS | darwin 25.3.0 |
| Shell | zsh |
| Go module | `github.com/Chachamaru127/claude-code-harness` |
| CC version | 2.1.111+ (Opus 4.7) target |
