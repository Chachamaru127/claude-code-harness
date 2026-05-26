# Phase 21 Release Checklist

Last updated: 2026-03-06

This checklist is the verification table for release decisions that include changes to `trust repair`, `evidence pack`, and `positioning refresh`.

## Surfaces

- [ ] `VERSION` and `.claude-plugin/plugin.json` are in sync
- [ ] README / README_ja use the latest release badge
- [ ] No broken links in README / README_ja
- [ ] `docs/distribution-scope.md` and `Plans.md` descriptions are consistent
- [ ] Classifications in `docs/claims-audit.md` do not conflict with the current wording

## Evidence

- [ ] `./tests/validate-plugin.sh`
- [ ] `./tests/validate-plugin-v3.sh`
- [ ] `./scripts/ci/check-consistency.sh`
- [ ] `cd core && npm test`
- [ ] `./scripts/evidence/run-work-all-smoke.sh`
- [ ] If needed: `./scripts/evidence/run-work-all-success.sh --full`
- [ ] To demonstrate a live Claude full run: `./scripts/evidence/run-work-all-success.sh --full --strict-live`
- [ ] If needed: `./scripts/evidence/run-work-all-failure.sh --full`

## Artifact Review

- [ ] The description in `docs/evidence/work-all.md` matches the generated artifacts
- [ ] Reviewed the most recent artifact in `out/evidence/work-all/`
- [ ] Noted in the release notes which of success / failure has not been verified

## Release Decision

- [ ] Determined whether this change requires a release metadata update
- [ ] Obtained explicit approval for GitHub Release / tag creation
- [ ] The announcement text does not mix `trust repair`, `evidence pack`, and `positioning refresh` — they are kept separate

## Current Recommendation (2026-03-06)

- Releasing only the evidence tooling with replay fallback is acceptable.
- However, if the announcement strongly claims "live Claude completed the happy path", collect a `--strict-live` artifact first before publishing.
