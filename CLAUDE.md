# CLAUDE.md - Claude Harness Development Guide

This file provides guidance for Claude Code when working in this repository.

## Project Overview

**Claude harness** is a plugin for autonomous operation of Claude Code in a "Plan → Work → Review" workflow.

**Special note**: This project is self-referential — it uses the harness itself to improve the harness.

## Claude Code Feature Utilization

<!-- Feature Table は docs/CLAUDE-feature-table.md に集約。ここに行を追加しない -->
CC v2.1.111+ と Opus 4.7 の機能を活用。詳細: [docs/CLAUDE-feature-table.md](docs/CLAUDE-feature-table.md)
長時間タスクの手順: [docs/long-running-harness.md](docs/long-running-harness.md)

主要活用機能: Agent Memory, Worktree isolation, Agent hooks, PreCompact/PostCompact, PermissionDenied tracking, 1M Context Window

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

All responses must be in **Japanese** (including `context: fork` skills).

### Code Style

- Use clear and descriptive names
- Add comments for complex logic
- Keep agents/skills single-responsibility

## Repository Structure

`.claude-plugin/` Plugin manifest / `agents/` Sub-agents (Worker, Reviewer, Scaffolder, Advisor) / `skills/` Skills / `hooks/` Hooks / `scripts/` Shell scripts / `docs/` Documentation / `tests/` Validation / `go/` Harness v4 Go native engine (guardrails + state management) ([SPEC.md](go/SPEC.md) — 詳細仕様, [DESIGN.md](go/DESIGN.md) — 設計) / `bin/` Go バイナリ出力

## Using Skills (Important)

**Before starting work:** If a relevant skill exists, launch it with the Skill tool first.

> For heavy tasks, skills spawn sub-agents from `agents/` in parallel via the Task tool.

### Top Skill Categories (Top 5)

| Category | Purpose | Trigger Examples |
|---------|---------|-----------------|
| work | Task implementation (auto-scope detection, --codex support) | "implement", "do it all", "/work" |
| breezing | Full auto-run with Agent Teams (--codex support) | "run with team", "breezing" |
| harness-review | Code review, quality checks | "review", "security", "performance" |
| setup | Setup integration hub (init, harness-mem, Codex CLI, etc.) | "setup", "initialize", "harness-mem", "codex-setup" |
| memory | SSOT management, memory search, SSOT promotion | "SSOT", "decisions.md", "memory search", "harness-mem" |

Full category list and hierarchy: [docs/CLAUDE-skill-catalog.md](docs/CLAUDE-skill-catalog.md)

## Development Flow

0. **When editing skills/hooks**: run `/reload-plugins` to refresh runtime cache immediately
1. **Plan**: Use `/plan-with-agent` to add tasks to Plans.md
2. **Implement**: `/work` (Claude implements) or `/breezing` (team full-run). Both support `--codex`
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
- **Worker 契約 (v4.3.0+)**: Worker は `worker-report.v1` で self_review 5 件必須。Plans.md の `cc:*` マーカー書換は NG-1 で自動 deny。詳細: [agents/worker.md](agents/worker.md)

## MCP Trust Policy

ユーザーレベル MCP は全て信頼済みソース。
外部 MCP 追加時のルール:
1. `harness_mem_ingest` 経由のメモリ書き込みには出所タグ (`source: "mcp:<server-name>"`) を付与
2. 不特定の外部入力はサブエージェントで検疫（隔離コンテキストで検証後にメモリ昇格）
3. プロジェクトレベル MCP 追加時は deny で `mcp__<新サーバー>__*` を制限し、必要なツールのみ allow

## Permission Boundaries

以下は settings.json の deny/ask + ガードレールエンジン (R01-R13) による**多層防御**。

| Rule | 防御層 | 理由 |
|------|--------|------|
| `.claude-plugin/settings*`, `.claude/settings*` | deny | 自己書き換え防止 |
| `.eslintrc*`, `eslint.config.*`, `biome.json`, `tsconfig*.json` | deny | 品質基準の保護 |
| `.github/workflows/*` | deny | CI パイプラインの保護 |
| `git push --force` | ask + R06 deny | 不可逆操作の防止 |
| `git push origin main/master` | R12 deny | protected branch 保護 |
| `git reset --hard` | ask + R11 deny | 不可逆操作の防止 |
| `mcp__codex__*` | deny | Codex MCP 直接使用の防止 |

変更が必要な場合はユーザーに手動操作を依頼すること。

## Key Commands (for development)

| Command | Purpose |
|---------|---------|
| `/plan-with-agent` | Add improvement tasks to Plans.md |
| `/work` | Implement tasks (auto-scope detection, --codex support) |
| `/breezing` | Full team parallel run with Agent Teams (--codex support) |
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

- Migration policy: [.claude/rules/migration-policy.md](.claude/rules/migration-policy.md) - deleted-concepts.yaml の運用ルール (Phase 40 で導入)
- Active watching test policy: [.claude/rules/active-watching-test-policy.md](.claude/rules/active-watching-test-policy.md) - 外部 daemon / opt-in ファイル監視機能の 3 状態テスト規約 (Phase 50 で導入、D40 / P29 運用ルール化)

<!-- harness-integrity: last-audit=2026-04-19 -->
