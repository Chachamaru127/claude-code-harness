# Tool Capability Matrix

Last updated: 2026-05-28

## Purpose

This document defines the Phase 73 host capability matrix for Hokage Core
extraction work. It is a contract document, not a marketing support matrix.

The current support-tier scope is:

| Host | Support tier | Claim boundary |
|---|---|---|
| Claude Code | `supported` | Public Claude-first support is allowed for the verified Claude Code path. |
| Codex CLI | `internal-compatible` | Existing mirrors, setup, companion review, local CLI command surface, and CI-gated direct plugin marketplace/install smoke can be described as internal compatibility; Codex app and hook parity are not implied. |
| Codex app | `candidate` | App behavior must be proven separately from Codex CLI help output. |
| OpenCode | `internal-compatible` | Existing mirror/package validation and Node-level bootstrap plugin checks can be described as internal compatibility; real OpenCode binary runtime bootstrap parity is not proven. |
| Cursor | `candidate` | Adapter skeleton + static smoke only; PM handoff docs are not adapter support; no supported claim until workflow smoke passes. |
| GitHub Copilot CLI | `candidate` | Candidate adapter only; Superpowers evidence and official docs are not Harness bootstrap proof. |
| Antigravity CLI | `future/unsupported` | No public setup, README support, or release claim until an official or verified route plus local bootstrap smoke exists. |

`not_observed != absent` applies to every host. Missing local runtime evidence
is `not observed` until the relevant source of truth is checked. It is not a
license to promote the host to supported.

## False Parity Rule

False parity is forbidden.

The same capability name does not mean the same enforcement strength. Claude
Code can stop some actions at runtime through hooks. Codex CLI does not have
the same hook model, so the Codex policy from `docs/hardening-parity.md` is
contract injection + post quality gate + merge gate. Codex CLI plugin install
smoke proves the marketplace/cache route only. OpenCode is currently a
packaging and instruction surface with Node-level bootstrap validation, not
proof of runtime guard parity. Candidate hosts do not inherit the safety or
bootstrap claims of supported hosts.

## Capability Status

| Capability | Core meaning | Claude Code | Codex CLI | OpenCode | Cursor |
|---|---|---|---|---|---|
| `skill_loading` | Host can discover and load workflow skills. | Supported through the Claude plugin `skills/` surface. | Supported through `codex/.codex/skills/` and project/user skill loading. | Partial through `opencode/skills/` mirror packaging. | Partial through `.cursor-plugin/plugin.json` → `skills/` and Cursor Skills surface; runtime load not proven until workflow smoke passes. |
| `bootstrap_notice` | Host can load startup guidance or prove the guidance surface exists. | Supported through Claude SessionStart guidance, plugin instructions, and root `CLAUDE.md`. | Supported through `codex/AGENTS.md`; no SessionStart hook parity claim. | Partial through `opencode/AGENTS.md`; no SessionStart hook parity claim. | Partial through `.cursor/AGENTS.md`, `.cursor/rules/`, optional hooks config shape; no SessionStart parity claim. |
| `prompt_routing` | Host can map user intent to a workflow. | Supported through slash commands, skill triggers, and SessionStart guidance. | Partial through explicit `$skill` invocation and `AGENTS.md` routing guidance. | Partial through `AGENTS.md` routing guidance and mirrored skill names. | Partial through AGENTS guidance + skill triggers; static contract only until runtime smoke. |
| `pre_use_guard` | Host can block risky actions before execution. | Supported through PreToolUse / permission boundaries. | Partial only by contract injection before execution; not runtime hook parity. | Unsupported for parity; instructions can warn, but no first-class pre-use guard is claimed. | Partial/investigation only; hooks may gate events but are not Claude PreToolUse parity. |
| `post_use_gate` | Host can inspect outputs after execution. | Supported through PostToolUse and review workflow checks. | Supported through post quality gate checks before merge. | Partial through package validation and release preflight checks. | Partial through review workflow guidance; no hook parity claim. |
| `review_artifact` | Host can produce structured review evidence. | Supported through harness-review and Claude-side review artifacts. | Supported through `scripts/codex-companion.sh review --base` and schema-backed review output. | Partial/static only; OpenCode package validation is not equivalent to an independent reviewer. | Partial/static only; reviewer subagent + harness-review skill guidance, not proven independent review loop. |
| `memory_bridge` | Host can use a controlled memory surface. | Supported when Agent Memory / harness-mem wiring is configured. | Partial through `AGENTS.md` guidance and harness-mem bridge configuration. | Future/unsupported for runtime memory bridge parity. | Future/unsupported until MCP/harness-mem wiring is smoke-proven for Cursor. |

## Candidate And Unsupported Host Boundaries

| Host | Phase 73 status | Allowed wording | Blocked wording |
|---|---|---|
| Codex app | `candidate` | app-specific candidate or research gate | supported, same as Codex CLI |
| Cursor | `candidate` | adapter candidate, handoff integration, static smoke, `.cursor-plugin/` skeleton | supported Cursor adapter |
| GitHub Copilot CLI | `candidate` | adapter candidate, CLI capability investigation | supported Copilot adapter |
| Antigravity CLI | `future/unsupported` | future scope, unsupported public claim, not observed | supported Antigravity adapter |

## Validation Requirements

The matrix is valid only when all of the following stay true:

- All required capability names are present exactly as code-formatted labels.
- Claude Code is `supported`.
- Codex CLI and OpenCode are `internal-compatible`.
- Codex app, Cursor, and GitHub Copilot CLI are `candidate`.
- Antigravity CLI is `future/unsupported` for public claim.
- Codex CLI runtime evidence is limited to direct plugin marketplace/install
  smoke in an isolated `CODEX_HOME`.
- OpenCode runtime evidence remains Node-level bootstrap validation unless a
  real binary smoke is observed.
- The Codex safety model references contract injection + post quality gate +
  merge gate.
- Any public support wording preserves the false parity rule.
- Cursor adapter static smoke is limited to `tests/test-cursor-adapter-candidate.sh`
  until Desktop/CLI workflow smoke is observed.
- Cursor Breezing multitask mapping is a smoke target, not a public parity claim.
