# Phase 58 Follow-up Decisions - 2026-05-03

This document is a decision memo for separating Phase 58's unaddressed upstream items into
"things that should be designed before implementing now" and "things that can be automatically inherited."

## In one sentence

**Harness does not immediately wrap Claude Code / Codex new features; it first fixes safety
boundaries and user navigation paths.**

## Analogy

When a new tool arrives, rather than distributing it to everyone immediately, you attach
a protective cover to sharp blades and decide which shelf and label to use before bringing
it to the floor.

## Official References

- Claude Code changelog: <https://code.claude.com/docs/en/changelog>
- Claude Code GitHub changelog: <https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md>
- OpenAI Codex `rust-v0.125.0` release: <https://github.com/openai/codex/releases/tag/rust-v0.125.0>
- OpenAI Codex `rust-v0.128.0` release: <https://github.com/openai/codex/releases/tag/rust-v0.128.0>
- OpenAI Codex `0.129.0-alpha.2` compare: <https://github.com/openai/codex/compare/rust-v0.128.0...rust-v0.129.0-alpha.2>

## 58.2.1 Claude protected-write and `dangerously-skip` hardening

### Current Harness surface

| Surface | Current state | Gap from upstream |
|---------|---------------|-------------------|
| `go/internal/guardrail/helpers.go` | Treats `.git/`, `.env`, keys, `.husky/` as protected paths | Claude Code 2.1.121 / 2.1.126 skip mode added prompt bypass for `.claude/`, `.vscode/`, shell config files, etc. |
| `go/internal/guardrail/rules.go` | Blocks / asks / warns for Write/Edit/MultiEdit and Bash writes | Immediately denying all of `.claude/` could break rules / memory / setup updates |
| `.claude-plugin/settings.json` / `harness.toml` | Syncs sandbox denied domains etc. | Need to recheck managed sandbox boundary after `allowManagedDomainsOnly` / `allowManagedReadPathsOnly` precedence bug fix |

### Decision

- **Do not immediately deny all of `.claude/`**
- First create a protected path taxonomy:
  - deny: `.git/`, secrets, shell rc / profile files, destructive hook entrypoints
  - ask: `.claude/skills/`, `.claude/agents/`, `.claude/commands/`, `.vscode/`
  - warn: `.claude/rules/`, `.claude/memory/`, project-local setup metadata
- Even in sessions using `--dangerously-skip-permissions`, do not relax guardrails within the Harness hook scope
- Verify managed sandbox in the order: `harness.toml` → generated settings → template → tests

### Acceptance target

- Protected path table is in docs or rule comment
- Go guardrail tests have deny/ask/warn expectations for `.claude/skills`, `.claude/agents`, `.claude/commands`, `.vscode`, shell config files
- `tests/test-claude-upstream-integration.sh` detects Phase 58 hardening coverage
- Does not over-deny normal setup / memory / rules updates

## 58.2.2 `PostToolUse.updatedToolOutput` output governance

### Current Harness surface

Phase 56 made `PostToolUse.duration_ms` a no-op.
The reason was that there is no per-tool telemetry sink and mixing session duration with tool duration creates confusion.

Claude Code 2.1.121 allows `PostToolUse` to return `hookSpecificOutput.updatedToolOutput` for all tools.

### Decision

- **Do not rewrite tool output by default**
- Use opt-in only
- First candidates are limited to redaction / compaction / machine-readable normalization
- Do not lose traceability between original output and updated output
- Do not use for purposes that erase review or test evidence

### Acceptance target

- Permitted / prohibited uses of `updatedToolOutput` are documented
- When implementing: test before/after/audit record
- For tools with JSON-contract stdout, do not mix human-readable explanations into stdout

## 58.2.3 Claude setup / MCP / telemetry refresh

### Decision

Treat the following as setup / docs / validation candidates, not runtime wrappers:

| Item | Decision |
|------|----------|
| `claude ultrareview [target] --json` | Do not compete with `/harness-review`; keep in comparison task as CI second-opinion |
| `${CLAUDE_EFFORT}` | Has value for skill prompt tuning, but do not mechanically add to all skills |
| `claude plugin validate` schema acceptance | Confirm in release / marketplace validation docs |
| MCP `alwaysLoad` | Keep usage distinction between always-load and deferred discovery in setup docs |
| `claude plugin prune` | Candidate for documentation as stale dependency cleanup. However, prioritize dry-run equivalent explanations since uninstall/prune is destructive |
| `ANTHROPIC_BEDROCK_SERVICE_TIER` | Treat as Claude Code Bedrock guidance; do not mix with Codex provider policy |
| `claude project purge` | Do not mix with Harness state cleanup; make it maintenance guidance with `--dry-run` first |
| `claude_code.skill_activated.invocation_trigger` | Has value for skill analytics, but telemetry sink design comes first |

## 58.3.1 Codex permission profiles and `--full-auto` migration

### Current Harness surface

`codex/.codex/config.toml` has the no-inline-hooks policy recorded in Phase 56.
Codex `0.125.0` / `0.128.0` made significant advances with permission profiles and sandbox profile controls.

### Decision

- Do not add `--full-auto` as the default in new docs
- Steer toward explicit permission profiles / trust flows as the primary path
- Treat `requirements.toml` as a place for org-managed policy; do not speculatively add to distribution defaults
- Make `codex exec --json` reasoning token usage a loop / report telemetry candidate
- Confirm rollout tracing doesn't duplicate existing AgentTrace

### Acceptance target

- Inventory stale `--full-auto` guidance with `rg`
- Codex permission profile examples do not contradict config surface
- If adding immediate hooks to `codex/.codex/config.toml`, add Codex package tests
- If continuing as no-op, leave reason in config comment / docs / tests

## 58.3.2 Codex plugin hooks, `/goal`, MultiAgentV2, app-server updates

### Decision

| Item | Decision |
|------|----------|
| `/goal` workflows | Do not duplicate `Plans.md` SSOT. Treat goal as runtime continuation candidate for investigation |
| Plugin-bundled hooks / hook enablement state | Re-evaluate Phase 56 no-inline-hooks policy, but prioritize disabled-by-default and opt-in in distribution defaults |
| External agent import | Determine ownership boundaries between Claude / Codex / external agents before using |
| MultiAgentV2 thread caps / wait controls | Verify relationship between `agents.max_threads = 8` and v2-specific controls |
| Sticky environments / remote thread config | Maintain one primary environment per write turn; remote is read-only first |
| App-server release artifacts / Python SDK | Keep as docs-only unless Harness bundles the SDK |

## Why this way

Phase 58's upstream is not a simple docs refresh.
On the Claude side, permission / hook output mutation changed significantly; on the Codex side,
permission profiles / plugin hooks / goal workflow changed significantly.

Therefore, in this snapshot, rather than rushing to add runtime features, we first fix
"what to protect," "how far to auto-inherit," and "which task to implement in."
