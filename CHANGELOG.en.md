# Changelog

Change history for claude-code-harness.

> **📝 Writing Guidelines**: This CHANGELOG describes "what changed for users".
> - Clear **Before/After** comparisons
> - Focus on "usage changes" and "experience improvements" over technical details
> - Make it clear "what's in it for you"

---

## [Unreleased]

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
