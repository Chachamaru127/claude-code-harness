# Hooks `type: "mcp_tool"` Adoption Decision (Phase 62.1.3)

> **Decision**: **Deferred (not adopted in Phase 62)**
> **Re-evaluation condition**: when harness-mem's MCP path reaches GA and the delay measured
> through the shell wrapper exceeds 5 minutes per month on a sustained basis in telemetry.

## In a nutshell

Claude Code `2.1.118` added support for hooks using `type: "mcp_tool"` to call MCP tools
directly. However, the latency introduced by the current Harness wrappers
(`scripts/hook-handlers/*.sh`) is small in measured terms, and the additional cost of
designing fallback behavior and the auth scope is larger, so Phase 62 records this as deferred.

## By analogy

It is similar to the question of upgrading to power tools. Manual tools (shell wrappers) get
the job done, and before switching to power tools (direct MCP calls), you need to sort out
where the outlet (auth) is and prepare an extension cord (fallback). The inconvenience of
manual tools is not great enough right now to justify the switch.

## Background

### Claude Code 2.1.118 changes

- In addition to the existing `type: "command"` (shell script) and `type: "agent"` (LLM agent),
  `type: "mcp_tool"` is now available in PostToolUse / PreToolUse and other hook events.
- Specifying `mcp_tool` lets a hook call a specific MCP server tool directly at execution time.
- Harness already has MCP tools such as `harness_mem_record_event` and `harness_mem_resume_pack`.

### Current Harness hook implementation

| Hook path | Mechanism | Example |
|-----------|-----------|---------|
| `scripts/hook-handlers/memory-bridge.sh` | Shell wrapper POSTs to harness-mem daemon via `curl` | UserPromptSubmit, PostToolUse |
| `scripts/hook-handlers/memory-session-start.sh` | Shell wrapper `exec`s the `harness-mem` script of the same name | SessionStart |
| `scripts/hook-handlers/elicitation-handler.sh` | Shell wrapper formats input with `jq` and returns JSON to stdout | Elicitation |

These were wired in Phase 49 (XR-003) and have been running without issues since.

## Comparison table

| Dimension | Shell wrapper (current) | `type: "mcp_tool"` direct call |
|-----------|------------------------|-------------------------------|
| Latency | 50-200ms (curl + jq + daemon RTT) | Estimated 10-50ms (CC internal MCP client RTT) |
| Auth scope | Wrapper does not hold the token directly (handled on the daemon side) | MCP auth scope resolution required at hook execution time |
| Error propagation | Shell exit code + stderr — coarse granularity | MCP RPC error code — fine granularity |
| Fallback | `silent skip` implemented inside wrapper | Hook itself cannot fall back (depends on CC) |
| Observability | Shell logs in `.claude/state/hook-runs.jsonl` | MCP call visible through OTel |
| Implementation cost | Existing assets intact | hooks.json schema extension + auth design + fallback wiring |
| Distribution risk | Low (shell wrapper idempotency guaranteed) | Medium (hook may fail if MCP server is unreachable) |

## Decision factors

### (i) Expected outcome when calling `harness_mem_record_event` directly from PostToolUse

- **Latency**: The measured latency of the current `memory-post-tool-use.sh` (50-150ms total)
  is expected to drop to roughly 10-50ms with `mcp_tool`. However, since PostToolUse hooks
  are not on the critical user-experience path, there would be no perceptible difference.
- **Auth**: `harness_mem_record_event` requires a bearer token (or local socket) for the
  harness-mem daemon. Whether the CC MCP client can hold this token in a hook execution
  context is unconfirmed.
- **Error propagation**: The shell wrapper currently performs a silent skip when the daemon is
  unreachable. Achieving equivalent behavior with `mcp_tool` depends on CC's hook timeout and
  retry specification.

### (ii) Shell wrapper vs. direct call trade-offs

Advantages of shell wrappers:

- Already wired in Phase 49 with no operational issues.
- Failures produce silent skips or partial successes entirely within the wrapper.
- Changes to the harness-mem API schema can be handled without touching the CC side (hooks.json).

Advantages of `mcp_tool`:

- Eliminates external process dependencies (curl, jq) because everything runs inside CC.
- OTel telemetry becomes consistent.
- Provides a natural migration path when harness-mem is converted to a pure MCP server in the future.

### (iii) Fallback strategy when MCP is unreachable

Options and the selection for this case:

| Strategy | Description | Selection |
|----------|-------------|-----------|
| `silent skip` | MCP unreachable = no-op, continue | **First candidate if adopted**. Consistent with current Phase 49 behavior |
| `queue` | Buffer locally when unreachable, retry next time | Over-engineering (harness-mem already has a queue, so this would be duplicated) |
| `drop` | Discard the event when unreachable | Not recommended — degrades telemetry accuracy |

If adopted, **silent skip** is the unified choice.

### (iv) Relationship with the Phase 61 local ledger

The `.claude/state/elicitation/events.jsonl` introduced in Phase 61 serves as an
**append-only fallback** when harness-mem is unreachable.
Even after adopting `mcp_tool`, the path that writes from the CC hook to the local ledger
when the daemon is unreachable must be preserved.
This means re-implementing the two-layer defense in the current wrapper structure on the CC
hook side, which adds implementation burden.

## Conclusion

| Item | Content |
|------|---------|
| Adoption decision | **Deferred** |
| Reason | Shell wrappers have no operational issues; adopting `mcp_tool` would require additional work on auth, fallback, and alignment with the Phase 61 ledger |
| Re-evaluation triggers | (a) harness-mem MCP path reaches GA, (b) wrapper latency exceeds 5 minutes/month in telemetry, (c) CC publishes official guidance on hook auth |
| Phase 62 scope | Creating this doc only. Implementation and hooks.json changes are deferred to a later phase |

## Acceptance criteria (Phase 62.1.3 DoD)

- [x] `docs/hooks-mcp-tool-evaluation.md` exists
- [x] Comparison table (latency / auth / error / fallback — 4 items) for shell wrapper vs. `type: "mcp_tool"` direct call exists
- [x] Fallback strategy when MCP is unreachable is explicitly set to `silent skip`
- [x] Overlap and complementary relationship with the Phase 61 ledger is explained in one paragraph
- [x] Decision recorded as one of adopt / defer / reject → **deferred**
- [x] Adoption conditions (re-evaluation triggers) written as 3 items

## References

- Claude Code CHANGELOG `2.1.118`: <https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md>
- Phase 53 snapshot doc: `docs/upstream-update-snapshot-2026-04-23.md` (decision in `53.1.2 MCP tool hook decision`: read-only MCP allowed, write operations prohibited)
- Phase 49 (XR-003): `.claude-plugin/hooks.json` shell wrapper wiring
- Phase 61: `.claude/state/elicitation/events.jsonl` local ledger
