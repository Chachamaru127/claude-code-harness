# CLAUDE.md - Claude Harness Development Guide

This file provides guidance for Claude Code when working in this repository.

## Project Overview

**Claude harness** is a plugin for autonomous operation of Claude Code in a "Plan → Work → Review" workflow.

**Special note**: This project is self-referential — it uses the harness itself to improve the harness.

## Claude Code 2.1.81+ Feature Utilization Guide

Harness makes full use of new features introduced in Claude Code 2.1.81.

| Feature | Skill | Purpose |
|---------|-------|---------|
| **Agent Memory (memory frontmatter)** | task-worker, code-reviewer | Persistent learning |
| **TeammateIdle/TaskCompleted Hook** | breezing | Automated team monitoring |
| **Skill budget scaling** | All skills | Auto-adjusts to 2% of context window |
| **Fast mode (Opus 4.6)** | All skills | High-speed output mode |
| **Worktree isolation** | breezing, parallel-workflows | Safe parallel writes to the same file |
| **`/simplify` Auto-Refinement** | work | Automatic code simplification after implementation |
| **HTTP hooks** | hooks | JSON POST to external services (Slack, dashboards, metrics) |
| **Effort levels + ultrathink (v2.1.68)** | harness-work | Multi-factor scoring injects ultrathink for complex tasks |
| **Agent hooks (v2.1.68)** | hooks | LLM-based code quality guard (type: "agent") |
| **`${CLAUDE_SKILL_DIR}` variable (v2.1.69)** | all skills | Stable skill-local reference path resolution |
| **InstructionsLoaded hook (v2.1.69)** | hooks | Pre-session instruction load tracking and environment checks |
| **`agent_id` / `agent_type` fields (v2.1.69)** | hooks, breezing | Robust teammate identity and role-aware guarding |
| **`{"continue": false}` teammate response (v2.1.69)** | breezing | Stop team loop when all tasks are completed or stop is requested |
| **`/reload-plugins` (v2.1.69)** | all skills | Immediate reflection after skill/hook edits without restarting |
| **`includeGitInstructions: false` (v2.1.69)** | breezing, work | Reduce prompt token overhead for git-instruction-light tasks |
| **`git-subdir` plugin source (v2.1.69)** | setup, release | Support plugin source managed from repository subdirectories |
| **Sonnet 4.5 → 4.6 auto-migration** | all skills | Legacy Sonnet references migrate to 4.6 behavior automatically |
| **WorktreeCreate/Remove hook (v2.1.50)** | breezing | Worktree lifecycle auto-setup and cleanup |
| **Auto Mode (Research Preview, Phase 1 active)** | breezing, work | `--auto-mode` flag for safer bypassPermissions alternative. Phase 1: RP started 2026-03-12 |
| **Per-agent hooks (v2.1.69+)** | agents-v3/ | Worker PreToolUse guard + Reviewer Stop log in agent frontmatter |
| **Agent `isolation: worktree` (v2.1.50+)** | agents-v3/worker | Auto worktree isolation for parallel writes with shared Agent Memory |
| **`/loop` + Cron scheduling (v2.1.71)** | breezing, harness-work | Periodic task monitoring with `/loop 5m /sync-status` |
| **PostToolUseFailure hook (v2.1.70)** | hooks | Auto-escalation after 3 consecutive failures |
| **Background Agent output fix (v2.1.71)** | breezing | Safe background agent usage with output path in completion notification |
| **Compaction image retention (v2.1.70)** | all skills | Images preserved during context compaction |
| **Subagent `background` field (v2.1.71+)** | breezing | Always-background agent execution via frontmatter |
| **Subagent `local` memory scope (v2.1.71+)** | agents-v3/ | Non-VCS agent memory in `.claude/agent-memory-local/` |
| **Agent Teams experimental flag (v2.1.71+)** | breezing | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` env var for official Agent Teams |
| **`/agents` command (v2.1.71+)** | setup, troubleshoot | Interactive agent management UI (create/edit/delete) |
| **Desktop Scheduled Tasks (v2.1.71+)** | harness-work | `~/.claude/scheduled-tasks/` SKILL.md-based recurring tasks |
| **`--agents` CLI flag (v2.1.71+)** | breezing, CI | Session-level JSON agent definitions without disk persistence |
| **`ExitWorktree` tool (v2.1.72)** | breezing, work | Programmatic worktree exit for agent workflows |
| **Effort levels simplified (v2.1.72)** | harness-work | 永続レベルは `low/medium/high`（`○ ◐ ●`）。`max` は Opus 4.6 のセッション専用オプションとして存続 |
| **Agent tool `model` param restored (v2.1.72)** | breezing | Per-invocation model overrides re-enabled |
| **`/plan` description argument (v2.1.72)** | harness-plan | `/plan fix the auth bug` enters plan mode with context |
| **Parallel tool call fix (v2.1.72)** | breezing, work | Failed Read/WebFetch/Glob no longer cancel sibling calls |
| **Worktree isolation fixes (v2.1.72)** | breezing | Task resume cwd restore + background notification worktreePath |
| **`/clear` preserves background agents (v2.1.72)** | breezing | `/clear` only kills foreground tasks; background agents survive |
| **Hooks fixes (v2.1.72)** | hooks | transcript_path fix, skill hooks double-fire fix, async stdin fix |
| **HTML comments hidden in CLAUDE.md (v2.1.72)** | all | `<!-- -->` hidden from auto-injection; visible via Read tool |
| **Sandboxing (`/sandbox`)** | breezing, work | OS-level filesystem/network isolation complementing bypassPermissions |
| **`opusplan` model alias** | breezing | Auto-switches Opus (plan) ↔ Sonnet (execute) for Lead sessions |
| **`CLAUDE_CODE_SUBAGENT_MODEL` env var** | breezing, work | Centralized subagent model control for Worker/Reviewer |
| **Checkpointing (`/rewind`)** | work | Session state tracking, rewind, and selective summarization |
| **Code Review (managed, RP)** | harness-review | Multi-agent PR review with `REVIEW.md` guidance. Teams/Enterprise |
| **Status Line (`/statusline`)** | all skills | Custom shell-script status bar for context/cost/git monitoring |
| **1M Context (`sonnet[1m]`)** | harness-review, breezing | 1M token context window for large codebase analysis |
| **Chrome Integration (`--chrome`, beta)** | harness-work, harness-review | Browser automation for UI testing, console debugging, data extraction |
| **`modelOverrides` setting (v2.1.73)** | setup, breezing | Map model picker entries to custom provider model IDs (Bedrock ARNs, etc.) |
| **`/output-style` deprecated (v2.1.73)** | all skills | Use `/config` instead; output style selection moved to config menu |
| **Bedrock/Vertex Opus 4.6 default (v2.1.73)** | breezing | Default Opus on cloud providers updated from 4.1 to 4.6 |
| **`autoMemoryDirectory` setting (v2.1.74)** | session-memory, setup | Custom auto-memory storage path for project-specific memory isolation |
| **`CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS` (v2.1.74)** | hooks | Configurable SessionEnd hooks timeout (was fixed 1.5s kill) |
| **Full model ID fix (v2.1.74)** | agents-v3/, breezing | `claude-opus-4-6` etc. now recognized in agent frontmatter and JSON config |
| **Streaming API memory leak fix (v2.1.74)** | breezing, work | Unbounded RSS growth in streaming response buffers fixed |
| **LSP server integration (`.lsp.json`)** | setup | Real-time diagnostics, code navigation via Language Server Protocol |
| **`SubagentStart`/`SubagentStop` matcher** | breezing, hooks | Agent type-specific lifecycle monitoring with matcher filtering |
| **Agent Teams: Task Dependencies** | breezing | Auto-unblocking dependent tasks with file-lock claiming |
| **`--teammate-mode` CLI flag** | breezing | Per-session display mode override (`in-process`/`tmux`) |
| **`skills` field in agent frontmatter** | agents-v3/ | Preload skill content into subagent context at startup |
| **`--remote` / Cloud Sessions** | breezing, harness-work | Terminal-to-cloud async task execution with `/teleport` retrieval |
| **`CLAUDE_ENV_FILE` SessionStart persistence** | hooks | Persist env vars from SessionStart hooks to subsequent Bash commands |
| **`PreCompact` hook** | hooks | Pre-compaction state save + WIP task warning (implemented) |
| **Slack Integration (`@Claude`)** | harness-work (future) | Route coding tasks from Slack channels via cloud sessions |
| **Analytics Dashboard** | setup, harness-review | PR attribution (`claude-code-assisted` label), usage/contribution metrics, leaderboard |
| **OpenTelemetry Monitoring** | hooks, breezing | OTel metrics/events export (sessions, tokens, cost, tool results, active time) |
| **`/security-review` command** | harness-review | Analyze pending changes for security vulnerabilities (injection, auth, data exposure) |
| **`/insights` command** | session-memory | Session analysis report: project areas, interaction patterns, friction points |
| **`/stats` command** | session | Daily usage visualization, session history, streaks, model preferences |
| **Prompt Suggestions** | all skills | Git-history-based context-aware autocomplete; Tab to accept, Enter to submit |
| **PR Review Status footer** | breezing, harness-review | Clickable PR link with color-coded review status (green/yellow/red/gray/purple) |
| **`CLAUDE_CODE_TASK_LIST_ID` env var** | breezing | Named task list sharing across sessions: `CLAUDE_CODE_TASK_LIST_ID=my-project claude` |
| **`fastModePerSessionOptIn` setting** | setup, breezing | Admin control: fast mode resets each session, users must `/fast` to re-enable |
| **1M Context Window (`opus[1m]`) (v2.1.75)** | breezing, harness-review | Opus 4.6 の 1M コンテキスト窓。Max/Team/Enterprise では自動昇格 |
| **Memory file timestamps (v2.1.75)** | session-memory, memory | メモリファイルの最終更新タイムスタンプ。鮮度ベースのメモリ判断を支援 |
| **Async hook suppression (v2.1.75)** | breezing, hooks | 非同期フック完了メッセージをデフォルト非表示。`--verbose` で表示 |
| **`/effort max` session-only (v2.1.75+)** | harness-work, harness-plan | Opus 4.6 限定の最深推論モード。セッション単位で有効化、永続化しない |
| **MCP Elicitation サポート (v2.1.76)** | hooks, breezing | MCP サーバーからの構造化入力要求。Breezing では自動スキップ |
| **`Elicitation`/`ElicitationResult` フック (v2.1.76)** | hooks | MCP elicitation の前後でインターセプト・ログ記録 |
| **`PostCompact` フック (v2.1.76)** | hooks, breezing | コンパクション完了後のコンテキスト再注入（PreCompact の対） |
| **`-n`/`--name` CLI フラグ (v2.1.76)** | breezing | セッション表示名の設定。セッション一覧での識別に活用 |
| **`worktree.sparsePaths` 設定 (v2.1.76)** | breezing, setup | モノレポでの worktree sparse-checkout。並列ワーカー起動高速化 |
| **`/effort` スラッシュコマンド (v2.1.76)** | harness-work | セッション中の effort レベル切替（low/medium/high） |
| **`--worktree` 起動高速化 (v2.1.76)** | breezing | git refs 直接読取 + 冗長な fetch スキップ |
| **バックグラウンドエージェント部分結果保持 (v2.1.76)** | breezing | kill 時にも部分結果がコンテキストに保存 |
| **stale worktree 自動クリーンアップ (v2.1.76)** | breezing | 中断された並列実行のワークツリーを自動削除 |
| **自動コンパクション circuit breaker (v2.1.76)** | all skills | 3 回連続失敗で自動停止（無限リトライ防止） |
| **`--plugin-dir` 仕様変更 (v2.1.76, breaking)** | setup | 複数ディレクトリは `--plugin-dir` 繰返しで指定 |
| **Deferred Tools スキーマ修正 (v2.1.76)** | all skills | コンパクション後の ToolSearch ツールスキーマ保持 |
| **`/context` コマンド (v2.1.74)** | all skills | コンテキスト消費の可視化と最適化提案。長時間セッションの肥大化防止 |
| **`maxTurns` エージェント安全制限** | agents-v3/ | Worker: 100, Reviewer: 50, Scaffolder: 75。暴走防止の安全弁 |
| **`Notification` フック実装** | hooks | 通知イベント（permission_prompt, idle_prompt 等）のログ記録。Breezing 観測性向上 |
| **Opus 4.6 出力 64k/128k (v2.1.77)** | all skills | デフォルト 64k、上限 128k トークン。長い実装・レビューの途切れ防止 |
| **Agent `resume` → `SendMessage` (v2.1.77)** | breezing | Agent tool の `resume` 廃止。`SendMessage` で stopped agent を自動再開 |
| **PreToolUse `allow`/`deny` セキュリティ修正 (v2.1.77)** | hooks | フック `allow` が `deny` ルールをバイパスしなくなった |
| **`StopFailure` hook (v2.1.78)** | hooks, breezing | API エラーでターン終了時に発火。Worker サイレント停止の検知（実装済み） |
| **`effort`/`maxTurns`/`disallowedTools` agent FM (v2.1.78)** | agents-v3/ | プラグインエージェント frontmatter の公式サポート |
| **`${CLAUDE_PLUGIN_DATA}` (v2.1.78)** | setup | アップデートを跨ぐプラグイン永続ストレージ |
| **`SessionEnd` `/resume` 修正 (v2.1.79)** | hooks, session | セッション切替時の SessionEnd 発火修正 |
| **`rate_limits` statusline (v2.1.80)** | all skills | レート制限使用率をステータスラインに表示 |
| **`effort` skill frontmatter (v2.1.80)** | all skills | スキル呼び出し時の自動 effort 切替（実装済み） |
| **`--bare` flag (v2.1.81)** | CI, codex | スクリプト用軽量モード。フック/LSP/プラグイン走査スキップ |
| **`--channels` relay (v2.1.81)** | breezing（将来） | モバイルへのツール承認プロンプト転送 |
| **Worktree resume (v2.1.81)** | breezing | セッション再開時の worktree 自動復帰 |

Full details: [docs/CLAUDE-feature-table.md](docs/CLAUDE-feature-table.md)

## Development Rules

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/): `feat:` / `fix:` / `docs:` / `refactor:` / `test:` / `chore:`

### Version Management

Keep `VERSION` and `.claude-plugin/plugin.json` in sync.
Normal feature/docs PRs must leave both files unchanged and record changes under `CHANGELOG.md`'s `[Unreleased]` section.
Use `./scripts/sync-version.sh bump` only when cutting a release.

### CHANGELOG

Details: [.claude/rules/changelog.md](.claude/rules/changelog.md) (Keep a Changelog format; include Before/After tables for major changes)

### Language

All responses must be in **Japanese** (including `context: fork` skills).

### Code Style

- Use clear and descriptive names
- Add comments for complex logic
- Keep commands/agents/skills single-responsibility

## Repository Structure

`.claude-plugin/` Plugin manifest / `agents/` Sub-agents / `skills/` Skills / `hooks/` Hooks / `scripts/` Shell scripts / `docs/` Documentation / `tests/` Validation

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
| memory | SSOT management, memory search, SSOT promotion | "SSOT", "decisions.md", "memory search", "claude-mem" |

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
