# Changelog

Change history for claude-code-harness.

> **📝 Writing Guidelines**: This CHANGELOG describes "what changed for users".
> - Clear **Before/After** comparisons
> - Focus on "usage changes" and "experience improvements" over technical details
> - Make it clear "what's in it for you"

---

## [Unreleased]

---

## [2.9.2] - 2026-01-16

### 🎯 What's Changed for You

**Phase 33 complete: SESSION_ID tracking, customizable Plans.md location, context usage monitoring.**

#### Before/After

| Before | After |
|--------|-------|
| No session tracking in logs | `${CLAUDE_SESSION_ID}` integrated into session-log.md |
| Plans.md fixed at project root | Customizable via `plansDirectory` setting |
| No context usage visibility | `/sync-status` shows usage with 70% warning threshold |
| LSP patterns only in skills | `agents/code-reviewer.md` includes LSP impact analysis |

### Added

- **SESSION_ID integration**: Track sessions across logs for better debugging
- **plansDirectory setting**: Move Plans.md to `.claude/memory/` if desired
- **context_window guidance**: Clear thresholds (green/yellow/red) in `/sync-status`
- **Nested Skills design doc**: `docs/NESTED_SKILLS_DESIGN.md` for future restructuring
- **code-reviewer LSP**: Step 2.5 with `findReferences`, `goToDefinition`, `hover`

### Changed

- **README**: Added Claude Code v2.1.6+ requirement with compatibility link
- **hooks-editing.md**: Extended timeout guidelines documented

---

## [2.9.1] - 2026-01-16

### 🎯 What's Changed for You

**Claude Code 2.1.x compatibility: smarter hooks, LSP guidance, and lightweight subagent init.**

#### Before/After

| Before | After |
|--------|-------|
| Quality rules only checked at review time | Quality guidelines injected during file edits via `additionalContext` |
| Subagents had same init overhead as main agent | Subagents get lightweight init (faster task-worker execution) |
| Manual code navigation for impact analysis | LSP guidance in impl/review skills (findReferences, goToDefinition) |
| Short hook timeouts caused failures | Extended timeouts for long-running hooks (up to 120s) |

### Added

- **PreToolUse additionalContext**: Injects quality guidelines when editing files
  - Test files → test-quality.md rules (no test tampering)
  - Source files → implementation-quality.md rules
- **SessionStart agent_type**: Subagents skip full initialization
- **LSP guidance**: impl/review skills now recommend LSP for code analysis
- **Compatibility docs**: `docs/CLAUDE_CODE_COMPATIBILITY.md` with version matrix

### Changed

- **Hook timeouts extended** (for Claude Code v2.1.3+):
  - usage-tracker: 10s → 30s
  - auto-test-runner: 30s → 120s
  - session-summary: 30s → 60s
  - auto-cleanup-hook: 30s → 60s
- **MCP auto mode** (v2.1.7+): Removed explicit MCPSearch calls from cursor-mem skill

---

## [2.9.0] - 2026-01-16

### 🎯 What's Changed for You

**Full-cycle parallel automation: implement → self-review → improve → commit in one command.**

#### Before/After

| Before | After |
|--------|-------|
| `/work` executes tasks one at a time | `/work --full --parallel 3` runs full cycle in parallel |
| Review was a separate manual step | Each task-worker self-reviews autonomously |
| Commits were manual | Auto-commit after `commit_ready` judgment |
| Same workspace risked file conflicts | `--isolation=worktree` for complete separation |

### Added

- **task-worker integration (Phase 32)**: `/work --full` automates implement → self-review → improve → commit
  - New agent `agents/task-worker.md` with 4-point self-review
  - 7 new options for `/work`: `--full`, `--parallel N`, `--isolation`, `--commit-strategy`, `--deploy`, `--max-iterations`, `--skip-cross-review`
- **4-phase parallel execution**: Dependency graph → task-workers → Codex cross-review → Commit
- **commit_ready criteria**: No Critical/Major issues, build success, tests pass

---

## [2.8.2] - 2026-01-14

### 🎯 What's Changed for You

**Codex parallel review now enforces individual MCP calls and smart expert filtering.**

#### Before/After

| Before | After |
|--------|-------|
| Experts might be combined in single MCP call | MANDATORY rules enforce individual parallel calls |
| Always called 8 experts | Smart filtering: only relevant experts for project type |
| Inconsistent tool names in docs | Unified to `mcp__codex__codex` |

### Fixed

- **MCP tool name** unified to `mcp__codex__codex` across all docs
- **"8 experts" → "up to 8 experts"** to clarify filtering applies
- **Document-only change rules** unified (Quality, Architect, Plan Reviewer, Scope Analyst priority)
- **MANDATORY parallel call rules** added to prevent expert consolidation

### Changed

- Expert filtering now considers:
  - Config-based (`enabled: false` → skip)
  - Project type (CLI/Backend → skip Accessibility, SEO)
  - Change content (docs only → skip Security, Performance)

---

## [2.8.1] - 2026-01-13

### 🎯 What's Changed for You

**CI-only commands are now hidden from `/` completion.**

- `harness-review-ci`, `plan-with-agent-ci`, `work-ci` now have `user-invocable: false`

---

## [2.8.0] - 2026-01-13

### 🎯 What's Changed for You

**Commit Guard + Codex Mode integration for quality gates.**

- **Commit Guard**: Blocks `git commit` until review is approved
- **Codex Mode**: 8 expert parallel reviews via MCP
- **Auto-judgment**: APPROVE/REQUEST CHANGES/REJECT with auto-fix loop

---

## [2.7.12] - 2026-01-11

### 🎯 What's Changed for You

**Codex now checks its own version and supports model selection.**

- **Codex CLI version check**: On first run, compares the installed Codex CLI version with the latest version and guides you through updating (runs `npm update -g @openai/codex` after approval).
- **Codex model selection**: Choose the model via config.
  - Default: `gpt-5.2-codex`
  - Options: `gpt-5.2-codex`, `gpt-5.1-codex`, `gpt-5-codex-mini`

---

## [2.7.11] - 2026-01-11

### 🎯 What's Changed for You

**Codex is now a true parallel reviewer inside `/harness-review` — and its suggestions can be verified and turned into executable Plans.md tasks.**

#### Before/After

| Before | After |
|--------|-------|
| Codex ran after Claude reviews (sequential) | Codex runs as the 5th parallel reviewer |
| Codex output was shown as-is | Claude validates Codex findings and proposes vetted fixes |
| Review results were “display-only” | After approval, fixes are written to Plans.md and executed via `/work` |

---

## [2.7.10] - 2026-01-11

### 🎯 What's Changed for You

**You can run Codex as a standalone reviewer with `/codex-review`, and `/harness-review` can auto-detect Codex on first run.**

- **New `/codex-review` command**: Runs a Codex-only second-opinion review.
- **First-run Codex detection (`once: true` hook)**: `/harness-review` checks whether Codex is installed and guides enablement when found.
- Added `scripts/check-codex.sh`.

---

## [2.7.9] - 2026-01-11

### 🎯 What's Changed for You

**Codex MCP integration: get a second-opinion review from Codex during `/harness-review`.**

- Integrates OpenAI Codex CLI as an MCP server for Claude Code.
- Works in both Solo and 2-Agent workflows.
- Added a new skill and references:
  - `skills/codex-review/SKILL.md`
  - `skills/codex-review/references/codex-mcp-setup.md`
  - `skills/codex-review/references/codex-review-integration.md`
- Added Codex integration guidance to the existing `review` skill:
  - `skills/review/references/codex-integration.md`
- Added `review.codex` config section (example):
  ```yaml
  review:
    codex:
      enabled: false
      auto: false
      prompt: "..."
  ```

---

## [2.7.8] - 2026-01-11

### 🎯 What's Changed for You

**Fixed a broken skill reference in `/plan-with-agent`.**

- After the Progressive Disclosure migration in v2.7.7, an old skill path remained.
- Updated `claude-code-harness:setup:adaptive-setup` → `claude-code-harness:setup`.

---

## [2.7.7] - 2026-01-11

### 🎯 What's Changed for You

**Skills now align with the official spec more closely (Progressive Disclosure), making them easier to discover and less fragile.**

- Migrated `doc.md` → `references/*.md` (43 files)
- Updated parent `SKILL.md` to the Progressive Disclosure pattern (14 skills)
- Removed non-official frontmatter field `metadata.skillport` (63 files)
- Fixed `vibecoder-guide/SKILL.md` name: `vibecoder-guide-legacy` → `vibecoder-guide`

#### Before/After

| Before | After |
|--------|-------|
| `skills/impl/work-impl-feature/doc.md` | `skills/impl/references/implementing-features.md` |
| Manual routing via `## Routing` + paths | “Details” table via Progressive Disclosure |
| Non-official `metadata.skillport` | Official fields only (`name`, `description`, `allowed-tools`) |

---

## [2.7.4] - 2026-01-10

### 🎯 What's Changed for You

**Sessions end smarter and cheaper with the Intelligent Stop Hook.**

- Consolidated 3 Stop scripts (check-pending, cleanup-check, plans-reminder) into a single `type: "prompt"` hook.
- Uses `model: "haiku"` to optimize cost/latency.
- Evaluates 5 angles on session stop: task completion, errors, follow-ups, Plans.md updates, cleanup recommendation.
- Kept `session-summary.sh` (command hook) as-is.
- Added `context: fork` to `ci` / `troubleshoot` skills to prevent context pollution.
- Added test coverage:
  - `tests/test-intelligent-stop-hook.sh`
  - `tests/test-hooks-sync.sh`

---

## [2.7.3] - 2026-01-08

### 🎯 What's Changed for You

**Fixed 2.6.x → 2.7.x migration compatibility so Stop hooks keep working even with older cached plugin versions.**

- `sync-plugin-cache.sh` now also syncs `.claude-plugin/hooks.json` and `.claude-plugin/plugin.json`.
- New Stop helper scripts are synced as well (`stop-cleanup-check.sh`, `stop-plans-reminder.sh`).

---

## [2.7.2] - 2026-01-08

### 🎯 What's Changed for You

**Fixed compatibility with Claude Code 2.1.1 security changes that blocked `prompt`-type Stop hooks.**

- Converted the Stop hook from `prompt` → `command` and implemented alternatives:
  - `stop-cleanup-check.sh` (cleanup recommendation)
  - `stop-plans-reminder.sh` (Plans.md marker reminder)
- Fully synchronized `hooks/hooks.json` and `.claude-plugin/hooks.json`.

---

## [2.7.1] - 2026-01-08

### 🎯 What's Changed for You

**Removed references to deprecated commands and clarified migration paths.**

- Removed `/validate` `/cleanup` `/remember` `/refactor` mentions across README / skills / hooks, replaced with skill guidance.
- Added missing frontmatter (`description`, `description-en`) to `commands/optional/harness-mem.md`.

---

## [2.7.0] - 2026-01-08

### 🎯 What's Changed for You

**Major update for Claude Code 2.1.0: fewer slash entries, stronger safety, and better lifecycle visibility.**

- Added SubagentStart/SubagentStop hooks (with history logging).
- Added `once: true` hooks to prevent duplicate runs in a session.
- Added `context: fork` support for heavy operations (e.g. `review` / `/harness-review`).
- Added `skills` and `disallowedTools` fields to agents for safer execution.
- Added templates for `language` setting and wildcard Bash permissions.
- Removed 4 duplicate commands in favor of skills: `/validate`, `/cleanup`, `/remember`, `/refactor`.

---

## [2.5.23] - 2025-12-23

### 🎯 What's Changed for You

**Added `/release` command. Release workflow (CHANGELOG update, version bump, tag creation) is now standardized.**

#### Before
- Had to manually update CHANGELOG, VERSION, plugin.json, and create tags for each release
- Easy to forget steps, inconsistent process

#### After
- **Just say `/release`** and the release process is guided
- Consistent flow from CHANGELOG format to version bump to tag creation

---

## [2.5.22] - 2025-12-23

### 🎯 What's Changed for You

**Plugin updates now reliably apply. No more "updated but still using old version".**

#### Before
- Plugin updates sometimes didn't apply due to stale cache
- Had to manually delete cache and reinstall

#### After
- **Just start a new session and latest version auto-applies**
- No manual intervention needed

---

## [2.5.14] - 2025-12-22

### 🎯 What's Changed for You

**Automated post-review handoff in 2-Agent workflow.**

#### Before
- After `/review-cc-work`, had to run `/handoff-to-claude` separately
- On approval, had to manually "analyze next task → generate request"

#### After
- **`/review-cc-work` auto-generates handoff for both approve/request_changes**
- On approve: auto-analyzes next task and generates request
- On request_changes: generates request with modification instructions

---

## [2.5.13] - 2025-12-21

### 🎯 What's Changed for You

**LSP (code analysis) is now automatically recommended when needed.**

#### Before
- LSP usage was optional, could skip it during code editing
- Impact analysis before code changes was often skipped

#### After
- **LSP analysis auto-recommended during code changes** (when LSP is installed)
- Work continues even without LSP (`/lsp-setup` for easy installation)
- All 10 official LSP plugins supported

---

## [2.5.10] - 2025-12-21

### 🎯 What's Changed for You

**LSP setup is now easy.**

#### Before
- Multiple ways to configure LSP, unclear which to use

#### After
- **`/lsp-setup` auto-detects and suggests official plugins**
- Setup completes in 3 steps

---

## [2.5.9] - 2025-12-20

### 🎯 What's Changed for You

**Adding LSP to existing projects is now easy.**

#### Before
- Unclear how to add LSP settings to existing projects

#### After
- **`/lsp-setup` adds LSP to existing projects in one go**
- Added language-specific installation command list

---

## [2.5.8] - 2025-12-20

### 🎯 What's Changed for You

**Jump to definitions and find references instantly with LSP.**

#### Before
- Had to manually search for function definitions and references
- Type errors only detected at build time

#### After
- **"Where is this function defined?"** → Jump instantly
- **"Where is this variable used?"** → List all usages
- **Detect type errors before build**

---

## [2.5.7] - 2025-12-20

### 🎯 What's Changed for You

**2-Agent mode setup gaps are now auto-detected.**

#### Before
- Sometimes Cursor commands weren't generated even after selecting 2-Agent mode
- Unclear what was missing

#### After
- **Auto-check required files on setup completion**
- Auto-regenerates missing files

---

## [2.5.6] - 2025-12-20

### 🎯 What's Changed for You

**Old settings are now auto-fixed during updates.**

#### Before
- Wrong settings remained after updates

#### After
- **`/harness-update` detects breaking changes and suggests auto-fixes**

---

## [2.5.5] - 2025-12-20

### 🎯 What's Changed for You

**Safely update existing projects to latest version.**

#### Before
- No way to update existing projects to latest version
- Risk of losing settings and tasks during update

#### After
- **`/harness-update` for safe updates**
- Auto-backup, non-destructive update

---

## [2.5.4] - 2025-12-20

### 🎯 What's Changed for You

**Fixed bug generating invalid settings.json syntax.**

---

## [2.5.3] - 2025-12-20

### 🎯 What's Changed for You

**Skill names are now simpler.**

#### Before
- Skill names were long like `ccp-work-impl-feature`

#### After
- **Intuitive names like `impl-feature`**

---

## [2.5.2] - 2025-12-19

### 🎯 What's Changed for You

**Fewer accidental skill activations.**

- Each skill now has clear "when to use / when not to use"
- Added MCP wildcard permission config examples

---

## [2.5.1] - 2025-12-19

### 🎯 What's Changed for You

**No more confirmation prompts on every edit.**

#### Before
- Edit/Write prompts on every edit, interrupting work

#### After
- **bypassPermissions reduces prompts while guarding dangerous operations**

---

## [2.5.0] - 2025-12-19

### 🎯 What's Changed for You

**Plans.md now supports task dependencies and parallel execution.**

#### Before
- Had to know when to use `/start-task` vs `/work`
- Couldn't express task dependencies

#### After
- **Just `/work`** (`/start-task` removed)
- **`[depends:X]`, `[parallel:A,B]` syntax for dependencies**

---

## [2.4.1] - 2025-12-17

### 🎯 What's Changed for You

**Plugin renamed to "Claude harness".**

- Simpler, easier to remember name
- New logo and hero image

---

## [2.4.0] - 2025-12-17

### 🎯 What's Changed for You

**Reviews and CI fixes now run in parallel, much faster.**

#### Before
- 4 aspects (security/performance/quality/accessibility) checked sequentially

#### After
- **When conditions met, 4 subagents spawn simultaneously**
- Up to 75% time savings

---

## [2.3.4] - 2025-12-17

### 🎯 What's Changed for You

**Version auto-bumps on code changes. Works on Windows too.**

- Pre-commit hook auto-increments patch version
- Works on Windows

---

## [2.3.3] - 2025-12-17

### 🎯 What's Changed for You

**Skills are now organized by purpose.**

- 14 categories: impl, review, verify, setup, 2agent, memory, principles, auth, deploy, ui, workflow, docs, ci, maintenance
- "I want to review" → find in `review` category

---

## [2.3.2] - 2025-12-16

### 🎯 What's Changed for You

**Skills activate more reliably.**

---

## [2.3.1] - 2025-12-16

### 🎯 What's Changed for You

**Choose Japanese or English.**

- Language selection (JA/EN) in `/harness-init`

---

## [2.3.0] - 2025-12-16

### 🎯 What's Changed for You

**License changed back to MIT.**

- Contributing to official repo now possible

---

## [2.2.1] - 2025-12-16

### 🎯 What's Changed for You

**Agents work smarter.**

- Each agent's available tools are explicit
- Color-coded for easy identification during parallel execution

---

## [2.2.0] - 2025-12-15

### 🎯 What's Changed for You

**License changed to proprietary (later reverted to MIT).**

---

## [2.1.2] - 2025-12-15

### 🎯 What's Changed for You

**Parallel execution with just `/work`.**

- Merged `/parallel-tasks` into `/work`

---

## [2.1.1] - 2025-12-15

### 🎯 What's Changed for You

**Far fewer commands to remember.**

- 27 → 16 commands
- Rest auto-activate via conversation (converted to skills)

---

## [2.0.0] - 2025-12-13

### 🎯 What's Changed for You

**Added Hooks guardrails. Added Cursor integration templates.**

- PreToolUse/PermissionRequest hooks
- `/handoff-to-cursor` command

---

## Past History (v0.x - v1.x)

See [GitHub Releases](https://github.com/Chachamaru127/claude-code-harness/releases) for details.

Key milestones:
- **v0.5.0**: Adaptive setup (auto tech stack detection)
- **v0.4.0**: Claude Rules, Plugin Hooks, Named Sessions support
- **v0.3.0**: Initial release (Plan → Work → Review cycle)
