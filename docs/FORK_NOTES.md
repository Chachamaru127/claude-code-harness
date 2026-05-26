# Fork Notes

This is an internal fork of [Chachamaru127/claude-code-harness](https://github.com/Chachamaru127/claude-code-harness).

## Fork Purpose

Turn the upstream harness into an internal **Claude Code-first** AI Engineering Harness for our engineering team.

## Upstream Origin

- **Original repository**: `Chachamaru127/claude-code-harness`
- **License**: MIT — attribution preserved in `LICENSE.md` and `LICENSE.ja.md` (untouched)
- **Nature of fork**: Internal/customized — not intended for public redistribution

## License & Code Policy

- MIT license attribution is preserved and must not be removed.
- We will **not** copy GPL-licensed code from other projects into this repository.
- Any third-party code added must carry a compatible permissive license (MIT, Apache 2.0, BSD).

## Upstream Sync Strategy

**Hard fork with selective manual cherry-pick.**

We do not track upstream as a git remote. If upstream ships a fix or feature we want, it is reviewed and cherry-picked manually into a dedicated PR. This prevents accidental import of scope creep (Codex, OpenCode, Cursor features).

## Naming Assumptions

| Assumption | Rationale |
|-----------|-----------|
| Project is called **Company AI Harness** | Generic enough for internal use; avoids upstream brand confusion |
| Binary and plugin identifiers (`bin/harness`, `.claude-plugin/`) retain upstream names | Changing them would require updating hooks.json, settings, and test scripts — deferred to v2 |
| `archive/` directory mirrors upstream path structure | Makes it easy to recover archived material without a separate git history lookup |

## What Was Archived

See `archive/` directory at repo root. Each subdirectory preserves the original path structure.

Archived surfaces: `codex/`, `opencode/`, `cursor/`, Cursor skill, Codex skill mirrors, Codex-specific scripts, `README_ja.md`, `workflows/`.

## What Was Not Changed

- `.claude-plugin/` — Claude Code plugin manifest and hooks (active, unchanged)
- `go/` — Go native engine (active, unchanged)
- `bin/` — Pre-built binaries (active, unchanged)
- `hooks/` — Hook shims (active, unchanged)
- `agents/` — Worker, reviewer, scaffolder agents (active, reviewed)
- `skills/` — Primary skills (active, reviewed per phase)
- `tests/` — Validation tests (active, unchanged pending review)
- `scripts/` — Non-Codex scripts (active, unchanged pending review)
- `LICENSE.md`, `LICENSE.ja.md` — License attribution (untouched)

## Fork Assumptions Made During Phase 0

| # | Assumption | Rationale |
|---|-----------|-----------|
| A1 | Claude Code is the sole target runtime for v1. | Codex CLI, OpenCode, and Cursor are out of scope; their directories are archived under `archive/`. |
| A2 | English is the working language for all active docs, skills, and scripts. | Team is English-speaking; Japanese is kept only where it appears in archived upstream material. |
| A3 | Go runtime binary (`bin/harness`, `go/`) is kept as-is. | Provides hooks, session monitor, and guardrail engine — all valid for our use case. |
| A4 | `Plans.md` (upstream project tracker) is archived, not deleted. | Documents upstream architectural decisions that may be useful as reference. |
| A5 | `skills-codex/` is archived. These are Codex CLI mirror copies of `skills/`. | `skills/` remains the SSOT. |
| A6 | `workflows/` (Japanese-language OpenCode workflow YAML) is archived. | Not used by Claude Code plugin path. |
| A7 | `README_ja.md` is archived (not deleted). | Upstream Japanese README; English `README.md` is kept. |
| A8 | `LICENSE.ja.md` is kept in place. | License attribution must not be removed. |
| A9 | Codex-specific scripts in `scripts/` (≈15 files) are archived; remaining scripts retained. | Many scripts support Claude Code hooks and Go runtime. |
| A10 | `CLAUDE.md` "All responses must be in Japanese" rule is replaced with English. | Our team uses English. Other project-specific rules reviewed per phase. |

## Phased Cleanup Plan

- **Phase 0 (complete)**: Inventory, archive non-Claude surfaces, English-first docs
- **Phase 1**: Review skills for Japanese text, update descriptions to English
- **Phase 2**: Review agents for Claude Code-specific correctness
- **Phase 3**: Adapt CLAUDE.md rules and scripts to internal conventions
