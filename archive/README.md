# archive/

This directory contains material from the upstream [Chachamaru127/claude-code-harness](https://github.com/Chachamaru127/claude-code-harness) that is **not active** in this internal fork.

Reason for archiving: our fork targets Claude Code only (v1). See `docs/FORK_NOTES.md` for the full rationale.

## Contents

| Path | Original path | Reason archived |
|------|---------------|-----------------|
| `codex/` | `codex/` | Codex CLI distribution — out of scope |
| `codex-plugin/` | `.codex-plugin/` | Codex CLI plugin manifest — out of scope |
| `opencode/` | `opencode/` | OpenCode distribution — out of scope |
| `skills-codex/` | `skills-codex/` | Codex-specific skill mirrors — out of scope |
| `workflows/` | `workflows/` | OpenCode workflow YAML (Japanese) — out of scope |
| `README_ja.md` | `README_ja.md` | Japanese-language README — English only in active docs |
| `Plans.md` | `Plans.md` | Upstream project tracker (136 KB) — internal tracking will use a separate file |

## Policy

- Do not import code from these directories without a deliberate decision.
- If a future phase requires Codex or OpenCode support, restore from here.
