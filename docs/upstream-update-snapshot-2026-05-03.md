# Claude Code / Codex upstream snapshot - 2026-05-03

This snapshot confirms unaddressed upstream changes since Phase 56 and splits them into:
items to add to Claude Code Harness now, items to plan, and items to auto-inherit.

Confirmed on:

- 2026-05-03 (Asia/Tokyo)

Local verification:

- `claude --version`: `2.1.126 (Claude Code)`
- `codex --version`: `codex-cli 0.128.0`

Existing Harness tracking baseline:

- Claude Code `2.1.119`
- Codex `0.124.0` stable
- Codex `0.125.0-alpha.2` watch
- Details: `docs/upstream-update-snapshot-2026-04-25.md`

Primary sources:

- Claude Code docs changelog: <https://code.claude.com/docs/en/changelog>
- Claude Code GitHub changelog: <https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md>
- OpenAI Codex releases: <https://github.com/openai/codex/releases>
- OpenAI Codex `rust-v0.125.0` release tag: <https://github.com/openai/codex/releases/tag/rust-v0.125.0>
- OpenAI Codex `rust-v0.128.0` release tag: <https://github.com/openai/codex/releases/tag/rust-v0.128.0>
- OpenAI Codex `rust-v0.128.0...rust-v0.129.0-alpha.2` compare: <https://github.com/openai/codex/compare/rust-v0.128.0...rust-v0.129.0-alpha.2>

Classifications:

- `A: Validation strengthening`: Fix upstream tracking decision in current snapshot / Feature Table / CHANGELOG / tests.
- `C: Automatic inheritance`: Receive Claude Code / Codex core fixes as-is. Do not overlay Harness wrappers.
- `P: Plans`: Has value for Harness, but do not implement at runtime in this snapshot PR; cut into Phase 58 tasks.

## Version-by-version breakdown

| Version | Upstream item | How it improves | Category | Harness surface | Harness action |
|---------|---------------|-----------------|----------|-----------------|----------------|
| Claude Code `2.1.120` | On Windows without Git Bash, use PowerShell tool | Shell execution in Claude Code works more easily in initial Windows environments | P | Windows compatibility / setup docs | Together with Phase 57 Windows worktree fix, confirm PowerShell primary shell documentation/tests in Phase 58.2.3 |
| Claude Code `2.1.120` | `claude ultrareview [target]` and `--json` | Easier to call Claude Code review from CI or scripts | P | `harness-review` / CI docs | Do not conflict with `/harness-review`; leave comparison of non-interactive review input and JSON stdout contract for Phase 58.2.3 |
| Claude Code `2.1.120` | Skills can reference `${CLAUDE_EFFORT}` | Skill body can be aware of current effort | P | skills / prompt guidance | Confirm value of adding effort conditional branching in Harness skills in Phase 58.2.3 |
| Claude Code `2.1.120` | `AI_AGENT` env for subprocesses | Easier attribution of agent traffic in external CLIs like `gh` | C | CLI runtime | Inherit from core without adding env wrapper on Harness side |
| Claude Code `2.1.120` | `claude plugin validate` accepts additional schema fields | Validation acceptance range for marketplace / plugin widens | P | plugin validation / release docs | Revisit validation guidance for `.claude-plugin/marketplace.json` and `plugin.json` in Phase 58.2.3 |
| Claude Code `2.1.120` | telemetry disable, false dangerous-rm prompt, Bash `find` fd exhaustion fixes | Existing operations become stable; false positives and host-wide crashes reduced | C | permissions / Bash runtime | Auto-inherit core fixes without adding Harness wrappers |
| Claude Code `2.1.121` | `PostToolUse` hooks can replace output for all tools via `hookSpecificOutput.updatedToolOutput` | Scope for handling tool output redaction / compaction / normalization in hooks expands | P | hooks / telemetry / output governance | Do not rewrite tool output by default; cut opt-in redaction / compaction and audit trail design into Phase 58.2.2 |
| Claude Code `2.1.121` | `--dangerously-skip-permissions` no longer prompts for writes to `.claude/skills/`, `.claude/agents/`, `.claude/commands/` | Skip mode UX speeds up, but affects Harness skill / agent / command integrity | P | guardrail / protected paths / tests | Harden protected path classification that must be maintained even under `dangerously-skip` in Phase 58.2.1 |
| Claude Code `2.1.121` | MCP `alwaysLoad`, startup retry, `mcp_authenticate.redirectUri`, `claude plugin prune` | MCP / plugin startup and cleanup become stable | P | setup / MCP docs / plugin lifecycle | Leave always-load vs deferred MCP boundary and safe path for plugin prune in Phase 58.2.3 |
| Claude Code `2.1.121` | `CLAUDE_CODE_FORK_SUBAGENT=1` works in SDK and `claude -p` | Easier to use fork subagent in non-interactive sessions | P | CI review / agent docs | Confirm compatibility with Harness CI / headless review runner in Phase 58.2.3 |
| Claude Code `2.1.122` | `ANTHROPIC_BEDROCK_SERVICE_TIER` | Can choose `default` / `flex` / `priority` when using Bedrock | P | provider setup docs | Leave as Claude Code Bedrock setup guidance in Phase 58.2.3 without mixing with Codex provider policy |
| Claude Code `2.1.122` | `/resume` PR URL search for GitHub Enterprise / GitLab / Bitbucket | Easier to find related sessions from PR URLs | P | review / session docs | Connect to Phase 56's docs-only multi-host policy; maintain GitHub-first for automation |
| Claude Code `2.1.122` | OpenTelemetry numeric attrs and `claude_code.at_mention` | Telemetry schema becomes more machine-processable | P | telemetry docs | Confirm schema drift together with skill activation telemetry in Phase 58.2.3 |
| Claude Code `2.1.122` | malformed hooks entry no longer invalidates entire settings file | Less likely for entire settings to be invalidated by partial corruption | C | hooks / settings runtime | Harness settings generator continues to produce valid JSON. Auto-inherit core fix |
| Claude Code `2.1.123` | OAuth 401 retry loop fix when `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1` | Fewer login-disabled loops | C | auth runtime | No Harness changes needed |
| Claude Code `2.1.126` | `claude project purge [path]` | Can delete transcripts / tasks / file history / config entries all at once | P | cleanup / maintenance docs | Cut safe procedures that don't mix Harness state cleanup with `--dry-run` as prerequisite in Phase 58.2.3 |
| Claude Code `2.1.126` | `--dangerously-skip-permissions` bypasses writes to `.claude/`, `.git/`, `.vscode/`, shell config files, and other protected paths | Dangerous skip mode becomes stronger; need to document Harness safety boundaries explicitly | P | guardrail / protected paths / permission docs | Design and implement deny / ask / warn boundary for `.claude/`, `.git/`, `.vscode/`, shell config files in Phase 58.2.1 |
| Claude Code `2.1.126` | Security fix for `allowManagedDomainsOnly` / `allowManagedReadPathsOnly` precedence | Fewer loopholes in managed sandbox policy | P | settings security consistency | Re-confirm managed sandbox boundary in Harness settings / template / consistency check in Phase 58.2.1 |
| Claude Code `2.1.126` | `claude_code.skill_activated` includes `invocation_trigger` and user slash command activation | Easier to distinguish skill launch paths in telemetry | P | telemetry / skill analytics | Consider including in Harness skill usage analysis in Phase 58.2.3 |
| Claude Code `2.1.126` | gateway `/v1/models` model picker, OAuth code paste, PowerShell 7 detection, deferred tools for forked skills/subagents | gateway / Windows / fork context runtime becomes stable | C/P | setup / Windows / agents | Basically auto-inherit. Document only what is necessary for Windows / forked skill guidance in Phase 58.2.3 |
| Codex `0.125.0` stable | App-server Unix socket, sticky environments, remote thread config/store, pagination-friendly resume/fork | Session management for app-server / remote environments becomes stronger | P | Codex workflow / app-server docs | Maintain Phase 56's one primary environment policy while organizing sticky environments in Phase 58.3.2 |
| Codex `0.125.0` stable | Remote plugin install and marketplace upgrade | Codex-side plugin lifecycle becomes practical | P | Codex plugin setup / marketplace docs | Cut paths that don't conflict with Harness plugin mirror policy into Phase 58.3.2 |
| Codex `0.125.0` stable | Permission profiles round-trip across TUI, user turns, MCP sandbox state, shell escalation, app-server APIs | Easier to keep permission state consistent across multiple surfaces | P | `codex/.codex/config.toml` / requirements / sandbox docs | Organize diff between current config and profile-based policy in Phase 58.3.1 |
| Codex `0.125.0` stable | `codex exec --json` reports reasoning-token usage | Programmatic consumers can see reasoning tokens | P | codex loop telemetry / reports | Consider including in `harness-loop` / breezing usage report in Phase 58.3.1 |
| Codex `0.125.0` stable | Rollout tracing records tool, code-mode, session, and multi-agent relationships | Multi-agent execution traces become more readable | P | agent trace / diagnostics | Confirm whether to integrate with existing AgentTrace in Phase 58.3.1 |
| Codex `0.128.0` stable | Persisted `/goal` workflows | Can create / pause / resume / clear goals | P | Plans / goal workflow | Leave as candidate in Phase 58.3.2 with the premise of not duplicating with `Plans.md` SSOT |
| Codex `0.128.0` stable | `codex update`, configurable keymaps, plan-mode nudges, `/statusline` and `/title` during active turns | Codex TUI long-running work UX improves | P | Codex setup / loop docs | Add setup docs and long-running status guidance as update candidates in Phase 58.3.1 |
| Codex `0.128.0` stable | Built-in permission profiles, sandbox CLI profile selection, cwd controls, active-profile metadata | Can shift to explicit permission profiles | P | Codex config / sandbox / `--full-auto` deprecation | Cut migration from `--full-auto` to explicit profiles into Phase 58.3.1 |
| Codex `0.128.0` stable | Plugin workflows: marketplace install, remote bundle caching/uninstall, plugin-bundled hooks, hook enablement state, external-agent config import | Plugin and hook distribution/enablement state becomes richer | P | Codex plugin / hooks / setup docs | Re-evaluate Phase 56's no-inline-hooks policy and compare plugin-bundled hooks in Phase 58.3.2 |
| Codex `0.128.0` stable | MultiAgentV2 thread caps, wait-time controls, root/subagent hints, depth handling | Multi-agent execution control becomes more granular | P | breezing / codex agents config | Verify relationship between `agents.max_threads` and MultiAgentV2 config in Phase 58.3.2 |
| Codex `0.128.0` stable | Managed network hardening, Bedrock `apply_patch`, MCP/plugin cleanup | Fewer accidents around network / provider / MCP | P/C | guardrails / provider docs | Do not duplicate in Harness; cut only necessary config docs and tests into Phase 58.3.1 |
| Codex `0.128.0` stable | `--full-auto` deprecated in favor of explicit permission profiles and trust flows | Permission intent becomes clearer | P | Codex docs / setup scripts | Review old `--full-auto` guidance in Phase 58.3.1 |
| Codex `0.129.0-alpha.2` pre-release | alpha body is thin; compare shows hooks browser, workspace plugin sharing, MCP output truncation, apply_patch streaming, sandbox/app-server changes | Can grasp direction of next stable early | P | upstream watch | Do not implement speculatively from alpha. Re-confirm when stable release or detailed release notes are published |

## Phase 58 follow-up candidates

Detailed follow-up decisions: `docs/upstream-followups-phase58-2026-05-03.md`

| Follow-up | Why it matters | Suggested Plans owner |
|-----------|----------------|-----------------------|
| Claude protected-write and `dangerously-skip` hardening | The protected write bypass scope in skip mode expanded with 2.1.121 / 2.1.126; redefine Harness deny / ask / warn boundary | 58.2.1 |
| `PostToolUse.updatedToolOutput` output governance | All tool output can now be replaced via hook; fix opt-in / audit / no-default-mutation before convenience | 58.2.2 |
| Claude setup / MCP / telemetry refresh | `alwaysLoad`, `plugin prune`, Bedrock service tier, project purge, skill activation telemetry affect setup guidance | 58.2.3 |
| Codex permission profiles and `--full-auto` migration | Profile-backed permissions became central with 0.125.0 / 0.128.0; review old flag guidance in Harness Codex docs | 58.3.1 |
| Codex plugin hooks, `/goal`, MultiAgentV2, app-server updates | 0.128.0 has large plugin/hook/workflow surface; needs design that doesn't duplicate Plans SSOT | 58.3.2 |

## Why B: Documentation-only is 0 items

- Only Phase 58 aggregated rows are added to the Feature Table, connected to this snapshot and `Plans.md` `58.1.1`-`58.3.2`.
- The current runtime implementation targets are not speculatively implemented on the spot; they are decomposed into DoD-bearing tasks as `P: Plans`.
- `A` is treated as validation strengthening through the Phase 58 snapshot / upstream integration tests.
- For `C`, the reasons for automatically inheriting Claude Code / Codex core bug fixes are stated explicitly.
- Codex `0.129.0-alpha.2` is alpha; no speculative implementation from comparison.

## No-op adaptation decision for this snapshot

This snapshot itself is a no-op adaptation.

Reasons:

- Claude Code `2.1.121` / `2.1.126` permission changes are important, but immediately denying all of `.claude/` could break rules / memory / setup updates. Cut the protected path taxonomy first in Phase 58.2.1.
- `PostToolUse.updatedToolOutput` is powerful, but rewriting tool output by default reduces debugability. Design opt-in and audit trail first in Phase 58.2.2.
- Codex `0.128.0` permission profiles / plugin hooks are valuable, but Phase 56 just placed a no-inline-hooks policy; separate the responsibilities of profile-backed policy and plugin-bundled hooks in Phase 58.3.x.
- `0.129.0-alpha.2` is pre-release with a thin release body; keep it on watch until stable.
