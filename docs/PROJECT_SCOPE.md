# Project Scope — Company AI Harness (v1)

## Project Name

**Company AI Harness** — an internal fork of [Chachamaru127/claude-code-harness](https://github.com/Chachamaru127/claude-code-harness).

## What This Is

An internal harness for AI-assisted engineering workflows, built on top of Claude Code.
It provides a structured **Spec → Plan → Work → Review → Release** cycle with:

- Skill-based slash commands (Claude Code plugin)
- Go-native guardrail engine and session monitor
- Hook-driven automation (PreToolUse, PostToolUse, SessionStart, TaskCompleted, etc.)
- Agent roles: Worker, Reviewer, Scaffolder

## Runtime Target

**Claude Code only** (v1).

Other runtimes are out of scope for v1 and archived under `archive/`.

## Core v1 Goals

| Goal | Description |
|------|-------------|
| Structured workflow | Spec → Plan → Work → Review → Release loop with Plans.md as the SSOT |
| Fail-closed guardrails | All destructive or irreversible operations require explicit human approval |
| Company safety policy | Internal rules wired into hooks and agents (no skip-permissions autonomy) |
| Stack awareness | Skills and agents tuned for Next.js, Metronic, Node.js, PostgreSQL, Docker, Proxmox |
| Evidence-based gates | Review and release require structured evidence; no rubber-stamp approvals |

## Out of Scope (v1)

The following runtimes and surfaces are explicitly excluded from v1:

| Surface | Status |
|---------|--------|
| Codex CLI | Archived under `archive/` |
| Codex app | Not supported |
| OpenCode | Archived under `archive/` |
| Cursor IDE | Archived under `archive/` |
| GitHub Copilot CLI | Not supported |
| Antigravity | Not supported |

## Non-Goals (v1)

- Public marketplace / plugin store publishing
- Multi-host parity (supporting more than Claude Code)
- Dashboard UI for plan or task management
- Production deploy automation
- Autonomous skip-permissions workflow

## Active Components

| Component | Path | Purpose |
|-----------|------|---------|
| Claude plugin | `.claude-plugin/` | Plugin manifest, hooks.json, settings |
| Go engine | `go/` | Hook handler, session monitor, guardrails |
| Binaries | `bin/` | Pre-built harness binaries |
| Skills | `skills/` | Slash commands for planning, work, review, etc. |
| Agents | `agents/` | Worker, reviewer, scaffolder role definitions |
| Hooks | `hooks/` | Hook entry shims |
| Scripts | `scripts/` | Supporting shell scripts |
| Tests | `tests/` | Plugin validation and integration tests |
| Rules | `.claude/rules/` | Operational rules loaded into Claude context |

## Plans.md Marker Vocabulary

Plans.md markers use a canonical English family (`cc:todo`, `cc:done`,
`pm:requested`, `pm:approved`, etc.). Legacy Japanese markers (`cc:完了`,
`pm:依頼中`, `cursor:依頼中`, etc.) are read-compatible but must not be
newly generated. Full reference: [docs/PLANS_MARKERS.md](PLANS_MARKERS.md).

## Language Policy

All active docs, skills, scripts, and commit messages: **English**.

Historical/archived material retains its original language.
