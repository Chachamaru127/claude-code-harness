# CLAUDE.md - Claude Harness Development Guide

This file provides guidance for Claude Code when working in this repository.

## Project Overview

**Company AI Harness** is a plugin for autonomous operation of Claude Code in a "Plan → Work → Review" workflow.

**Special note**: This project is self-referential — it uses the harness itself to improve the harness.

## Claude Code Feature Utilization

<!-- Feature Table is consolidated in docs/CLAUDE-feature-table.md — do not add rows here -->
Targets CC v2.1.111+ and Opus 4.7 features. Details: [docs/CLAUDE-feature-table.md](docs/CLAUDE-feature-table.md)
Long-running task procedures: [docs/long-running-harness.md](docs/long-running-harness.md)

Key features used: Agent Memory, Worktree isolation, Agent hooks, PreCompact/PostCompact, PermissionDenied tracking, 1M Context Window

## Development Rules

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/): `feat:` / `fix:` / `docs:` / `refactor:` / `test:` / `chore:`

### Version Management

Keep `VERSION`, `.claude-plugin/plugin.json`, and `harness.toml` in sync.
Normal feature/docs PRs must leave both files unchanged and record changes under `CHANGELOG.md`'s `[Unreleased]` section.
Use `./scripts/sync-version.sh bump` only when cutting a release.

### CHANGELOG

Details: [.claude/rules/github-release.md](.claude/rules/github-release.md) (Keep a Changelog format; include Before/After tables for major changes)

### Language

All responses must be in **English** (including `context: fork` skills).

### Code Style

- Use clear and descriptive names
- Add comments for complex logic
- Keep agents/skills single-responsibility

## Repository Structure

`.claude-plugin/` Plugin manifest / `.claude/` Claude runtime state, memory, rules, hooks / `agents/` Sub-agents / `skills/` Primary skills / `hooks/` Hooks / `scripts/` Shell scripts / `docs/` Documentation / `templates/` Templates / `tests/` Validation / `go/` Harness v4 Go native engine ([SPEC.md](go/SPEC.md), [DESIGN.md](go/DESIGN.md)) / `archive/` Non-Claude runtime surfaces (Codex, OpenCode, Cursor — archived, not active)

See [docs/PROJECT_SCOPE.md](docs/PROJECT_SCOPE.md) for active vs. archived component list.

## Using Skills (Important)

**Before starting work:** If a relevant skill exists, launch it with the Skill tool first.

> For heavy tasks, skills spawn sub-agents from `agents/` in parallel via the Task tool.

### Top Skill Areas

| Category | Purpose | Trigger Examples |
|---------|---------|-----------------|
| harness-work | Task implementation from Plans.md | "implement", "do it all", "/work" |
| breezing | Full parallel run with Agent Teams | "run with team", "breezing" |
| harness-review | Code review, quality checks | "review", "security", "performance" |
| harness-plan | Planning and task shaping into Plans.md | "plan", "break this down", "/plan-with-agent" |
| harness-sync | Check alignment across Plans.md, git state, and implementation | "sync", "is this aligned?", "check drift" |
| memory | SSOT management, memory search, SSOT promotion | "SSOT", "decisions.md", "memory search", "harness-mem" |
| cognitive-load (Plan Brief / Progress / Accept) | 3 surface HTML for non-engineer review | "plan brief", "progress check", "accept decision", "ship/wait/reject" |

Skills are organized as flat directories under `skills/`. Full catalog: [docs/CLAUDE-skill-catalog.md](docs/CLAUDE-skill-catalog.md)
Cognitive-load surfaces: [docs/cognitive-load-surfaces.md](docs/cognitive-load-surfaces.md) / Cross-project safety: [docs/cross-project-safety.md](docs/cross-project-safety.md)

## Development Flow

0. **When editing skills/hooks**: run `/reload-plugins` to refresh runtime cache immediately
1. **Plan**: Use `/plan-with-agent` to add tasks to Plans.md
2. **Implement**: `/work` (Claude implements) or `/breezing` (team full-run)
3. **Review**: Runs automatically (manual: `/harness-review`)
4. **Validate**: Run `./tests/validate-plugin.sh` for structural validation

## Testing

```bash
./tests/validate-plugin.sh          # Validate plugin structure
./scripts/ci/check-consistency.sh   # Consistency check
```

Details: [docs/CLAUDE-commands.md](docs/CLAUDE-commands.md)

## Notes

- **Watch for self-reference**: Running `/work` on this plugin means editing its own code
- **Hooks run automatically**: PreToolUse/PostToolUse guards are active
- **VERSION sync**: Leave version files untouched in normal PRs; update them only for releases
- **Worker contract (v4.3.0+)**: Worker must include 5 self_review items in `worker-report.v1`. Rewriting `cc:*` markers in Plans.md is auto-denied (NG-1). Details: [agents/worker.md](agents/worker.md)
- **Skill frontmatter design**: `disable-model-invocation: true` is reserved for dangerous side-effect skills only. Applying it to read-only or decision skills blocks invocation via the Skill tool. Anti-Pattern: [.claude/rules/skill-editing.md](.claude/rules/skill-editing.md) + [.claude/memory/patterns.md](.claude/memory/patterns.md) P27 (codified 2026-05-18)
- **Slash command output summary contract**: When a `/command` `<local-command-stdout>` is long (10+ lines) and passed to host Claude, host must summarize in 1-3 lines as an assistant message and state the next action (wait / end / request user decision). The skill side must also emit a summary instruction line at conclusion. Details: [.claude/memory/patterns.md](.claude/memory/patterns.md) P35 (codified 2026-05-19)

## MCP Trust Policy

All user-level MCPs are treated as trusted sources.
Rules when adding external MCPs:
1. Memory writes via `harness_mem_ingest` must include a source tag (`source: "mcp:<server-name>"`)
2. Unverified external input must be quarantined in a sub-agent (validate in isolated context before promoting to memory)
3. When adding a project-level MCP, deny `mcp__<new-server>__*` and only allow required tools explicitly

## Permission Boundaries

Multi-layer defense via settings.json deny/ask + guardrail engine (R01-R13).

| Rule | Layer | Reason |
|------|-------|--------|
| `.claude-plugin/settings*`, `.claude/settings*` | deny | Prevent self-modification |
| `.eslintrc*`, `eslint.config.*`, `biome.json`, `tsconfig*.json` | deny | Protect quality standards |
| `.github/workflows/*` | deny | Protect CI pipeline |
| `git push --force` | ask + R06 deny | Prevent irreversible operations |
| `git push origin main/master` | R12 ask (configurable deny/allow) | Protect main branch |
| `git reset --hard` | ask + R11 deny | Prevent irreversible operations |
| `mcp__codex__*` | deny | Prevent direct Codex MCP use (archived runtime) |

If a change is needed, ask the user to perform the operation manually.

External API sandbox allowlist configuration (Firecrawl / web scraping, etc.): [docs/sandbox-allowlist-recipe.md](docs/sandbox-allowlist-recipe.md) — SSOT for `~/.claude/settings.json` patch procedure. Keep in sync with `templates/sandbox-settings.json.template`.

## Key Commands (for development)

| Command | Purpose |
|---------|---------|
| `/plan-with-agent` | Add improvement tasks to Plans.md |
| `/work` | Implement tasks (auto-scope detection) |
| `/breezing` | Full team parallel run with Agent Teams |
| `/harness-review` | Review changes |
| `/validate` | Validate plugin |
| `/remember` | Record learnings |

Details & handoff: [docs/CLAUDE-commands.md](docs/CLAUDE-commands.md)

## SSOT (Single Source of Truth)

- `.claude/memory/decisions.md` - Decisions (Why)
- `.claude/memory/patterns.md` - Reusable patterns (How)

## Test Tampering Prevention

> **Absolutely prohibited**: Tampering with tests to fake "success"

Details: [.claude/rules/test-quality.md](.claude/rules/test-quality.md) / [.claude/rules/implementation-quality.md](.claude/rules/implementation-quality.md)

- Migration policy: [.claude/rules/migration-policy.md](.claude/rules/migration-policy.md) - deleted-concepts.yaml operational rules (introduced Phase 40)
- Active watching test policy: [.claude/rules/active-watching-test-policy.md](.claude/rules/active-watching-test-policy.md) - 3-state test contract for external daemon / opt-in file watching (introduced Phase 50, D40/P29 operational rules)
- Cross-repo handoff: [.claude/rules/cross-repo-handoff.md](.claude/rules/cross-repo-handoff.md) - claude-code-harness ↔ harness-mem responsibility boundary + 2-path handoff workflow (codified Phase 65, D42 shareable policy)

<!-- harness-integrity: last-audit=2026-05-18 -->
