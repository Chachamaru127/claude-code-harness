# I18n Language Contract

Status: Phase 55 / task 55.0.1

Issues:

- [#105 Can the default language be changed to English?](https://github.com/Chachamaru127/claude-code-harness/issues/105)
- [#147 Status Marker Localization Issue](https://github.com/Chachamaru127/claude-code-harness/issues/147)

Confirmed: 2026-04-24
Updated: 2026-05-24 for Issue #147

## Purpose

Claude Code Harness must ship with English as the user-facing default while
preserving the existing Japanese user experience for users who opt in to
Japanese or who issue Japanese instructions.

This contract is intentionally about state and compatibility first. Translation
work, runtime message rewrites, setup template rewrites, and CI gates must use
this document as the source of truth.

## Decisions

1. User-facing default locale is `en`.
2. Japanese remains supported through explicit opt-in and Japanese input UX.
3. Status markers are protocol values, but they are also visible user-facing
   text in generated Plans.md rows, summaries, and notifications.
4. Skill frontmatter must keep both `description-en` and `description-ja`.
5. Migration must be non-destructive and idempotent.

## Locale Resolution

Locale resolution has one source of truth: the locale resolver introduced in
Phase 55 implementation work. Scripts and Go hook handlers must not keep
separate hard-coded defaults once that resolver exists.

The resolver priority is:

| Priority | Source | Meaning |
| --- | --- | --- |
| 1 | Explicit user or session setting | A direct user choice in current session state, CLI setup choice, or another persisted explicit preference. |
| 2 | `.claude-code-harness.config.yaml` `i18n.language` | Project-level configuration. Existing values must be treated as intentional. |
| 3 | `CLAUDE_CODE_HARNESS_LANG` | Process-level override for local runs, tests, and temporary sessions. |
| 4 | Default | `en`. |

Only `en` and `ja` are valid locale values. Unknown values must normalize to
`en` for the current process and must not rewrite the original state.

Japanese input detection is a UX and routing signal, not a persisted locale
setting. A Japanese prompt such as `実装して`, `レビューして`, or `計画作って` must
continue to route to the appropriate skill even when the current display locale
is `en`. Japanese input must not silently overwrite an explicit `en` setting.

## State And Migration Contract

The implementation must distinguish these states:

| State | Examples | Required behavior |
| --- | --- | --- |
| Unset | No session preference, no `i18n.language`, no environment variable | Use `en`. Do not create a Japanese preference implicitly. |
| Explicit Japanese | `i18n.language: ja`, `CLAUDE_CODE_HARNESS_LANG=ja`, or explicit session/user `ja` | Preserve Japanese behavior and messages. Do not overwrite on first startup after upgrade. |
| Explicit English | `i18n.language: en`, `CLAUDE_CODE_HARNESS_LANG=en`, or explicit session/user `en` | Preserve English behavior and messages. Japanese input still routes correctly. |
| Legacy saved value | Existing config or state from before Phase 55 | Read it if valid. Treat `ja` as an intentional opt-in. Do not rewrite unless the user runs an explicit locale command. |
| Missing or corrupted state | Invalid YAML, invalid enum value, unreadable state file | Use safe current-process fallback `en` only after higher-priority valid sources are unavailable. Do not delete or rewrite corrupted state automatically. |

Migration checks must be repeatable. Running startup, setup, or locale detection
multiple times with the same files must produce the same locale decision and
must not keep changing files.

Failure handling favors preserving existing state over forcing the new default.
If migration cannot safely determine whether an existing state was explicit,
the implementation must avoid writing over it and should fall back only for the
current process.

## Status Markers

These markers remain read-compatible protocol values:

| Marker | Meaning |
| --- | --- |
| `pm:依頼中` | PM requested work. |
| `cc:WIP` | Claude Code / Codex is working. |
| `cc:TODO` | Work is queued. |
| `cc:完了` | Work is complete and awaiting PM confirmation. |
| `pm:確認済` | PM confirmed completion. |
| `blocked` | Work is blocked. |

New and updated writer paths must not keep generating a mixed-language marker
family such as `cc:TODO`, `cc:WIP`, and `cc:完了` in Plans.md rows or
notification text. That shape is valid legacy input, but it is not the
canonical output for future writes.

The canonical writer output for new or updated rows is:

| State | New/update writer output | Read-compatible aliases |
| --- | --- | --- |
| Requested | `pm:requested` | `pm:依頼中`, `cursor:依頼中` |
| Queued | `cc:todo` | `cc:TODO` |
| In progress | `cc:wip` | `cc:WIP` |
| Done | `cc:done` | `cc:完了` |
| Approved | `pm:approved` | `pm:確認済`, `cursor:確認済` |
| Blocked | `blocked` | `cc:blocked` |

Japanese opt-in localizes surrounding prose, templates, and runtime messages,
but it does not change status marker writer output. Existing Plans.md files
must not be bulk-rewritten implicitly; migration requires an explicit command
or user approval.

The state contract for marker parsing is intentionally narrow:

| Checkpoint | Required invariant |
| --- | --- |
| Input | Existing `Plans.md` rows and heading-style tasks may contain canonical markers, cursor aliases, or the English aliases listed above. |
| Storage | `Plans.md` remains the source of truth; parser checks must not rewrite it during validation or dry-run paths. |
| Update trigger | Writers update task state only when executing an approved workflow such as work completion or PM confirmation. |
| Readers | `codex-loop`, sprint-contract generation, Plans issue bridge, and format checks must accept legacy markers and English aliases. |
| Writers | All new/update writer paths emit the English marker family; locale affects prose only. |
| Rollback | Rollback must preserve parser compatibility for legacy Plans.md files; do not remove legacy marker recognition. |

## Skill Metadata Contract

Every shipped `SKILL.md` must include:

```yaml
description: "..."
description-en: "..."
description-ja: "..."
```

For the distributed English default, `description` must equal
`description-en`.

For Japanese opt-in, locale tooling may copy `description-ja` into
`description`, but it must keep both language-specific fields intact.

Japanese trigger discoverability must remain. At minimum, the Japanese routing
phrases for implementation, review, and planning must be preserved in
`description-ja` or nearby skill usage text:

- `実装して`
- `レビューして`
- `計画作って`

## Skill Body And Completion Report Contract

Skill instructions that define user-facing output must apply the same locale
resolution contract as runtime scripts. They must not rely on the language of
the surrounding instruction prose or translate an output template ad hoc.

For `harness-work` Solo, forced single-task Parallel, and Breezing completion
reports:

1. Resolve locale through the shared `get_harness_locale` function. An explicit
   session or user language is passed as its optional argument; otherwise the
   resolver keeps the project config, environment, then `en` default priority.
2. Unset, invalid, and resolved `en` use the English template.
3. Only resolved `ja` uses the Japanese template.
   Japanese input alone does not select a Japanese completion template.
4. English and Japanese templates must carry the same semantic fields. Status
   markers, review verdicts, commit hashes, paths, and commands remain
   machine-readable values.
5. Claude, Codex, and OpenCode copies must be regenerated and checked whenever
   this output contract or either template changes.

## Japanese UX Regression Boundary

English default means the first distributed discovery surface is English. It
does not mean Japanese-only user value should be deleted.

When a surface exists primarily for Japanese users, keep one of these paths:

| Surface type | English default boundary | Japanese opt-in boundary |
| --- | --- | --- |
| README and setup templates | English onboarding remains the default path. | `README_ja.md` and `templates/locales/ja/` remain reachable and render Japanese output when `i18n.language: ja` or `CLAUDE_CODE_HARNESS_LANG=ja` is explicit. |
| Skill metadata | `description` equals `description-en` in shipped packages. | `description-ja` remains complete, and `scripts/i18n/set-locale.sh ja` can copy it into `description`. |
| Hook and system messages | English is emitted when no locale is configured. JSON shape and decisions are unchanged. | Existing Japanese messages remain available through explicit `ja`. |
| Memory / output style modes | English mode remains `templates/modes/harness.json`. | `templates/modes/harness--ja.json` remains valid JSON and keeps Japanese language requirements. |
| Creative skills such as `x-announce` and `x-article` | English `description-en` controls default skill discovery and must not promise English creative output unless an English playbook exists. | Japanese article / post structure, Japanese image text defaults, and Japanese publication tone are retained as intentional creative defaults. |

For Japanese-specific creative defaults, the safe rule is additive: if English
users need a full English creative flow later, add an English playbook or mode.
Do not remove Japanese defaults just because the distribution default changed
to English.

## Surface Checklist

The following surfaces are in scope for Phase 55 implementation and must be
checked before Issue #105 is closed:

| Surface | Required check |
| --- | --- |
| `README.md` | English default guidance and Japanese opt-in link are clear. |
| `README_ja.md` | Japanese onboarding remains reachable. |
| `CLAUDE.md` | Repository guidance does not imply Japanese-only behavior for distributed users. |
| `AGENTS.md` | OpenCode/Codex-compatible guidance follows the same language contract. |
| `claude-code-harness.config.schema.json` | `i18n.language` default is `en`; enum keeps `ja`. |
| `claude-code-harness.config.example.json` | Example uses `en` by default and documents `ja`. |
| `templates/.claude-code-harness.config.yaml.template` | Generated project config follows English default. |
| `skills/` | Root skills have `description-en` and `description-ja`; distributed `description` is English. |
| `skills-codex/` | Codex source skills follow the same metadata rule. |
| `codex/.codex/skills/` | Codex packaged mirror has no metadata drift. |
| `opencode/skills/` | OpenCode packaged skills follow the same metadata rule. |
| `.agents/skills/` | Local-only mirror is either synchronized or explicitly documented as excluded from distribution. |
| `scripts/i18n/set-locale.sh` | Locale switching supports `ja -> en` and `en -> ja` without losing language fields. |
| `scripts/i18n/check-translations.sh` | Checks all shipped skill surfaces, not only root `skills/`. |
| `scripts/config-utils.sh` | Contains the shell locale resolver. |
| `scripts/pretooluse-guard.sh` | Uses the shared resolver and defaults to English when unset. |
| `scripts/userprompt-inject-policy.sh` and hook shell output | User-facing output follows locale. JSON shape remains unchanged. |
| Go hook handlers under `go/internal/hookhandler/` | System messages are English by default and Japanese with explicit `ja`. |
| `templates/AGENTS.md.template` | Default setup output is English or locale-aware. |
| `templates/CLAUDE.md.template` | Default setup output is English or locale-aware. |
| `templates/Plans.md.template` | Generated plan guidance is English by default while protocol markers remain unchanged. |
| `templates/modes/harness--ja.json` | Japanese mode remains valid and reachable. |
| `scripts/setup-existing-project.sh` | Setup can render English default and Japanese opt-in. |
| `scripts/setup-hook.sh` | Hook setup messaging follows locale rules. |
| `scripts/quick-install.sh` | Installer messaging and generated config follow locale rules. |
| `.claude-plugin/marketplace.json` | Marketplace user-facing text is English default. |
| `.claude-plugin/hooks.json` and `hooks/hooks.json` | Hook metadata stays synchronized and user-facing descriptions follow English default. |
| `docs/constitution.md` | Any language guidance aligns with this contract. |
| `opencode/README.md` and `codex/README.md` | Runtime-specific docs do not contradict the contract. |

Known current drift after 55.2.2 setup hardening:

- `scripts/pretooluse-guard.sh` defaults to Japanese when no environment
  variable is set.
- Runtime shell / Go messages are not yet fully locale-aware.
- Setup content templates now ship English defaults with Japanese opt-in copies
  under `templates/locales/ja/`.

These are implementation targets for later Phase 55 tasks, not blockers for
this contract task.

## Acceptance Criteria For Later Tasks

Phase 55 implementation must prove these cases:

1. New user first startup uses English by default.
2. Existing Japanese users with explicit `ja` keep Japanese after upgrade.
3. Existing English users with explicit `en` keep English after restart.
4. Explicit locale switching persists across restart or repeat invocation.
5. Missing state falls back to English without writing surprise state.
6. Corrupted state does not get destroyed by the migration path.
7. Re-running migration on old state is idempotent.
8. Japanese input still discovers and routes major workflows:
   `実装して`, `レビューして`, and `計画作って`.
9. Internal Plans.md status markers remain parseable and unchanged unless an
   alias compatibility layer is tested first.
10. All shipped skills retain both `description-en` and `description-ja`.

## Non-goals For 55.0.1

This task does not implement the resolver, update templates, rewrite runtime
messages, or close Issue #105. It fixes the contract that those later changes
must follow.
