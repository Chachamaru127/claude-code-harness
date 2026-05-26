# Session ID Env Policy (Phase 62.2.4)

> **Status**: Active (2026-05-07)
> **Background**: As of Claude Code `2.1.132`, `CLAUDE_CODE_SESSION_ID` is passed as an
> environment variable to Bash subprocesses. This document clarifies the available routes
> for obtaining the session ID in hook handlers, shell wrappers, and CLI helpers, and
> prevents confusion about which route to use.

## In brief

There are **4 routes** for obtaining the session ID, and the correct one depends on context.
For hook handlers, **stdin JSON (`.session_id`)** is the right choice — do not rely on the env var.
Use the env var (`CLAUDE_CODE_SESSION_ID`) only when a Bash child process needs the session ID.

## Analogy

Think of it like not confusing your house key with your car key.
The hook handler receives the key directly from CC (stdin), so it uses that.
Bash child processes (subshells launched by rg / jq / curl) are not called directly by CC,
so they need to fetch the key from the "key rack" (env var).

## The 4 routes

| # | Route | Source | When to use |
|---|-------|--------|-------------|
| 1 | stdin JSON `.session_id` | hook input | **Primary route for hook handlers** |
| 2 | `CLAUDE_CODE_SESSION_ID` env var | OS env | Bash child processes, CLI helpers |
| 3 | `.session_id` in `.claude/state/session.json` | local state file | Long-lived watchers such as session-monitor / session-broadcast |
| 4 | regex extract from `CLAUDE_TRANSCRIPT_PATH` | env var (regex) | **Do not use (legacy)** |

## Which to use

### (1) Inside a hook handler → stdin JSON

```bash
SESSION_ID="$(printf '%s' "${INPUT}" | jq -r '.session_id // ""')"
```

Reason: Hook handlers receive JSON input from CC. The stdin JSON is the SSOT.

Relying on the env var risks inheriting the parent session's env during parallel
multi-session execution (Bash subprocesses inherit the parent env).

### (2) Bash child process → `CLAUDE_CODE_SESSION_ID` env var (CC 2.1.132+)

```bash
# Example: when a jq subprocess launched from scripts/codex-companion.sh needs the session ID
SESSION_ID="${CLAUDE_CODE_SESSION_ID:-}"
if [ -z "${SESSION_ID}" ]; then
  echo "[warn] CLAUDE_CODE_SESSION_ID not set; running on CC 2.1.131 or older" >&2
  SESSION_ID="unknown"
fi
```

Reason: Bash child processes do not receive stdin directly from CC, so the env var is
the only available route. On CC `2.1.131` or older the env var does not exist, so an
`unknown` fallback is required.

### (3) Long-running watcher → `.claude/state/session.json`

```bash
SESSION_ID="$(jq -r '.session_id // "unknown"' "${PROJECT_ROOT}/.claude/state/session.json")"
```

Reason: Session-monitor / session-broadcast and similar processes run continuously after
session start, so the state file is the SSOT. They cannot read env / stdin.

### (4) regex extract from `CLAUDE_TRANSCRIPT_PATH` → do not use

Legacy example: `echo "$CLAUDE_TRANSCRIPT_PATH" | sed 's|.*/\([a-f0-9-]*\)\.json|\1|'`

Problems:
- The transcript path format may change between CC versions
- A broken regex requires complex fallback handling
- The `CLAUDE_CODE_SESSION_ID` env var is available directly (CC 2.1.132+)

**Not used in the current Harness**. Do not adopt it in new implementations either.

## 3-state test naming convention (following `.claude/rules/active-watching-test-policy.md`)

Test scripts that deal with session ID retrieval must cover all of the following states:

| State | Name | Expected behavior |
|-------|------|-------------------|
| Healthy | `TestSessionIdEnv_Healthy` | env var present → use it directly |
| NotConfigured | `TestSessionIdEnv_NotConfigured` | env absent → fall back to state file; no warning emitted |
| Corrupted | `TestSessionIdEnv_Corrupted` | both env and state absent → `unknown` fallback; warning emitted |

## Related docs

- `.claude/rules/active-watching-test-policy.md` — 3-state test policy
- `docs/long-running-harness.md` — env inheritance in long-running sessions
- Claude Code 2.1.132 CHANGELOG: Added `CLAUDE_CODE_SESSION_ID` environment variable to Bash tool subprocess environment

## Acceptance criteria (Phase 62.2.4 DoD)

- [x] The 4 routes and when to use each are documented
- [x] It is documented that hook handlers use the stdin JSON route (no env dependency)
- [x] Fallback for CC 2.1.131 and older is shown
- [x] Aligned with the 3-state test policy (`.claude/rules/active-watching-test-policy.md`)
- [x] It is documented that regex extract from `CLAUDE_TRANSCRIPT_PATH` must not be used
