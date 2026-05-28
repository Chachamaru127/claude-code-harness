# Bootstrap Routing Contract

Last updated: 2026-05-28

## Purpose

This document defines the Phase 73 bootstrap routing contract for Claude Code,
Codex CLI, Codex app, OpenCode, Cursor, GitHub Copilot CLI, and Antigravity CLI.
It keeps bootstrap proof, support tier, and public support claims separate.

Golden prompts in this document are a static contract fixture. They are not
runtime auto-routing proof. Passing this contract means the repository declares
the expected routing surface; it does not prove that a model invocation will
always auto-fire the matching skill at runtime.

## False Parity Rule

False parity is forbidden.

Claude SessionStart, Codex AGENTS.md, and OpenCode AGENTS.md are different
bootstrap mechanisms. They may point at the same conceptual workflow, but they
must not be described as equivalent runtime enforcement.

Candidate and unsupported hosts must not inherit Claude Code, Codex CLI, or
OpenCode bootstrap evidence. `not observed` means evidence is missing from the
current artifact set; it does not mean the capability is absent.

## Support Tier Boundary

| Host | Phase 73 bootstrap tier | Bootstrap claim boundary |
|---|---|---|
| Claude Code | `supported` | SessionStart, plugin instructions, skills, hooks, and release validation may be used as support evidence. |
| Codex CLI | `internal-compatible` | `codex/AGENTS.md`, Codex skills, setup scripts, and companion checks are internal compatibility evidence until direct plugin install and runtime smoke pass together. |
| Codex app | `candidate` | App behavior must be verified separately from Codex CLI; no app support claim before app-specific smoke evidence exists. |
| OpenCode | `internal-compatible` | `opencode/AGENTS.md` and mirror/package checks are compatibility evidence until runtime bootstrap smoke passes. |
| Cursor | `candidate` | `.cursor/AGENTS.md`, `.cursor-plugin/plugin.json`, rules/skills/agents, optional hooks/MCP config shape; static smoke via `tests/test-cursor-adapter-candidate.sh`; PM handoff docs are not adapter support. |
| GitHub Copilot CLI | `candidate` | Manual instruction or CLI profile research is allowed; no Harness support claim without Harness-specific bootstrap evidence. |
| Antigravity CLI | `future/unsupported` | No setup docs, bootstrap route, or support claim until an official or verified adapter route is observed. |

## Host Bootstrap Routes

### Claude SessionStart

Claude Code uses plugin instructions, root `CLAUDE.md`, skills in `skills/`,
and SessionStart-style guidance to make workflow routing visible when a
session begins.

Expected properties:

- Natural language prompts can be paired with slash commands and skills.
- Guardrails can use runtime hooks such as PreToolUse and PostToolUse.
- Bootstrap evidence can mention SessionStart, but it must not imply that
  Codex or OpenCode has the same hook surface.

### Codex AGENTS.md

Codex uses `codex/AGENTS.md`, project/user skill loading, and explicit
`$skill-name` invocation guidance.

Expected properties:

- Routing guidance must tell Codex which workflow skill matches a task family.
- Safety guidance follows the Codex model from `docs/hardening-parity.md`:
  contract injection + post quality gate + merge gate.
- Bootstrap evidence is AGENTS.md guidance, not SessionStart hook parity.

### OpenCode AGENTS.md

OpenCode uses `opencode/AGENTS.md`, `opencode/skills/`, and package validation
as its current bootstrap surface.

Expected properties:

- OpenCode routing guidance may mirror workflow names from Claude Code Harness.
- OpenCode validation proves package shape and stale-doc avoidance, not runtime
  auto-routing parity.
- OpenCode remains below Claude/Codex enforcement strength until adapter
  contract tests prove otherwise.

### Cursor AGENTS.md and Plugin Route

Cursor uses `.cursor/AGENTS.md`, `.cursor/rules/`, `.cursor-plugin/plugin.json`,
core `skills/` via the plugin manifest, `.cursor/agents/` subagents, and optional
`.cursor/hooks.json` / `.cursor/mcp.json` as its current bootstrap surface.

Expected properties:

- Routing guidance maps plan/work/review/sync/setup intents to Harness skills.
- Subagent frontmatter `model` and Task tool explicit `model` are adapter
  surfaces; they must follow `docs/model-routing-policy.md` priority (explicit
  override first, routed default second).
- Breezing parallel execution maps to Cursor subagents / background agents /
  multitask only as a smoke target. Core keeps review and cherry-pick serial.
- Bootstrap evidence is AGENTS.md + plugin manifest + static smoke, not Claude
  SessionStart hook parity.
- Cursor remains `candidate` until workflow smoke and release preflight pass.

Required smoke (static minimum):

```bash
bash tests/test-cursor-adapter-candidate.sh
```

Optional runtime evidence when Cursor CLI/Desktop is available:

```bash
HARNESS_CURSOR_ADAPTER_SMOKE_REQUIRED=1 bash tests/test-cursor-adapter-candidate.sh
```

Cloud Agent API smoke is optional paid/auth evidence and must not be conflated
with local Desktop/CLI adapter proof.

### Candidate Host Routes

Codex app, Cursor, and GitHub Copilot CLI are candidate hosts in Phase 73. Their
routes may be researched, documented, and smoke-tested, but they are not golden
prompt success routes until host-specific bootstrap evidence exists.

Expected properties:

- Candidate route docs must include the observed source, missing proof, and
  verification command or transcript needed to advance the tier.
- Candidate route failures must produce `candidate`, `not observed`, or
  `manual` evidence, not `supported` evidence.
- A host-specific adapter candidate must not claim safety, hook, or bootstrap
  parity from Claude Code, Codex CLI, or OpenCode.

### Unsupported Host Routes

Antigravity CLI is future/unsupported in Phase 73. It is part of the support
tier matrix so that unknown data stays visible, but it is not part of the
golden prompt fixture.

Expected properties:

- Unsupported routes must produce `future/unsupported`, `not observed`, or
  `manual` evidence.
- Unsupported routes must not publish setup docs that look like a verified
  install path.
- Unsupported routes can move to `candidate` only after an official or verified
  adapter/bootstrap route is recorded.

## Golden Prompts

These golden prompts are static contract fixture rows. They are used to check
that docs name the expected workflow for common user intent.

| Prompt fixture | Expected workflow | Claude SessionStart route | Codex AGENTS.md route | OpenCode AGENTS.md route |
|---|---|---|---|---|
| `Todoアプリを作って` / `build a todo app` | `harness-plan` | Start with planning unless an accepted plan already exists. | Route to `$harness-plan` before implementation. | Route to `harness-plan` guidance when available; otherwise manual planning. |
| `計画して` / `plan this` | `harness-plan` | Route to planning workflow. | Route to `$harness-plan`. | Route to `harness-plan` guidance when available. |
| `実装して` / `work on this` | `harness-work` | Route to implementation workflow. | Route to `$harness-work`. | Route to `harness-work` guidance when available. |
| `implement all Plans.md tasks` | `breezing` | Route to team execution wrapper when multiple ready tasks exist. | Route to `$breezing` or `$harness-work all` according to ready task count. | Route to `breezing` or `harness-work` guidance when available; otherwise manual execution. |
| `全部やって` / `breezing all` | `breezing` | Route to team execution wrapper. | Route to `$breezing`. | Route to `breezing` guidance when available. |
| `review this PR` | `harness-review` | Route to independent review workflow. | Route to `$harness-review`. | Route to `harness-review` guidance when available; unsupported hosts must return `unsupported` or `manual`. |
| `レビューして` / `review this` | `harness-review` | Route to independent review workflow. | Route to `$harness-review`. | Route to `harness-review` guidance when available. |
| `進捗確認` / `sync status` | `harness-sync` | Route to sync workflow. | Route to `$harness-sync`. | Route to `harness-sync` guidance when available. |
| `セットアップして` / `setup harness` | `harness-setup` | Route to setup workflow. | Route to `$harness-setup`. | Route to `harness-setup` guidance when available. |

## Candidate And Unsupported Hosts

Codex app, Cursor, and GitHub Copilot CLI are candidate hosts. Antigravity CLI
is future/unsupported. They are not part of the golden prompt fixture and must
not be counted as successful runtime routing until their own evidence exists.

## Validation Requirements

The routing contract is valid only when all of the following stay true:

- Claude SessionStart, Codex AGENTS.md, and OpenCode AGENTS.md are named as
  separate bootstrap routes.
- Golden prompts are explicitly called a static contract fixture.
- The document says the fixture is not runtime auto-routing proof.
- Candidate hosts and unavailable routes must produce `candidate`, `not observed`,
  or `manual` evidence instead of being counted as successful runtime routing.
- Future/unsupported hosts must produce `future/unsupported`, `not observed`, or
  `manual` evidence instead of being counted as successful runtime routing.
- Each core workflow listed above has at least one prompt fixture.
- Codex app, Cursor, and GitHub Copilot CLI remain candidate until
  host-specific bootstrap evidence exists.
- Antigravity CLI remains future/unsupported until an official or verified
  adapter route exists.
- Cursor static adapter smoke must stay green when `.cursor-plugin/` or
  `.cursor/AGENTS.md` changes.
