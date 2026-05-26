---
name: cc-update-review
description: "Quality guardrail for Claude/Codex update integration. Detects doc-only Feature Table additions and requires implementation or explicit planning. Internal use only."
user-invocable: false
disable-model-invocation: true
allowed-tools: ["Read", "Grep", "Glob", "Bash"]
---

# Claude/Codex Update Review Guardrail

A quality guardrail to prevent "documentation only" additions when integrating Claude Code / OpenAI Codex updates.
Classifies whether Feature Table additions are accompanied by implementation, verification, or explicit future task planning, and forces output of an implementation proposal if any are missing.

## Quick Reference

This skill is triggered in the following situations:

- When reviewing a Claude Code / Codex upstream update integration PR
- When a diff adding new rows to `docs/CLAUDE-feature-table.md` is detected
- When `/harness-review` determines the PR is an upstream update integration, as an internal call
- When reviewing changes to the `claude-codex-upstream-update` skill

This skill is NOT triggered in the following situations:

- Normal implementation work
- Changes unrelated to Feature Table / upstream tracking
- Setup or initialization work

## Getting the Diff Input

This skill is exclusively for diff-aware review, so always establish the diff to review using one of the following:

1. The calling `/harness-review` passes the PR diff / changed files / Feature Table additions
2. This skill itself runs read-only Bash commands such as `git status --short`, `git diff --name-only`, `git diff -- docs/CLAUDE-feature-table.md`, `git show --stat --name-only` to verify

Bash is used only for read-only git inspection. Do not run tests, formatting, generation, network access, or file-modifying commands.
If the diff cannot be obtained, do not estimate `B: doc-only 0 items`; instead halt the review with "diff not provided, classification impossible".

## Precondition Checks

At the start of every review, verify:

- Is the diff source confirmed to be either caller-provided or read-only git inspection?
- If the PR edited `skills/` or `hooks/`, was `/reload-plugins` run immediately after to refresh the runtime cache (per `{skills,hooks}/**` guidelines)?
- Is there a version-by-version breakdown table for the upstream changes?
- Is the primary information URL for Claude Code pointing to `anthropics/claude-code` or official docs?
- Is the primary information URL for Codex pointing to `openai/codex/releases` or official OpenAI articles?
- Are there zero `B: doc-only` items remaining?
- If touching skill mirrors, are the diffs between `skills/`, `codex/.codex/skills/`, and `.agents/skills/` intentional?

Prohibited old references:

- Old TypeScript guardrail path
- Old TypeScript implementation glob
- Old Codex feature-table path
- Old Codex plugin directory
- Any reference to the old Codex state directory as the current source of truth
- Non-existent Anthropic-side Codex repo URL

## A/B/C/P Classification

Classify each item added to the Feature Table as one of A, B, C, or P:

### (A) Implementation present

Definition: The Feature Table addition is accompanied by corresponding changes in hooks / settings / Go / scripts / agents / skills / tests within the same PR.

Criteria:

- Files related to the feature mentioned in the Feature Table row are changed
- There is a substantive diff in any of: `hooks/hooks.json`, `.claude-plugin/hooks.json`, `.claude-plugin/settings.json`, `go/internal/guardrail/`, `go/internal/hookhandler/`, `scripts/`, `agents/`, `skills/`, `tests/`
- Fixed by a corresponding test or verification script

Examples:

| Feature Table addition | Corresponding implementation change | Verdict |
|------------------------|--------------------------------------|---------|
| `AskUserQuestion updatedInput` | Go handler + hooks wiring + upstream integration test | A |
| `sandbox.network.deniedDomains` | `.claude-plugin/settings.json` + jq test | A |
| `find -delete hardening` | `go/internal/guardrail/` + unit test | A |

Result: OK. No additional action required.

---

### (B) Doc-only

Definition: A row was added only to the Feature Table, with no corresponding Harness implementation changes or Plans tasks. Also not eligible for upstream auto-inheritance.

Criteria:

- A new row exists in the Feature Table
- No related implementation / test / skill / Plans changes are in the same PR
- This is a feature where Harness should provide its own value-add

Examples:

| Feature Table addition | Corresponding implementation change | Verdict |
|------------------------|--------------------------------------|---------|
| `PreCompact hook` | None | B |
| `permission hardening` | No settings / guardrail / tests verified | B |
| `Codex marketplace` | Not extracted to Plans | B |

Result: NG. Block the PR and require an implementation proposal or Plans task.

---

### (C) Upstream auto-inheritance

Definition: Performance improvements, bug fixes, internal optimizations, etc. in Claude Code / Codex itself where no Harness changes are required.

Criteria:

- The fix is in upstream itself and there is no room for Harness to wrap or extend it
- Does not affect Harness settings / hooks / guardrail / workflow / tests
- Feature Table explicitly states "upstream auto-inheritance" or "CC auto-inheritance / Codex auto-inheritance"

Note:

- Do not lightly classify permission / sandbox / security / Bash allowlist / MCP trust boundary items as C
- Confirm that the item does not affect Harness's own guardrails or settings before marking as C
- Do not mark Claude Code 2.1.113 hardening as C until `sandbox.network.deniedDomains`, wrapper Bash deny, `find -exec/-delete`, and macOS dangerous rm paths are verified

Examples:

| Feature Table addition | Reason | Verdict |
|------------------------|--------|---------|
| `Agent Teams permission dialog crash fix` | CC core crash fix. No Harness changes needed | C |
| `Codex Guardian timeout wording` | Codex-side UX fix. No Harness surface | C |

Result: OK. But state the reason explicitly.

---

### (P) Planned (future task)

Definition: Not implemented this time, but has enough value to include in Harness, so it is left as an explicit task in `Plans.md`.

Criteria:

- The Feature Table value-add column reads as `A: future task` or `P: planned`
- A corresponding task exists in `Plans.md` with implementation details such as setup / guardrails / memory / Codex workflow
- A reason for not implementing immediately is given, such as alpha release or major design change

Examples:

| Feature Table addition | Plans extraction | Verdict |
|------------------------|-----------------|---------|
| `Codex marketplace / MCP Apps` | Codex workflow comparison axis task | P |
| `Codex 0.122.0-alpha` | Comparison investigation task after stable release | P |

Result: OK. Can be picked up in the next cycle.

## Upstream Update PR Checklist

```markdown
## Claude/Codex Update Integration Checklist

### 1. Primary source and breakdown table
- [ ] Diff source confirmed as either caller-provided or read-only git inspection
- [ ] Official Claude / Codex URL verified
- [ ] Table of Version / Upstream item / Category / Harness surface / Action is present
- [ ] alpha / stable / docs-only distinction is clear

### 2. Feature Table diff
- [ ] Added rows in `docs/CLAUDE-feature-table.md` are listed
- [ ] Each row has one of A / C / P
- [ ] Zero B items

### 3. Per-category checks
- [ ] (A) Implementation present: corresponding implementation files and tests exist
- [ ] (B) Doc-only: 0 items. Block PR if any remain
- [ ] (C) Auto-inheritance: permission / sandbox / security / workflow impact confirmed
- [ ] (P) Planned: future tasks exist in `Plans.md`

### 4. Mirrors and stale paths
- [ ] No unintended drift between `skills/` and `codex/.codex/skills/`
- [ ] If `.agents/skills/` exists, Claude/Codex annotations are intact
- [ ] No old references: old TypeScript guardrail path, old Codex plugin directory, old Codex feature-table path, etc.

### 5. CHANGELOG / tests
- [ ] CHANGELOG has a "Before / After" or equivalent user-facing description
- [ ] Upstream integration test or targeted unit test is added / updated
```

## Output Format for Category B Detection

When one or more Category B items are detected, output implementation proposals in the following format.
This output is mandatory and cannot be omitted.

```markdown
## Category B Detected: Implementation Proposals

### B-{number}. {Feature Table item name}

**Current state**: Listed in Feature Table only. No Harness implementation / verification / Plans task.

**Harness-specific value-add**:
{Specific explanation of how Harness should leverage this feature}

**Implementation proposal**:

| Target file | Changes |
|-------------|---------|
| `{file path}` | {specific changes} |
| `{file path}` | {specific changes} |

**User experience improvement**:
- Before: {current user experience}
- After: {user experience after implementation}

**Implementation priority**: {High / Medium / Low}
**Estimated effort**: {Small / Medium / Large}
```

## Related Skills

- `claude-codex-upstream-update` - Upstream diff investigation and implementation cycle
- `harness-review` - Code review
- `harness-work` - Category B / P implementation
- `memory` - SSOT-ification of classification criteria
