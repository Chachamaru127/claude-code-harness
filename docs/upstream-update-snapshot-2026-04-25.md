# Claude Code / Codex upstream snapshot - 2026-04-25

This snapshot confirms the official upstream as of 2026-04-25 and breaks down items
to be directly integrated into Claude Code Harness versus those to be left as
automatic inheritance / future tasks.

Confirmed on:

- 2026-04-25 (Asia/Tokyo)

Primary sources:

- Claude Code docs changelog: <https://code.claude.com/docs/en/changelog>
- Claude Code GitHub changelog: <https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md>
- OpenAI Codex releases: <https://github.com/openai/codex/releases>
- OpenAI Codex `rust-v0.124.0` release tag: <https://github.com/openai/codex/releases/tag/rust-v0.124.0>

Confirmed versions:

- Claude Code `2.1.119`
- Codex `0.124.0` stable
- Codex `0.125.0-alpha.2` pre-release

Classifications:

- `A: Validation strengthening`: Fix the upstream tracking decision in the current snapshot / Feature Table / CHANGELOG / tests without changing Harness implementation.
- `C: Automatic inheritance`: Receive improvements from Claude Code / Codex core as-is. Overlaying Harness wrappers would create dual responsibilities.
- `P: Future task`: Do not implement this time, but leave as a next-round candidate in Plans. Do not implement speculatively from alpha or unstable specs.

## Version-by-version breakdown

| Version | Upstream item | How it improves | Category | Harness surface | Harness action |
|---------|---------------|-----------------|----------|-----------------|----------------|
| Claude Code 2.1.119 | `/config` settings persist to `~/.claude/settings.json` and join project/local/policy precedence | Local theme / editor / verbose settings survive restarts, and priority order with managed settings becomes clearer | P | setup / managed settings docs | Overlaps with Phase 53's plugin-managed-settings policy; consolidate into a precedence table in next setup docs update |
| Claude Code 2.1.119 | `prUrlTemplate` customizes footer PR badge URLs | Teams using GitHub Enterprise / GitLab / Bitbucket can navigate to the correct review page from the footer | P | review / release docs | Review GitHub-fixed PR guidance and keep as a future candidate for enterprise git host support |
| Claude Code 2.1.119 | `--print` honors agent `tools:` and `disallowedTools:` frontmatter | The same tool restrictions that apply in interactive mode work in CI / script execution | A | upstream snapshot / tests | Record `--print` frontmatter parity in Phase 56 as a gate candidate for future CI review runners |
| Claude Code 2.1.119 | `--agent <name>` honors `permissionMode` for built-in agents | Built-in agent permission policy is reflected in main-thread agent execution | P | agents / permission docs | Leave together with Phase 53's `--agent` + `mcpServers` follow-up in the agents audit |
| Claude Code 2.1.119 | `PostToolUse` and `PostToolUseFailure` inputs include `duration_ms` | Can measure tool execution time from the hook side and use it for diagnosing slow processes | P | hooks / session monitor | High value to incorporate into Session Monitor or hook telemetry, but separate into another task before changing existing hook JSON shape |
| Claude Code 2.1.119 | OTEL `tool_result` / `tool_decision` include `tool_use_id`, and `tool_result` includes `tool_input_size_bytes` | Easier to correlate traces with tool input size | P | telemetry docs | Follow-up candidate when working with Harness telemetry. Do not add schema wrapper for now |
| Claude Code 2.1.119 | Status line stdin JSON includes `effort.level` and `thinking.enabled` | Can display thinking intensity and thinking state from the status line | P | statusline / session monitor | Worth including in Harness status line but separate into another task for UI display policy |
| Claude Code 2.1.119 | Subagent and SDK MCP server reconfiguration connects servers in parallel; MCP OAuth / headers / client secret / env placeholder fixes | MCP reconfiguration and auth become stable | C | MCP runtime | Auto-inherit core improvement. Do not add reconfiguration wrapper or OAuth workaround on Harness side |
| Claude Code 2.1.119 | `blockedMarketplaces` correctly enforces `hostPattern` and `pathPattern` entries | Fewer loopholes in managed marketplace policy | C | managed settings | Auto-inherit as core fix to Phase 53 policy |
| Claude Code 2.1.119 | Glob/Grep tools no longer disappear on native macOS/Linux when Bash is denied; auto mode no longer overrides plan mode | Behavior under Bash deny / plan mode becomes stable | C | permissions / search / Auto Mode | Auto-inherit core fix. Harness does not relax Bash deny or add more Auto Mode guidance |
| Codex 0.124.0 | TUI quick reasoning controls and model-upgrade reasoning reset | Can quickly adjust reasoning level from TUI; avoid stale reasoning on model change | C | Codex TUI | Auto-inherit as core UX. Do not change Harness skill frontmatter |
| Codex 0.124.0 | App-server sessions manage multiple environments and choose environment / working directory per turn | Easier to handle multiple workspaces / remote environments in the same session | P | Codex workflow / branch policy | Cut multi-environment branch/workdir policy as a Phase 56 follow-up |
| Codex 0.124.0 | First-class Amazon Bedrock support for OpenAI-compatible providers with AWS SigV4 auth | Easier to handle Bedrock usage on Codex side as an official provider | C | Codex provider docs | Maintain Phase 53 provider policy with automatic inheritance; docs refresh when needed |
| Codex 0.124.0 | Remote plugin marketplaces can be listed and read directly | Easier to check remote plugin sources | P | plugin mirror policy | Add as a follow-up candidate for Harness plugin mirror / marketplace source policy |
| Codex 0.124.0 | Hooks are stable, configurable inline in `config.toml` and managed `requirements.toml`, and can observe MCP tools, `apply_patch`, and long-running Bash | Can create stable hook policy on Codex side too | P | Codex hooks / guardrails / tests | Separate Claude Code hooks and Codex hooks parity into another task. Do not change `config.toml` speculatively |
| Codex 0.124.0 | Eligible ChatGPT plans default to Fast service tier unless explicitly opted out | Faster responses for eligible plans | C | runtime UX | Auto-inherit as core / plan-side behavior. Harness does not fix service tier |
| Codex 0.124.0 | Permission-mode drift, `wait_agent` queued mailbox timeout, relative stdio MCP command resolution, managed config startup edge cases | permissions / subagent wait / MCP startup / managed config become stable | C | Codex runtime | Auto-inherit core fixes. Do not change Harness worker prompt or setup defaults |
| Codex 0.125.0-alpha.2 | Pre-release tag exists, release body is thin | Can detect upcoming changes early | P | upstream watch | Do not implement speculatively from alpha. Re-confirm when stable release or sufficient release notes are published |

## Phase 56 follow-up candidates

| Follow-up | Why it matters | Suggested Plans owner |
|-----------|----------------|-----------------------|
| Consider whether to include Claude Code `PostToolUse.duration_ms` in Session Monitor / hook telemetry | Can explain slow hook / tool execution to users | hooks / session monitor |
| Consider whether to include Claude Code status line `effort.level` / `thinking.enabled` in Harness status line | Can visualize "what intensity is it thinking at" during long-running work | statusline / session monitor |
| Organize `prUrlTemplate` / `--from-pr` multi-host review support | Review paths for GitHub Enterprise / GitLab / Bitbucket users become more natural | harness-review / release |
| Codex `0.124.0` stable hooks and Claude Code hooks parity review | Possible to leverage Codex-side stable hooks for guardrail / long-running Bash / MCP tool observation | Codex package / guardrails |
| Codex multi-environment app-server and branch/workdir policy | Can reduce confusion between multiple repos / worktrees / remote environments | Codex workflow |

## Phase 56.2 closeout

Phase 56 follow-up decisions are recorded in `docs/upstream-followups-phase56-2026-04-25.md`.

Key points:

- `PostToolUse.duration_ms` is no-op this time; leave per-tool telemetry sink as a separate task
- `effort.level` / `thinking.enabled` are incorporated into `scripts/statusline-harness.sh` and also saved to statusline telemetry
- Codex stable hooks are parity-reviewed only; leave only a comment for no-op reason in `codex/.codex/config.toml`
- `prUrlTemplate` / `--from-pr` multi-host review is docs-only; maintain GitHub-first automation for owner / branch / CI
- Codex multi-environment app-server is treated as workflow guidance; adopt safe default of limiting writes to 1 primary environment per turn and adding a write guard

## Why B: Documentation-only is 0 items

- All Feature Table Phase 56 addition rows are connected to this snapshot and Phase 56 tasks in Plans.
- This time, distributed hooks / settings / guardrails were not changed; official diffs were classified as `A: Validation strengthening`, `C: Automatic inheritance`, `P: Future task`.
- `A` is "validation strengthening through Phase 56 snapshot and upstream integration tests" — not fabricating an implementation.
- `P` is left as a follow-up task in Plans; no speculative implementation from the unstable `0.125.0-alpha.2`.

## No-op adaptation decision

This time is a no-op adaptation.

Reasons:

- Most of Claude Code `2.1.119` are core runtime / TUI / MCP OAuth / managed settings fixes; overlaying Harness wrappers easily creates dual responsibilities.
- Codex `0.124.0` stable hooks are valuable, but their config surface differs from Claude Code hooks. It is safer to cut as a Codex hooks parity review than to immediately add hooks to `codex/.codex/config.toml`.
- The pre-release Codex `0.125.0-alpha.2` has a thin release body; do not implement speculatively from comparison.
