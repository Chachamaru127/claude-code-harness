# Changelog

Change history for claude-code-harness.

> **📝 Writing Guidelines**: Focus on user-facing changes. Keep internal fixes brief.

## [2.21.0] - 2026-02-18

### 🎯 What's Changed for You

**New OpenClaw plugin: autonomous daemon that checks Gmail, Calendar, LINE, Slack, Discord every 30 minutes using Bun + Claude Agent SDK.**

| Before | After |
|--------|-------|
| No autonomous message/email handling | `/openclaw start` launches a Bun daemon that runs Agent SDK sessions on a cron schedule |
| Manual email/message checking required | Daemon auto-checks all enabled services, drafts replies, and generates structured reports |
| No cross-service integration | Single daemon manages Gmail, Calendar, LINE, Slack, Discord via MCP servers |

### Added

- **OpenClaw daemon** (`openclaw/daemon/`): Bun + Claude Agent SDK cron-based autonomous agent
  - `index.ts`: Entry point with croner scheduling and Agent SDK `query()` invocation
  - `config.ts`: Config loader from `.claude-code-harness.config.yaml`
  - `mcp-registry.ts`: MCP server builder for 5 services (Google Workspace, LINE, Slack, Discord)
  - `session-manager.ts`: Session resume/new management for context continuity
  - `prompt-builder.ts`: Dynamic prompt generation based on enabled services
  - `logger.ts`: Structured NDJSON logging
  - `types.ts`: TypeScript type definitions
- **Skill `openclaw`** (`skills/openclaw/`): User-facing management commands
  - Subcommands: `setup`, `start`, `stop`, `status`, `config`
  - References: setup-guide, gmail-calendar, line, slack, discord, daemon-management
- **Agent `openclaw-daemon`** (`agents/openclaw-daemon.md`): Subagent definition for autonomous execution
- **Scripts**: `openclaw-start.sh`, `openclaw-stop.sh`, `openclaw-status.sh`
- **Config**: `openclaw` section in `.claude-code-harness.config.yaml`

---

## [2.20.9] - 2026-02-15

### 🎯 What's Changed for You

**In Codex mode, `harness-review` guidance is now consistently documented as delegating to Claude CLI (`claude -p`).**

| Before | After |
|--------|-------|
| Codex-side review docs mixed Codex/MCP wording and delegation targets | Codex-side docs consistently describe Claude CLI (`claude -p`) delegation flow |

### Changed

- Updated Codex-side review docs to align review mode wording, integration flow, and detection guidance around `claude -p` delegation.

### Internal

- Documentation consistency cleanup for Codex review-mode references.

---
## [2.20.8] - 2026-02-14

### Changed

- **Claude Code 2.1.41/2.1.42 adaptation**: Updated compatibility matrix and recommended version to v2.1.41+
  - Added v2.1.39〜v2.1.42 entries to `docs/CLAUDE_CODE_COMPATIBILITY.md` (4 new version sections, 30+ feature rows)
  - Recommended version raised from v2.1.38+ to **v2.1.41+** (Agent Teams Bedrock/Vertex/Foundry model ID fix, Hook stderr visibility fix)
- **Breezing Bedrock/Vertex/Foundry note**: Added CC 2.1.41+ requirement note to `guardrails-inheritance.md` for non-Anthropic API users
- **Session `/rename` auto-naming**: Added CC 2.1.41+ auto-generate session name documentation to session skill
- **Troubleshoot `claude auth` commands**: Added CC 2.1.41+ `claude auth login/status/logout` to diagnostic table

---
## [2.20.7] - 2026-02-14

### Fixed

- **Stop hook "JSON validation failed" on every turn (#42)**: Replaced unreliable `type: "prompt"` hook with deterministic `type: "command"` hook (`stop-session-evaluator.sh`)
  - Root cause: prompt-type hook instructed the LLM to respond in JSON, but the model frequently returned natural language, causing repeated JSON parse errors
  - New command-based evaluator always outputs valid JSON, eliminating validation failures entirely
  - Both `hooks/hooks.json` and `.claude-plugin/hooks.json` updated in sync

---
## [2.20.6] - 2026-02-14

### Fixed

- **session-auto-broadcast.sh の hookEventName バリデーションエラー** (#41):
  - `hookEventName` を `"AutoBroadcast"` → `"PostToolUse"` に修正（4箇所）
  - `session-broadcast.sh` の `hookEventName` を `"Broadcast"` → `"PostToolUse"` に修正
  - subprocess の stdout 汚染を防止（`>/dev/null` リダイレクト追加）
  - `test-hook-event-names.sh` テスト追加（hookEventName 一貫性の回帰テスト）

---
## [2.20.5] - 2026-02-12

### Fixed

- **Breezing `--codex` subagent_type enforcement**: Fixed `--codex` flag being ignored during Implementer spawn
  - Root cause: `execution-flow.md` Step 3 hardcoded `task-worker` with no `--codex` branch
  - Added mandatory `impl_mode` branching to SKILL.md, execution-flow.md, and team-composition.md
  - Added three "absolute prohibition" rules: codex mode must use `codex-implementer`, standard mode must use `task-worker`, codex mode Lead must not Write/Edit source
  - Added explicit parallel spawn instruction: N Implementers spawned simultaneously (`N = min(independent_tasks, --parallel N, 3)`)
  - Compaction Recovery now restores correct subagent_type based on `impl_mode`

---

## [2.20.4] - 2026-02-11

### Fixed

- **Codex MCP → CLI migration (Phase 7 completion)**:
  - Replace all `mcp__codex__codex` text references with `codex exec (CLI)` in `pretooluse-guard.sh` (4 messages) and `codex-worker-engine.sh` (1 log message)
  - Remove MCP legacy note from `codex-review/SKILL.md`
  - Add `codex-cli-only.md` rule to `.claude/rules/` for prevention
  - Add PreToolUse hook failsafe: deny `mcp__codex__*` tool calls with localized message via `emit_deny` + `msg()` pattern
  - Add `.gitignore` patterns for opencode/codex mirror dev-only skills (`test-*`, `x-promo`, `x-release-harness`)

### Security

- **Codex MCP dual-defense**: Three-layer protection against deprecated MCP usage (text correction + hook block + rule file). Codex review: Security A, Architect B

---

## [2.20.3] - 2026-02-10

### Fixed

- **Hook handler security hardening** (Codex review Round 1-3):
  - Replace manual JSON string escaping with `jq -nc --arg` and `python3 json.dumps` for safe JSON construction
  - Fix Python code injection vulnerability: pass data via `sys.argv`/`stdin` instead of triple-quote interpolation
  - Fix `grep` failure under `set -euo pipefail` with `|| true`
  - Use `grep -F` for fixed-string matching (avoid regex metacharacter issues)
  - Add `chmod 700` on `.claude/state` directory
  - Add `tostring` guard for description truncation type safety
  - Add 5-second dedup for TeammateIdle events
  - Add JSONL rotation (500 → 400 lines) to prevent unbounded growth

---

## [2.20.2] - 2026-02-10

### Added

- **TeammateIdle/TaskCompleted hook handlers**: New `scripts/hook-handlers/teammate-idle.sh` and `task-completed.sh` log agent team events to `.claude/state/breezing-timeline.jsonl`
- **3-layer memory architecture (D22)**: Documented coexistence design for Claude Code auto memory, Harness SSOT, and Agent Memory in `decisions.md`
- **Task(agent_type) pattern (P18)**: Documented sub-agent type restriction syntax in `patterns.md`

### Changed

- **Claude Code 2.1.38+ adaptation**: Updated Feature Table in CLAUDE.md with 6 new rows (TeammateIdle/TaskCompleted Hook, Agent Memory, Fast mode, Auto Memory, Skill Budget Scaling, Task(agent_type))
- **Version references**: Updated all "CC 2.1.30+" references to "CC 2.1.38+" across 16+ skill and agent files
- **Skill budget scaling**: Relaxed 500-line hard rule to recommendation in `skill-editing.md`, noting CC 2.1.32+ 2% context window scaling
- **Session memory**: Added "Auto Memory Relationship (D22)" section to `session-memory/SKILL.md` and `memory/SKILL.md`
- **Breezing execution flow**: Updated hook implementation status to "implemented" in `execution-flow.md`
- **Guardrails inheritance**: Added Task(agent_type) to safety mechanism table

---

## [2.20.1] - 2026-02-10

### Fixed

- **PostToolUse hook syntax error**: Fix bash parser error in `posttooluse-tampering-detector.sh` caused by `|| true` after heredoc inside command substitution
- **python3 fallback in all hooks**: Replace heredoc python3 fallback with `python3 -c` in all 10 hook scripts to fix stdin conflict
- **POSIX compliance**: Replace `echo` with `printf '%s'` for safe input piping, `echo -e` with `printf '%b'`
- **Pattern matching**: Replace `echo | grep -qE` with `[[ =~ ]]` for 6 pattern checks (with word boundaries)
- **Error handling**: Change `set -euo pipefail` to `set +e` to match all other PostToolUse scripts
- **Bilingual warnings**: Add English + Japanese warning messages to hook scripts

---

## [2.20.0] - 2026-02-08

### 🎯 What's Changed for You

**28 skills consolidated to 19. Breezing now runs with Phase A/B/C separation, teammate permissions fixed, and repo cleaned up.**

| Before | After |
|--------|-------|
| `memory`, `sync-ssot-from-memory`, `cursor-mem` as 3 skills | Unified `memory` (SSOT promotion + memory search in references) |
| `setup`, `setup-tools`, `harness-mem`, `codex-setup`, `2agent`, `localize-rules` as 6 skills | Unified `setup` (routing table dispatches to references) |
| `ci`, `agent-browser`, `x-release-harness` visible as slash commands | Hidden with `user-invocable: false` (auto-load still works) |
| Delegate mode ON at breezing start → bypass permissions lost | Phase A (prep) maintains bypass → delegate only in Phase B |
| Delegate mode stays on during completion → commit restricted | Phase C exits delegate → Lead can commit directly |
| Teammates auto-denied Bash due to "prompts unavailable" | `mode: "bypassPermissions"` + PreToolUse hooks for safety |
| Build artifacts, dev docs, lock files tracked in git | 33 files untracked, .gitignore updated |

### Changed

- **Skill consolidation (28 → 19)**:
  - `/memory`: Absorbed `sync-ssot-from-memory` and `cursor-mem`
  - `/setup`: Absorbed `setup-tools`, `harness-mem`, `codex-setup`, `2agent`, `localize-rules`
  - `/troubleshoot`: Added CI failure triggers to description
- **Breezing Phase separation**: Restructured execution flow into Phase A (Pre-delegate) / Phase B (Delegate) / Phase C (Post-delegate)
  - Phase A: Maintain user's permission mode while initializing Team and spawning teammates
  - Phase B: Delegate mode — Lead uses only TaskCreate/TaskUpdate/SendMessage
  - Phase C: Exit delegate, then run integration verification, commit, and cleanup
- **Teammate permission model**: All teammate spawns use `mode: "bypassPermissions"` with PreToolUse hooks as safety layer
  - PreToolUse hooks fire independently of permission system (official spec)
  - Safety layers: disallowedTools + spawn prompt constraints + .claude/rules/ + Lead monitoring
- **English-only releases**: GitHub release notes now written in English. Updated release rules and skills.
- **All related docs updated**: execution-flow.md, team-composition.md, codex-engine.md, guardrails-inheritance.md, session-resilience.md

### Added

- `skills/memory/references/cursor-mem-search.md` - Cursor memory search reference
- `skills/setup/references/harness-mem.md` - Harness-Mem setup reference
- `skills/setup/references/localize-rules.md` - Rule localization reference
- **Codex first-use check hook**: Auto-runs `check-codex.sh` on first `/codex-review` use (`once: true`)
- **timeout/gtimeout detection**: Guides macOS users to `brew install coreutils`

### Fixed

- **Codex review fixes (22 issues)**: pretooluse-guard JSON parse consolidation (5→1 jq call), symlink security guard, session-monitor `eval` removal
- **macOS compatibility**: All docs `timeout N codex exec` → `$TIMEOUT N codex exec` (GNU coreutils independent)
- **Teammate Bash auto-deny**: Resolved "prompts unavailable" error for background teammates

### Removed

- **Untracked 33 files**: `mcp-server/dist/` (24 build artifacts), `docs/design/` (2), `docs/slides/` (1), `docs/claude-mem-japanese-setup.md`, dev-only docs (3), lock files (2)
- **Archived skills**: `sync-ssot-from-memory`, `cursor-mem`, `setup-tools`, `harness-mem`, `codex-setup`, `2agent`, `localize-rules` → `skills/_archived/`

---

## [2.19.0] - 2026-02-08

### 🎯 What's Changed for You

**5つの実装コマンドを `/work` と `/breezing` の2つに統一。両方 `--codex` 対応。**

| Before | After |
|--------|-------|
| `/work`, `/ultrawork`, `/breezing`, `/breezing-codex`, `/codex-worker` の5コマンド | `/work` と `/breezing` の2コマンドに統一 |
| コマンドの使い分けが複雑 | `/work` = Claude 実装、`/breezing` = チーム完走 |
| Codex は別コマンド (`/codex-worker`, `/breezing-codex`) | `--codex` フラグで統一切り替え |
| スコープ指定方法がコマンドごとに異なる | 両コマンド共通の対話式スコープ確認 |

### Changed

- **`/work` 全面改修**: 対話式スコープ確認 + タスク数に応じた自動戦略選択
  - 1タスク → 直接実装、2-3 → 並列、4+ → 自動反復（旧 ultrawork 統合）
  - `--codex` フラグで Codex MCP 実装委託モード
  - 新リファレンス: scope-dialog.md, auto-iteration.md, codex-engine.md
- **`/breezing` 更新**: `--codex` フラグ統合（旧 breezing-codex 吸収）
  - 対話式スコープ確認の追加
  - Codex Implementer 連携を codex-engine.md に集約
- **pretooluse-guard.sh**: `ultrawork-active.json` → `work-active.json` に統一
  - 後方互換: 旧ファイル名もフォールバックで検出

### Removed

- **ultrawork** スキル → `/work all` で同等機能（`skills/_archived/` に移動）
- **breezing-codex** スキル → `/breezing --codex` で同等機能（`skills/_archived/` に移動）
- **codex-worker** スキル → `/work --codex` で同等機能（`skills/_archived/` に移動）

---

## [2.18.11] - 2026-02-06

### 🎯 What's Changed for You

**In `--codex` mode, Claude now acts as PM and Edit/Write are automatically blocked**

| Before | After |
|--------|-------|
| Claude could edit directly in `--codex` mode | Edit/Write blocked except for Plans.md |
| Ambiguous role separation | Clear PM (Claude) vs Worker (Codex) separation |

### Added

- **breezing skill (v2)**: Full auto task completion using Agent Teams
  - Lead in delegate mode (coordination only), Implementer for coding, independent Reviewer
  - `--codex-review` for multi-AI review integration
  - session_id-based Hook enforcement: Reviewer Read-only, Implementer file ownership (pretooluse-guard.sh)
  - Flexible flow: Lead-autonomous stages replace rigid Phase 0-4
  - State simplification: Agent Teams TaskList as SSOT, breezing-active.json metadata-only
  - Peer-to-peer: Reviewer↔Implementer direct dialogue for lightweight questions
  - Agent Trace: per-Teammate metrics in completion reports
- **Codex mode guard**: Added Codex mode detection to `pretooluse-guard.sh`
  - Claude functions as PM, delegating implementation to Codex Worker
  - Enabled via `codex_mode: true` in `ultrawork-active.json`
  - Only Plans.md state marker updates allowed

### Changed

- **Codex review improvements**: Enhanced parallel review quality
  - SSOT-aware reviews (considers decisions.md/patterns.md)
  - Output limit relaxed 1500 → 2500 chars for thorough analysis
  - Clear termination conditions (APPROVE when Critical/High = 0)
  - Fixed "nitpicking" issue (Low/Medium only → APPROVE)

### Internal

- Minor expert template fixes

---

## [2.18.10] - 2026-02-06

### Added

- **Agent persistent memory**: Added `memory: project/user` to all 7 agents
  - Subagents can now build institutional knowledge across conversations
  - Security: Read-only agents (code-reviewer, project-analyzer) keep Bash/Write/Edit disabled
  - Privacy guards: Each agent documents forbidden data (secrets, PII, source code snippets)

---

## [2.18.7] - 2026-02-05

### Changed

- **Claude guardrails**: Stop prompting on normal `git push`; prompt only on `git push -f/--force/--force-with-lease`.

---

## [2.18.6] - 2026-02-05

### Fixed

- **Codex guardrails**: `harness.rules` now parses reliably and avoids prompting on safe commands (e.g. `git clean -n`, `sudo -n true`).
- **Claude guardrails**: `templates/claude/settings.security.json.template` now uses valid permission syntax (`:*`) and prompts only on destructive variants.

### Internal

- **Codex package test**: Added rule example validation to prevent startup parse errors.

---

## [2.18.5] - 2026-02-05

### Added

- **gogcli-ops skill**: Google Workspace CLI operations (Drive/Sheets/Docs/Slides)
  - Auth workflow and account selection
  - URL-to-ID resolution via `gog_parse_url.py`
  - Read-only by default, write requires confirmation

---

## [2.18.4] - 2026-02-04

### Added

- **Codex setup command**: Added `/codex-setup` skill and `scripts/codex-setup-local.sh`
- **Setup tools**: `/setup-tools codex` subcommand for in-session Codex setup
- **Harness init/update**: Optional Codex CLI sync during `/harness-init` and `/harness-update`

---

## [2.18.2] - 2026-02-04

### Added

- **Codex CLI distribution**: Added `codex/.codex` with full skills and temporary Rules guardrails
- **Codex setup**: Added `scripts/setup-codex.sh` and `codex/README.md`
- **Codex AGENTS**: Added `codex/AGENTS.md` tuned for `$skill` usage
- **Codex package test**: Added `tests/test-codex-package.sh`

### Changed

- **Docs**: README now includes Codex CLI setup instructions

---

## [2.18.1] - 2026-02-04

### Added

- **Aivis/VOICEVOX TTS support**: Added Japanese TTS providers to generate-video skill
  - `aivis`: Aivis Cloud API (speaker_id, intonation_scale, etc.)
  - `voicevox`: VOICEVOX (character voices like Zundamon)
  - Sample character configurations included

### Changed

- **MCP server optional**: Removed `.mcp.json`, excluded mcp-server from distribution
  - Users who need it can set up separately

---

## [2.18.0] - 2026-02-04

### Added

- **Claude Code 2.1.30 compatibility**: Full integration with new features
  - **AgentTrace v0.3.0**: Task tool metrics (tokenCount, toolUses, duration) in `docs/AGENT_TRACE_SCHEMA.md`
  - **`/debug` command integration**: troubleshoot skill now routes to `/debug` for complex session issues
  - **PDF page range reading**: notebookLM and harness-review support `pages` parameter for large documents
  - **Git log extended flags**: harness-review, CI, release-harness use `--format`, `--raw`, `--cherry-pick`
  - **OAuth `--client-id/--client-secret`**: codex-mcp-setup.md documents DCR-incompatible MCP setup
  - **68% memory optimization**: session-memory and session skills document `--resume` benefits
  - **Subagent MCP access**: task-worker and codex-worker document MCP tool sharing (bugfix in CC 2.1.30)
  - **Accessibility settings**: harness-ui documents `reducedMotion` setting

---

## [2.17.10] - 2026-02-04

### Added

- **PreCompact/SessionEnd hooks**: Support automatic session state save and cleanup
- **AgentTrace v0.2.0**: Added Attribution field for plugin attribution tracking
- **Sandbox settings template**: Added `templates/settings/harness-sandbox.json`

### Changed

- **context: fork added**: deploy/generate-video/memory/verify skills now use isolated context
- **release → release-harness**: Renamed to avoid conflict with Claude Code built-in command

---

## [2.17.9] - 2026-02-04

### Changed

- **Codex mode as default**: New project config template now defaults to `review.mode: codex`
- **Worktree necessity check**: `/ultrawork --codex` now auto-determines if Worktree is actually needed
  - Single task, all sequential dependencies, or file overlap → fallback to direct execution mode
  - Avoids unnecessary Worktree creation overhead

---

## [2.17.8] - 2026-02-04

### Fixed

- **release skill**: Fix `/release` not launching via Skill tool
  - Removed `disable-model-invocation: true`

---

## [2.17.6] - 2026-02-04

### 🎯 What's Changed for You

**generate-video スキルが JSON Schema 駆動のハイブリッドアーキテクチャに進化、README も刷新されました**

| Before | After |
|--------|-------|
| 動画生成の設定がコードに散在 | JSON Schema でシナリオを一元管理 |
| README の構成が長大 | TL;DR: Ultrawork セクションで即座に始められる |
| スキル説明が英語のみ | 28個のスキル description が日本語化 + ユーモア表現 |

### Added

- **generate-video JSON Schema Architecture** (#37)
  - `scenario-schema.json` でシナリオ構造を厳密定義
  - `validate-scenario.js` でセマンティック検証
  - `template-registry.js` でテンプレート管理
  - パストラバーサル攻撃対策を実装

- **TL;DR: Ultrawork セクション**: README に「説明が長い？これだけ」セクション追加
  - 日本語版にも「🪄 説明が長い？ならこれ: Ultrawork」として追加

### Changed

- **スキル description 日本語化**: 28個のスキルに日本語の説明とユーモア表現を追加
- **README 構成整理**: Install → TL;DR → Core Loop の流れに最適化
- **スキル数更新**: 42 → 45 スキル

### Fixed

- `validate-scenario.js`: セマンティックエラーフィルタリングのバグ修正
- `TransitionWrapper.tsx`: `slideIn` → `slide_in` でスキーマ命名規則に統一

---

## [2.17.3] - 2026-02-03

### 🎯 What's Changed for You

**Ultrawork がレビュー後に自動で自己修正ループに入るようになりました**

| Before | After |
|--------|-------|
| レビュー後に手動でプロンプト入力が必要 | APPROVE まで自動修正ループ |
| Codex 有無を手動で指定 | Codex MCP 自動検出 + フォールバック |
| 改善方法が不明確 | 「🎯 How to Achieve A」で改善指針を明示 |

### Added

- **自己修正ループ**: `/harness-review` 実行後、APPROVE になるまで自動で修正を繰り返す
  - リトライ状態管理（`ultrawork-retry.json`）で進捗追跡
  - REJECT/STOP は即停止して手動介入を促す
  - 最大3回のリトライ後に STOP

- **検証全実行規則**: 存在する検証スクリプトを優先順で全て実行し、失敗で即停止

- **改善指針テンプレート**: 「🎯 How to Achieve A」セクションで A 評価達成方法を明示
  - Decision 別統一フォーマット（APPROVE/REQUEST CHANGES/REJECT/STOP）

### Changed

- **Codex 自動検出**: Codex MCP が利用可能な場合は自動で Codex モードに切り替え
  - 利用不可の場合はサブエージェント並列にフォールバック
  - `timeout_ms`（ミリ秒単位）でタイムアウト設定可能

- **差分計算改善**: `merge-base` 基準で変更ファイル数を算出
  - staged/unstaged 差分も含む
  - 初回コミット/マージにも対応

- **review_aspects 検出**: パスベースの正規表現で決定的に判定

---

## [2.17.2] - 2026-02-03

### 🎯 What's Changed for You

**Codex Worker 完了時に Plans.md が自動更新されるようになりました**

| Before | After |
|--------|-------|
| 作業完了後に手動で Plans.md を更新 | スキルが自動で `cc:done` に更新 |

### Added

- **Plans.md 自動更新**: Codex Worker スキル完了時に必ずタスク完了処理を実行
  - 該当タスクを自動特定
  - `[ ]` → `[x]`, `cc:WIP` → `cc:done` に更新
  - タスクが見つからない場合はユーザーに確認

### Internal

- Codex Worker スクリプト品質改善（共通ライブラリ化、セキュリティ強化）

---

## [2.17.1] - 2026-02-03

### Added

- **Agent Trace**: Track AI-generated code edits for session context visibility
  - `emit-agent-trace.js`: PostToolUse hook records Edit/Write operations to `.claude/state/agent-trace.jsonl`
  - `agent-trace-schema.json`: JSON Schema (v0.1.0) for trace records
  - Stop hook now shows project name, current task, and recent edits at session end
  - `sync-status` skill now includes Agent Trace data for progress verification
  - `session-memory` skill now reads Agent Trace for cross-session context

### Changed

- Stop hook (`session-summary.sh`) enhanced with Agent Trace information display
- VCS info retrieval optimized: single `git status --porcelain=2 -b -uno` call with 5s TTL cache
- Repo root detection no longer spawns git process (walks up directory tree)

### Fixed

- Security hardening for trace file operations (symlink checks, permission enforcement)
- Rotation concurrency protection with lock file (O_CREAT|O_EXCL pattern)

---

## [2.17.0] - 2026-02-03

### Added

- **Codex Worker**: Delegate implementation tasks to OpenAI Codex as parallel workers
  - `codex-worker` skill for single task delegation
  - `ultrawork --codex` for parallel worker execution with git worktrees
  - Quality gates: evidence verification, lint/type-check, test, tampering detection
  - File locking mechanism with TTL and heartbeat
  - Automatic Plans.md update on task completion

### Changed

- Skills `codex-worker` and `codex-review` now have explicit routing rules (Do NOT Load For sections)
- Improved skill description for better auto-loading accuracy

### Fixed

- Shell script security improvements (jq injection, git option injection, value validation)
- POSIX compatibility for grep patterns (`\s` to `[[:space:]]`)
- Arithmetic operation in `set -e` context

### Internal

- Added 5 shell scripts: `codex-worker-setup.sh`, `codex-worker-engine.sh`, `codex-worker-lock.sh`, `codex-worker-quality-gate.sh`, `codex-worker-merge.sh`
- Added integration test: `tests/test-codex-worker.sh`
- Added reference documentation: `skills/codex-worker/references/*.md`

---

## [2.16.21] - 2026-02-03

### Changed

- `ultrawork` Codex Mode options (`--codex`, `--parallel`, `--worktree-base`) moved to Design Draft
  - These features are planned but not yet implemented
  - Documentation now clearly marks them as "(Design Draft / 未実装)"

### Internal

- Added `skills/ultrawork/references/codex-mode.md` as design draft documentation
- Added Codex Worker scripts and references (untracked, for future implementation)

---

## [2.16.20] - 2026-02-03

### Internal

- Centralized skill routing rules to `skills/routing-rules.md` (SSOT pattern)
- Made `codex-review` and `codex-worker` routing deterministic (removed context judgment)

---

## [2.16.19] - 2026-02-03

### Fixed

- Reduced duplicate display of Stop hook reason (now outputs keywords only)

---

## [2.16.17] - 2026-02-03

### 🎯 What's Changed for You

**Skills now show usage hints in autocomplete**

| Before | After |
|--------|-------|
| `/harness-review` | `/harness-review [code|plan|scope]` |
| `/troubleshoot` | `/troubleshoot [build|test|runtime]` |

### Added

- Usage hints (`argument-hint`) added to 17 skills
- Inter-session notifications (useful for multi-session workflows)

### Internal

- Updated CI/tests/docs for Skills-only architecture

---

## [2.16.14] - 2026-02-02

### 🎯 What's Changed for You

**Implementation requests are now automatically registered in Plans.md**

| Before | After |
|--------|-------|
| Ad-hoc requests not tracked | All tasks recorded in Plans.md |
| Hard to track progress | `/sync-status` shows full picture |

---

## [2.16.11] - 2026-02-02

### 🎯 What's Changed for You

**Commands have been unified into Skills (usage unchanged)**

| Before | After |
|--------|-------|
| `/work`, `/harness-review` as commands | Same names, now powered by skills |
| Internal skills (impl, verify) in menu | Hidden (less noise) |
| `dev-browser`, `docs`, `video` | Renamed to `agent-browser`, `notebookLM`, `generate-video` |

### Internal

- README rewritten for VibeCoders (added troubleshooting, uninstall)
- CI scripts updated for Skills structure

---

## [2.16.5] - 2026-01-31

### 🎯 What's Changed for You

**`/generate-video` now supports AI images, BGM, subtitles, and visual effects**

| Before | After |
|--------|-------|
| Manual image preparation | AI auto-generates (Nano Banana Pro) |
| No BGM/subtitles | Royalty-free BGM, Japanese subtitles |
| Basic transitions only | GlitchText, Particles, and more |

---

## [2.16.0] - 2026-01-31

### 🎯 What's Changed for You

**`/ultrawork` now requires fewer confirmations for rm -rf and git push (experimental)**

| Before | After |
|--------|-------|
| rm -rf always asks | Only paths approved in plan auto-approved |
| git push always asks | Auto-approved during ultrawork (except force) |

---

## [2.15.0] - 2026-01-26

### 🎯 What's Changed for You

**Full OpenCode compatibility mode added**

| Before | After |
|--------|-------|
| Separate setup needed for OpenCode | `/setup-opencode` auto-configures |
| Different skills/ structure | Same skills work in both environments |

---

## [2.14.0] - 2026-01-16

### 🎯 What's Changed for You

**`/work --full` enables parallel task execution**

| Before | After |
|--------|-------|
| Tasks run one at a time | `--parallel 3` runs up to 3 concurrently |
| Manual completion checks | Each worker self-reviews autonomously |

---

## [2.13.0] - 2026-01-14

### 🎯 What's Changed for You

**Codex MCP parallel review added**

| Before | After |
|--------|-------|
| Claude reviews alone | 4 Codex experts review in parallel |
| One perspective at a time | Security/Quality/Performance/a11y simultaneously |

---

## [2.12.0] - 2026-01-10

### Added

- **Harness UI Dashboard** (`/harness-ui`) - Track progress in browser
- **Browser Automation** (`agent-browser`) - Page interactions & screenshots

---

## [2.11.0] - 2026-01-08

### Added

- **Inter-session Messaging** - Send/receive messages between Claude Code sessions
- **CRUD Auto-generation** (`crud` skill) - Generate endpoints with Zod validation

---

## [2.10.0] - 2026-01-04

### Added

- **LSP Integration** - Go-to-definition, Find-references for accurate code understanding
- **AST-Grep Integration** - Structural code pattern search

---

## Earlier Versions

For v2.9.x and earlier, see [GitHub Releases](https://github.com/Chachamaru127/claude-code-harness/releases).

[2.20.9]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.8...v2.20.9
[2.20.8]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.7...v2.20.8
[2.20.7]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.6...v2.20.7
[2.20.6]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.5...v2.20.6
[2.20.5]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.4...v2.20.5
[2.18.7]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.6...v2.18.7
[2.18.6]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.5...v2.18.6
[2.18.5]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.4...v2.18.5
[2.18.4]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.2...v2.18.4
[2.18.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.1...v2.18.2
[2.18.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.0...v2.18.1
[2.18.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.17.10...v2.18.0
