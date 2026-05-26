# Release Preflight

`scripts/release-preflight.sh` is a read-only check that stops you before publishing — verifying
"is it safe to release now?" upfront.
It assumes vendor-neutrality and does not depend on AWS-specific infrastructure or particular deployment platforms.

## What it checks

- Whether the working tree is clean
- Whether `CHANGELOG.md` has an `[Unreleased]` section
- Whether `.env.example` and `.env` are not significantly out of sync. Repos without `.env` get only a warning — this avoids blocking managed-secrets setups
- Whether existing `healthcheck` / `preflight` commands pass
- Warns if residue such as `mockData` / `dummy` / `localhost` / `TODO` / `FIXME` remains on shipped surfaces in `agents/` / `core/` / `hooks/` / `scripts/`
- Before creating a tag, runs `node scripts/build-opencode.js` / `node scripts/validate-opencode.js` / `bash scripts/sync-skill-mirrors.sh --check` and verifies that mirror drift in `opencode/`, `skills-codex/`, `codex/.codex/skills/` is 0
- When available, verifies that the latest CI status is successful

The mirror drift gate is a fail gate before the release tag. If `build-opencode.js` generates a diff,
preflight fails and the diff must be committed before proceeding to tag creation.

Actions runtime audit (2026-05-11): repo workflows use `actions/checkout@v6`; Node setup uses `actions/setup-node@v6`; Go setup uses `actions/setup-go@v6`. These v6 action lines run on the Node 24 action runtime and avoid the Node 20 deprecation warning.

## Usage

```bash
scripts/release-preflight.sh
scripts/release-preflight.sh --root /path/to/other/repo
```

## Environment variables

- `HARNESS_RELEASE_PROJECT_ROOT`: Root path when inspecting another repo
- `HARNESS_RELEASE_HEALTHCHECK_CMD`: Repo-specific healthcheck command
- `HARNESS_RELEASE_CI_STATUS_CMD`: Command to replace CI status checking

## Relationship with dry-run

Even with `/release --dry-run`, preflight always runs.
dry-run means "do not perform publishing operations." Preflight means "verify it is safe to publish."
They are separate concerns — preflight is not skipped even in dry-run mode.

## GitHub Release workflow

In `.github/workflows/release.yml`, `bash ./scripts/release-preflight.sh --check-adapters`
is run before creating a GitHub Release or uploading assets to an existing release.

Tag-triggered workflows run with a detached HEAD, so CI status unavailability is treated as
a warning boundary. The release-ready judgment is based on the assumption that preflight
failures — clean tree, mirror drift, adapter smoke, distribution archive gate — are all 0.

`tests/test-distribution-archive.sh` validates the shape of the distribution from `git archive HEAD`.
This verifies committed artifacts; dirty/untracked local files are not included.
Therefore, use it in combination with clean-tree preflight before making release claims.
