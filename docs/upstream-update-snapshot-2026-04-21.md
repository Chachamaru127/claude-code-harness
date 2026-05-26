# Claude Code / Codex upstream snapshot - 2026-04-21

This snapshot confirms the official upstream as of 2026-04-21 and breaks down items to be directly
integrated into Claude Code Harness versus those to be left as automatic inheritance / Plans items.

Primary sources:

- Claude Code changelog: <https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md>
- Claude Code docs changelog: <https://code.claude.com/docs/en/changelog>
- OpenAI Codex releases: <https://github.com/openai/codex/releases>

## Version-by-version breakdown

| Version | Upstream item | Category | Harness surface | Action |
|---------|---------------|----------|-----------------|--------|
| Claude Code 2.1.116 | Large-session `/resume` is faster and handles dead-fork entries more efficiently | C | session resume/fork UX | No Harness session-control changes needed. Confirm it does not conflict with large-transcript resume guidance |
| Claude Code 2.1.116 | MCP startup defers `resources/templates/list` until first `@` mention | C | MCP / `@` mention guidance | Do not change Harness MCP setup. If building MCP health watch in future, assume deferred startup |
| Claude Code 2.1.116 | `/reload-plugins` and background auto-update install missing marketplace dependencies | P | plugin setup / marketplace docs | Revisit plugin dependency policy description and setup smoke in a follow-up. Do not overlay a dependency resolver on Harness for now |
| Claude Code 2.1.116 | Sandbox auto-allow no longer bypasses dangerous-path safety for `rm` / `rmdir` | C | guardrail / Bash safety | Same direction as Phase 51 R05 guardrail. Maintain existing tests on Harness side and inherit CC core fix automatically |
| Claude Code 2.1.116 | Agent frontmatter `hooks:` fire for main-thread agents via `--agent` | P | agents / skills docs | Leave for a follow-up audit whether Harness agents assume hook prerequisites under `--agent` main-thread execution |
| Claude Code 2.1.116 | Bash tool shows GitHub API rate-limit hints for `gh` commands | P | ci / release / review skills | Candidate to reflect `gh` retry/backoff guidance in CI / release skills. No implementation this time; add to Plans |
| Codex 0.122.0 | `/side` conversations and queued slash / `!` shell prompts while work is running | P | long-running work guidance | Possibly useful for the "side question while work is running" UX in Harness loop / breezing. Handle together with Codex-native skill audit |
| Codex 0.122.0 | Plan Mode can start implementation in a fresh context with context usage shown | P | `/plan-with-agent` / `/work --codex` handoff | Compare with Plan -> Work context carry policy. Do not change Harness phase model immediately |
| Codex 0.122.0 | Plugin workflows add tabbed browsing, toggles, marketplace removal, remote/cross-repo/local sources | P | plugin mirror / setup policy | Carry over to follow-up cleanup for Harness plugin mirror policy and marketplace source policy |
| Codex 0.122.0 | Filesystem permissions add deny-read glob, managed deny-read, platform sandbox enforcement, isolated `codex exec` | P | sandbox / guardrail | Different axis from Claude-side `sandbox.network.deniedDomains`. Leave for follow-up comparison as Codex mirror sandbox policy |
| Codex 0.122.0 | Tool discovery and image generation default-on, higher-detail image handling | P | Codex mirror skill metadata | Leave for drift audit on allowed-tools / image skill / tool discovery guidance |
| Codex 0.122.0 | App-server stale prompt dismissal and resume/fork token usage replay | C/P | session resume / heartbeat | Codex core UX is automatic inheritance. Overlap with Harness heartbeat / resume summary to be confirmed in a follow-up |
| Codex 0.123.0-alpha.2 | Pre-release with thin release body | P | future compare | Do not implement speculatively from release body. Re-confirm when stabilized or release notes become more detailed |

## UX judgement

There are few upstream features that should be implemented in Harness immediately this time.
Since `AskUserQuestion.updatedInput` and Claude 2.1.113 hardening were already implemented in Phase 51,
the safe approach for 2.1.116 / Codex 0.122.0 is to check "does it conflict with existing implementation"
and "should it be deferred to the follow-up setup / Codex-native skill audit."

Reasons not to implement directly:

- Most of Claude 2.1.116 are CC core TUI / resume / plugin updater improvements; overlaying Harness wrappers is likely to create behavioral differences and dual responsibilities.
- Codex 0.122.0 includes large design changes such as plugin workflow / filesystem permission / Plan Mode, and these are easier to handle concurrently with the existing Phase 51.2 Codex-native skill audit to avoid breaking dependencies.
- Codex 0.123.0-alpha.2 is pre-release and the release body is thin, so no speculative implementation from comparison.

## Follow-up candidates

- Organize the integration plan for Codex plugin marketplace source policy and Harness mirror policy together with Phase 51.2.3.
- Decide whether to add retry/backoff policy responding to `gh` rate-limit hints to CI / release / review skills.
- Confirm whether `--agent` main-thread hook behavior should be reflected in Harness agents' frontmatter policy.
- Create a diff table between Codex deny-read glob / isolated `codex exec` and Harness sandbox / guardrail policy.
