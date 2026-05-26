# Active Watching Test Policy

Testing requirements to follow when adding **new features that actively monitor external processes, files, or daemons** (e.g., Session Monitor).
Operationalizes D40 (tri-state health) and P29 (dual hooks sync) as rules, providing the SSOT for eliminating regressions like the "false warning to non-installed users" seen in v4.3.3 from the earliest phase.

## Why This Rule Is Necessary

Immediately after adding `harness-mem` active monitoring to Session Monitor in v4.3.1,
a v4.3.3 hotfix was needed to fix a regression where `⚠️ harness-mem unhealthy: not-initialized`
was displayed every session for users who had `~/.claude-mem/` absent (i.e., users who had not opted in to harness-mem).

The root cause was relying solely on inclusion-based testing and not writing tests for the state where **the dependency does not exist**.
Active watching often depends on opt-in external resources, and **covering all 3 states — not-installed / not-running / corrupted — from the start** is the only way to prevent recurrence.

## Scope

Follow this policy when adding new code that matches any of the following:

- Adding a new health check to `go/internal/session/monitor.go`
- Probing an external daemon or HTTP endpoint from `scripts/hook-handlers/` or similar
- Reading optional directories under `~/.claude-*/` or `$HOME/`
- Monitoring the running state of an MCP server
- Checking the availability of a Codex daemon or external CLI per session
- Surfacing the availability of an external resource via `additionalContext` in `UserPromptSubmit` or `SessionStart` hooks

Conversely, the following are out of scope:

- Sanity checks for required dependencies (Go standard library, `bin/harness` itself)
- Tests that run only in CI environments (where dependencies are guaranteed to be present)

## Defining the 3 States

States that an active-watching dependency can be in, and the expected behavior for each:

| State | Identifier (reason) | `healthy` | Exit | Monitor warning | Typical example |
|------|----------------|-----------|------|------------|--------|
| Not installed / opt-in not used | `not-configured` | **true** | 0 | **Do not emit** | `~/.claude-mem/` absent |
| Not running / unreachable | `daemon-unreachable`, `timeout`, `unreachable` | false | 1 | Emit | TCP connect failure |
| Configuration corrupted / file missing | `corrupted`, `invalid-config` | false | 1 | Emit | settings.json absent |
| Healthy | `""` | true | 0 | Do not emit | All components OK |

Key principles:

- **"Not in use" is not the same as "broken"**. Do not emit warnings for a state where an opt-in feature is simply not being used.
- Concentrate the determination logic on the **health check subcommand side** so that the behavior is consistent across Monitor and other callers (D40).
- `healthy=true + reason="not-configured"` must always be treated by the Monitor implementation as the contract for suppressing warnings.

## Test Naming Conventions

Write at least one test for each of the 3 states. Use the following fixed naming scheme.

| State | Test function name pattern | What to verify |
|------|-------------------|---------|
| `not-configured` | `TestXxx_NotConfigured` | `exit=0`, `healthy=true`, `reason="not-configured"`, Monitor emits no warning |
| `unreachable` | `TestXxx_DaemonUnreachable` or `TestXxx_Unreachable` | `exit=1`, `healthy=false`, specific reason string, Monitor emits warning |
| `corrupted` | `TestXxx_Corrupted` | `exit=1`, `healthy=false`, `reason="corrupted"`, Monitor emits warning |
| Healthy | `TestXxx_Healthy` | `exit=0`, `healthy=true`, `reason=""`, Monitor passes silently |

Prepare Monitor-side integration tests using the same naming conventions (e.g., `TestMonitorHandler_XxxNotConfigured`).

## Checklist

Verify the following when including an active-watching feature in a PR:

- [ ] Wrote 4 tests on the health check side (healthy + 3 failure states)
- [ ] Wrote an integration test on the Monitor side asserting that no warning is emitted for `not-configured`
- [ ] Enumerated `reason` strings as an enum (do not use free text; document them in a table)
- [ ] The Monitor side references the `healthy=true + reason="not-configured"` contract
- [ ] Naming conventions do not conflict with existing dependencies (e.g., `harness-mem`)
- [ ] Documented the 3 states in documentation (e.g., `go/SPEC.md`)

## Case Study Appendix: v4.3.3 harness-mem Hotfix

The direct triggering case that gave rise to this policy. Reference it as a model for test structure.

- **Background commit**: [`23589344`](https://github.com/Chachamaru127/claude-code-harness/commit/23589344) (PR #98 / v4.3.3 hotfix)
- **Health check implementation**: `runMemHealthCheck()` in `go/cmd/harness/mem.go` — returns `not-configured` via two-stage early return (`UserHomeDir` failure / `~/.claude-mem/` absent)
- **Health check tests**: `go/cmd/harness/mem_test.go`
  - `TestRunMemHealth_Healthy`
  - `TestRunMemHealth_DaemonUnreachable`
  - `TestRunMemHealth_NotConfigured` ← the core of 3-state coverage
  - `TestRunMemHealth_Corrupted`
- **Monitor integration tests**: `go/internal/session/monitor_test.go`
  - `TestMonitorHandler_HarnessMemHealthy`
  - `TestMonitorHandler_HarnessMemUnhealthy` (fixture reason = `daemon-unreachable`)
  - `TestMonitorHandler_HarnessMemNotConfigured` ← explicitly asserts no warning is emitted

What this case confirmed: **a regression occurs if even 1 of the 3 states is missing**.
If the `not-configured` test had been written from the start, the problem would have been caught at v4.3.1.

## Related Rules

- [D40](../memory/decisions.md) — Design decision behind tri-state health (the theoretical basis of this policy)
- [P29](../memory/patterns.md) — dual hooks.json sync + CI gate (prevention of recurrence on the wiring side)
- [migration-policy.md](./migration-policy.md) — Sister policy for exclusion-based verification (deleted residue vs. absent dependency)
- [test-quality.md](./test-quality.md) — General test quality (prohibition of hollow tests)
- [implementation-quality.md](./implementation-quality.md) — General implementation quality
