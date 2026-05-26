# Japanese Text Cleanup Inventory

**Task**: AIH-012A / AIH-012B  
**Date**: 2026-05-26  
**Status**: Pass 1 complete — Groups C, I, L, M translated; governance test assertions updated

Catalogues all Japanese text found in the active Claude Code path, classified by surface type and recommended action.
Does not include `archive/`, `.git/`, vendor output, or binary files.

---

## Summary

| Group | Files | Lines (approx) | Action | Status |
|-------|-------|----------------|--------|--------|
| A — i18n infrastructure | 12 | — | **keep** | ✓ kept |
| B — `description-ja` frontmatter in skills | 30+ SKILL.md | ~30 | **keep** | ✓ kept |
| C — Japanese body text in skills | 30 SKILL.md + 60 references | >1 000 | **translate now** | ✅ done (pass 1) |
| D — Legacy Plans markers | templates, docs | ~20 refs | **keep (compat)** | ✓ kept |
| E — Go user-facing strings | 20+ `.go` | ~213 | **translate now** | ⏳ pending |
| F — Go comments / docstrings | 132 `.go` | ~3 285 | **defer** | deferred |
| G — Shell scripts — user output | ~15 scripts | ~50 | **translate now** | ⏳ pending |
| H — Shell scripts — comments only | ~105 scripts | large | **defer** | deferred |
| I — Templates deployed to user projects | ~30 templates | large | **translate now** | ✅ done (pass 1) |
| J — `docs/` internal dev notes | 80 docs | large | **defer** | deferred |
| K — `CHANGELOG.md` history | 1 | 1 535 | **defer** | deferred |
| L — `CONTRIBUTING.md` | 1 | 21 | **translate now** | ✅ done |
| M — `harness.toml` config comments | 1 | 15 | **translate now** | ✅ done |
| N — Tests with Japanese fixtures | ~110 tests | — | **keep** | ✓ kept; governance test assertions updated to English |
| O — `spec.md` legacy marker refs | 1 | 2 | **keep (compat)** | ✓ kept |

---

## Group A — Intentional i18n Infrastructure

**Active / Internal-only / keep**

These files exist to support the opt-in Japanese locale and must not be removed.

| File | Purpose |
|------|---------|
| `templates/locales/ja/AGENTS.md.template` | Japanese-locale project template |
| `templates/locales/ja/CLAUDE.md.template` | Japanese-locale project template |
| `templates/locales/ja/Plans.md.template` | Japanese-locale project template |
| `templates/locales/ja/.claude-code-harness.config.yaml.template` | Japanese-locale config |
| `templates/modes/harness--ja.json` | Japanese output-mode definition |
| `docs/i18n-language-contract.md` | i18n design contract |
| `tests/test-i18n-default-language.sh` | Regression: default = English |
| `tests/test-i18n-japanese-ux-regression.sh` | Regression: Japanese UX surfaces |
| `tests/test-i18n-locale-resolver.sh` | Locale resolution tests |
| `tests/test-i18n-locale-roundtrip.sh` | Locale switch round-trip tests |
| `tests/test-i18n-skill-frontmatter.sh` | Validates `description-ja` on all skills |
| `LICENSE.ja.md` | Japanese translation of the license (intentional) |

---

## Group B — `description-ja` Frontmatter in Skills

**Active / Internal-only (opt-in) / keep**

Every `skills/*/SKILL.md` contains a `description-ja:` frontmatter field.
These are the mechanism by which users running the Japanese locale (`scripts/i18n/set-locale.sh ja`)
get Japanese trigger phrases. Removing them would break the Japanese opt-in path.

```
description-ja: "HAR:Plans.md タスクを1件から全並列チーム実行まで担当。..."
```

**Action**: keep as-is. Do not merge into `description`.

---

## Group C — Japanese Body Text in Skills

**Active / User-facing / translate now**

30 of 35 active `skills/*/SKILL.md` files contain Japanese in the body (not just frontmatter).
60 files under `skills/*/references/` are written entirely in Japanese.
These instructions are loaded into the model context when the skill fires and are user-visible.

Representative samples:

| File | Nature | Priority |
|------|---------|---------|
| `skills/harness-work/SKILL.md` | Execution mode table, section headings in Japanese | high |
| `skills/harness-review/references/code-review.md` | Full reference doc in Japanese | high |
| `skills/harness-plan/SKILL.md` | Step descriptions in Japanese | high |
| `skills/harness-release/references/release-notes.md` | Release workflow in Japanese | high |
| `skills/memory/references/ssot-initialization.md` | SSOT workflow in Japanese | high |
| `skills/breezing/SKILL.md` | Execution details in Japanese | medium |
| `skills/generate-video/references/*.md` | Video generation workflow in Japanese | medium |
| `skills/generate-slide/references/*.md` | Slide generation workflow in Japanese | medium |

**Action**: translate now, skill by skill. Preserve `description-ja` frontmatter.
Target: all body text in `description` locale should be English in the English distribution.

**AIH-012B result**: All active `skills/*/SKILL.md` and their `references/` files translated to English.
Remaining Japanese in skills: `description-ja` frontmatter only (intentional, Group B).
Japanese trigger phrases in `harness-review/SKILL.md` `trigger:` field preserved for locale support.

---

## Group D — Legacy Plans Markers

**Active / User-facing (in templates) / keep (compatibility read support)**

The following Japanese status markers appear in templates, tests, and documentation
as compatibility aliases. The system continues to read them from existing Plans.md files.

| Marker | English equivalent | Appears in |
|--------|--------------------|-----------|
| `cc:完了` | `cc:done` | `templates/Plans.md.template`, `templates/AGENTS.md.template`, `tests/`, `spec.md` |
| `pm:依頼中` | `pm:requested` | `templates/AGENTS.md.template`, `tests/` |
| `pm:確認済` | `pm:approved` | `templates/AGENTS.md.template`, `tests/` |
| `cursor:依頼中` | `pm:requested` alias | `templates/AGENTS.md.template` |
| `cursor:確認済` | `pm:approved` alias | `templates/AGENTS.md.template` |

**Action**: keep compatibility read support. New system output must use the English forms.
The legend rows (`pm:依頼中 | Compatibility alias`) document the compat surface and should stay.

---

## Group E — Go Source — User-facing Strings

**Active / User-facing / translate now**

~213 Japanese string occurrences across 20+ non-test Go files that surface as
permission denial reasons, system messages, or `additionalContext` fields shown to the user.

Key files with user-visible strings:

| File | Sample | Priority |
|------|--------|---------|
| `go/internal/guardrail/rules.go` | `"sudo is prohibited..."`, `"git push --force is prohibited..."` (currently in Japanese) | **high** |
| `go/internal/guardrail/post_tool.go` | denial reasons | high |
| `go/internal/guardrail/helpers.go` | `"Warning: ..."` system messages (currently in Japanese) | high |
| `go/internal/guardrail/tampering.go` | tampering detection messages | high |
| `go/internal/event/permission_denied.go` | permission denied messages | high |
| `go/internal/hookhandler/ask_user_question_normalizer.go` | user prompt strings | high |
| `go/internal/hookhandler/plans_watcher.go` | watcher notifications | medium |
| `go/internal/hookhandler/breezing_signal_injector.go` | signal messages | medium |
| `go/internal/hookhandler/ci_status_checker.go` | CI status strings | medium |
| `go/internal/hookhandler/inbox_check.go` | inbox messages | medium |

**Action**: translate all `Reason`, `SystemMessage`, `additionalContext` string literals
from Japanese to English. Update corresponding `_test.go` assertions (Group N).

---

## Group F — Go Source — Comments and Docstrings

**Active / Internal-only / defer**

~3 285 Japanese comment lines across 132 Go files. These are developer-facing comments
inside the codebase and have no user-visible runtime impact.

**Action**: defer. Translate opportunistically when touching files for other reasons.
Do not create a dedicated translation PR — it would generate unmanageable diff noise.

---

## Group G — Shell Scripts — User-facing Output Strings

**Active / User-facing / translate now**

~15 scripts contain Japanese text in strings that reach the user via stdout,
`additionalContext`, or desktop notifications.

| File | Sample | Priority |
|------|--------|---------|
| `scripts/hook-handlers/notification-handler.sh` | notification body strings | high |
| `scripts/hook-handlers/stop-failure.sh` | failure messages | high |
| `scripts/hook-handlers/elicitation-handler.sh` | elicitation text | high |
| `scripts/stop-plans-reminder.sh` | reminder text | medium |
| `scripts/session-summary.sh` | summary labels | medium |
| `scripts/plans-watcher.sh` | watcher notifications | medium |
| `scripts/hook-handlers/task-completed.sh` | completion messages | medium |

**Action**: translate Japanese output strings. Leave Japanese comments in place for now (Group H).

---

## Group H — Shell Scripts — Comments Only

**Active / Internal-only / defer**

~105 scripts have Japanese only in `#` comment lines.
Runtime behavior is unaffected.

**Action**: defer. Translate when touching files for other reasons.

---

## Group I — Templates Deployed to User Projects

**Active / User-facing / translate now**

Templates under `templates/` (excluding `templates/locales/ja/`) are copied into user projects
during `harness-setup`. Japanese body text in these files becomes visible to project members.

| Sub-group | Files | Priority |
|-----------|-------|---------|
| `templates/rules/*.md.template` | 10 rule templates | **high** |
| `templates/cursor/commands/*.md` | 5 Cursor integration commands | high |
| `templates/opencode/commands/*.md` | 5 OpenCode integration commands | high |
| `templates/memory/*.md.template` | 3 memory templates | high |
| `templates/html/*.html.template` | 4 HTML surface templates | medium |
| `templates/Plans.md.template` | Plans legend rows | compat — keep marker refs |
| `templates/AGENTS.md.template` | Agents legend rows | compat — keep marker refs |
| `templates/hooks/auto-cleanup-hook.sh` | hook comments only | defer |
| `templates/sandbox-settings.json.template` | comments | defer |

**Action**: translate rule templates, cursor/opencode commands, and memory templates now.
HTML templates contain layout and label strings — translate labels, keep compat marker legend rows.

**AIH-012B result**: All `templates/rules/*.md.template` and `templates/memory/*.md.template` files translated.
Remaining deferred: `templates/cursor/`, `templates/opencode/`, `templates/html/` (planned pass 2).
Legacy compat marker aliases preserved in `workflow.md.template` and `plans-management.md.template`.

---

## Group J — `docs/` Internal Development Notes

**Active / Internal-only / defer**

80 files under `docs/` contain Japanese. Most are internal development records:
upstream update snapshots, phase completion reports, benchmark rubrics, and architecture decisions.

Files referenced in `CLAUDE.md` (higher visibility):

| File | Japanese lines | Note |
|------|---------------|------|
| `docs/CLAUDE-feature-table.md` | 1 199 | Referenced in CLAUDE.md; internal dev table |
| `docs/CLAUDE-skill-catalog.md` | 61 | Referenced in CLAUDE.md |
| `docs/CLAUDE-commands.md` | (many) | Referenced in CLAUDE.md |

**Action**: defer. The `CLAUDE.md` pointers make these internal-only visible to contributors.
Translate `CLAUDE-skill-catalog.md` and `CLAUDE-commands.md` in a follow-up task
(smaller scope, higher contributor-visibility).

---

## Group K — `CHANGELOG.md` History

**Active / Internal-only / defer**

1 535 Japanese lines in `CHANGELOG.md`. This is the historical record of the project
written in Japanese since its inception.

**Action**: defer. The CLAUDE.md language rule already requires new entries in English.
Retroactive translation would generate massive, low-value churn and obscure git blame.

---

## Group L — `CONTRIBUTING.md`

**Active / User-facing / translate now**

21 Japanese lines in `CONTRIBUTING.md`, a public-facing file for contributors.
Section `## CHANGELOG Entry Rules` and surrounding content were in Japanese.

**Action**: translate now. Small scope, high visibility.

**AIH-012B result**: Done. Section `## CHANGELOG Entry Rules (Required)` is now in English.

---

## Group M — `harness.toml` Config Comments

**Active / User-facing / translate now**

15 Japanese comment lines in `harness.toml`. This file is the primary user configuration
surface and is read directly by project maintainers when customizing the harness.

Key commented sections:
- `direct push to main/master policy` (line 22-23)
- Worker self-review rule comments (lines 151-167)

**Action**: translate now. Small scope, direct user impact.

**AIH-012B result**: Done. All user-visible comments in `harness.toml` translated to English.

---

## Group N — Tests Containing Japanese Fixtures

**Active / Internal-only / keep**

~110 test files (excluding the 5 i18n-specific tests) contain Japanese strings
used as compatibility fixtures or test inputs. These verify:

- Legacy marker parsing (`cc:完了`, `pm:依頼中`)
- Japanese UX regression surfaces
- i18n locale round-trips

**Action**: keep. Modifying these would break test coverage for the compatibility surface.
When Group E strings are translated, update corresponding test assertions in the same PR.

**AIH-012B result**: Governance test assertions updated to match translated skill content:
- `tests/test-harness-review-governance.sh` — 8 Japanese terms → English equivalents in `required_skill_terms`; 3 terms in `required_reference_terms`
- `tests/test-harness-release-governance.sh` — 6 Japanese terms → English equivalents in `required_terms`
- `tests/test-spec-ssot-workflow.sh` — 8 Japanese grep patterns → English equivalents
Remaining Japanese in tests: compat fixture tests (Group D markers), i18n regression tests (Group A) — kept intentionally.

---

## Recommended Translation Order

| Priority | Groups | Rationale |
|----------|--------|-----------|
| 1 (now) | E — Go user-facing strings | Runtime messages shown to every user |
| 2 (now) | G — Shell script output strings | Runtime messages shown to every user |
| 3 (now) | L — `CONTRIBUTING.md` | Public contributor guide |
| 4 (now) | M — `harness.toml` | Primary config surface |
| 5 (next sprint) | I — Templates | Deployed to user projects at setup |
| 6 (next sprint) | C — Skills body text | In-model instructions shown when skills fire |
| 7 (defer) | J — `docs/` internal notes | Internal; low user impact |
| 8 (defer) | F, H — Code comments | Internal; no runtime impact |
| 9 (defer) | K — `CHANGELOG.md` history | Historical record; retroactive translation is low-value |

---

## Constraints

- **Do not remove Group A** (i18n infrastructure) — the Japanese locale opt-in path depends on it.
- **Do not remove Group B** (`description-ja` fields) — the `set-locale.sh ja` mechanism depends on them.
- **Do not remove Group D** (legacy marker references in tests/templates) — breaks compat read support.
- **Do not modify Group N** (test fixtures) in isolation — update only when translating the Go/shell strings they assert against.
- **`spec.md`**: 2 Japanese lines are compat marker references (`cc:完了`, `pm:依頼中`). Keep.
