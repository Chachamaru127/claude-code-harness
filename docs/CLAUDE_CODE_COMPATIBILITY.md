# Claude Code Compatibility

Last updated: 2026-03-12

## Supported Baseline

- Claude Code: `v2.1+`
- Node.js: `18+`
- Plugin version: `3.10.2`

## Latest Verified Snapshot

The most recent local verification snapshot for this repository was:

- Claude Code `2.1.74`
- Node.js `v24.10.0`
- `./tests/test-task-completed-finalize.sh`
- `./tests/test-fix-proposal-flow.sh`
- `./tests/validate-plugin.sh`
- `./tests/validate-plugin-v3.sh`
- `./scripts/ci/check-consistency.sh`
- `cd core && npm test`

This snapshot is a verification reference, not a hard upper bound. If you upgrade Claude Code or Node.js, rerun the commands above before trusting the environment.

## Maintenance Policy

To keep this document maintainable, we intentionally track compatibility in two layers:

- **Supported baseline**: the minimum supported Claude Code / Node.js versions
- **Latest verified snapshot**: the newest environment we actually reran locally

We do **not** maintain a full version-by-version support matrix in the README. That tends to drift quickly and costs more to maintain than it returns. If we need deeper notes about feature adoption, we keep them in dedicated docs instead of the landing page.

## What This Compatibility Promise Covers

- `/harness-setup`, `/harness-plan`, `/harness-work`, `/harness-review`, `/harness-release`
- TypeScript guardrail engine in [`core/`](../core)
- Hook shims in [`hooks/`](../hooks)
- Packaging and mirror checks enforced by CI

## Windows Checkout Note

On Windows, Git often defaults to `core.symlinks=false`. Public `harness-*` command skills are therefore shipped as real directories in `skills/`, `codex/.codex/skills/`, and `opencode/skills/` so they still appear in command lists after checkout. Session start repair still handles broken extension links inside `skills/extensions/`.

Native Windows Git Bash/MSYS/Cygwin sessions resolve `bin/harness-windows-amd64.exe` through the `bin/harness` shim. WSL2 sessions keep using the Linux binary. Breezing worktree isolation should therefore have a real hook binary on Windows amd64 instead of silently falling back because no platform binary was found.

## What Requires Extra Validation

These flows are supported, but they depend on extra tools or environment setup and should be verified in your own environment:

- Breezing / agent teams
- Codex CLI integration
- Cursor 2-agent workflow
- Video or slide generation
- Memory / daemon integrations

## Recommended Upgrade Check

Run this set after updating Claude Code, Node.js, or the plugin itself:

```bash
./tests/validate-plugin.sh
./tests/validate-plugin-v3.sh
./scripts/ci/check-consistency.sh
cd core && npm test
```

If you also rely on `/harness-work all`, run the success/failure fixture contract in [Work All Evidence Pack](evidence/work-all.md).
