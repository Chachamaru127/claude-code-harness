# Host Workflow Smoke Policy (Phase 111.2)

Last updated: 2026-07-09

## Modes

| Mode | Env | Meaning |
|------|-----|---------|
| Structural (default) | — | Build host dist, assert core skills, write plan artifact from `harness-plan` SKILL.md |
| Required | `HARNESS_<HOST>_WORKFLOW_SMOKE_REQUIRED=1` | Structural failures fail the job |
| Live (optional) | `HARNESS_<HOST>_WORKFLOW_SMOKE_LIVE=1` | Reserve for real model/CLI plan sessions (costly; not default CI) |

## Promotion rules

| Target tier | Minimum smoke |
|-------------|----------------|
| `candidate` | static adapter tests |
| `internal-compatible` | structural workflow smoke green + install/setup evidence |
| `supported` (正式対応) | structural **plus** live or CI-gated plan→artifact with host CLI, plus H1–H8 full bar |

Structural smoke alone is **not** enough for public `supported`.

## Commands

```bash
bash tests/test-host-smoke-lib.sh
bash tests/test-host-workflow-smoke.sh --host grok
bash tests/test-host-workflow-smoke.sh --host cursor
bash tests/test-host-workflow-smoke.sh --host codex
bash tests/test-host-workflow-smoke.sh --host claude

HARNESS_GROK_WORKFLOW_SMOKE_REQUIRED=1 bash tests/test-host-workflow-smoke.sh --host grok
```

Evidence lands in `out/workflow-smoke/<host>/` (gitignored via `out/` if present).

## CI posture (111.2.3)

- **PR / validate-plugin path**: structural smoke for registry hosts is recommended on adapter path changes.
- **Nightly / release**: may set `*_WORKFLOW_SMOKE_REQUIRED=1` when CLI images and secrets are available.
- **Live model**: never required on every PR (cost + flake). Record decision in decisions.md when promoting to `supported`.

## Live operator runbook (H4)

Copy-paste commands and reply keywords:

- `docs/onboarding/host-live-cli-smoke.md`
- `bash scripts/print-live-cli-smoke.sh keywords`
- `bash scripts/print-live-cli-smoke.sh claude|codex|cursor|grok`

Operator replies with one line, e.g. `LIVE: grok PASS`, so the agent can update
Plans / evidence without re-deriving the procedure.
