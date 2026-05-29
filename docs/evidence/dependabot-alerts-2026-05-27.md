# Dependabot Alerts Snapshot - 2026-05-27

## Scope

Repository: `Chachamaru127/claude-code-harness`

Planning target: remaining open Dependabot alerts after the v4.12.4 security/i18n release.

## Live Alert Inventory

Command:

```bash
gh api --method GET \
  -H "Accept: application/vnd.github+json" \
  repos/Chachamaru127/claude-code-harness/dependabot/alerts \
  -f state=open
```

Observed open alerts: 10

All 10 alerts point to one tracked manifest:

- `benchmarks/breezing-bench/agent-eval/package-lock.json`

| Package | Alerts | Severity | Current | Patched | Source |
|---------|--------|----------|---------|---------|--------|
| `undici` | 6 | 3 high, 3 medium | `7.20.0` | `7.24.0` | `@vercel/sandbox -> undici` |
| `minimatch` | 3 | 3 high | `10.1.2` | `10.2.3` / `10.2.1` | `glob -> minimatch` |
| `uuid` | 1 | medium | `10.0.0` | `11.1.1` | `dockerode -> uuid` |

Current key package versions from the lockfile:

```text
node_modules/@vercel/agent-eval 0.0.11
node_modules/@vercel/sandbox    1.4.1
node_modules/dockerode          4.0.9
node_modules/minimatch          10.1.2
node_modules/undici             7.20.0
node_modules/uuid               10.0.0
```

## Local Audit Baseline

Command:

```bash
cd benchmarks/breezing-bench/agent-eval
npm audit --json
```

Observed result:

- npm audit grouped the 10 GitHub advisory alerts into 5 vulnerability objects.
- Metadata: 2 high, 3 moderate, 0 critical.
- `npm audit` suggested a fix path involving `@vercel/agent-eval@0.0.4`, which is a downgrade from the current direct dependency line.

## Remediation Matrix

Tested in temporary directories only; no repository files were modified during evaluation.

| Candidate | Result | Notes |
|-----------|--------|-------|
| `@vercel/agent-eval@0.14.1` only | audit still non-zero | `minimatch` fixed, but `undici` and `uuid` remained. |
| `@vercel/agent-eval@0.14.1` + `dockerode@5` + `undici/minimatch` overrides | audit 0, help OK | Wider transitive major override; keep as fallback. |
| `@vercel/agent-eval@0.14.1` + `undici/minimatch` overrides + scoped `dockerode.uuid` override | audit 0, help OK | Preferred: smaller than `dockerode@5` override and avoids `agent-eval` downgrade. |

Preferred package shape:

```json
{
  "dependencies": {
    "@vercel/agent-eval": "^0.14.1",
    "typescript": "^5.3.0"
  },
  "overrides": {
    "undici": "^7.24.0",
    "minimatch": "^10.2.4",
    "dockerode": {
      "uuid": "^11.1.1"
    }
  }
}
```

Temp lockfile proof from preferred candidate:

```text
npm audit: 0 vulnerabilities
node_modules/@vercel/agent-eval 0.14.1
node_modules/@vercel/sandbox    1.4.1
node_modules/dockerode          4.0.9
node_modules/minimatch          10.2.5
node_modules/undici             7.26.0
node_modules/uuid               11.1.1
agent-eval --help: exited 0
```

## Smoke Boundary

`agent-eval --help` passes under the preferred candidate.

`npm run eval:vanilla:dry` currently fails before dependency-specific behavior can be assessed:

```text
Error: Eval "task-01" not found. Available evals: task-11, task-12, task-13, task-14, task-15, task-16, task-17, task-18, task-19, task-20
```

This is a pre-existing benchmark configuration mismatch:

- `experiments/vanilla.ts` references `task-01` through `task-10`.
- `benchmarks/breezing-bench/agent-eval/evals/` currently contains `task-11` through `task-20`.

Closeout should not report benchmark dry-run success until this mismatch is either fixed or explicitly scoped out with a replacement smoke command.

## Final Remediation Evidence

Implemented remediation:

- `@vercel/agent-eval`: `^0.0.11` -> `^0.14.1`
- npm overrides:
  - `undici`: `^7.24.0`
  - `minimatch`: `^10.2.4`
  - `dockerode.uuid`: `^11.1.1`
- benchmark experiment task references: `task-01`-`task-10` -> `task-11`-`task-20`
- benchmark scripts: use local `agent-eval` binary from the installed lockfile instead of `npx @vercel/agent-eval`
- Dependabot npm updates added for `/benchmarks/breezing-bench/agent-eval`
- CI audit gate added via `tests/test-breezing-agent-eval-deps.sh`

Final lockfile proof:

```text
node_modules/@vercel/agent-eval 0.14.1
node_modules/@vercel/sandbox    1.4.1
node_modules/dockerode          4.0.9
node_modules/minimatch          10.2.5
node_modules/undici             7.26.0
node_modules/uuid               11.1.1
```

Verification:

```bash
bash tests/test-breezing-agent-eval-deps.sh
cd benchmarks/breezing-bench/agent-eval && npm audit --audit-level=moderate
cd benchmarks/breezing-bench/agent-eval && ./node_modules/.bin/agent-eval --help
cd benchmarks/breezing-bench/agent-eval && npm run eval:vanilla:dry
cd benchmarks/breezing-bench/agent-eval && npm run eval:breezing:dry
```

Observed result:

- `tests/test-breezing-agent-eval-deps.sh`: PASS
- `npm audit --audit-level=moderate`: 0 vulnerabilities
- `agent-eval --help`: exited 0
- `eval:smoke:dry`: found `task-11`, dry-run exited 0
- `eval:vanilla:dry`: found `task-11` through `task-20`, dry-run exited 0
- `eval:breezing:dry`: found `task-11` through `task-20`, dry-run exited 0

Full benchmark execution remains out of scope for this dependency closeout
because it requires the actual model/sandbox runtime path. The `smoke --dry`
and full-config dry runs are the intended dependency/runtime-start gates for
this phase.

## GitHub Closeout

Pull request:

- PR #159: https://github.com/Chachamaru127/claude-code-harness/pull/159
- Merge commit: `942fa996899179619b1ddeae7745eeedc70a4281`

Review and branch CI:

- `bash scripts/codex-companion.sh review --base origin/main`: APPROVE/no blocking finding
- `validate-plugin` branch run `26490923383`: success
- `smoke-install` branch run `26490923384`: success
- CodeRabbit: success (`Review skipped`)

Main closeout:

- `validate-plugin` main run `26491162442`: success
- `scorecard` main run `26491162444`: success
- `Dependabot Updates` runs `26491164580`, `26491164453`,
  `26491164490`, and `26491164507`: success
- `gh api .../dependabot/alerts -f state=open --jq 'length'`: `0`
- target manifest query for
  `benchmarks/breezing-bench/agent-eval/package-lock.json`: no open alerts

Release/tag action was intentionally skipped because this change remediates
benchmark tooling lockfile alerts and adds CI/Dependabot coverage, but does not
change shipped plugin runtime behavior or user-facing distribution metadata.

## External References

- GitHub REST API: Dependabot alerts for a repository: https://docs.github.com/en/rest/dependabot/alerts
- GitHub Dependabot alerts overview: https://docs.github.com/en/code-security/dependabot/dependabot-alerts/about-dependabot-alerts
- npm `package.json` `overrides`: https://docs.npmjs.com/cli/v11/configuring-npm/package-json#overrides
- npm audit command: https://docs.npmjs.com/cli/v11/commands/npm-audit
- GitHub Advisory `undici` patched range examples: https://github.com/advisories/GHSA-f269-vfmq-vjvj
- GitHub Advisory `minimatch` patched range examples: https://github.com/advisories/GHSA-7r86-cg39-jmmj
- GitHub Advisory `uuid` patched range: https://github.com/advisories/GHSA-w5hq-g745-h8pq
