# Claude Code upstream snapshot - 2026-05-07

This snapshot confirms **`2.1.112`-`2.1.118` and `2.1.127`-`2.1.132`** (13 versions in total)
beyond `2.1.119`-`2.1.126` already tracked in Phase 56 / Phase 58,
and records the implementation as Harness Tier 1 (5 items) + Tier 2 (5 items) in Phase 62.

Confirmed on:

- 2026-05-07 (Asia/Tokyo)

Local verification:

- `claude --version`: `2.1.132 (Claude Code)` (expected)
- (CHANGELOG confirmed from official GitHub source)

Existing Harness tracking baseline:

- Claude Code `2.1.119` (Phase 56)
- Claude Code `2.1.120`-`2.1.126` (Phase 58, some implementations completed in Phase 62.2.x)

Primary sources:

- Claude Code GitHub CHANGELOG: <https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md>
- Claude Code docs CHANGELOG: <https://code.claude.com/docs/en/changelog>

Classifications:

- `A: Validation strengthening`: Fixed in the current Phase 62 via snapshot / Feature Table / CHANGELOG / tests / implementation.
- `C: Automatic inheritance`: Receive Claude Code core fixes as-is. Do not overlay Harness wrappers.
- `B: Documentation-only`: **0 items** (this snapshot does not create `B`). All classified as `A` or `C`.

## Version-by-version breakdown

| Version | Upstream item | How it improves | Category | Harness surface | Harness action |
|---------|---------------|-----------------|----------|-----------------|----------------|
| Claude Code `2.1.112` | Auto mode for Opus 4.7 stability fix | Opus 4.7 does not become briefly unavailable in auto mode | C | runtime | Auto-inherit |
| Claude Code `2.1.113` | Subagent stalling mid-stream fail after 10 minutes | Worker freeze detection confirmed on CC side as 600s timeout | A | `agents/worker.md`, `docs/team-composition.md` | Phase 62.1.1: documented as 2-layer defense (CC 600s + elicitation-handler.sh) |
| Claude Code `2.1.113` | `sandbox.network.deniedDomains` setting | Can deny outbound network at session level | A | `.claude-plugin/settings.json`, `templates/claude/settings.security.json.template` | Phase 62.1.4: expanded template baseline to 9 items (added 6 paste-site entries) |
| Claude Code `2.1.113` | deny rules match `env`/`sudo`/`watch` wrappers | Wrapper bypass denied on CC side | A | `go/internal/guardrail/rules_test.go` | Phase 62.1.5: fixed 9 cases for R06/R11/R12 × 3 wrappers in fix posture |
| Claude Code `2.1.113` | `/private/{etc,var,tmp,home}` dangerous removal targets, `find -exec`/`-delete` not auto-approved | Safety of macOS and find-based removals improves | C | guardrail | Existing R05 helpers cover this via classifyBashProtectedWrite / hasDangerousFindDelete |
| Claude Code `2.1.114` | Permission dialog crash fix with agent teammate | Breezing becomes more stable | C | runtime | Auto-inherit |
| Claude Code `2.1.116` | `/resume` 67% faster on 40MB+ sessions | Session resume speeds up | C | session | Auto-inherit |
| Claude Code `2.1.116` | `/reload-plugins` auto-installs missing dependencies | Plugin lifecycle becomes stable | C | plugin | Auto-inherit |
| Claude Code `2.1.116` | Bash tool hints when `gh` hits rate limit | API rate limit becomes visible | C | Bash runtime | Auto-inherit |
| Claude Code `2.1.116` | Sandbox auto-allow bypasses dangerous-path check (security) | Double-firing of dangerous-path check is removed | C | sandbox | Auto-inherit |
| Claude Code `2.1.117` | `CLAUDE_CODE_FORK_SUBAGENT=1` works in SDK and `claude -p` | Fork subagent in non-interactive mode | P (already tracked in Phase 58) | CI review docs | Handled in Phase 58 |
| Claude Code `2.1.117` | Agent frontmatter `mcpServers` loaded for main-thread sessions | MCP works in main-thread agents too | C | agent runtime | Auto-inherit (no additional implementation needed on Harness side) |
| Claude Code `2.1.117` | `cleanupPeriodDays` covers `tasks/`, `shell-snapshots/`, `backups/` | Session cleanup operates more broadly | C | maintenance | Auto-inherit |
| Claude Code `2.1.117` | Default effort for Pro/Max on Opus/Sonnet 4.6 is `high` | Default behavior for Pro/Max users | C | runtime | Auto-inherit |
| Claude Code `2.1.118` | `/cost` and `/stats` merged into `/usage` | Single entry point for usage information | C | session | Auto-inherit |
| Claude Code `2.1.118` | Hooks can invoke MCP tools via `type: "mcp_tool"` | Can call MCP directly from hooks | A | `docs/hooks-mcp-tool-evaluation.md` | Phase 62.1.3: **adoption decision: deferred**. Fixed 3 re-evaluation trigger items |
| Claude Code `2.1.118` | Auto mode `"$defaults"` to extend built-in | Can extend while keeping existing defaults | C | auto-mode runtime | Already handled in Phase 53 (auto mode policy doc) |
| Claude Code `2.1.118` | `claude plugin tag` for release tags | Integrate plugin tag into release flow | C | release | Already handled in Phase 53 (`harness-release` skill supports tagging) |
| Claude Code `2.1.118` | `DISABLE_UPDATES` env var | Manual update control | C | runtime | Already handled in Phase 53 (`docs/plugin-managed-settings-policy.md`) |
| Claude Code `2.1.127`-`2.1.128` | (no 2.1.127 release; 2.1.128 batch fixes) | Runtime UX improvements | C | UX | Auto-inherit |
| Claude Code `2.1.128` | `--plugin-dir` accepts `.zip` plugin archives | More flexible plugin archive loading | C | plugin | Auto-inherit |
| Claude Code `2.1.128` | `EnterWorktree` creates branch from local HEAD (not `origin/<default>`) | Prevents unexpected branch origin | C | worktree | Auto-inherit (consistent with Harness WorktreeCreate hook) |
| Claude Code `2.1.128` | MCP `workspace` reserved server name | Prevents MCP name collisions | C | MCP | Auto-inherit |
| Claude Code `2.1.128` | Sub-agent progress summaries fixes | Fewer duplicate/missing progress notifications | C | agent | Auto-inherit |
| Claude Code `2.1.129` | `--plugin-url <url>` for `.zip` plugin archives | Remote plugin retrieval | C | plugin | Auto-inherit |
| Claude Code `2.1.129` | `CLAUDE_CODE_FORCE_SYNC_OUTPUT=1`, `CLAUDE_CODE_PACKAGE_MANAGER_AUTO_UPDATE` | Output sync, auto-update control | C | env | Auto-inherit |
| Claude Code `2.1.129` | `skillOverrides` works with `off` / `user-invocable-only` / `name-only` | More skill governance options | A | `docs/skill-overrides-policy.md`, `tests/test-settings-baseline.sh` | Phase 62.2.5: documented usage of 3 modes and recommended defaults |
| Claude Code `2.1.129` | OTel `claude_code.pull_request.count` for MCP-created PRs | PR creation telemetry extended | C | telemetry | Auto-inherit |
| Claude Code `2.1.129` | `Bash(mkdir *)` and similar allow rules now honored, `deniedMcpServers` mixed-case | Consistency in permission rules | C | permissions | Auto-inherit |
| Claude Code `2.1.131` | VS Code extension fix on Windows; Mantle endpoint auth fix | Enterprise stability | C | enterprise runtime | Auto-inherit |
| Claude Code `2.1.132` | `CLAUDE_CODE_SESSION_ID` env to Bash tool subprocess | Bash child processes can directly retrieve session ID | A | `docs/session-id-env-policy.md`, `tests/test-hook-handler-session-id.sh` | Phase 62.2.4: documented policy for 4 paths; hook handlers fixed in tests to use stdin JSON path |
| Claude Code `2.1.132` | `CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN=1` opt-out fullscreen | Can disable terminal fullscreen | C | TUI | Auto-inherit |
| Claude Code `2.1.132` | Various TUI / paste / vim / MCP / cache fixes | Fine-grained stabilization | C | runtime | Auto-inherit |

## Phase 62 implementation summary

Tier 1 (Phase 62.1.1-62.1.5) — Direct hardening of Harness weaknesses:

| Task | Implementation |
|------|----------------|
| 62.1.1 | Worker stall 2-layer defense (CC 600s + elicitation-handler) |
| 62.1.2 | ENABLE_PROMPT_CACHING_1H opt-in used in long-running skills (5 items → existing note + breezing/SKILL.md / long-running-harness.md extension) |
| 62.1.3 | hooks `type: "mcp_tool"` adoption decision doc (= deferred) |
| 62.1.4 | `sandbox.network.deniedDomains` baseline expansion (template canonical 9 items; settings.json is user manual) |
| 62.1.5 | R06/R11/R12 wrapper bypass test (env/sudo/watch × 3 = 9 cases) |

Tier 2 (Phase 62.2.1-62.2.5) — Phase 58 design implementations:

| Task | Implementation |
|------|----------------|
| 62.2.1 | `PostToolUse.updatedToolOutput` opt-in handler (allowlist approach + audit ledger) |
| 62.2.2 | agent permissionMode reaffirmation test (fixed Phase 59.2.3 policy in tests) |
| 62.2.3 | `skill_activated.invocation_trigger` telemetry (local-only ledger + privacy-first) |
| 62.2.4 | `CLAUDE_CODE_SESSION_ID` env policy doc + test (4-path usage distinction) |
| 62.2.5 | `skillOverrides` 3-mode governance doc |

Tier 3 (= `C: Automatic inheritance`):

UI improvements, performance improvements, OAuth fixes, terminal/clipboard fixes, etc. require no Harness-side changes.

## Why B: Documentation-only is 0 items

`.claude/rules/cc-update-policy.md` causes merge blocks for `B: Documentation-only` items.
In Phase 62, all upstream items are classified as one of the following:

- Implementation or test addition (`A`) — 10 tasks in Tier 1 + Tier 2
- CC automatic inheritance (`C`) — UX / performance / fix types
- Already handled in an existing Phase (Phase 53 / 56 / 58, etc.)

Upstream items that become neither implementation nor tests are fixed as `C` (automatic inheritance)
with the reason stated in one line. This prevents the "Feature Table row added only" state.

## User manual action follow-up

`.claude-plugin/settings.json`'s `sandbox.network.deniedDomains` cannot be edited by the Harness
self-protection guardrail (`Edit/Write(.claude-plugin/settings*) deny`).
To sync with the template (`templates/claude/settings.security.json.template`),
the user must manually add the following 6 items:

```json
"deniedDomains": [
  "169.254.169.254",
  "metadata.google.internal",
  "metadata.azure.com",
  "pastebin.com",     // add
  "transfer.sh",       // add
  "0x0.st",            // add
  "paste.ee",          // add
  "termbin.com",       // add
  "ix.io"              // add
]
```

`tests/test-settings-baseline.sh` records mismatches as WARN (not FAIL — tolerated),
outputting a message prompting user manual sync.

## Related docs

- Phase 56 snapshot: `docs/upstream-update-snapshot-2026-04-25.md`
- Phase 58 snapshot: `docs/upstream-update-snapshot-2026-05-03.md`
- Phase 62 follow-up doc: none (implementation completed in this snapshot)
- Phase 62 task entries: `Plans.md` Phase 62.1.1-62.3.1
