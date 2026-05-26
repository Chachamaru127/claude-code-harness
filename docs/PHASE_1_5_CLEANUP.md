# Phase 1.5 — Stale Non-Claude Test Cleanup

Date: 2026-05-26

## Objective

Remove or archive active tests that reference archived non-Claude runtime surfaces
(Codex, OpenCode, Cursor, mirror paths). Phase 1 archived those runtime directories;
the active test suite now validates only the Claude Code plugin.

---

## Test Classification Decisions

### 1. `tests/test-breezing-advisor-protocol.sh` — **Rewritten**

**Reason**: The test validated advisor protocol contract across 5 surfaces:
`skills/` (active), `skills-codex/`, `codex/.codex/skills/`, `opencode/skills/`
(all archived). The stale surfaces caused hard failures because the directories
no longer exist.

**Action**: Removed codex/opencode variable declarations, existence checks, content
assertions, and mirror diff checks. Kept the active `skills/harness-work/SKILL.md`
and `skills/breezing/SKILL.md` assertions (`advisor-request.v1`, `advisor-response.v1`,
max-3-consults contract).

---

### 2. `tests/test-advisor-config.sh` — **Rewritten**

**Reason**: The final subshell (lines 105–116) referenced two scripts that no longer
exist — `scripts/codex-worker-engine.sh` and `scripts/codex-loop.sh` — both removed
with the Codex runtime in Phase 1. Running the test would fail immediately at the grep
against a missing file path.

**Action**: Removed the `WORKER_ENGINE` / `LOOP_SCRIPT` variable declarations and the
entire subshell block that tested them. Kept all advisor config defaults/overrides tests
and the `ensure_advisor_state_files` initialization tests, which exercise
`scripts/config-utils.sh` (still active).

**Note**: `get_advisor_codex_model` and its default `gpt-5.4` remain in
`scripts/config-utils.sh` as a vestigial key. The config key itself still parses
correctly even without Codex; the test keeps the override assertion for it since
the function is still present.

---

### 3. `tests/test-i18n-skill-frontmatter.sh` — **Rewritten**

**Reason**: The Python inline script iterated over three surfaces: `skills/`,
`skills-codex/`, and `codex/.codex/skills/`. The latter two are archived and no
longer present. Additionally, the test called `node scripts/validate-opencode.js`
which was removed with the OpenCode runtime.

**Action**: Restricted `SURFACES` list to `[Path("skills")]` only. Removed the
`node scripts/validate-opencode.js` call. The test is still invoked from
`scripts/ci/check-consistency.sh` and `.github/workflows/validate-plugin.yml`
with no changes needed there.

---

### 4. `tests/test-i18n-locale-roundtrip.sh` — **Rewritten**

**Reason**: The `list_skill_files` function used `find skills skills-codex codex/.codex/skills`.
The Python inline `verify_locale_copy` listed `root / "skills-codex"` and
`root / "codex/.codex/skills"` as surfaces to verify. Both are archived.

**Action**: Changed `find` to `find skills` only. Restricted Python `surfaces` list
to `[root / "skills"]`. The roundtrip idempotency contract is still fully verified
for all active skill files.

---

### 5. `tests/test-antigravity-unknown-boundary.sh` — **Moved to archive**

**Destination**: `tests/_archived/non-claude/`

**Reason**: This test validates a research boundary document
(`docs/research/antigravity-cli-adapter.md`) that records why Antigravity CLI is
classified as `future/unsupported`. The document is still present and the markers
are still correct. However, the test guards adoption of a non-Claude runtime surface
and belongs conceptually with the other archived non-Claude tests rather than the
active Claude plugin test suite.

**Backward compatibility**: No test runner (`validate-plugin.sh`,
`check-consistency.sh`, CI workflow) references this test directly, so moving it
does not break any pipeline.

---

### 6. `tests/test-github-copilot-cli-candidate.sh` — **Moved to archive**

**Destination**: `tests/_archived/non-claude/`

**Reason**: Same rationale as `test-antigravity-unknown-boundary.sh`. The test
validates `docs/research/github-copilot-cli-adapter.md` — a boundary record that
GitHub Copilot CLI remains `candidate`. This is non-Claude runtime governance, not
Claude plugin behavior.

**Backward compatibility**: Not referenced by any active test runner.

---

### 7. `tests/test-harness-loop-flow.sh` — **Rewritten**

**Reason**: `SCRIPT_PATH_SURFACES` listed nine paths across five runtime surfaces.
Eight of the nine paths were stale (codex, opencode, `.agents`). Although the loop
used `[ -f "${surface}" ] || continue` so they did not cause failures, the dead
entries were misleading and would silently skip validation that was intended.

**Action**: Replaced the nine-entry list with the three active skill files:
`skills/harness-work/SKILL.md`, `skills/harness-loop/SKILL.md`,
`skills/breezing/SKILL.md`. All bare-scripts/ call checks now run against the files
that actually exist.

---

## Invariants Preserved

- No archived runtime paths were restored.
- No active Claude behavior assertions were weakened or removed.
- `validate-plugin.sh`, `check-consistency.sh`, and `.github/workflows/validate-plugin.yml`
  required no changes (the rewritten tests are still in the same locations).
- The `tests/_archived/non-claude/` directory now holds both non-Claude adapter
  boundary tests alongside the existing `test-codex-worker.sh`.

## Files Changed

| File | Change |
|------|--------|
| `tests/test-breezing-advisor-protocol.sh` | Rewritten (removed codex/opencode mirror checks) |
| `tests/test-advisor-config.sh` | Rewritten (removed codex-worker-engine / codex-loop block) |
| `tests/test-i18n-skill-frontmatter.sh` | Rewritten (skills/ surface only; removed validate-opencode.js call) |
| `tests/test-i18n-locale-roundtrip.sh` | Rewritten (skills/ surface only) |
| `tests/test-antigravity-unknown-boundary.sh` | Moved → `tests/_archived/non-claude/` |
| `tests/test-github-copilot-cli-candidate.sh` | Moved → `tests/_archived/non-claude/` |
| `tests/test-harness-loop-flow.sh` | Rewritten (SCRIPT_PATH_SURFACES to active skills/ only) |
| `docs/PHASE_1_5_CLEANUP.md` | Created (this document) |

---

## Phase 1.5 — check-consistency.sh Fork Adaptation (2026-05-26)

### Objective

Replace 7 stale upstream public-release checks in `scripts/ci/check-consistency.sh`
section 12 with fork-appropriate checks. Also complete the i18n test cleanup (items
3 and 4 above were partially addressed earlier; the Japanese UX regression test also
needed updating).

### Checks Removed (upstream-specific)

| Check | Reason |
|-------|--------|
| `README.md latest release link` | Upstream GitHub release URL; fork has no public release |
| `README.md latest release badge` | Upstream shields.io badge URL; absent in fork README |
| `README.md compatibility doc link` | Fork README has no link to `CLAUDE_CODE_COMPATIBILITY.md` |
| `README.md work-all evidence link` | Fork README has no link to `docs/evidence/work-all.md` |
| `README.md distribution scope link` | Fork README has no link to `docs/distribution-scope.md` |
| `README.md 5 verb skills message` | Marketing string absent in fork README |
| `README.md Go-native guardrail engine message` | Phrasing differs in fork README |

### Checks Added (fork-appropriate, section 12)

| Check | Validates |
|-------|-----------|
| `README.md internal-fork declaration` | "Internal fork" notice present |
| `README.md Claude Code-first target` | "Claude Code" appears in README |
| `README.md marks non-Claude runtimes as archived` | "archived and out of scope" present |
| `README.md references archive/ for non-Claude surfaces` | `archive/` mentioned |
| `README.md upstream public release badge absent` | No upstream shields.io URL in README |
| `plugin.json name: company-ai-harness` | Plugin identity correct post-rename |
| `hooks/hooks.json is valid JSON` | Structural validity of hooks config |
| `archived non-Claude surfaces not at top level` | `codex/`, `opencode/`, `.cursor/`, `.codex-plugin/` absent at root |

### Additional i18n Test Fix

`tests/test-i18n-japanese-ux-regression.sh` was updated:
- Removed `copy_dir skills-codex` and `copy_dir codex/.codex/skills`
- Removed codex entries from `key_skills` list
- Adjusted surface-count assertion from `>= 9` to `>= 6` (skills/ + .agents/skills/)
- Gated `README_ja.md` checks on file existence (upstream-only file)

### Result

`scripts/ci/check-consistency.sh`: **✅ すべてのチェックに合格しました** (0 failures)

---

## Phase 1.5 — Plans Marker Compatibility Documentation (2026-05-26)

### Objective

Document the preferred v1 Plans.md marker family and the legacy read-compatible
markers, and define a sunset path so future work can remove legacy marker
recognition in a planned, non-breaking way.

### Background

The codebase supports legacy Japanese and Cursor-style markers such as `cc:完了`,
`pm:依頼中`, and `cursor:依頼中`. This is intentional backward compatibility, not
active Cursor IDE support. Without documentation, future contributors may (a) not
know which marker family to use for new output, or (b) mistake `cursor:*` read
support for Cursor IDE support.

### Actions

| File | Change |
|------|--------|
| `docs/PLANS_MARKERS.md` | Created — full marker reference, preferred/legacy split, migration plan |
| `docs/PROJECT_SCOPE.md` | Added "Plans.md Marker Vocabulary" section with link to PLANS_MARKERS.md |
| `docs/PHASE_1_5_CLEANUP.md` | This section |

### Generator audit findings

Known occurrences of legacy marker generation as of 2026-05-26:

| Location | Occurrence type | Action needed |
|----------|----------------|---------------|
| `skills/workflow-guide/SKILL.md` | Documentation table / flow diagram | Update to preferred markers in a follow-up |
| `skills/workflow-guide/examples/typical-workflow.md` | Workflow example text | Update to preferred markers in a follow-up |
| `skills/workflow-guide/references/commands.md` | Reference example | Update to preferred markers in a follow-up |
| `skills/memory/references/sync-project-specs.md` | Reference table | Update in follow-up |
| `skills/memory/references/plans-merging.md` | Reference table | Update in follow-up |
| `skills/session-init/SKILL.md` | Descriptive list | Update in follow-up |
| `skills/harness-loop/SKILL.md` | Flow comment | Update in follow-up |
| `skills/harness-loop/references/flow.md` | Code comment | Update in follow-up |
| `skills/harness-work/references/execution-modes.md` | Reference text | Update in follow-up |
| `skills/harness-work/references/failure-reticketing.md` | Reference table | Update in follow-up |
| `skills/principles/references/general-principles.md` | Rule text | Update in follow-up |
| `skills/harness-plan-brief/SKILL.md` | Schema enum (uses `cc:完了`) | Update enum to `cc:done` in follow-up |
| `skills/harness-plan-brief/schemas/plan-brief-context.v1.schema.json` | Schema enum | Update in follow-up |
| `skills/harness-progress/SKILL.md` | Description + count text | Update in follow-up |
| `skills/harness-progress/schemas/progress-snapshot.v1.schema.json` | Description strings | Update in follow-up |
| `templates/AGENTS.md.template` | Marker table | Documentation only; acceptable |
| `templates/Plans.md.template` | Compat table | Documentation only; acceptable |
| `templates/locales/ja/Plans.md.template` | Compat table | Documentation only; acceptable |
| `templates/locales/ja/AGENTS.md.template` | Marker table | Documentation only; acceptable |

All occurrences are in documentation examples or descriptive text, not in active
code paths that write to Plans.md. The most impactful follow-ups are the
`harness-plan-brief` schema (`cc:完了` enum value) and the `harness-progress`
SKILL.md descriptions, which reference legacy markers in user-visible output text.

### Invariants

- No production Plans.md write path was changed in this task.
- Read compatibility for legacy markers is unchanged.
- The `cursor:*` compatibility clarification is now documented and removes
  ambiguity without changing any behavior.

---

## Phase 1.5 — Design Docs Non-Claude Reference Audit (2026-05-26)

### Objective

Mark Codex/OpenCode/Cursor references in active design docs as archived context
rather than active support claims. The active test suite and runtime already operate
Claude-only; this task aligns the design documentation with that reality.

### Reference Classification

| File | Location | Kind | Classification | Action taken |
|------|----------|------|----------------|--------------|
| `go/SPEC.md` | top of file | design doc | primary target | Added fork note at top |
| `go/SPEC.md` | §10 R07 `codexMode` | guardrail rule | historical (Codex companion guard) | Inline `*(historical)*` note |
| `go/SPEC.md` | §決定事項 codex-companion.sh | design decision | historical | Added `Archived for v1` callout |
| `go/SPEC.md` | §4 `mcp__codex__*` deny | security rule | **active** (MCP deny still valid) | No change |
| `go/DESIGN.md` | top of file | design doc | primary target | Added fork note at top |
| `go/DESIGN.md` | Memory Bridge `codex-notify` row | hook target | historical | Inline `*(archived for v1)*` note |
| `go/DESIGN.md` | `codex-notify` flow comment | flow diagram | historical | Inline `# archived for v1` comment |
| `go/DESIGN.md` | D2 Codex companion | design decision | historical | Inline `*(archived for v1)*` note |
| `docs/CLAUDE_CODE_COMPATIBILITY.md` | Windows checkout note | compat note | historical dirs mentioned | Inline note about archived dirs |
| `docs/CLAUDE_CODE_COMPATIBILITY.md` | "What Requires Extra Validation" list | compat claim | historical | `*(archived for v1)*` inline |
| `docs/team-composition.md` | "Codex bridge" section | bridge doc | historical | `Archived for v1` callout |
| `docs/agent-view-policy.md` | "Codex teammate" row | policy table | historical | Inline `*(archived for v1)*` |
| `docs/harness-review-operating-model.md` | `codex-closeout` mode row | mode table | historical | Inline `*(archived for v1)*` |
| `docs/harness-review-operating-model.md` | "Adopted from external codex-review" heading | design note | historical upstream | Heading note added |
| `docs/ultrareview-policy.md` | "Codex adversarial review" rows | comparison table | **null entry** (no claim) | No change needed |
| `docs/upstream-update-snapshot-2026-04-23.md` | Codex 0.123.0 rows | upstream snapshot | **archive doc** (snapshot by design) | Not edited |
| `docs/claims-audit.md` | Codex setup / Cursor entries | audit record | **archive by design** | Not edited |

### Invariants

- No technical history was removed; all Codex design context is preserved for
  potential future cherry-picks.
- Active security rule `mcp__codex__*` deny in `go/SPEC.md` was not touched.
- Archive docs and upstream snapshot docs were not edited (task scope excludes them).
- `go/SPEC.md` `mcp__codex__*` in the example settings.json remains valid:
  the deny rule still applies even when Codex is not an active surface.

### Files Changed

| File | Change |
|------|--------|
| `go/SPEC.md` | Added fork note; R07 historical annotation; codex-companion.sh archived callout |
| `go/DESIGN.md` | Added fork note; codex-notify historical annotations; D2 archived annotation |
| `docs/CLAUDE_CODE_COMPATIBILITY.md` | Windows note + validation list archived annotations |
| `docs/team-composition.md` | Codex bridge archived callout |
| `docs/agent-view-policy.md` | Codex teammate row archived annotation |
| `docs/harness-review-operating-model.md` | codex-closeout archived annotation; section heading note |
| `docs/PHASE_1_5_CLEANUP.md` | This section appended |
