# Issue #105 Response Draft

Status: prepared for Phase 55 / task 55.4.1

Issue: [#105 Can the default language be changed to English?](https://github.com/Chachamaru127/claude-code-harness/issues/105)

## Draft Reply

Thanks for opening this.

Yes. The default user-facing language is now English for new distributed surfaces, while Japanese remains preserved as an explicit opt-in.

What changed:

- New setup templates render English by default.
- The config schema and example default `i18n.language` to `en`.
- Shipped skill metadata uses English in `description`, while keeping both `description-en` and `description-ja`.
- Japanese users can still opt in with `i18n.language: ja`, `CLAUDE_CODE_HARNESS_LANG=ja`, or the Japanese locale templates.
- Japanese workflow discovery is preserved. Important Japanese triggers such as `実装して`, `レビューして`, and `計画作って` remain covered by the skill metadata or usage text.
- Internal Plans.md status markers such as `cc:完了`, `pm:確認済`, and `cc:WIP` remain protocol values. They are intentionally not translated as part of this change, so existing Plans tooling keeps working.

Verification commands:

```bash
bash scripts/i18n/check-translations.sh
bash tests/test-i18n-default-language.sh
bash tests/test-i18n-skill-frontmatter.sh
bash tests/test-i18n-locale-roundtrip.sh
bash tests/test-setup-language-rendering.sh
bash scripts/sync-skill-mirrors.sh --check
node scripts/build-opencode.js
node scripts/validate-opencode.js
bash tests/test-codex-package.sh
./tests/validate-plugin.sh
bash scripts/ci/check-consistency.sh
cd go && go test ./... && go vet ./...
```

The CI path also runs the i18n regression suite through `.github/workflows/validate-plugin.yml`, and `scripts/ci/check-consistency.sh` now includes an i18n gate so distribution preflight catches language drift before release.

## Pre-Close Guardrails

These guardrails are the state-migration safety notes for closing the issue.

| Item | Current state | Target state | Required behavior |
| --- | --- | --- | --- |
| Default locale | Some user-facing surfaces historically assumed Japanese. | New distributed surfaces default to English. | Missing or unset locale resolves to `en`. |
| Explicit Japanese | Existing users may set `i18n.language: ja` or `CLAUDE_CODE_HARNESS_LANG=ja`. | Japanese remains opt-in. | Valid `ja` must be preserved and must not be overwritten by startup or validation. |
| Skill metadata | Skills may contain bilingual metadata and mirrored copies. | `description` equals `description-en`; `description-ja` remains present. | Mirror checks and i18n checks must cover root, Codex, and OpenCode skill surfaces. |
| Status markers | Plans tooling stores Japanese protocol markers. | Protocol markers remain unchanged. | Writers keep canonical markers; readers keep alias compatibility. |
| Setup templates | Default and Japanese templates coexist. | Default setup emits English; Japanese setup remains reachable. | Template rendering tests must verify both paths and unresolved placeholders. |

Invariants:

- Do not translate internal Plans.md state markers during this issue.
- Do not delete Japanese templates, Japanese README, or Japanese skill routing text.
- Do not rewrite explicit user locale state during validation.
- Re-running locale checks or setup rendering tests must be idempotent.
- Mirror validation must prove packaged skill surfaces match their source of truth.

Rollback:

- The functional rollback is forward-fix preferred: restore the failing surface, rerun the i18n suite, then rerun full preflight.
- If the CI gate itself causes a false positive, revert only the gate change while keeping the already-shipped English/Japanese state intact.
- Because this task adds validation and documentation, it does not require destructive data rollback.

Abort conditions:

- Any i18n regression command fails.
- `sync-skill-mirrors.sh --check` reports drift.
- `build-opencode.js` or `validate-opencode.js` creates unexpected distribution drift.
- `validate-plugin.sh`, `check-consistency.sh`, Go tests, or Go vet fail.

Dry-run and verification:

- Treat all commands in the draft reply as the pre-close dry-run.
- Compare `git status --short` before and after `node scripts/build-opencode.js && node scripts/validate-opencode.js`; only intentional docs, CI, or gate changes should remain.
- Keep Issue #105 open until the response draft and verification output agree.
