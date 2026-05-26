# Distribution Scope

Last updated: 2026-05-14

This document explicitly defines what "exists in the `claude-code-harness` repo but is not included in
the Claude Code plugin distribution payload."
When there is uncertainty about `Plans.md`, README, `.gitattributes`, distribution scripts, or
validation scripts, treat this table as the source of truth.

## Scope Table

| Path | Status | Why it exists | Enforcement signal |
|------|--------|---------------|--------------------|
| `.claude-plugin/` | Distribution-included | Claude Code plugin manifest / hooks / settings | `claude plugin validate`, `test-distribution-archive.sh` |
| `bin/harness*` | Distribution-included | Go-native guardrail / lifecycle runtime | `validate-plugin`, `go test`, archive required entries |
| `skills/` | Distribution-included | Primary skill surface for Claude Code | `validate-plugin`, mirror sync checks |
| `agents/` | Distribution-included | worker / reviewer / scaffolder / advisor | `validate-plugin`, agent frontmatter tests |
| `hooks/`, `monitors/` | Distribution-included | Runtime hook / monitor definitions | `hooks/hooks.json`, `validate-plugin` |
| `output-styles/` | Distribution-included | Claude Code output style | `plugin.json`, archive required entries |
| `templates/`, `workflows/` | Distribution-included | Project init / rules / workflow templates | `check-consistency.sh`, template registry checks |
| `scripts/` runtime files | Distribution-included | Hook handlers, setup, sync, review, plan, loop runtime | `validate-plugin`, runtime hook tests |
| `assets/`, public `docs/` | Distribution-included | README assets and public user documentation | README claim drift checks |
| `commands/` | Compatibility-retained | Legacy slash command assets. Validated only if present | `validate-plugin` |
| `codex/`, `opencode/`, `skills-codex/` | Source-repo mirror only | Mirror / setup paths for alternative clients. Not included in Claude plugin archive | `test-codex-package.sh`, `opencode-compat.yml`, `.gitattributes` |
| `go/`, `tests/`, `benchmarks/`, `.github/` | Development-only and distribution-excluded | Source / CI / benchmark / validation | `.gitattributes`, `test-distribution-archive.sh` |
| `.claude/`, `.cursor/`, `CLAUDE.md`, `AGENTS.md`, `Plans.md` | Development-only and distribution-excluded | Repo-local agent context, local plans, editor setup | `.gitattributes`, `test-distribution-archive.sh` |
| `.private/` | Local-only and distribution-excluded | Escape destination for private/dev-only skills that would appear in `claude --plugin-dir .` inventory if placed under `skills/` | `.gitignore`, `test-public-plugin-inventory.sh` |
| `scripts/ci/`, `scripts/evidence/`, `scripts/sandbox-test/` | Development-only and distribution-excluded | CI helpers, evidence fixtures, local sandbox examples | `.gitattributes`, `test-distribution-archive.sh` |
| `mcp-server/` | Development-only and distribution-excluded | Optional feature. Remains in repo for development/investigation but not included in distribution payload | `.gitignore`, `.gitattributes`, CHANGELOG history |
| `harness-ui/`, `harness-ui-archive/`, `remotion/` | Development-only and distribution-excluded | Optional UI / video experiments and archives | `.gitignore`, `.gitattributes`, CHANGELOG history |
| `docs/research/`, `docs/private/`, `docs/notebooklm/`, `docs/slides/`, `docs/presentation/`, `docs/social/` | Private or generated reference | Research records, pre-publication drafts, generated intermediates | `.gitignore`, `.gitattributes`, `test-distribution-archive.sh` |

## Current Decisions

- `commands/` is not treated as deleted. Currently **Compatibility-retained**.
- `codex/` / `opencode/` are validation targets as repo mirrors but are excluded from the Claude Code plugin archive.
- `.claude/` / `.cursor/` / `CLAUDE.md` / `AGENTS.md` / `Plans.md` are repo-local context, not plugin payload.
- Private/dev-only skills must not be placed under `skills/`. Even if `.gitignore`d, they are exposed in the local inventory of `claude --plugin-dir .`, so move them outside the public plugin surface to `.private/skills/` or similar.
- `mcp-server/` is not treated as deleted. Currently **Development-only and distribution-excluded**.
- `scripts/hook-handlers/memory-bridge.sh` and `memory-*.sh` are **Distribution-included** even as local bridges. They must be tracked in the repo since hooks reference them.
- Use "deleted" in README or `Plans.md` only when the item has actually been removed from the tree.
- Use the labels "distribution-excluded," "compatibility-retained," and "development-only" consistent with this document.

## Update Rule

Update this table in the same PR / commit when any of the following occurs:

1. Changing the architecture / install / compatibility description in README
2. Changing exclusion rules in `.gitignore` or build scripts
3. Changing how directories like `commands/` or `mcp-server/` — whose purpose is prone to misunderstanding — are handled
4. Changing `export-ignore` in `.gitattributes` or the required/forbidden lists in `tests/test-distribution-archive.sh`
