# Changelog

Change history for claude-code-harness.

> **Writing Guidelines**: This CHANGELOG describes "what changed for users".
> - Clear **Before/After** comparisons
> - Focus on "usage changes" and "experience improvements" over technical details
> - Make it clear "what's in it for you"
> - **Based on**: Link to Claude Code official features when referenced

---

## [2.5.0] - 2025-12-19

### What's Changed for You

**SDD (Simple Development Discipline) Upgrade: Plans.md-centric workflow enhanced with dependency and parallel execution support.**

#### Before
- Had two commands `/start-task` and `/work` - needed to know when to use which
- Plans.md couldn't express task dependencies or parallel execution
- Specification documents (proposal.md, etc.) scattered between root and `docs/`
- Constitution (development principles) settings not defined in schema

#### After
- **`/start-task` removed**: Unified into `/work` for consistent flow from start to completion
- **Dependency & parallel notation**: Plans.md supports `[depends:X]`, `[parallel:A,B]` syntax
- **docs/ standardization**: `/plan-with-agent` outputs unified to `docs/proposal.md`, `docs/technical-spec.md`, `docs/priority_matrix.md`
- **Constitution support**: Centralized quality gates, DoD, and principles in `docs/constitution.md`
- **Regression prevention**: CI checks for `/start-task` removal and docs/ normalization

### Changes

#### Phase 1: Remove /start-task workflow
- Deleted `workflows/default/start-task.yaml`
- Removed start-task references from profiles, templates, scripts
- Completed `/sync-status` → `/work` integration

#### Phase 2: Enhance /work workflow
- Added cc:WIP auto-transition to `workflows/default/work.yaml`
- Added marker auto-update documentation to `commands/core/work.md`

#### Phase 3: Extend Plans.md management
- Added dependency & parallel notation to `templates/Plans.md.template`
- Added extended syntax to `templates/rules/plans-management.md.template`
- Added visual dependency analysis examples to `skills/plans-management/SKILL.md`

#### Phase 4: Constitution file support
- Support `docs/constitution.md` creation
- Added `constitution` property to `claude-code-harness.config.schema.json`
- Added i18n and constitution sections to config files

#### Phase 5: Strengthen regression checks
- Added to `scripts/ci/check-consistency.sh`:
  - `/start-task` removal regression check (6/7)
  - docs/ normalization check (7/7)
  - Added `technical-spec.md` to coverage

#### Other
- Unified output list in `commands/core/plan-with-agent.md`
- All validation tests passed (35/35 plugin validation, 7/7 consistency checks)

### Based on
- [OpenSpec/spec-kit/cc-sdd](https://github.com/OpenSpec) - Dependency & parallel notation concepts

---

## [2.4.1] - 2025-12-17

### What's Changed for You

**Plugin renamed to "Claude harness". Fresh branding with new logo and hero image.**

#### Before
- Plugin was named "Claude Code Harness"
- Old naming scattered across documentation and scripts

#### After
- **New name "Claude harness"**: Simpler and easier to remember
- **New logo & hero image**: Added SVG logo and PNG hero image
- Unified naming across all documentation

### Changes
- Changed plugin.json name to `claude-harness`
- Set logo and hero image in README.md
- Updated naming in all documentation (9 files)
- Removed old hero image (hero.png)

---

## [2.4.0] - 2025-12-17

### What's Changed for You

**Reviews and CI fixes now run in parallel. Skills automatically spawn subagents.**

#### Before
- `/harness-review` checked 4 aspects (security/performance/quality/accessibility) sequentially
- Large reviews took a long time
- `agents/` subagent definitions weren't being utilized

#### After
- **Parallel reviews**: When conditions are met (aspects>=2 & files>=5), Task tool spawns 4 subagents simultaneously
- **CI fix delegation**: Complex CI failures auto-delegate to ci-cd-fixer subagent
- **Time savings**: Up to 75% faster with parallel execution (full 4-aspect review)

### Changes
- Added subagent orchestration to CLAUDE.md (+2 lines only)
- Added parallel subagent launch logic to `skills/review/SKILL.md`
- Added ci-cd-fixer integration to `skills/ci/SKILL.md`
- Clarified Task tool patterns in `commands/core/harness-review.md`

### Based on
- [Claude Code Subagents](https://code.claude.com/docs/en/sub-agents) - Parallel subagent spawning via Task tool

---

## [2.3.4] - 2025-12-17

### What's Changed for You

**Version auto-bumps on code changes. Works on Windows too.**

#### Before
- Had to manually run `./scripts/sync-version.sh bump` before commits
- Forgetting caused CI failures and double work

#### After
- **Auto version bump**: Patch version auto-increments on commits with code changes
- **Windows support**: Works from PowerShell/CMD with Git for Windows
- No more CI failures from forgetting version bumps

### Changes
- Fixed pre-commit hook encoding issues (Japanese → English messages)
- Added Windows compatibility docs to `CONTRIBUTING.md` and `install-git-hooks.sh`
- Enable with `./scripts/install-git-hooks.sh`

---

## [2.3.3] - 2025-12-17

### What's Changed for You

**Skills are now organized by purpose. Easier to find what you need.**

#### Before
- Skills scattered across `core/`, `optional/`, `worker/`
- "Want to review" → Can't find where it is

#### After
- **14 categories**: impl, review, verify, setup, 2agent, memory, principles, auth, deploy, ui, workflow, docs, ci, maintenance
- **Find by purpose**: "Review" → `review` category, "Deploy" → `deploy` category

### Changes
- Reorganized skills into purpose-based categories (52 files changed)
- Added skill category table to CLAUDE.md
- Removed old categories (core, optional, worker)

### Acknowledgements
- Hierarchical skill structure: Implemented based on feedback from [AI Masao](https://note.com/masa_wunder)

---

## [2.3.2] - 2025-12-16

### What's Changed for You

**Skills activate more reliably.**

#### Before
- Vague skill descriptions caused unintended activations

#### After
- **Clear trigger words**: Each skill has exclusive keywords
- **Evaluation flow**: Auto-evaluates matching skills before work

### Changes
- Enhanced all skill descriptions (explicit trigger words)
- Added skill evaluation flow to CLAUDE.md

---

## [2.3.1] - 2025-12-16

### What's Changed for You

**Choose Japanese or English. PR submissions to official repo now possible.**

#### Before
- Command descriptions in Japanese only
- Hard to use for English users

#### After
- Language selection (JA/EN) in `/harness-init`
- All 16 commands have English descriptions (`description-en`)
- Set `i18n.language` in config file

### Changes
- Added language selection step to `/harness-init`
- Added `description-en` field to all 16 commands
- Added `i18n.language` option to config schema
- Added translation validation script `scripts/i18n/check-translations.sh`
- Changed license to MIT (for official repo contributions)

---

## [2.3.0] - 2025-12-16

### What's Changed for You

**License changed back to MIT. Contributing to official repo is now possible.**

#### Before (Proprietary License - v2.2.0)
- Redistribution and sales prohibited
- PR submissions to official repo not possible

#### After (MIT License)
- **Free distribution/redistribution**: Fork, PR, packaging allowed
- **Contributing to official repo possible**: PRs to Anthropic official plugins OK
- **Usage unchanged**: Personal use, commercial use, modifications still free

### Changes
- Changed license from proprietary to MIT
- Updated LICENSE.md, LICENSE.ja.md to standard MIT license text
- Simplified license section in README.md

---

## [2.2.1] - 2025-12-16

### What's Changed for You

**Agents work smarter.**

#### Before
- Unclear what tools agents could use
- Multiple parallel agents hard to distinguish
- Skill info crammed in one file, inefficient token usage

#### After
- Each agent's available tools are explicit, using only appropriate tools
- Agents have colors for easy identification during parallel execution
- Skills are hierarchical, loading only needed info for faster performance

### Changes

#### Agent Definitions (Official Format - 6 files)

```yaml
# Before
---
description: ...
capabilities: [...]
---

# After
---
name: code-reviewer
description: ...
tools: [Read, Grep, Glob, Bash]
model: sonnet
color: blue
---
```

| Agent | Role | color |
|-------|------|-------|
| code-reviewer | Code review | blue |
| ci-cd-fixer | CI fixes | orange |
| error-recovery | Error recovery | red |
| project-analyzer | Project analysis | green |
| project-scaffolder | Project generation | purple |
| project-state-updater | State management | cyan |

#### Progressive Disclosure Skill Structure

```
# Before
skills/plans-management/
└── SKILL.md   # All info in one file

# After
skills/plans-management/
├── SKILL.md              # Core info only
├── references/
│   └── markers.md        # Detailed specs (load when needed)
└── examples/
    └── task-lifecycle.md # Examples (load when needed)
```

**Target skills**: plans-management, workflow-guide

---

## [2.2.0] - 2025-12-15

### What's Changed for You

**License changed (usage unchanged).**

#### Before (MIT License)
- Anyone could freely redistribute/sell
- Could create and sell similar services

#### After (Proprietary License)
- **Your usage unchanged**: Personal use, commercial use, modifications, AI use still free
- **Prohibited**: Redistribution, sales, similar service provision

### Changes
- Changed license from MIT to proprietary
- Added LICENSE.md (English), LICENSE.ja.md (Japanese)
- Added license explanation section to README.md (bilingual)

---

## [2.1.2] - 2025-12-15

### What's Changed for You

**Parallel execution with just `/work`.**

#### Before
- Normal task execution: `/work`
- For parallel execution: `/parallel-tasks` (separate command)

#### After
- **Just `/work`**: Auto parallel execution when multiple independent tasks
- Fewer commands to remember (17 → 16)

### Changes
- Merged `/parallel-tasks` into `/work`
- `/work` auto-analyzes dependencies, decides parallel/serial

---

## [2.1.1] - 2025-12-15

### What's Changed for You

**Far fewer commands to remember.**

#### Before
- Had to remember 27 commands
- Run individual commands like `/analytics`, `/auth`, `/deploy-setup`

#### After
- **Just 16 commands** needed
- Rest auto-activate by **just saying** "add auth", "setup deploy" (converted to skills)

### Changes
- Commands: 27 → 17
- `/plan` → `/plan-with-agent` renamed
- `/skill-list` shows available skills
- These became skills (auto-activate in conversation):
  - `/analytics`, `/auth`, `/auto-fix`, `/deploy-setup`, etc.

---

## [2.0.9] - 2025-12-14

### Added
- Added `/sync-project-specs` to sync specs/operation docs (Plans/AGENTS/Rules) to latest operation (PM↔Impl, pm:*)

---

## [2.0.8] - 2025-12-14

### Changed
- Added checklists to handoff commands to prevent forgetting Plans.md marker updates in PM/Impl handoff
- Stop hook detects Plans.md update omissions and shows Japanese reminder (only when changes detected)

---

## [2.0.7] - 2025-12-14

### Added
- Added `/handoff-to-pm-claude` and `/handoff-to-impl-claude` to enable "PM ↔ Impl" 2-role operation solo

### Changed
- Added `pm:依頼中` / `pm:確認済` to Plans markers (`cursor:*` treated as compatible synonyms)
- Added Plans update notification output to `.claude/state/pm-notification.md` (compatible: `cursor-notification.md`)

---

## [2.0.6] - 2025-12-14

### Changed
- Localized PreToolUse guard confirm/reject messages to Japanese (`CLAUDE_CODE_HARNESS_LANG=en` switches to English)

---

## [2.0.5] - 2025-12-14

### Changed
- Improved description wording for `/work` and `/start-task` to clarify usage in command list

---

## [2.0.4] - 2025-12-14

### Changed
- CI: Replaced **auto-push on version not updated (causing double CI runs)** with warning + failure (recommending pre-commit auto-update)
- Completely removed `cursor-cc.config.*` compatibility notation/remnants, unified to `claude-code-harness.config.*`
- Unified command descriptions for VibeCoder (added "say this / output" to each `commands/*.md`)

---

## [2.0.3] - 2025-12-14

### Changed
- Unified `cursor-cc` notation to `claude-code-harness`
- Removed compatibility commands (`/init`, `/review`) (migration period ended)
- Cursor integration: Organized to `.claude-code-harness-version` / `.claude-code-harness.config.yaml`

---

## [2.0.2] - 2025-12-14

### Added
- CI/pre-commit check: **Auto patch bump** on version not updated (CI + pre-commit)

---

## [2.0.1] - 2025-12-14

### Added
- README: Added TOC for easier navigation in long documents
- GitHub Actions: Auto-run `validate-plugin` / `check-consistency` (`.github/workflows/validate-plugin.yml`)
- Config files: Added `claude-code-harness.config.schema.json` / `claude-code-harness.config.example.json`

### Changed
- Synced `CONTRIBUTING.md` product name/flow/installation to current
- Synced Marketplace metadata to `claude-code-harness`

---

## [2.0.0] - 2025-12-13

### Added
- PreToolUse/PermissionRequest hooks (guardrails + safe command auto-allow)
- Cursor integration templates (`templates/cursor/commands/*`) and `/setup-cursor`
- `/handoff-to-cursor` (completion report for Cursor PM)

### Changed
- Updated `.claude-plugin/plugin.json` to latest Plugins reference (author as object, removed manual command listing)
- Command collision avoidance: Unified to `/harness-init` `/harness-review` (old name commands deprecated)
- Updated README/Docs to `/harness-init` `/harness-review` basis

### Fixed
- Unified stdin JSON input handling for hooks (fixed PostToolUse script misfires)
- Resolved missing template issue in CI consistency check

---

## (Imported) cursor-cc-plugins history

The following `0.5.x` series is kept as reference from the base `cursor-cc-plugins` history.

---

## [0.5.4] - 2025-12-12

### Fixed
- CI checklist sync fix
  - Synced `setup-2agent.md` checklist with script
  - Removed trailing slashes, listed individual files
  - Fixed CI `check-checklist-sync.sh` to pass correctly

---

## [0.5.3] - 2025-12-12

### Added
- **Phase 2: Parallel Task Execution**
  - `/parallel-tasks` command - Execute multiple tasks simultaneously
  - Integrated report generation - Batch report parallel execution results
  - Auto dependency detection - Auto-select parallel/serial execution
  - `parallel-workflows` skill update

- **Phase 3: Resident Monitoring Agent**
  - `auto-test-runner.sh` - Recommend tests on source code changes
  - `plans-watcher.sh` - Monitor Plans.md changes and notify Cursor
  - `.claude/state/pm-notification.md` - PM notification generation (compatible: `.claude/state/cursor-notification.md`)
  - Auto-detect related test files

### Changed
- Added new hooks to `hooks/hooks.json`
  - PostToolUse: auto-test-runner.sh
  - PostToolUse: plans-watcher.sh

---

## [0.5.2] - 2025-12-12

### Added
- **Session Monitoring Hooks**
  - `session-monitor.sh` - Show project state on session start
  - `track-changes.sh` - Track file changes and detect important changes
  - `session-summary.sh` - Generate summary on session end
  - Persist state to `.claude/state/session.json`
  - Auto-detect changes to Plans.md / CLAUDE.md / AGENTS.md

### Changed
- Added new hooks to `hooks/hooks.json`
  - SessionStart: session-monitor.sh
  - PostToolUse: track-changes.sh
  - Stop: session-summary.sh

---

## [0.5.1] - 2025-12-12

### Added
- `/remember` command - Auto-rule learning items
  - Just say "remember this" during work to record in optimal format
  - Auto-determine best destination from Rules/Commands/Skills/Memory
  - Constraints/prohibitions → Rules
  - Operation procedures → Commands
  - Implementation patterns → Skills
  - Decisions → Memory

### Fixed
- Added Japanese keyword support for important pattern detection
  - Security, test required, accessibility, performance, etc.
  - Added AGENTS.md, CLAUDE.md to search targets

---

## [0.5.0] - 2025-12-12

### Added
- **Adaptive Setup**
  - Auto-analyze project tech stack and existing config
  - `scripts/analyze-project.sh` - Output analysis results in JSON
  - Detect Node.js, Python, Rust, Go, Ruby, Java
  - Detect React, Next.js, Vue, Django, FastAPI, etc.
  - Detect ESLint, Prettier, Biome, Ruff, etc.
  - Respect existing Claude/Cursor settings (no overwrite)
  - Detect Conventional Commits patterns
  - Detect security, testing, accessibility important items

- **3-Phase Setup Flow**
  - Phase 1: Project analysis and results display
  - Phase 2: Rule customization (LLM optimization)
  - Phase 3: Interactive confirmation and placement

- **New Skills/Docs**
  - `skills/core/ccp-adaptive-setup/SKILL.md` - Adaptive setup skill
  - `docs/design/adaptive-setup.md` - Design document

### Changed
- Updated `/setup-2agent` command to adaptive
- Added `--analyze-only` option to `scripts/setup-2agent.sh`
- Guide to `/update-2agent` when existing config found

### Philosophy
- **Non-destructive updates**: Don't overwrite existing customizations
- **Project understanding**: Understand tech stack and conventions before placing
- **Staged confirmation**: Show analysis results to user before execution

---

## [0.4.7] - 2025-12-12

### Added
- **Claude Rules Best Practices Support**
  - `paths:` YAML frontmatter for conditional rule application
  - `plans-management.md.template` - Apply only when editing Plans.md
  - `testing.md.template` - Apply only when editing test files

### Changed
- `workflow.md.template` - Explicit global application with `alwaysApply: true`
- `coding-standards.md.template` - `paths:` specified for code files only
- Setup script and CI consistency check support 4 rules

### Documentation
- Improved rule structure referencing Anthropic official best practices
- Implemented progressive disclosure (apply rules only when needed) principle

---

## [0.4.0] - 2025-12-11

### Added
- **`.claude/rules/` Directory Support**
  - `workflow.md` - 2-Agent workflow rules
  - `coding-standards.md` - Coding standards (`paths:` YAML frontmatter for conditional application)
  - Auto-generated by `/setup-2agent`, updated by `/update-2agent`
- **Plugin Hooks (`hooks/hooks.json`)**
  - `${CLAUDE_PLUGIN_ROOT}` variable references plugin root
  - `SessionStart` hook - Show Plans.md status on session start
  - `PostToolUse` hook - Auto file size check
- **Named Sessions**
  - `/start-session` generates session name in `{project}-{feature}-{YYYYMMDD}` format
  - `/rename` to change name, `/resume <name>` to resume
- **CI Consistency Check**
  - `.github/workflows/consistency-check.yml`
  - Auto-run template existence, version sync, Hooks validation
  - Local validation with `scripts/ci/check-consistency.sh`

### Changed
- Added Phase 5.5 (Claude Rules update) to `/update-2agent`
- Updated skill definitions for v0.4.0
  - `ccp-setup-2agent-files` - Added rules placement to Step 4
  - `ccp-update-2agent-files` - Added rules update to Step 8

---

## [0.3.0] - 2025-12-08

### Added
- Initial release
- Plan → Work → Review cycle
- VibeCoder guide
- Error recovery feature
