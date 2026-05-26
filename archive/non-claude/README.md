# archive/non-claude — Historical Upstream Material

These files are preserved from the upstream `claude-code-harness` repository for reference only.

## Status

- **Not active in v1.** The Company AI Harness is Claude Code-only.
- CI, build, test, and runtime must not depend on these files.
- Active source code does not require anything from this directory.

## Contents

| Directory | Origin | Notes |
|-----------|--------|-------|
| `codex/` | Upstream codex runtime surface | AGENTS.md and .codexignore preserved for reference |
| `codex-plugin/` | Upstream Codex plugin manifest | Historical plugin.json |
| `opencode/` | Upstream OpenCode runtime surface | AGENTS.md and config preserved for reference |
| `docs/` | Upstream non-Claude documentation | Policy docs, integration guides, release notes |
| `scripts/` | Upstream Codex/OpenCode scripts | codex-loop.sh, setup scripts, worker scripts |
| `tests/` | Upstream non-Claude tests | Tests validating Codex, OpenCode, Cursor surfaces |

## Future Support

Future releases may selectively reintroduce parts of these surfaces if Claude Code-compatible
integration patterns emerge. Any reintroduction must go through the active planning process
(Plans.md + PR review) and must not re-add archived paths to active CI/build/test gates.
