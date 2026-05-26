# Project Scope — Internal AI Engineering Harness

## What This Is

An internal harness for AI-assisted engineering workflows, built on top of Claude Code.
It provides a structured **Plan → Work → Review** cycle with:

- Skill-based slash commands (Claude Code plugin)
- Go-native guardrail engine and session monitor
- Hook-driven automation (PreToolUse, PostToolUse, SessionStart, TaskCompleted, etc.)
- Agent roles: Worker, Reviewer, Scaffolder

## Runtime Target

**Claude Code only** (v1).

Other runtimes (Codex CLI, OpenCode, Cursor) are out of scope for v1.
Archived material is preserved under `archive/` in case future scope expands.

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

## Out of Scope (v1)

- Codex CLI integration
- OpenCode integration
- Cursor IDE integration
- Japanese-language UI / docs (English only going forward)
- `Plans.md` upstream project tracker (archived for reference)

## Language Policy

All active docs, skills, scripts, and commit messages: **English**.

Historical/archived material retains its original language.
