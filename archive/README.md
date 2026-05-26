# archive/

This directory contains material from the upstream [Chachamaru127/claude-code-harness](https://github.com/Chachamaru127/claude-code-harness) that is **not active** in this internal fork.

Reason for archiving: our fork targets Claude Code only (v1). See `docs/FORK_NOTES.md` for the full rationale.

## Contents

| Path | Original path | Reason archived |
|------|---------------|-----------------|
| `non-claude/` | (multiple) | All non-Claude runtime surfaces — see below |
| `Plans.md` | `Plans.md` | Upstream project tracker (136 KB) — internal tracking uses a separate file |
| `README_ja.md` | `README_ja.md` | Japanese-language README — English only in active docs |

## non-claude/

All Codex CLI, OpenCode, Cursor, and related material lives under `non-claude/`.
Archived on 2026-05-26 as part of AIH-011 (v1 Claude Code-only cleanup).

| Path | Original path | Reason archived |
|------|---------------|-----------------|
| `non-claude/codex/` | `codex/` | Codex CLI distribution — out of scope for v1 |
| `non-claude/codex-plugin/` | `.codex-plugin/` | Codex CLI plugin manifest — out of scope for v1 |
| `non-claude/opencode/` | `opencode/` | OpenCode distribution — out of scope for v1 |
| `non-claude/cursor/` | `.cursor/` | Cursor IDE config and rules — out of scope for v1 |
| `non-claude/skills/` | `archive/skills/` | Cursor-specific skills (`cc-cursor-cc`) |
| `non-claude/skills-codex/` | `skills-codex/` | Codex-specific skill mirrors — out of scope for v1 |
| `non-claude/scripts/` | `archive/scripts/` | Codex companion and helper scripts |
| `non-claude/tests/` | `archive/tests/` | Codex/OpenCode-specific test files |
| `non-claude/workflows/` | `workflows/` | OpenCode workflow YAML — out of scope for v1 |
| `non-claude/docs/` | `docs/codex-*`, `docs/CURSOR_INTEGRATION.md`, etc. | Docs covering only non-Claude host surfaces |

## Policy

- Do not import code from these directories without a deliberate decision.
- If a future phase requires Codex or OpenCode support, restore from here.
