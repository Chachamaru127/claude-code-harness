# Changelog

Change history for claude-code-harness.

> **📝 Writing Guidelines**: This CHANGELOG describes "what changed for users".
> - Clear **Before/After** comparisons
> - Focus on "usage changes" and "experience improvements" over technical details
> - Make it clear "what's in it for you"

---

## [2.12.0] - 2026-01-26

### 🎯 What's Changed for You

**OpenCode can now work as PM (Project Manager). Use OpenCode subscription (cheaper than Cursor) to manage plans while Claude Code implements.**

#### Before → After

| Before | After |
|--------|-------|
| PM role required Cursor | `/start-session`, `/plan-with-cc` work in OpenCode |
| Handoff to Cursor only | `/handoff-to-opencode` for OpenCode PM |
| `/opencode-setup` only installed Impl commands | PM commands installed by default in `pm/` |

### Added

- **PM Commands for OpenCode** (`opencode/commands/pm/`)
  - `/start-session` - Session start (situational awareness → plan)
  - `/plan-with-cc` - Plan creation with Evals
  - `/project-overview` - Quick project overview
  - `/handoff-to-claude` - Generate request for Claude Code
  - `/review-cc-work` - Review and approve work

- **`/handoff-to-opencode`** - Completion report for OpenCode PM
  - Counterpart to `/handoff-to-cursor`
  - Used when Impl Claude Code hands off to OpenCode PM

### Changed

- **`/opencode-setup`** now installs PM commands by default
  - PM commands in `.opencode/commands/pm/`
  - Updated completion message with PM mode usage

- **`build-opencode.js`** processes PM templates
  - New source: `templates/opencode/commands/`
  - Output: `opencode/commands/pm/`

### PM Workflow

```
OpenCode (PM)                    Claude Code (Impl)
    |                                   |
    | /start-session                    |
    | /plan-with-cc                     |
    | /handoff-to-claude ─────────────> |
    |                                   | /work
    |                                   | /handoff-to-opencode
    | <─────────────────────────────────|
    | /review-cc-work                   |
```

---

## [2.11.1] - 2026-01-26

### 🎯 What's Changed for You

**session-inbox messages are now automatically displayed without confirmation prompts. When other sessions send you messages, they appear directly in the context—no need to run `/session-inbox` manually.**

#### Before → After

| Before | After |
|--------|-------|
| `📨 2 unread messages. Run /session-inbox to check.` | `📨 Messages from other sessions (2):\n---\n[10:30] session-abc1: UserAPI changed\n---` |
| Manual command execution required | Message content shown automatically |
| Needed user permission to view | Messages are for the session itself, no permission needed |

### Changed

- **`pretooluse-inbox-check.sh` auto-display messages**
  - Message content now included directly in `additionalContext`
  - "Please check" prompt removed
  - Max 5 messages displayed (prevents long output)
  - Auto-read mark not applied (user controls with `--mark`)

- **`/session-inbox` command role clarified**
  - Now used for detailed view and read-mark operations
  - Auto-check section updated to reflect auto-display behavior
  - Added note about v2.11.1+ behavior

---

## [2.11.0] - 2026-01-26

### 🎯 What's Changed for You

**`/generate-video` automatically generates product demo, architecture explanation, and release note videos. Analyzes your codebase, suggests optimal structure, and generates scenes in parallel with AI agents.**

#### Before → After

| Before | After |
|--------|-------|
| Video creation was manual with external tools | `/generate-video` for analysis → proposal → parallel generation |
| Remotion setup was complex | `/remotion-setup` for one-command initialization |
| Manual component creation per scene | AI agents auto-generate each scene |

### Added

- **`/generate-video` auto video generation command**
  - Codebase analysis (framework, features, UI detection)
  - Auto scenario proposal (video type auto-detection)
  - AskUserQuestion for scene confirmation/editing
  - Task tool for up to 5 parallel scene generation
  - Remotion rendering (MP4/WebM/GIF)

- **`/remotion-setup` setup command**
  - New project creation (`npx create-video@latest`)
  - Brownfield integration for existing projects
  - Remotion Agent Skills auto-install
  - Harness templates (optional)

- **`skills/video/` video generation skills**
  - `analyzer.md` - Codebase analysis engine
  - `planner.md` - Scenario planner
  - `generator.md` - Parallel scene generation engine

- **`agents/video-scene-generator.md` subagent**
  - Specialized for single scene generation
  - intro/ui-demo/cta/architecture/changelog templates
  - Playwright MCP integration (UI capture)

### Video Types

| Type | Auto-detection | Structure |
|------|---------------|-----------|
| Product Demo | New project, UI changes | Intro → Feature Demo → CTA |
| Architecture | Major structural changes | Overview → Details → Data Flow |
| Release Notes | Recent release, CHANGELOG update | Version → Changes → New Feature Demo |

> ⚠️ **License Note**: Remotion may require a paid license for commercial use

---

## [2.10.8] - 2026-01-26

### 🎯 What's Changed for You

**OpenCode version of `/harness-review` no longer includes Codex mode. Review focuses on Claude's multi-perspective analysis with Task tool parallel execution.**

#### Before → After

| Before | After |
|--------|-------|
| Codex mode built into harness-review | Codex removed, use `/codex-review` explicitly |
| `check-codex.sh` hook ran on first execution | No hooks, cleaner startup |
| 5 perspectives (including Codex) | 4 perspectives (Security/Performance/Quality/Accessibility) |

### Changed

- **Codex mode removed from OpenCode `harness-review.md`**
  - YAML frontmatter hooks section removed
  - Step 0 (Codex check) and Step 0.5 (context check) removed
  - Step 2 Codex Mode subsection removed
  - Step 2.5 (Result Integration with Codex) removed
  - Parallel Execution section updated for 4 perspectives

- **Added guidance to use `/codex-review` for second opinions**
  - Clear separation: `/harness-review` = Claude analysis, `/codex-review` = Codex opinion
  - Users can explicitly choose when to invoke Codex

---

## [2.10.7] - 2026-01-25

### 🎯 What's Changed for You

**`/opencode-setup` now provides all 26 Harness skills for OpenCode.ai. NotebookLM, review, deploy, and more - everything available in Claude Code now works in OpenCode.ai.**

#### Before → After

| Before | After |
|--------|-------|
| Skills unavailable in OpenCode.ai | 26 skills copied to `.claude/skills/` and available |
| `AGENTS.md` was minimal | Full `CLAUDE.md` content now in `AGENTS.md` |
| Symlink-based, no Windows support | Copy-based by default, Windows compatible |
| Re-linking needed for skill updates | `build-opencode.js` regenerates all at once |

### Added

- **Skill copy feature in `/opencode-setup`**
  - 26 skills (docs, impl, review, deploy, etc.) auto-copied
  - `test-*`, `x-*` dev skills automatically excluded
  - `--symlink` option for traditional symlink approach

- **`build-opencode.js` as SSOT (Single Source of Truth) for skill conversion**
  - Recursive skill directory copying
  - `AGENTS.md` generated from full `CLAUDE.md` content
  - Pre-generates 32 commands, 26 skills in `opencode/` directory

### Changed

- **`AGENTS.md` content significantly expanded**
  - Before: Minimal overview
  - After: Full `CLAUDE.md` content (dev rules, skill list, SSOT info, etc.)

- **`setup-opencode.sh` synced with `/opencode-setup`**
  - Added `.claude/skills/` copy processing
  - Completion message shows available skills list

---

## [2.10.6] - 2026-01-25

### 🎯 What's Changed for You

**MCP server security and performance improved. Command injection prevention, type safety enhancement, and Windows compatibility achieved.**

#### Before → After

| Before | After |
|--------|-------|
| Broadcast append slow with 100+ messages | `setImmediate()` async trimming, immediate response |
| No path validation on input | Dangerous characters detected, command injection prevented |
| `getProjectRoot()` infinite loop on Windows | `path.parse()` for cross-platform support |
| Type casts (`as`) reduced type safety | Type guard functions for runtime validation |

### Security

- **Path validation added to `getRecentChangesAsync()`**
  - Prevents command injection attacks
  - Rejects dangerous characters (`; | & $ \`` etc.)

- **Session ID/client name validation**
  - Only alphanumeric, hyphens, underscores allowed (1-128 chars)
  - Invalid input rejected

### Fixed

- **`appendBroadcast()` performance issue**
  - Synchronous trimming caused delays when messages exceeded 100
  - Async via `setImmediate()`, main processing no longer blocked

- **Windows compatibility**
  - `getProjectRoot()` was Unix-only (`current !== "/"`)
  - `path.parse()` for root detection, works on both Windows and Unix

### Changed

- **Type guard functions added**
  - Implemented `isBroadcastArgs()`, `isInboxArgs()`, `isRegisterArgs()`
  - Eliminated `as` type casts, runtime type safety ensured

- **`ensureDir()` call optimization**
  - Changed from every function call to once at module initialization
  - Reduced filesystem access

---

## [2.10.5] - 2026-01-25

### 🎯 What's Changed for You

**Inter-session communication now works correctly. Sessions are automatically registered at startup, and CLI/MCP communication formats are unified.**

#### Before → After

| Before | After |
|--------|-------|
| Sessions not registered to `active.json` at startup | Auto-registered via `session-init.sh` / `session-resume.sh` |
| Manual `/session-list` required to discover other sessions | Sessions discoverable automatically at startup |
| CLI used `broadcast.md`, MCP used `broadcast.json` | Both use `broadcast.md` (Markdown format) |
| Difficult to integrate with OpenCode.ai | OpenCode.ai can communicate via MCP |

### Added

- **`scripts/session-register.sh`** - Dedicated script to register sessions to `active.json`
  - Silent output design to avoid mixing with hook JSON
  - Auto-cleanup of sessions older than 24 hours

### Fixed

- **Inter-session communication bug fixes**
  - Fixed `session-init.sh` not registering to `active.json`
  - Fixed `session-resume.sh` with same issue
  - Resolved CLI/MCP format split (`broadcast.md` vs `broadcast.json`)

### Changed

- **MCP session.ts now uses Markdown format**
  - `loadBroadcasts()` parses Markdown format
  - `appendBroadcast()` writes in Markdown format
  - Full compatibility with CLI achieved

---

## [2.10.4] - 2026-01-25

### 🎯 What's Changed for You

**`/dev-tools-setup` now asks whether to configure MCP globally or per-project.**

#### Before → After

| Before | After |
|--------|-------|
| MCP config always created in project `.mcp.json` | User chooses: global (`~/.mcp.json`) or project (`.mcp.json`) |

### Changed

- **`/dev-tools-setup` adds user confirmation for MCP scope**
  - Step 4.2: AskUserQuestion prompts for global vs project-specific
  - Global config enables harness MCP tools across all projects

---

## [2.10.3] - 2026-01-25

### 🎯 What's Changed for You

**`/dev-tools-setup` now configures MCP server automatically, ensuring Claude uses AST-Grep and LSP tools instead of falling back to standard grep/read.**

#### Before → After

| Before | After |
|--------|-------|
| `/dev-tools-setup` only installed tools | Also configures MCP server (`.mcp.json`) |
| Claude might ignore AST-Grep | MCP tools explicitly available in prompts |
| Review skill used standard tools | Review skill uses `harness_ast_search` for code smell detection |

### Added

- **Quality protection rules** - Prevent test tampering and hollow implementations
  - `.claude/rules/test-quality.md` - Detects `it.skip()`, assertion removal, eslint-disable additions
  - `.claude/rules/implementation-quality.md` - Detects hardcoded test values, stub implementations

### Changed

- **`/dev-tools-setup` now includes MCP configuration**
  - Creates `.mcp.json` with harness MCP server
  - Documents design intent: "Why MCP?" section explains tool discoverability
- **Review skill enhanced with AST-Grep MCP usage**
  - Added "MCP Code Intelligence Tools" section
  - Explicit guidance to prefer `harness_ast_search` over grep

---

## [2.10.0] - 2026-01-25

### 🎯 What's Changed for You

**OpenCode.ai compatibility layer enables multi-LLM development (o3, Gemini, etc.) with unified workflow, plus new AST-Grep and LSP code intelligence tools.**

#### Before → After

| Before | After |
|--------|-------|
| Claude Code only | OpenCode.ai support for o3, Gemini, Grok, DeepSeek |
| `/work` with complex flag parsing | `/work` defaults to turbo mode (simpler, faster) |
| Code search via grep/ripgrep | AST-Grep for language-aware semantic search |
| No LSP integration in MCP | LSP tools via MCP for definitions, references, hover |
| Manual OpenCode setup | `/opencode-setup` one-command installation |
| No dev tool setup guidance | `/dev-tools-setup` for AST-Grep, LSP, and more |

### Added

- **OpenCode.ai compatibility layer** - Full harness workflow for non-Claude LLMs
  - All core commands ported: `/harness-init`, `/plan-with-agent`, `/work`, `/harness-review`
  - `/opencode-setup`: One-command installation and configuration
  - `opencode/` directory with translated commands
  - GitHub Actions workflow for automatic sync
  - Comprehensive documentation in `docs/OPENCODE_COMPATIBILITY.md`
- **Code intelligence MCP tools** - AST-aware code analysis
  - `ast_search`: Semantic code search with AST-Grep patterns
  - `lsp_definitions`: Jump to symbol definitions
  - `lsp_references`: Find all references to a symbol
  - `lsp_hover`: Get type info and documentation
  - Language support: TypeScript, JavaScript, Python, Go, Rust, Java, C/C++
- **`/dev-tools-setup` command** - Developer tooling installation guide
  - AST-Grep installation and usage examples
  - LSP server setup for multiple languages
  - MCP tool configuration instructions

### Changed

- **`/work` simplified** - Now defaults to turbo mode
  - No more `--turbo` flag needed
  - Faster execution out of the box
  - Original behavior available via explicit flags

### Security

- **Command injection prevention** - MCP code intelligence tools hardened
  - `execFile` instead of `exec` to prevent shell injection
  - Strict path validation with symlink detection
  - Language whitelist for AST-Grep queries
  - Runtime type validation for all inputs

---

## [2.9.24] - 2026-01-24

### 🎯 What's Changed for You

**Full Claude Code v2.1.10-v2.1.19 compatibility with Setup hooks, plansDirectory, context monitoring, and TodoWrite sync.**

#### Before → After

| Before | After |
|--------|-------|
| No `claude --init` / `--maintenance` integration | Setup hooks auto-run on `--init` and `--maintenance` |
| Plans.md fixed at project root | Customizable via `plansDirectory` setting |
| No context usage visibility | Visual indicator with color-coded thresholds in harness-ui |
| TodoWrite and Plans.md disconnected | TodoWrite changes logged and tracked |
| No MCP auto:N documentation | Comprehensive MCP configuration guide |
| Sessions work in isolation | `/session-broadcast` enables cross-session messaging |
| Claude Code only | MCP Server supports Codex, Cursor via standard protocol |
| Manual PR reviews | `/webhook-setup` automates GitHub Actions reviews |

### Added

- **Setup hook event** (v2.1.10): Auto-runs during `claude --init` and `claude --maintenance`
  - `init` mode: Creates default config, CLAUDE.md, Plans.md
  - `maintenance` mode: Cleans old sessions, syncs cache, validates config
- **plansDirectory setting**: Full implementation across all scripts and harness-ui
  - New `scripts/config-utils.sh` for centralized config reading
  - session-init, session-monitor, plans-watcher respect the setting
  - harness-ui server and project-discovery support custom paths
- **context_window percentage display** (v2.1.6): Real-time indicator in harness-ui dashboard
  - Green (0-50%), Yellow (50-70%), Red (70%+) color coding
  - Warning messages at high usage levels
- **TodoWrite sync** (v2.1.17): PostToolUse hook tracks TodoWrite state changes
  - Logs todo counts (pending/in_progress/completed) to session events
  - State saved to `.claude/state/todo-sync-state.json`
- **MCP Configuration Guide**: New `docs/MCP_CONFIGURATION.md`
  - Documents `auto:N` syntax for threshold-based auto-approval
  - Examples for different server trust levels
- **Related files verification** (`verify-related-files`) - Automatically checks for missed file updates after implementation
  - Detects function signature changes → warns about unchecked callers
  - Detects interface/type changes → warns about implementation inconsistencies
  - Detects export changes → warns about broken imports
  - Detects config changes → warns about unsynchronized related configs
  - Integrated into `/work` flow (Phase 1 self-review and Phase 3 pre-commit)
- **Inter-session communication** - Real-time messaging between sessions
  - `/session-broadcast`: Send messages to all active sessions
  - `/session-inbox`: Check for messages from other sessions
  - `/session-list`: View active sessions
  - Auto inbox check hook: Notifies unread messages before Write/Edit
  - Auto broadcast hook: Notifies API/type file changes automatically
- **MCP Server** (`mcp-server/`) - Cross-client session communication
  - Enables Claude Code, Codex, and Cursor to share sessions via MCP protocol
  - Session tools: `harness_session_list`, `harness_session_broadcast`, `harness_session_inbox`
  - Workflow tools: `harness_workflow_plan`, `harness_workflow_work`, `harness_workflow_review`
  - Status tools: `harness_status`
  - `/mcp-setup`: Configure MCP for different clients
- **Webhook automation** (`/webhook-setup`) - GitHub Actions integration
  - Auto-review PRs with `/harness-review`
  - Plans.md status comments on PRs
- **E2E verification design** (`docs/E2E_VERIFICATION_DESIGN.md`) - Future CDP/Playwright integration

### Changed

- **CLAUDE_CODE_COMPATIBILITY.md**: Updated matrix for v2.1.10-v2.1.19
- **hooks.json**: Added Setup event and TodoWrite PostToolUse matcher
- **TodoWrite integration**: TodoWrite tool now syncs with Plans.md
  - Todo status changes automatically logged to session events
  - Pending/in_progress/completed counts tracked in real-time
  - State persisted to `.claude/state/todo-sync-state.json`

### Fixed

- **Symlink escape protection**: Shell scripts now validate paths to prevent directory traversal via symlinks
- **harness-ui security**: Path traversal protection strengthened with proper path normalization
- **harness-ui accessibility**: ContextIndicator now includes ARIA attributes for screen readers
- **harness-ui performance**: App.tsx polling optimized with Page Visibility API (pauses when tab hidden)
- **MCP server namespace**: Changed from `@anthropic-ai` to `@claude-code-harness` to avoid confusion
- **Session scripts resource leak**: Added trap cleanup for temp files in session-broadcast.sh and session-list.sh

---

## [2.9.22] - 2026-01-20

### Fixed

- **README version badge fixed** - Badge was not updated during v2.9.21 release
- **sync-version.sh README update restored** - Unified badge format so `bump` command auto-updates README

---

## [2.9.21] - 2026-01-19

### 🎯 What's Changed for You

**You now get a quick context-budget snapshot at session start, plus an optional quality automation pack.**

#### Before → After

| Before | After |
|--------|-------|
| No context budget signal at session start | MCP/plugin estimates are shown at session start |
| No optional quality automation pack | Opt-in PostToolUse pack (Prettier/tsc/console.log scan) |

### Added

- **Context budget snapshot** (estimated MCP/plugin counts) shown at session start and stored in tooling-policy.json
- **Optional quality automation pack** (PostToolUse) with Prettier, tsc, console.log scan (disabled by default)

### Changed

- **session-monitor** now records MCP/plugin estimates for tooling policy

---

## [2.9.19] - 2026-01-19

### 🎯 What's Changed for You

**Codex experts can now provide 3x more detailed analysis. Command menu is cleaner with internal commands hidden.**

#### Before → After

| Before | After |
|--------|-------|
| Codex experts limited to 500 chars output | Codex experts can output up to 1500 chars for detailed analysis |
| `/cc-cursor-cc` visible in menu (rarely used) | Hidden from menu (still available for 2-Agent workflows) |
| `/harness-ui` and `/harness-ui-setup` as separate commands | `/harness-ui` automatically enters setup mode if needed |

### Changed

- **Codex expert output limit relaxed** (500 → 1500 chars)
  - All 8 expert prompts updated: security, quality, accessibility, performance, SEO, architect, plan-reviewer, scope-analyst
  - Enables more detailed analysis and specific fix suggestions
  - Total context impact: ~4,000 tokens (8 experts × 1500 chars) - manageable
- **`/harness-ui` unified** - Now includes auto-setup mode
  - Automatically detects if license key is configured
  - Enters setup mode when `$HARNESS_BETA_CODE` is not set
  - Single command for both setup and dashboard access

### Deprecated

- **`/harness-ui-setup`** - Merged into `/harness-ui`
  - Still works internally but hidden from menu
  - Use `/harness-ui` for both setup and dashboard

### Removed (from menu)

- **`/cc-cursor-cc`** - Hidden from command menu (`user-invocable: false`)
  - Still functional for 2-Agent workflows
  - Low usage frequency justified hiding

---

## [2.9.18] - 2026-01-19

### 🎯 What's Changed for You

**`/resume` now automatically restores Harness session state. Your work context is preserved across session interruptions.**

#### Before → After

| Before | After |
|--------|-------|
| `/resume` only restored Claude Code conversation | `/resume` also restores Harness session state (Plans.md progress, task markers) |
| Session state lost on interruption | CC session_id → Harness session mapping enables seamless restoration |

### Added

- **SessionStart Resume detection** (hooks.json `matcher: "resume"`)
  - Automatically triggers when using `/resume` command
  - Restores session.json and session.events.jsonl from archive
  - CC session_id ↔ Harness session_id mapping for reliable restoration
- **session-resume.sh**: New script for resume-specific session restoration
- **D16 decision**: Design-implementation gap prevention measures documented

### Changed

- **session-init.sh**: Now captures CC session_id and saves mapping for future resume

---

## [2.9.16] - 2026-01-19

### 🎯 What's Changed for You

**`/review-cc-work` now outputs handoff prompts with `/work` command prefix, matching `/handoff-to-claude` format.**

#### Before → After

| Before | After |
|--------|-------|
| Handoff output starts with `## 依頼` or `## 修正依頼` | Handoff starts with `/claude-code-harness:core:work` + `ultrathink` |

### Changed

- **`/review-cc-work` handoff format** (Cursor → Claude Code)
  - Both `approve` and `request_changes` outputs now include `/work` command prefix
  - Consistent with `/handoff-to-claude` format
  - Enables immediate `/work` execution when pasting to Claude Code

---

## [2.9.15] - 2026-01-19

### 🎯 What's Changed for You

**Hooks permission issues are now auto-fixed. Cursor command updates are explicitly overwritten (no more unwanted merges).**

#### Before → After

| Before | After |
|--------|-------|
| Shell scripts in `.claude/hooks/` fail silently if missing `chmod +x` | `/harness-init` and `/harness-update` auto-fix permissions |
| `/harness-update` may merge old Cursor commands | Cursor commands are explicitly overwritten from templates |

### Added

- **Hooks permission auto-fix** (`/harness-init`, `/harness-update`)
  - Phase 4.5 / Step 6: Auto `chmod +x` for `.claude/hooks/*.sh`
  - Prevents silent hook failures from permission issues
- **`hooks/BEST_PRACTICES.md`**: Documentation for shell script hooks
  - Checklist: permission, shebang, path validation
  - Troubleshooting guide for common issues
- **`.claude/rules/github-release.md`**: Release notes format rules
  - Mandatory `🎯 What's Changed for You` section
  - Before/After table requirement

### Changed

- **Cursor command update policy** (in `/harness-update`)
  - Now explicitly marked as "ALWAYS overwritten, never merged"
  - Instructions: "Do NOT read existing files before updating"
  - Prevents Claude from merging old versions

---

## [2.9.14] - 2026-01-19

### 🎯 What's Changed for You

**`/codex-review` now shows real-time progress. Expert prompts optimized for token efficiency.**

#### Before → After

| Before | After |
|--------|-------|
| MCP mode: no progress display during review | exec mode: progress visible in STDERR in real-time |
| Expert responses in Japanese (high token cost) | English only, max 500 chars (Claude integrates in Japanese) |
| No output limits on parallel experts | Critical/High: all, Medium/Low: max 3 each |

### Changed

- **Default execution mode**: MCP → exec (CLI direct) for single `/codex-review`
  - Progress now visible in STDERR during execution
  - Legacy MCP mode available via `execution_mode: mcp` setting
- **Parallel experts remain MCP**: Claude's built-in parallel tool calls for efficiency
- **Expert output constraints** (all 8 experts):
  - English only (token savings, Claude integrates in Japanese)
  - Max 500 chars per expert
  - Critical/High: report all, Medium/Low: max 3 each
  - No issues → `Score: A / No issues.`

---

## [2.9.11] - 2026-01-18

### 🎯 What's Changed for You

**Session Orchestration System complete: state machine, resume/fork UX, cost control & skill governance.**

### Added

- **Session Orchestration System (Phase 0-3 complete)**
  - `scripts/session-state.sh`: 10-state system, 21 transition rules, lock mechanism
  - `skills/session-state/SKILL.md`: Session state management skill
  - `scripts/pretooluse-guard.sh`: cost_control checks (total/edit/bash limits)
  - `.claude-code-harness.config.yaml`: orchestration + cost_control sections
  - `tests/validate-skills.sh`: SKILL.md frontmatter validation, tool name checks
  - `tests/test-session-control.sh`: 14 unit tests

### Changed

- `posttooluse-log-toolname.sh`: Added current_state field

---

## [2.9.10] - 2026-01-18

### 🎯 What's Changed for You

**`/work --resume` and `/work --fork` enable session continuation and branching. harness-ui session archives API added.**

### Added

- **Resume/Fork UX**
  - `commands/core/work.md`: CLI documentation (session list, resume, fork commands)
  - `harness-ui/src/shared/types.ts`: SessionArchive type definitions
  - `harness-ui/src/server/index.ts`: `/api/session-archives` endpoint

---

## [2.9.9] - 2026-01-18

### 🎯 What's Changed for You

**State machine enforcement for session transitions. Unified state field in event logs.**

### Added

- **State Machine Enforcement**
  - `scripts/session-state.sh`: State transition engine
  - `skills/session-state/references/state-transition.md`: Transition specification

---

## [2.9.8] - 2026-01-18

### 🎯 What's Changed for You

**UI skill constraints tightened with explicit guardrails and opt-in aesthetics.**

### Added

- **UI skill constraint priority**: Define explicit constraint ordering
- **UI skills summary**: `skills/ui/references/ui-skills.md` for quick reference
- **Frontend design summary**: `skills/ui/references/frontend-design.md` with design guidelines
- **Opt-in aesthetics**: UI generation now follows explicit guardrails

---

## [2.9.7] - 2026-01-18

### 🎯 What's Changed for You

**Compact guard added before Codex reviews for better context management.**

### Added

- **Compact guard**: `/harness-review` and `/codex-review` now include compact guards
- **Codex parallel review guardrails**: Enhanced `codex-parallel-review.md`
- **Review SKILL.md**: Compact mode support added

---

## [2.9.6] - 2026-01-18

### 🎯 What's Changed for You

**Session resume and fork controls: continue interrupted work or branch from existing sessions.**

#### Before/After

| Before | After |
|--------|-------|
| Sessions lost on interruption | `/work --resume <id>` to continue |
| No branching from sessions | `/work --fork <id>` to branch |
| Manual state management | Automatic session archiving |

### Added

- **Session resume**: `/work --resume <session-id>` continues interrupted sessions
- **Session fork**: `/work --fork <session-id>` branches from existing sessions
- **session-control.sh**: New script for session state management
- **Session archiving**: Auto-save state for resume capability
- **test-session-control.sh**: Tests for session control features

### Changed

- **SESSION_ORCHESTRATION.md**: Resume/fork specifications added

---

## [2.9.5] - 2026-01-18

### 🎯 What's Changed for You

**Session lifecycle events now persisted for debugging and analysis.**

### Added

- **Lifecycle event persistence**: Session start/resume/stop events recorded in state files
- **Tool event logging**: `posttooluse-log-toolname.sh` tracks tool usage
- **Enhanced session-monitor.sh**: Expanded event tracking
- **Lifecycle summary**: `session-summary.sh` now includes lifecycle overview

### Changed

- **CLAUDE.md**: Fixed frontmatter warnings
- **commands/core/CLAUDE.md**, **commands/optional/CLAUDE.md**: Documentation improvements

---

## [2.9.4] - 2026-01-18

### 🎯 What's Changed for You

**Deterministic session orchestration spec for reproducible execution.**

### Added

- **SESSION_ORCHESTRATION.md**: New design specification for session control
- **Reproducible sessions**: Guidelines for deterministic session execution

---

## [2.9.3] - 2026-01-17

### 🎯 What's Changed for You

**`/work --full` workflow orchestration implementation (Phase 34).**

### Added

- **parse-work-flags.md**: Extended flag parsing logic
- **work.yaml workflow**: Updated for full-cycle support
- **Sandbox test**: `/work --full` sandbox test added

### Changed

- **harness-ui session state files**: Cleaned up unnecessary state files

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

[Unreleased]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.11.1...HEAD
[2.11.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.11.0...v2.11.1
[2.11.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.10.8...v2.11.0
[2.10.8]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.10.7...v2.10.8
[2.10.7]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.10.6...v2.10.7
[2.10.6]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.10.5...v2.10.6
[2.10.5]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.10.4...v2.10.5
[2.10.4]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.10.3...v2.10.4
[2.10.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.10.2...v2.10.3
[2.10.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.10.1...v2.10.2
[2.10.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.10.0...v2.10.1
[2.10.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.9.24...v2.10.0
[2.9.24]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.9.22...v2.9.24
[2.9.22]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.9.21...v2.9.22
[2.9.21]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.9.20...v2.9.21
[2.9.11]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.9.10...v2.9.11
[2.9.10]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.9.9...v2.9.10
[2.9.9]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.9.8...v2.9.9
[2.9.8]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.9.7...v2.9.8
[2.9.7]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.9.6...v2.9.7
[2.9.6]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.9.5...v2.9.6
[2.9.5]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.9.4...v2.9.5
[2.9.4]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.9.3...v2.9.4
[2.9.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.9.2...v2.9.3
[2.9.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.9.1...v2.9.2
[2.9.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.9.0...v2.9.1
[2.9.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.8.2...v2.9.0
[2.8.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.8.1...v2.8.2
[2.8.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.8.0...v2.8.1
[2.8.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.7.16...v2.8.0
[2.0.0]: https://github.com/Chachamaru127/claude-code-harness/releases/tag/v2.0.0
