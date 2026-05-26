# CLAUDE.md Structure Audit — Phase 47.1.1 Investigation Report

Investigation date: 2026-04-20
Target: `CLAUDE.md` v2026-04-19 (142 lines, after the pointer addition in Phase 50.1.1)
Phase 47 goal: Measure session-start loading cost in practice → decide whether to split into `.claude/rules/`

## (a) Line count by section

Result of aggregating line counts per `## H2` boundary with `awk`:

| # | Section | Line range | Lines |
|---|---------|-----------|-------|
| 1 | Project Overview | 5-10 | 6 |
| 2 | Claude Code Feature Utilization | 11-18 | 8 |
| 3 | Development Rules | 19-44 | **26** |
| 4 | Repository Structure | 45-48 | 4 |
| 5 | Using Skills (Important) | 49-66 | **18** |
| 6 | Development Flow | 67-74 | 8 |
| 7 | Testing | 75-83 | 9 |
| 8 | Notes | 84-90 | 7 |
| 9 | MCP Trust Policy | 91-98 | 8 |
| 10 | Permission Boundaries | 99-114 | **16** |
| 11 | Key Commands (for development) | 115-127 | 13 |
| 12 | SSOT (Single Source of Truth) | 128-132 | 5 |
| 13 | Test Tampering Prevention | 133-142 | 10 |
|   | (Header + blank lines) | 1-4 | 4 |
|   | **Total** | | **142** |

### Top 3 heaviest sections

1. **Development Rules (26 lines)**: 5 sub-sections (Commit / Version / CHANGELOG / Language / Code Style)
2. **Using Skills (18 lines)**: Top Skill Categories table (5 lines) + trigger explanations
3. **Permission Boundaries (16 lines)**: 7-row guardrail table + explanation

No section exceeds 30 lines. The 142-line total amounts to ~3.5 KB (1-2% of the session-start context).

## (b) Split candidate sections

Candidates that could be moved to `.claude/rules/`:

| Candidate | Current location | Proposed split target | Benefit | Concern |
|-----------|-----------------|----------------------|---------|---------|
| **MCP Trust Policy** | CLAUDE.md 91-98 (8 lines) | `.claude/rules/mcp-trust-policy.md` | Consistent with existing `codex-cli-only.md`, manages external MCP addition procedures independently | Only 8 lines, so split value is limited |
| **Permission Boundaries** | CLAUDE.md 99-114 (16 lines) | `.claude/rules/permission-boundaries.md` | Linked to settings.json deny, easier to expand the table | This is important information that should be read every session-start |
| **Development Rules** | CLAUDE.md 19-44 (26 lines) | Bulk move to `.claude/rules/development-rules.md` or distribute per sub-section | Lighten the largest section | CHANGELOG is already split to `github-release.md`; remaining content is short |
| **Notes** | CLAUDE.md 84-90 (7 lines) | Delete or merge into Repository Structure | Section header + 4 items has high overhead | Too small; splitting alone provides no value |

DoD (b) requiring 2+ candidates is satisfied. The decision to split or not is made in step (d).

## (c) Investigation of `@` notation availability

### Investigation method

Grep to confirm use of `@path/to/file.md` pattern in the existing repo:

```bash
grep -rE '@[a-zA-Z0-9_/.-]+\.md' CLAUDE.md .claude/rules/*.md
# → 0 matches
```

Other usages found:
- `.claude/worktrees/flamboyant-shannon/templates/*/commands/review-cc-work.md:83`: used **inside prompt body** as `@Plans.md ...`
- `docs/constitution.md:99`: `@docs/constitution.md` quality gate (self-reference, prose)

### Verdict

1. **Official spec for `@file.md` notation in CC 2.1.111+**: Claude Code auto-includes CLAUDE.md, but **there is no confirmed stable, officially documented feature** for additional imports via `@path/to/file.md` notation. It can be used as a reference guide in prompt bodies, but in the current setup where CLAUDE.md itself is auto-loaded there is also a risk of double-loading.
2. **Existing usage**: Not used inside CLAUDE.md. Pointers always take the markdown link form `[.claude/rules/xxx.md](path)`.
3. **Smoke test coverage**: `tests/test-claude-md-auto-include.sh` does not exist. This is a CC version compatibility question, not a feature to verify via smoke test.

**Conclusion**: The `@` notation **has no guarantee of stable operation**. The current pointer approach (regular markdown links + assistant reading them with the Read tool when needed at session-start) is the safest option.

## (d) Final decision and rationale

### Decision: **Maintain current state (do not split)**

### Rationale

1. **Quantitative data**: 142 lines / max 26 lines per section is lightweight relative to the CC session-start context. Token pressure is low without splitting.
2. **Safety of the pointer approach**: The current CLAUDE.md is already designed with a "concise overview + detailed pointer" pattern (CHANGELOG → `github-release.md`, skill catalog → `docs/CLAUDE-skill-catalog.md`, feature table → `docs/CLAUDE-feature-table.md`). Detailed information is already externalized; what remains in CLAUDE.md is "the overview and index that should always be read at session-start."
3. **Uncertainty around `@` notation**: There is no guarantee that `@` notation will be promoted to auto-include in CC 2.1.111+. The current pointers (regular links) work in a model where the assistant follows them with Read when needed. Migrating to `@` carries more divergence risk than gain.
4. **Subjective cost of splitting**: Moving sections to `.claude/rules/` distributes the source of truth across two places. This loses the benefit of seeing a complete "table of contents" for Harness-specific operational rules just by reading CLAUDE.md.
5. **Handling hook warnings**: A mechanism to warn when `PostToolUse` hooks exceed ~130 lines was introduced around v4.3.1, but this means "reconsider if approaching 150 lines," not "split immediately." The +1 line added in Phase 50.1.1 was a necessary minimal pointer addition, done intentionally.

### Future split triggers (future action rules)

- **Trigger A**: If any single section exceeds 30 lines, consider splitting that section only
- **Trigger B**: If the full CLAUDE.md exceeds 180 lines, consider a full restructure
- **Trigger C**: If CC official docs formally document `@` notation auto-include behavior, consider section reorganization + migration to bulk `@` imports

At the current state (142 lines, max 26 lines per section), none of Triggers A/B/C are met, so maintaining the current state is the optimal solution.

## (e) Outcome of this Phase

This Phase was investigation only — **the main `CLAUDE.md` structure was not changed**.
The 1-line pointer addition from Phase 50.1.1 was carried out as a separate task.

## Related Files

- `CLAUDE.md` (target of investigation, unchanged)
- 17 files under `.claude/rules/` (candidate split targets)
- `docs/CLAUDE-feature-table.md` (example of already-externalized content)
- `docs/CLAUDE-skill-catalog.md` (example of already-externalized content)
- `docs/CLAUDE-commands.md` (example of already-externalized content)
