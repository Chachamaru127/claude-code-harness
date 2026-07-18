# Claude Code Compatibility

Last updated: 2026-07-10

## Supported Baseline

- Claude Code: `v2.1+`
- Plugin version: `5.2.0`
- Guardrail runtime: bundled Go-native `harness` binary

Node.js is not required for the Go-native guardrail engine. Optional skills and
repository maintenance scripts can still declare their own tool requirements;
that does not change the runtime baseline above.

## Latest Verified Snapshot

The 2026-07-10 local audit verified these version surfaces:

- `VERSION`: `5.0.0`
- `.claude-plugin/plugin.json`: `5.0.0`
- `harness.toml`: `5.0.0`
- `./bin/harness-darwin-arm64 version`: `5.0.0 (Hokage)`

The binary observation is for the shipped macOS arm64 artifact only. Other
platform binaries remain subject to the repository's binary/source drift and
release checks; this snapshot does not claim that they were executed locally.

Host support tiers are not maintained in this document. They are derived from
[`hosts/registry.json`](../hosts/registry.json) and checked against public docs
by `tests/test-host-registry.sh` and `tests/test-support-claim-wording.sh`.

## Maintenance Policy

Compatibility has two layers:

- **Supported baseline**: the minimum supported Claude Code version and the
  current plugin/runtime architecture.
- **Dated verification**: the version surfaces and commands actually observed
  on a stated date.

Do not infer a full version matrix from a dated snapshot. After upgrading
Claude Code or the plugin, rerun the checks below before publishing a stronger
compatibility claim.

## What This Compatibility Promise Covers

- `/harness-setup`, `/harness-plan`, `/harness-work`, `/harness-review`, and
  `/harness-release`
- the Go-native policy and hook runtime under [`go/`](../go)
- hook shims under [`hooks/`](../hooks)
- packaging, host-tier, and mirror checks enforced by CI

## Windows Checkout Note

On Windows, Git often defaults to `core.symlinks=false`. Public `harness-*`
command skills are shipped as real directories in `skills/`,
`codex/.codex/skills/`, and `opencode/skills/`, so they remain discoverable
after checkout. Session-start repair still handles broken extension links under
`skills/extensions/`.

Native Windows Git Bash/MSYS/Cygwin sessions resolve
`bin/harness-windows-amd64.exe` through the `bin/harness` shim. WSL2 sessions
use the Linux binary. Windows hook behavior and binary/source parity remain
release-gated checks, not assumptions made by this document.

## What Requires Extra Validation

These paths depend on host tools or local environment setup and must be checked
in the environment where they will run:

- Breezing / agent teams
- Codex CLI integration
- Cursor workflows (`internal-compatible`, not public `supported`)
- video or slide generation
- memory / daemon integrations

## Recommended Upgrade Check

All commands below exist in the current repository:

```bash
./tests/validate-plugin.sh
./scripts/ci/check-consistency.sh
bash tests/test-host-registry.sh
bash tests/test-support-claim-wording.sh
cd go && go test ./...
bash scripts/release-preflight.sh --dry-run
```

If you rely on `/harness-work all`, also run the success/failure fixture
contract in [Work All Evidence Pack](evidence/work-all.md).
