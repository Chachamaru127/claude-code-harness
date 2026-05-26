# Claude Code / Codex Feature Table (full upstream snapshot)

> **Overview**: List of major Claude Code / Codex features and upstream snapshots tracked and utilized by Harness.
> Full version of the CLAUDE.md Feature Table (with detailed descriptions).

## Feature List

| Feature | Utilized Skills | Purpose |
|------|-----------|------|
| **Phase 69 Claude Code 2.1.133-2.1.142 follow-up** | upstream-update, hooks, guardrails, agents, harness-plan, harness-work | `A: implemented / C: auto-inherited / P: Plans-ified (B: 0 items)`. Decomposed `docs/upstream-update-snapshot-2026-05-15.md` into Tier 1 5 items (`worktree.baseRef` template explicit / hooks `$CLAUDE_EFFORT` rule / `autoMode.hard_deny` baseline 7 items / hook `args` exec form + `continueOnBlock` + SessionStart command-only rules / hook `terminalSequence` opt-in implementation) + Tier 2 5 items (CC native `/goal` follows Plans.md SSOT policy / `claude agents` agent-view policy + 9 flag usage conditions / background permission mode retention Worker expectations / `claude plugin details` as CI auxiliary info / Phase 69 rule SSOT). Created `.claude/rules/hooks-2.1.139-plus.md` and `docs/agent-view-policy.md`, added `worktree.baseRef: "fresh"` / `autoMode.hard_deny` baseline to `templates/claude/settings.security.json.template` (manual merge to `.claude-plugin/settings.json` is release operator work due to self-write guardrail); `webhook-notify.sh` and `notification-handler.sh` emit `terminalSequence` via `scripts/lib/terminal-notify.sh` with `HARNESS_TERMINAL_NOTIFY` opt-in. |
| **Phase 67 Codex 0.130.0 stable snapshot** | upstream-update, setup, codex, harness-review | `A: validation strengthened / C: auto-inherited / P: Plans-ified (B: 0 items)`. Connected `docs/upstream-update-snapshot-2026-05-10.md` to Plans `67.1.1`-`67.1.4`, classifying `rust-v0.130.0` stable features (`codex remote-control`, plugin-bundled hooks, plugin sharing metadata, app-server Thread pagination APIs, Bedrock `aws login`, selected-environment `view_image`, live threads from latest config snapshot, `apply_patch` turn diffs, ThreadStore summaries/resume/fork, `response.processed`, Windows sandbox runtime bin cache, `cargo install --locked`, OTel trace metadata, built-in MCPs, `CODEX_HOME` environments TOML provider) as A/C/P. |
| **Phase 62 Claude Code 2.1.112-2.1.132 follow-up + Opus 4.7 follow-up** | upstream-update, harness-loop, breezing, harness-review, guardrails, hooks | `A: validation strengthened / C: auto-inherited (B: 0 items)`. Connected `docs/upstream-update-snapshot-2026-05-07.md` to Plans `62.1.1`-`62.3.1`. Tier 1: subagent stall 2-layer defense (CC 600s + elicitation-handler), `ENABLE_PROMPT_CACHING_1H` 1h cache opt-in for long-running, hooks `type: "mcp_tool"` adoption decision (= deferred), `sandbox.network.deniedDomains` baseline expansion (template canonical 9 items), R06/R11/R12 wrapper bypass test (env/sudo/watch × 3 = 9 cases). Tier 2: `PostToolUse.updatedToolOutput` opt-in handler + audit, agent permissionMode reaffirmation (Phase 59.2.3 policy gate), `skill_activated.invocation_trigger` privacy-first telemetry, `CLAUDE_CODE_SESSION_ID` env policy 4 paths, `skillOverrides` 3 mode governance. |
| **Phase 61 Sandbagging-Aware Weak-Supervision Harness** | harness-review, harness-loop, harness-mem | Connected to `docs/sandbagging-aware-weak-supervision.md` and `docs/weak-supervision-elicitation-snapshot-2026-05-06.md`. Records surface successes, weak scoring, and counter-examples in `weak-supervision-report.v1` / `elicitation-event.v1` / `.claude/state/elicitation/events.jsonl`, used for Advisor cues and Reviewer detection. Advisor keeps `PLAN/CORRECTION/STOP`; Reviewer keeps final verdict. |
| **Issue #105 English default + Japanese opt-in CI gate** | setup, harness-work, CI | New distribution surfaces default to English while Japanese opt-in UX, bilingual skill metadata, setup rendering, and mirror consistency are locked by the i18n regression suite. |
| **Phase 58 Claude Code 2.1.120-2.1.126 / Codex 0.125.0-0.128.0 snapshot** | upstream-update, harness-review, setup, codex | `A: validation strengthened / P: Plans-ified`. Connected `docs/upstream-update-snapshot-2026-05-03.md` and `docs/upstream-followups-phase58-2026-05-03.md` to Plans `58.1.1`-`58.3.2`, classifying Claude Code `--dangerously-skip-permissions`, `PostToolUse.updatedToolOutput`, MCP `alwaysLoad`, `claude plugin prune`, `claude project purge`, Codex permission profiles, `codex exec --json` reasoning tokens, plugin-bundled hooks, `/goal`, MultiAgentV2, and `0.129.0-alpha.2` watch status as A/C/P; runtime implementations cut to follow-up tasks for protected path taxonomy / output governance / Codex profile migration. |
| **Phase 56 Claude Code 2.1.119 / Codex 0.124.0 snapshot** | upstream-update, harness-review, setup | `A: validation strengthened`. Connected `docs/upstream-update-snapshot-2026-04-25.md` and `docs/upstream-followups-phase56-2026-04-25.md` to Plans `56.1.1`-`56.2.4`, classifying `--print` frontmatter parity, `PostToolUse.duration_ms`, status line effort/thinking, `prUrlTemplate`, Codex stable hooks, multi-environment app-server, and `0.125.0-alpha.2` watch status as A/C/P; locked statusline tracking and docs-only safe defaults in tests. |
| **Task tool metrics** | parallel-workflows | Aggregates token/tool/time for subagents |
| **`/debug` command** | troubleshoot | Diagnoses complex session issues |
| **PDF page range** | notebookLM, harness-review | Efficient processing of large documents |
| **Git log flags** | harness-review, CI, harness-release | Structured commit analysis |
| **OAuth authentication** | codex-review | Configuration for non-DCR MCP servers |
| **68% memory optimization** | session-memory, session | Active use of `--resume` |
| **Subagent MCP** | task-worker | MCP tool sharing during parallel execution |
| **Reduced Motion** | harness-ui | Accessibility setting |
| **TeammateIdle/TaskCompleted Hook** | breezing | Automated team monitoring |
| **Agent Memory (memory frontmatter)** | task-worker, code-reviewer | Persistent learning |
| **Fast mode (Opus 4.6)** | all skills | Fast output mode |
| **Auto memory recording** | session-memory | Automatic cross-session knowledge persistence |
| **Skill budget scaling** | all skills | Auto-adjusts to 2% of context window |
| **Task(agent_type) restriction** | agents/ | Subagent type restriction |
| **Plugin settings.json** | setup | Reduced init tokens / immediate security protection |
| **Worktree isolation** | breezing, parallel-workflows | Safe parallel writes to the same file |
| **Background agents** | generate-video | Async scene generation |
| **ConfigChange hook** | hooks | Configuration change audit |
| **last_assistant_message** | session-memory | Session quality evaluation |
| **Sonnet 4.6 (1M context)** | all skills | Large-scale context processing |
| **Memory leak fixes (v2.1.50–v2.1.63)** | breezing, work | Improved stability of long-running team sessions |
| **`claude agents` CLI (v2.1.50)** | troubleshoot | Agent definition diagnostics and inspection |
| **WorktreeCreate/Remove hook (v2.1.50)** | breezing | Automatic worktree lifecycle setup/cleanup (implemented) |
| **`claude remote-control` (v2.1.51)** | investigated / future support | External build and local environment serving |
| **`/simplify` (v2.1.63)** | work | Phase 3.5 Auto-Refinement: automatic code cleanup after implementation |
| **`/batch` (v2.1.63)** | breezing | Parallel migration delegation for horizontal tasks |
| **`code-simplifier` plugin** | work | Deep refactoring with `--deep-simplify` |
| **HTTP hooks (v2.1.63)** | hooks | JSON POST template. Activates TaskCompleted notifications when `HARNESS_WEBHOOK_URL` is set |
| **Auto-memory worktree sharing (v2.1.63)** | breezing | Memory sharing across worktree agents |
| **`/clear` skill cache reset (v2.1.63)** | troubleshoot | Cache issue diagnostics during skill development |
| **`ENABLE_CLAUDEAI_MCP_SERVERS` (v2.1.63)** | setup | Option to disable claude.ai MCP servers |
| **Effort levels + ultrathink (v2.1.68)** | harness-work | Multi-factor scoring automatically injects ultrathink for complex tasks |
| **Agent hooks (v2.1.68)** | hooks | LLM agent code quality guard via type: "agent" |
| **Opus 4/4.1 removed (v2.1.68)** | — | Removed from first-party API. Auto-migrated to Opus 4.6 |
| **`${CLAUDE_SKILL_DIR}` variable (v2.1.69)** | all skills | Resolves reference paths inside skills independent of execution environment |
| **InstructionsLoaded hook (v2.1.69)** | hooks | Tracks instructions loading event before session |
| **`agent_id` / `agent_type` added (v2.1.69)** | hooks, breezing | Stabilizes teammate identification and role determination |
| **`{"continue": false}` teammate response (v2.1.69)** | breezing | Enables automatic stop when all tasks are complete |
| **`/reload-plugins` (v2.1.69)** | all skills | Immediately applies skill/hook edits without session restart |
| **`includeGitInstructions: false` (v2.1.69)** | work, breezing | Token reduction when git instructions are not needed |
| **`git-subdir` plugin source (v2.1.69)** | setup, release | Supports plugin source managed in a subdirectory |
| **Auto Mode (RP Phase 1)** | breezing, work | CC native feature. Harness side only tracks PermissionDenied. Decision logic not implemented. Current default is `bypassPermissions` |
| **Per-agent hooks (v2.1.69+)** | agents/ | Added `hooks` field to agent definition frontmatter. Sets PreToolUse guard on Worker, Stop log on Reviewer |
| **Agent `isolation: worktree` (v2.1.50+)** | agents/worker | Added `isolation: worktree` to Worker agent definition. Automatic worktree isolation during parallel writes |
| **Compaction image retention (v2.1.70)** | notebookLM, harness-review | Images retained in summary requests. Improved prompt cache reuse |
| **Subagent final report conciseness (v2.1.70)** | breezing, harness-work | Reduced token consumption in subagent completion reports |
| **`--resume` skill list re-injection removed (v2.1.70)** | session | Saves ~600 tokens on session resume |
| **Plugin hooks fix (v2.1.70)** | hooks | Stop/SessionEnd fires after /plugin, template conflict resolved, WorktreeCreate/Remove works correctly |
| **Teammate nesting prevention additional fix (v2.1.70)** | breezing | Additional nesting prevention fix on top of v2.1.69 |
| **PostToolUseFailure hook (v2.1.70)** | hooks | New hook event that fires on tool call failure |
| **`/loop` + Cron scheduling (v2.1.71)** | breezing, harness-work | Periodic execution with `/loop 5m <prompt>`. Used for automatic task progress monitoring |
| **Background Agent output path fix (v2.1.71)** | breezing, parallel-workflows | Completion notification includes output file path. Results recoverable after compaction |
| **`--print` team agent hang fix (v2.1.71)** | CI integration | Fixed team agent hang in `--print` mode |
| **Plugin install parallel execution fix (v2.1.71)** | breezing | Stabilized plugin loading state with multiple instances |
| **Marketplace improvements (v2.1.71)** | setup | `@ref` parser fix, update merge conflict fix, MCP server deduplication, `/plugin uninstall` uses settings.local.json |
| **Subagent `background` field (v2.1.71+)** | breezing, parallel-workflows | Added `background: true` to agent definition. Always runs as a background task |
| **Subagent `local` memory scope (v2.1.71+)** | agents/ | `memory: local` saves to `.claude/agent-memory-local/`. Isolates sensitive learning not committed to VCS |
| **Agent Teams experimental flag (v2.1.71+)** | breezing | Enable Agent Teams with `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` env var. Officially documented |
| **`/agents` command (v2.1.71+)** | troubleshoot, setup | Interactive agent management UI. Create/edit/delete/list agents via GUI |
| **Desktop Scheduled Tasks (v2.1.71+)** | harness-work | CC native feature. No Harness default configuration (CronCreate tool available) |
| **`CronCreate/CronList/CronDelete` tools (v2.1.71+)** | breezing, harness-work | Internal tools for `/loop`. Creates and manages periodic tasks within a session |
| **`CLAUDE_CODE_DISABLE_CRON` env var (v2.1.71+)** | setup | `=1` disables the Cron scheduler. For environments that restrict periodic execution by security policy |
| **`--agents` CLI flag (v2.1.71+)** | breezing, CI | Passes agent definitions as JSON at session launch. Temporary configuration not saved to disk |
| **`ExitWorktree` tool (v2.1.72)** | breezing, harness-work | Tool to programmatically exit a worktree session |
| **Effort levels simplified (v2.1.72)** | harness-work | `max` removed, 3-level `low/medium/high` + `○ ◐ ●` symbols. `/effort auto` resets to default |
| **Agent tool `model` parameter restored (v2.1.72)** | breezing | per-invocation model override available again |
| **`/plan` description argument (v2.1.72)** | harness-plan | Enter plan mode with a description: `/plan fix the auth bug` |
| **Parallel tool call fix (v2.1.72)** | breezing, harness-work | Read/WebFetch/Glob failure no longer cancels sibling calls (only Bash errors cascade) |
| **Worktree isolation fix (v2.1.72)** | breezing | Restores cwd on task resume, background notification includes worktreePath |
| **`/clear` background agent retention (v2.1.72)** | breezing | `/clear` only stops foreground tasks. Background agents continue |
| **Hooks fix set (v2.1.72)** | hooks | transcript_path fix, PostToolUse double display fix, async hooks stdin fix, skill hooks double-fire fix |
| **HTML comments hidden (v2.1.72)** | all skills | `<!-- -->` in CLAUDE.md hidden during auto-injection. Still visible via Read tool |
| **Bash auto-approval additions (v2.1.72)** | guardrails | `lsof`, `pgrep`, `tput`, `ss`, `fd`, `fdfind` added to allow list |
| **Prompt cache fix (v2.1.72)** | all skills | Fixed SDK `query()` cache invalidation bug. Up to 12x reduction in input token cost |
| **Output Styles (v2.1.72+)** | all skills | Define custom output styles in `.claude/output-styles/`. `harness-ops` provides structured output for Plan/Work/Review |
| **`permissionMode` in agent frontmatter (v2.1.72+)** | agents/ | Explicitly declare `permissionMode` in agent definition YAML. No longer need `mode` specification on spawn |
| **Agent Teams official best practices (v2.1.72+)** | breezing | 5-6 tasks/teammate guideline, `teammateMode` setting, plan approval pattern reflected in team-composition |
| **Sandboxing (`/sandbox`)** | breezing, harness-work | OS-level filesystem/network isolation. Complementary layer to `bypassPermissions` |
| **`opusplan` model alias** | breezing | Auto-switches: Opus for planning, Sonnet for execution. Optimal for Lead's Plan → Execute flow |
| **`CLAUDE_CODE_SUBAGENT_MODEL` env var** | breezing, harness-work | Sets model for all subagents. Centralizes model control for Worker/Reviewer |
| **`availableModels` setting** | setup | Restricted list of available models. Model governance for enterprise deployments |
| **Checkpointing (`/rewind`)** | harness-work | Tracks/rewinds/summarizes session state. Supports safe exploration and experimentation |
| **Code Review (managed service)** | harness-review | Multi-agent PR review + `REVIEW.md`. Research Preview for Teams/Enterprise |
| **Status Line (`/statusline`)** | all skills | Custom shell script status bar. Continuously monitors context usage, cost, and git state |
| **1M Context Window (`sonnet[1m]`)** | harness-review, breezing | Utilizes 1 million token context window for large codebase analysis |
| **Per-model Prompt Caching Control** | all skills | Per-model cache control via `DISABLE_PROMPT_CACHING_*`. Debug and cost optimization |
| **`CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING`** | harness-work | Disables Adaptive Reasoning, reverts to fixed thinking budget. Predictable cost control |
| **Chrome Integration (`--chrome`, beta)** | harness-work, harness-review | Browser automation for UI tests, form input, and console debugging. Switch in session with `/chrome` |
| **LSP server integration (`.lsp.json`)** | setup | CC native feature. No Harness default `.lsp.json` configuration (configure individually with `/setup lsp`) |
| **`SubagentStart`/`SubagentStop` matcher (v2.1.72+)** | breezing, hooks | Monitors subagent lifecycle by agent type at the settings.json level. Individual tracking for Worker/Reviewer/Scaffolder/Video Generator |
| **Agent Teams: Task Dependencies** | breezing | Automatic management of inter-task dependencies. Blocked tasks auto-unblock when dependency completes. File lock prevents claim conflicts |
| **`--teammate-mode` CLI flag (v2.1.72+)** | breezing | Switches display mode per session: `in-process`/`tmux`. `claude --teammate-mode in-process` |
| **`CLAUDE_CODE_DISABLE_BACKGROUND_TASKS` (v2.1.72+)** | setup | `=1` disables all background task functionality. For environments that restrict background execution by security policy |
| **`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` (v2.1.72+)** | breezing, harness-work | Adjusts auto-compaction threshold for subagents (default 95%). `50` enables early compaction; improves long-running Worker stability |
| **`cleanupPeriodDays` setting (v2.1.72+)** | setup | Controls automatic cleanup period for subagent transcripts (default 30 days) |
| **`/btw` side question (v2.1.72+)** | all skills | Short question while preserving current context. No tool access, not saved to history. Lightweight alternative to spawning a subagent |
| **Plugin CLI commands (v2.1.72+)** | setup | `claude plugin install/uninstall/enable/disable/update` + `--scope` flag. Supports scripted automation |
| **Remote Control enhancements (v2.1.72+)** | investigated / future support | Enable from within session with `/remote-control` (`/rc`). `--name`, `--sandbox`, `--verbose` flags. QR code display with `/mobile`. Auto-reconnect |
| **`skills` field in agent frontmatter (v2.1.72+)** | agents/ | Preloads skills into subagents. Worker gets `harness-work`+`harness-review`, Reviewer gets `harness-review`, Scaffolder gets `harness-setup`+`harness-plan` (implemented) |
| **`modelOverrides` setting (v2.1.73)** | setup, breezing | Maps model picker entries to custom provider model IDs such as Bedrock ARNs |
| **`/output-style` deprecated (v2.1.73)** | all skills | Migrated to `/config`. Output style selection integrated into config menu |
| **Bedrock/Vertex Opus 4.6 default (v2.1.73)** | breezing | Cloud provider default Opus updated from 4.1 → 4.6 |
| **`autoMemoryDirectory` setting (v2.1.74)** | session-memory, setup | Customizes auto-memory save path. Supports project-specific memory isolation |
| **`CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS` (v2.1.74)** | hooks | Configurable SessionEnd hook timeout (previously hard-killed at 1.5 seconds) |
| **Full model ID fix (v2.1.74)** | agents/, breezing | Full model IDs like `claude-opus-4-6` now recognized in agent frontmatter and JSON config |
| **Streaming API memory leak fix (v2.1.74)** | breezing, harness-work | Fixed unbounded RSS growth in streaming response buffer |
| **`--remote` / Cloud Sessions** | breezing, harness-work | Launch cloud sessions from terminal with `--remote`. Async task execution |
| **`/teleport` (`/tp`)** | session | Pulls a cloud session into local terminal |
| **`CLAUDE_CODE_REMOTE` env var** | hooks, session-env-setup | Detects cloud vs. local execution. Used for conditional hook branching |
| **`CLAUDE_ENV_FILE` SessionStart persistence** | hooks, session-env-setup | Persists environment variables from SessionStart hook to subsequent Bash commands |
| **Slack Integration (`@Claude`)** | — | Future support (requires Teams/Enterprise). No Harness implementation |
| **Server-managed settings (public beta)** | setup | Centralized settings delivery via server. For Teams/Enterprise |
| **Microsoft Foundry** | setup, breezing | Added as a new cloud provider |
| **`PreCompact` hook** | hooks | State save and WIP task warning before context compaction (implemented) |
| **`Notification` hook event** | hooks | Custom handler when notification fires (implemented) |
| **`/context` command (v2.1.74)** | all skills | Visualizes context consumption and provides optimization suggestions |
| **`maxTurns` agent safety limit** | agents/ | Runaway prevention via turn limit. Worker: 100, Reviewer: 50, Scaffolder: 75 |
| **Output token limits 64k/128k (v2.1.77)** | all skills | Opus 4.6 / Sonnet 4.6 default 64k, max 128k tokens |
| **`allowRead` sandbox setting (v2.1.77)** | harness-review | Re-allow specific path reads within `denyRead` |
| **PreToolUse `allow` respects `deny` (v2.1.77)** | guardrails | Hook `allow` no longer overrides settings.json `deny` |
| **Agent `resume` → `SendMessage` (v2.1.77)** | breezing | Agent tool `resume` removed; migrated to `SendMessage({to: agentId})` |
| **`/branch` (formerly `/fork`) (v2.1.77)** | session | `/fork` renamed to `/branch`. Alias remains |
| **`claude plugin validate` enhanced (v2.1.77)** | setup | Added frontmatter + hooks.json syntax validation |
| **`--resume` 45% speedup (v2.1.77)** | session | Faster resume and reduced memory for fork-heavy sessions |
| **Stale worktree conflict fix (v2.1.77)** | breezing | Prevention of accidental active worktree deletion |
| **`StopFailure` hook event (v2.1.78)** | hooks | Captures session stop failures due to API errors |
| **`${CLAUDE_PLUGIN_DATA}` variable (v2.1.78)** | hooks, setup | State directory that persists across plugin updates |
| **Agent `effort`/`maxTurns`/`disallowedTools` frontmatter (v2.1.78)** | agents/ | Declarative control of plugin agent definitions |
| **`deny: ["mcp__*"]` fix (v2.1.78)** | setup | MCP tools now correctly blocked by settings.json deny |
| **`ANTHROPIC_CUSTOM_MODEL_OPTION` (v2.1.78)** | setup | Custom model picker entry |
| **`--worktree` skills/hooks load fix (v2.1.78)** | breezing | Normal skill/hook loading when using worktree flag |
| **Skill `effort` frontmatter (v2.1.80)** | harness-work, harness-review, harness-plan, harness-release | Gives the 5-verb skills their own thinking intensity, raising initial quality for heavy flows |
| **Agent `initialPrompt` frontmatter (v2.1.83)** | agents/ | Stabilizes the first turn of Worker / Reviewer / Scaffolder per role |
| **`sandbox.failIfUnavailable` (v2.1.83)** | setup, guardrails | Does not silently fall back to unsandboxed when sandbox fails to start |
| **`CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` (v2.1.83)** | hooks, setup | Reduces credential exposure surface to hook / Bash / MCP stdio subprocesses |
| **`TaskCreated` / `CwdChanged` / `FileChanged` hooks (v2.1.83-2.1.84)** | hooks, session | Adds reactive state tracking and Plans / rule re-read reminders |
| **Rules / skills `paths:` YAML list (v2.1.84)** | setup, localize-rules | Stores multiple globs in a structured form, making rule scope more readable and robust |
| **Hooks conditional `if` field (v2.1.85)** | hooks, guardrails | Narrows `PermissionRequest` to safe Bash and edit operations only, reducing unnecessary hook invocations and false alerts |
| **Large session truncation fix (v2.1.78)** | session | Fixed truncation of sessions over 5MB |
| **`--console` auth flag (v2.1.79)** | setup | Anthropic Console API billing authentication |
| **Turn duration display (v2.1.79)** | all skills | Toggle turn execution time display in `/config` |
| **`CLAUDE_CODE_PLUGIN_SEED_DIR` multiple support (v2.1.79)** | setup | Specify multiple seed directories |
| **SessionEnd hooks `/resume` fix (v2.1.79)** | hooks | SessionEnd fires correctly on interactive session switching |
| **18MB startup memory reduction (v2.1.79)** | all skills | Reduced startup memory usage |
| **MCP tool description cap 2KB (v2.1.84)** | all skills | Prevents context bloat from large MCP schemas from OpenAPI. CC auto-inherited |
| **`TaskCreated` hook blocking (v2.1.84)** | hooks | Hook fires synchronously on TaskCreate. Used for runtime-reactive state tracking |
| **Idle-return prompt 75min (v2.1.84)** | session | Suggests `/clear` after 75+ minutes away. Prevents token waste from stale sessions. CC auto-inherited |
| **`X-Claude-Code-Session-Id` header (v2.1.86)** | setup | Adds session ID header to API requests. Available for proxy-side aggregation. CC auto-inherited |
| **Cowork Dispatch fix (v2.1.87)** | breezing | Cowork Dispatch message delivery fix. CC auto-inherited |
| **`PermissionDenied` hook event (v2.1.89)** | hooks, breezing | Fires when auto mode classifier denies. `{retry:true}` guides retry. Implemented for Breezing Worker denial tracking and Lead notification |
| **`"defer"` permission decision (v2.1.89)** | hooks, breezing | Returning `"defer"` from PreToolUse pauses a headless session → re-evaluated on resume. Safety valve for Breezing |
| **`updatedInput` + `AskUserQuestion` (v2.1.89+)** | hooks | In headless environments, external UI / explicit answer source collects question answers; only known synonyms are normalized to canonical option labels and returned as `updatedInput.answers`. A: implemented (`ask-user-question-normalize`) |
| **Hook output >50K disk save (v2.1.89)** | hooks | Saves large hook output to disk + preview. Prevents context bloat |
| **Hooks `if` compound command fix (v2.1.89)** | hooks | Compound commands like `ls && git push` or `FOO=bar git push` now match `if` conditions correctly. CC auto-inherited |
| **Autocompact thrash loop fix (v2.1.89)** | all skills | 3 consecutive compact→immediate refill now emits actionable error and stops. CC auto-inherited |
| **Nested CLAUDE.md re-injection fix (v2.1.89)** | all skills | Fixed bug where CLAUDE.md was re-injected dozens of times in long sessions. CC auto-inherited |
| **Thinking summaries default off (v2.1.89)** | all skills | Default generation of thinking summaries stopped. Restore with `showThinkingSummaries:true`. CC auto-inherited |
| **PreToolUse exit 2 JSON fix (v2.1.90)** | hooks, guardrails | Fixed block behavior for JSON stdout + exit 2. pre-tool.sh deny now works more reliably |
| **PostToolUse format-on-save fix (v2.1.90)** | hooks | Fixed Edit/Write failure after PostToolUse hook rewrites a file. CC auto-inherited |
| **`--resume` prompt-cache miss fix (v2.1.90)** | session | Regression fix for v2.1.69+. Resume cache miss when using deferred tools/MCP/agents. CC auto-inherited |
| **SSE/transcript performance (v2.1.90)** | all skills | SSE frame O(n²)→O(n), transcript writes quadratic→linear. CC auto-inherited |
| **`/powerup` interactive lessons (v2.1.90)** | — | Animated demo for learning Claude Code features. CC auto-inherited |
| **MCP `maxResultSizeChars` 500K (v2.1.91)** | hooks, setup | Extends MCP tool result max size to 500K via `_meta["anthropic/maxResultSizeChars"]`. Useful for large harness-mem results |
| **`disableSkillShellExecution` setting (v2.1.91)** | setup, guardrails | Disables shell execution within skills. For high-security environments |
| **Plugin `bin/` directory (v2.1.91)** | setup | Plugins can bundle compiled binaries in `bin/` directory. Future distribution expansion candidate |
| **Transcript chain breaks fix (v2.1.91)** | session | Fixed transcript breaks on `--resume`. CC auto-inherited |
| **Subagent spawning fix (v2.1.92)** | breezing | Fixed "Could not determine pane count". Improved Breezing stability. CC auto-inherited |
| **`forceRemoteSettingsRefresh` (v2.1.92)** | — | Fail-closed remote settings for Teams/Enterprise. CC auto-inherited |
| **`/usage` usage / cost / stats view (v2.1.92, v2.1.118 refresh)** | all skills | `/usage` as entry point for usage/cost/stats. Old `/cost` / `/stats` as shortcuts opening related tabs. CC auto-inherited |
| **Linux `apply-seccomp` helper (v2.1.92)** | setup | Strengthened sandbox unix-socket blocking. CC auto-inherited |
| **Plugin `skills` field explicit (v2.1.94)** | setup | Explicitly declares `"skills": ["./"]` in plugin.json. CC 2.1.94 skill call names now based on frontmatter `name`. A: implemented (plugin.json updated) |
| **Monitor tool (v2.1.98)** | breezing/harness-work/ci/deploy/harness-review | Streaming stdout monitoring for long-running processes. Lower latency and token consumption than polling for tracking CI/deploy progress. A: implemented (allowed-tools + usage guide + Feature Table) |

## Phase 44 Supplemental Table

This supplemental section provides a consolidated view of `2.1.99-2.1.111` and Opus 4.7.

| Feature | Utilized Skills / Area | Purpose | Added value |
|------|-------------------|------|----------|
| **Versions with no public changelog (`2.1.99`, `2.1.100`, `2.1.102`, `2.1.103`, `2.1.104`, `2.1.106`)** | all skills | No explicit tracking items. Baseline confirmation only | `C: CC auto-inherited` |
| **`/team-onboarding` and `2.1.101`-series stabilization** | setup, session | Improved onboarding / resume UX | `C: CC auto-inherited` |
| **`PreCompact` hook (v2.1.105)** | hooks, breezing | Foundation for blocking compaction during long-running Worker execution | `A: explicit tracking target` |
| **plugin `monitors` manifest (v2.1.105)** | hooks, setup, breezing | Auto-arm monitors on session start / skill invoke | `A: explicit tracking target` |
| **thinking hint improvements (v2.1.107, v2.1.109)** | all skills | UI hint improvements during extended thinking | `C: CC auto-inherited` |
| **`ENABLE_PROMPT_CACHING_1H` (v2.1.108)** | session, work, breezing | Enables 1-hour prompt cache TTL as opt-in | `A: explicit tracking target` |
| **recap / built-in slash command discovery (v2.1.108)** | session, all skills | Improved resume quality and slash command discoverability | `C: CC auto-inherited` |
| **permission deny re-evaluation fix (v2.1.110)** | hooks, guardrails | Reflect assumption that deny is re-evaluated after `updatedInput` and mode updates in docs and test perspective | `A: explicit tracking target` |
| **`/tui`, focus, recap UX improvements (v2.1.110)** | session | Improved screen display and remote client experience | `C: CC auto-inherited` |
| **`xhigh` effort (v2.1.111)** | harness-review, advisor, docs | Adopt the intermediate intensity between `high` and `max` as official target | `A: explicit tracking target` |
| **`/ultrareview` (v2.1.111)** | harness-review, docs | Clarify roles between cloud multi-agent review and `/harness-review` | `A: explicit tracking target` |
| **Auto mode no longer requires `--enable-auto-mode` (v2.1.111)** | docs, guardrails | Update Auto Mode prerequisite text from old enable flag dependency | `A: explicit tracking target` |
| **`/effort` slider and model picker integration (v2.1.111)** | harness-review, docs | Make effort easier to adjust during conversation | `A: explicit tracking target` |
| **read-only bash permission prompt relaxation (v2.1.111)** | guardrails, docs | Update assumption that safe read-only commands trigger fewer prompts | `C: CC auto-inherited` |

### Opus 4.7 Section

| Feature | Utilized Skills / Area | Purpose | Added value |
|------|-------------------|------|----------|
| **literal instruction following** | agents, skills, docs | Reduce ambiguous expressions and make instructions and stop conditions concrete | `A: explicit tracking target` |
| **`xhigh` effort** | harness-review, advisor, docs | Raise thinking intensity one level for heavy review / advisory only | `A: explicit tracking target` |
| **task budgets** | docs, future work | First resolve conflicts with existing `max_consults` / cost controls | `A: explicit tracking target` |
| **tokenizer improvements** | all skills | Benefit from token efficiency improvements | `C: CC auto-inherited` |
| **vision 2576px** | harness-review, docs | Update operational upper limit for high-resolution review | `A: explicit tracking target` |
| **memory improvements** | session-memory, docs | Align long-running execution and resume documentation with new assumptions | `A: explicit tracking target` |
| **`/ultrareview`** | harness-review, docs | Formalize role division with `/harness-review` | `A: explicit tracking target` |
| **Auto Mode expansion** | docs, guardrails | Drop enable flag prerequisite and treat as a permanent feature | `A: explicit tracking target` |

| **`context: fork` host CLAUDE.md inheritance spec and auto-start avoidance pattern (Phase 46)** | harness-review | Resolved the issue where `context: fork` skills run in isolated context and are stopped by overriding host CLAUDE.md session-start rules. Host CLAUDE.md inheritance spec and auto-start avoidance pattern documented in `skill-editing.md` (Issue #84). A: implemented (SKILL.md Step 0 hardening + `REVIEW_AUTOSTART` marker contract) | `A: implemented` |

**Notes**:
This supplement uses `A` / `C` / `P`; `B` is `0` items.
`A` means "items where Harness has an obligation to explicitly track", `C` means "items inherited directly from Claude Code / Codex updates", `P` means "items not directly implemented this time but Plans-ified".

## Phase 51 Supplemental Table

This supplemental section classifies only the items to include in Harness from the primary sources for Claude Code `2.1.112-2.1.114` and Codex `0.121.0`.

| Feature | Utilized Skills / Area | Purpose | Added value |
|------|-------------------|------|----------|
| **AskUserQuestion `updatedInput.answers` bridge** | hooks, harness-plan, harness-release | Reads explicitly passed answers in `PreToolUse` and normalizes only known synonyms like `solo/team` or `scripted/exploratory` to option labels to continue headless interaction | `A: implemented` (`go/internal/hookhandler/ask_user_question_normalizer.go`, `hooks/hooks.json`, `tests/test-claude-upstream-integration.sh`) |
| **Claude Code 2.1.113 permission / sandbox hardening** | settings, guardrails | Configures `sandbox.network.deniedDomains` and detects `find -exec` / `-delete` and macOS dangerous rm paths in Harness guardrail | `A: implemented` (`.claude-plugin/settings.json`, `go/internal/guardrail/helpers.go`, `tests/test-claude-upstream-integration.sh`) |
| **Claude Code 2.1.114 permission dialog crash fix** | hooks, team execution | Fixed Agent Teams teammate permission dialog crash | `C: CC auto-inherited` |
| **Claude/Codex upstream update Skills gate** | skills, review | Requires a version-by-version breakdown table before upstream updates, and syncs determination of PR-target `skills/` / `codex/.codex/skills/` vs local-only `.agents/skills/` | `A: implemented` (`claude-codex-upstream-update`, `cc-update-review`) |
| **Codex 0.121.0 marketplace / MCP Apps / memory controls** | setup, future Codex workflow | Retains plugin marketplace, MCP Apps tool calls, memory reset / cleanup, sandbox metadata in Harness's Codex comparison axis | `P: Plans-ified`. Prioritized Claude hardening implementation this time; cut to Plans |
| **Codex 0.121.0 secure devcontainer / bubblewrap** | setup, guardrails | Use secure devcontainer profile and macOS Unix socket allowlist as future sandbox policy comparison targets | `C: Codex side investigated / no Harness changes` |
| **Skills mirror comprehensive audit** | skills, setup | Audit `.agents/skills` Claude/Codex replacement drift, Codex native tool model, memory/session path, and media generation metadata | `P: Plans-ified` (`docs/skills-audit-2026-04-20.md`) |

**Notes**:
Phase 51 also has `B: written only` at `0` items. The large Codex 0.121.0 items were kept in Plans as a "Codex comparison axis" rather than direct implementation this time. Claude Code side `AskUserQuestion.updatedInput` and 2.1.113 hardening were implemented through settings / Go / tests and marked `A`.

## Phase 52 Supplemental Table

This supplemental section classifies from primary sources for Claude Code `2.1.116` and Codex `0.122.0` / `0.123.0-alpha.2` whether to directly implement in Harness or defer to auto-inherited / Plans-ified. Details recorded in `docs/upstream-update-snapshot-2026-04-21.md`.

| Feature | Utilized Skills / Area | Purpose | Added value |
|------|-------------------|------|----------|
| **Claude Code 2.1.116 resume / MCP / plugin updater UX refresh** | session, setup, MCP | Cross-reference `/resume` speedup, MCP startup deferred loading, and plugin dependency auto-install with Harness session / setup guidance | `C/P: auto-inherited + Plans-ified`. No Harness wrapper added; remains as follow-up candidate for plugin dependency policy and MCP health watch |
| **Claude Code 2.1.116 dangerous-path safety / agent hooks refresh** | guardrails, agents | Cross-reference sandbox auto-allow dangerous-path safety and main-thread `--agent` hooks firing with existing guardrail / agent policy | `C/P: auto-inherited + Plans-ified`. Maintains R05 guardrail; remains in agent frontmatter policy audit |
| **Codex 0.122.0 plugin / Plan Mode / permission model** | codex workflow, setup, sandbox | Classify `/side`, fresh-context Plan Mode, plugin workflow, deny-read glob, tool discovery default-on as Codex mirror improvement candidates | `P: Plans-ified`. Handle together with Phase 51.2 Codex-native skill audit |
| **Codex 0.123.0-alpha.2 pre-release** | future compare | Do not speculatively implement thin-release-body alpha; mark as re-confirmation target after stabilization | `P: Plans-ified`. Do not speculatively implement from comparison |
| **Upstream update Skills merge hardening** | skills, review, tests | Made `cc-update-review` diff-aware, added no-op adaptation support to `claude-codex-upstream-update`, and added mirror drift test | `A: implemented` (`skills/cc-update-review`, `skills/claude-codex-upstream-update`, `tests/test-claude-upstream-integration.sh`) |

**Notes**:
Phase 52 also has `B: written only` at `0` items. UX that naturally improves in Claude / Codex itself is classified as `C`; items that would create dual responsibilities in Harness are classified as `P` and connected to the follow-up Codex-native skill audit / plugin policy. Direct implementation is limited to preventing recurrence of review findings, with skill mirror drift and no-op adaptation locked in tests.

## Phase 53 Supplemental Table

This supplemental section classifies from primary sources for Claude Code `2.1.117-2.1.118` and Codex `0.123.0` whether to directly implement in Harness or defer to auto-inherited / Plans-ified. Details recorded in `docs/upstream-update-snapshot-2026-04-23.md`.

| Feature | Utilized Skills / Area | Purpose | Added value |
|------|-------------------|------|----------|
| **Claude Code `type: "mcp_tool"` hooks** | hooks, MCP diagnostics, tests | Validate a small read-only MCP health / resource diagnostic hook without adding shell scripts | `A: implemented`. In 53.1.2, manifest addition kept as no-op; decision not to include in distributed hooks until permanent read-only diagnostic tool and stable field spec are available is recorded in snapshot. Absence of write-type MCP tool calls locked in `tests/test-claude-upstream-integration.sh` |
| **Claude Code `claude plugin tag`** | harness-release, plugin release | Create a plugin version validation tag after confirming `VERSION` and `.claude-plugin/plugin.json` sync | `A: planned`. Added to release flow / dry-run / test guidance in 53.1.3 |
| **Auto Mode `"$defaults"` extension** | permissions, sandbox, settings docs | Update guidance to add Harness-specific rules without replacing built-in defaults | `A: implemented`. Recorded `"$defaults"` as additive baseline in 53.1.4; reason it does not create dual responsibility with R05 / `deniedDomains` locked in snapshot, template, and upstream integration test |
| **Plugin themes / managed settings / dependency auto-resolve** | setup, plugin policy, enterprise docs | Organize `themes/`, `DISABLE_UPDATES`, `blockedMarketplaces`, `strictKnownMarketplaces`, dependency hints for managed environments | `A: documented`. Created `docs/plugin-managed-settings-policy.md` in 53.1.5 and documented policy not to layer Harness-specific resolver. Theme bundling decision remains as `P` in snapshot |
| **Claude Code UX / runtime fixes** | session, agents, MCP, search, effort | Organize `/usage` integration, `/resume` `/add-dir` support, `--agent` + `mcpServers`, stale session summary, native `bfs` / `ugrep`, high effort default | `C/P: auto-inherited + Plans-ified`. Reason for not adding wrapper recorded in snapshot in 53.1.6; `--agent` + `mcpServers` and external forked subagent flag remain as `P` (agent audit candidates) |
| **Codex 0.123.0 provider / model metadata** | Codex setup, provider policy | Reflect built-in `amazon-bedrock` provider, AWS profile support, and current `gpt-5.4` default metadata in Codex setup guidance | `A: documented`. Created `docs/codex-provider-setup-policy.md` in 53.2.1 and locked policy that Harness distributed config does not fix `model` / `model_provider`; only Bedrock users add to user / project config |
| **Codex 0.123.0 MCP diagnostics / plugin loading** | troubleshoot, setup, Codex plugin docs | Reflect `/mcp verbose`, diagnostics / resources / resource templates, and `.mcp.json` `mcpServers` format vs top-level server map format in setup guidance | `A: documented`. Created `docs/codex-mcp-diagnostics.md` in 53.2.2 and locked procedure to use `/mcp` normally and `/mcp verbose` only when troubleshooting; policy not to mix with Claude Code MCP guidance |
| **Codex 0.123.0 realtime handoff silence** | harness-loop, breezing, long-running | Organize interim report frequency assuming background agents receive transcript delta and can explicitly stay silent when not needed | `A: documented`. Locked in 53.2.3: `harness-loop` reports once per cycle, `breezing` once per task completion; advisor / reviewer drift excluded from silence scope |
| **Codex 0.123.0 sandbox / exec changes** | sandbox, execution policy | Follow `remote_sandbox_config` and `codex exec` shared flags | `A: documented`. Added `docs/codex-sandbox-execution-policy.md` in 53.2.4 and locked sandbox requirement comparison per remote environment and wrapper flag redundancy reduction feasibility |
| **Codex 0.123.0 automatic bug fixes** | Codex long-running UX, session shell, review privacy | Record `/copy` rollback, manual shell follow-up queue, Unicode / dead-key, stale proxy env, VS Code WSL keyboard, review prompt leak | `C: Codex auto-inherited`. Reason for not adding workaround documented in 53.2.5 |

**Notes**:
Phase 53 also has `B: written only` at `0` items. Feature Table kept as an entry point; official URLs and version-by-version decision rationale consolidated in `docs/upstream-update-snapshot-2026-04-23.md`. `A` is connected to specific Phase 53 tasks, `C` is auto-inherited from core fixes, `P` is treated as future decisions not to speculatively implement.

In Phase 53 closeout, broad Codex mirror / path drift audit remains as a TODO in Phase 51.2's Codex-native skill audit. Phase 53 closes only the concrete reflection of upstream `0.123.0` diffs and does not pre-emptively handle Phase 51.2.1-51.2.4's tool model / memory path / mirror path / media metadata cleanup.

## Phase 69 Supplemental Table (Claude Code 2.1.133-2.1.142)

This supplemental section describes how the 10 versions of Claude Code `2.1.133-2.1.142` were classified for Harness implementation/auto-inherited/deferred. See `docs/upstream-update-snapshot-2026-05-15.md` for primary sources and version-by-version decision rationale.

| Feature | Utilized Skills / Area | Purpose | Added value |
|------|-------------------|------|----------|
| **Claude Code `worktree.baseRef` (2.1.133)** | settings, breezing, worker isolation | Explicitly specify the origin of `--worktree` / `EnterWorktree` / agent-isolation worktree as `origin/<default>` (`fresh`) or local `HEAD` (`head`) | `A: implemented` (`templates/claude/settings.security.json.template`). Phase 69.1.1 made baseline `fresh` explicit in template; teams wanting to bring unpushed commits can opt-in `head` at project level. Plugin body `.claude-plugin/settings.json` requires manual merge by release operator due to self-write deny |
| **Claude Code hook `$CLAUDE_EFFORT` env + `effort.level` JSON (2.1.133)** | hooks, observability | Observe current effort from hook handler / Bash subprocess | `A: implemented` (`.claude/rules/hooks-2.1.139-plus.md`). Phase 69.1.2 documented "observation only; guard rail effort relaxation is prohibited" |
| **Claude Code `settings.autoMode.hard_deny` (2.1.136)** | settings, guardrails, auto mode | Enables Auto Mode classifier to "always deny regardless of permission intent" | `A: implemented` (`templates/claude/settings.security.json.template`). Phase 69.1.3 aligned template baseline 7 items (`Bash(sudo:*)` / `Bash(rm -rf:*)` / `Bash(rm -fr:*)` / `Bash(git push -f:*)` / `Bash(git push --force:*)` / `Bash(git reset --hard:*)` / `mcp__codex__*`) with Harness deny. Plugin body `.claude-plugin/settings.json` requires manual merge by release operator due to self-write deny |
| **Claude Code `claude agents` agent view (2.1.139-2.1.142)** | agents, breezing, operator workflow | Operator entrypoint for monitoring all CC sessions on one screen. 9 flags (`--cwd`, `--add-dir`, `--settings`, `--mcp-config`, `--plugin-dir`, `--permission-mode`, `--model`, `--effort`, `--dangerously-skip-permissions`) configure dispatched background sessions | `A: implemented` (`docs/agent-view-policy.md`, `docs/team-composition.md`, `agents/worker.md`). Phase 69.2.2 documented separation from teammate spawn workflow (breezing skill) and usage conditions for each flag |
| **Claude Code native `/goal` command (2.1.139)** | harness-plan, harness-work, Codex `/goal` complement | Retains completion conditions across turns | `A: implemented` (`docs/codex-plugin-workflows-policy.md`). Phase 69.2.1 integrated 3 rules with Codex `/goal`: "limited to session continuation memo", "does not take over Plans.md SSOT", "acceptance criteria not placed solely in `/goal`" |
| **Claude Code `claude plugin details <name>` (2.1.139)** | plugin observability, CI auxiliary | Shows plugin component breakdown and projected per-session token cost | `A: implemented` (`docs/agent-view-policy.md`, `docs/upstream-update-snapshot-2026-05-15.md`). Phase 69.2.4 positioned as CI / doctor auxiliary information; documented response steps when plugin exceeds session budget threshold |
| **Claude Code hook `args: string[]` (exec form, 2.1.139)** | hooks, security, future-proof | Spawns command directly without going through shell | `A: implemented` (`.claude/rules/hooks-2.1.139-plus.md`). Phase 69.1.4 codified as rule: "prefer exec form for path placeholder only; keep existing `command` when shell control is needed" |
| **Claude Code hook `PostToolUse.continueOnBlock` (2.1.139)** | hooks, guardrails | Feeds back hook rejection reason to Claude, enabling turn continuation | `A: implemented` (`.claude/rules/hooks-2.1.139-plus.md`). Phase 69.1.4 codified as rule: "only true for diagnostic feedback; `false` mandatory for R01-R13 / secret / protected config" |
| **Claude Code hook `terminalSequence` (2.1.141)** | hooks, local notification | Fires desktop notification / window title / bell without a controlling terminal | `A: implemented` (`scripts/lib/terminal-notify.sh`, `scripts/hook-handlers/webhook-notify.sh`, `scripts/hook-handlers/notification-handler.sh`). Phase 69.1.5 implemented `HARNESS_TERMINAL_NOTIFY` (`0` / `bell` / `title` / `osc9` / `notify`) opt-in. Independent from existing `HARNESS_WEBHOOK_URL` |
| **Claude Code background permission mode retention (2.1.141)** | agents, breezing | Teammate launched via `/bg` / `←←` / `claude agents` retains launch-time mode | `A: implemented` (`agents/worker.md`, `docs/team-composition.md`). Phase 69.2.3 documented expectation: "Worker does not need permission mode re-injection; settings.json deny is not overridden even with `bypassPermissions`" |
| **Claude Code hook config error (SessionStart/Setup/SubagentStart command-only, 2.1.142)** | hooks, validation | LLM-type hooks are rejected in bootstrap-stage hooks | `A: implemented` (`.claude/rules/hooks-2.1.139-plus.md`). In the same rule as Phase 69.1.4: "SessionStart/Setup/SubagentStart limited to `type: "command"`" made grep-able explicit |
| **CC 2.1.142 fast mode Opus 4.7 default + `CLAUDE_CODE_OPUS_4_6_FAST_MODE_OVERRIDE`** | model defaults | fast mode always runs on Opus 4.7 | `C: CC auto-inherited`. Harness already treats Opus 4.7 as default; no changes needed |
| **CC 2.1.139 MCP stdio receives `CLAUDE_PROJECT_DIR`** | MCP setup | MCP server can resolve project dir | `C: CC auto-inherited` |
| **CC 2.1.139 `x-claude-code-agent-id` / `parent-agent-id` headers + OTEL attrs** | OTel | Improved subagent observability | `C: CC auto-inherited` |
| **CC 2.1.141 `claude agents --cwd`** | operator UX | Can scope session list by directory | `A: implemented` (`docs/agent-view-policy.md`). Phase 69.2.2 documented per-project isolation operations |
| **CC 2.1.141 Rewind "Summarize up to here"** | session | Retains intermediate state during context compression | `C: CC auto-inherited`. Consistent with `/undo` policy in `.claude/rules/commit-safety.md` |
| **CC 2.1.133/2.1.136-2.1.142 runtime bug fixes (parallel session credential race / MCP `/clear` persistence / OAuth refresh / extended thinking redaction / `--resume` underscore / WSL2 image paste / agent color palette / settings hot-reload symlink / spinner amber / many plugin/MCP/UX fixes)** | runtime | safety / stability | `C: CC auto-inherited`. No wrapper added on Harness side |

**Notes**:
Phase 69 also has `B: written only` at `0` items. Feature Table kept as an entry point; official URLs and version-by-version decision rationale consolidated in `docs/upstream-update-snapshot-2026-05-15.md`. `A` is linked to actual file changes (settings / hooks / rules / docs / scripts), `C` is auto-inherited from core fixes, `P` is treated as future decisions not to speculatively implement.

## Feature Details

### Task tool metrics

Aggregates token count, tool call count, and execution time consumed by subagents.
The `parallel-workflows` skill consolidates metrics from multiple subagents for cost analysis.

```
metrics: {tokens: 40000, tools: 7, duration: 67s}
```

### `/debug` command

Session diagnostics command. Used to investigate causes of complex errors and unexpected behavior.
The `troubleshoot` skill launches automatically and diagnoses issues systematically.

### PDF page range

Specify page range when loading large PDFs (e.g., `pages: "1-5"`).
Used in `notebookLM` skill document processing and `harness-review` for referencing large specifications.

### Git log flags

Leverages structured options for `git log` (`--format`, `--stat`, `--since`, etc.).
Streamlines release note generation, commit analysis, and change tracking.

### OAuth authentication

OAuth authentication configuration for MCP servers that do not support DCR (Dynamic Client Registration).
Used for Codex CLI connections in the `codex-review` skill.

### 68% memory optimization

Reduced memory usage when resuming sessions with the `--resume` flag.
Effective for maintaining context in long-running work sessions.

### Subagent MCP

Subagents launched by Task tool can share the parent session's MCP tools.
During parallel implementation in `task-worker`, each agent can use the same MCP tool set.

### Reduced Motion

Accessibility setting. Option to reduce motion/animations.
Considered when generating UI in the `harness-ui` skill.

### TeammateIdle/TaskCompleted Hook

Hook that fires when a Breezing team member becomes idle or when a task completes.
Handled in `scripts/hook-handlers/teammate-idle.sh` and `task-completed.sh`.

```json
"TeammateIdle": [{"hooks": [{"type": "command", "command": "...teammate-idle", "timeout": 10}]}],
"TaskCompleted": [{"hooks": [{"type": "command", "command": "...task-completed", "timeout": 10}]}]
```

### Agent Memory (memory frontmatter)

Enables persistent memory with the `memory: project` field in agent definition YAML.
`task-worker` and `code-reviewer` learn past implementation patterns, failures, and solutions across sessions.

### Fast mode (Opus 4.6)

High-speed output mode switched with the `/fast` command. Uses the same Opus 4.6 model.
Available in all skills. Effective for reducing wait times on long implementation tasks.

### Auto memory recording

Automatically persists learned content to memory files at session end.
Managed by the `session-memory` skill. Automatically restores previous session context in the next session.

### Skill budget scaling

SKILL.md character budget automatically adjusts to 2% of the context window.
The recommended 500 lines is a guideline. The effective upper limit depends on the model's context window size.

### Task(agent_type) restriction

Specifies `subagent_type` when calling Task tool to restrict the type of subagent.
Combined with `agents/` definitions to ensure only intended agents are launched.

### Plugin settings.json

Pre-defines initialization settings in plugin's `settings.json`.
Reduces init token consumption and applies security policy immediately from session start.

### Worktree isolation

Uses `git worktree` to make parallel writes to the same file safe.
Prevents conflicts during multi-agent parallel implementation in `breezing` and `parallel-workflows`.

### Background agents

Launches background agents asynchronously. Can continue other processing without waiting for completion.
Used for parallel scene generation in the `generate-video` skill.

### ConfigChange hook

Hook that fires when a configuration file (`settings.json`, etc.) changes.
Records and audits changes in `scripts/hook-handlers/config-change.sh`.

### last_assistant_message

Feature that allows referencing the last assistant message at session end.
Used by the `session-memory` skill for self-evaluation of session quality.

### Sonnet 4.6 (1M context)

Sonnet 4.6 model with up to 1M token context window.
Handles large codebase analysis and processing of lengthy documents. Available in all skills.

> Note: In the 2.1.69 series, old Sonnet 4.5 references are auto-migrated to Sonnet 4.6.

### Memory leak fixes (v2.1.50–v2.1.63)

In CC 2.1.50, memory leaks related to LSP diagnostic data, large tool output, file history, and shell execution were fixed.
Garbage collection for completed tasks was also implemented, significantly improving stability of long-running team sessions like `/breezing`.
In v2.1.63, additional fixes were made for leaks in MCP reconnection, git root cache, JSON parse cache, Teammate message retention, and shell command prefix cache.
Harness already has its own countermeasures with JSONL rotation (500→400 lines) and atomic updates.

### `claude agents` CLI (v2.1.50)

Displays a list of registered agents with `claude agents list`.
Used in `troubleshoot` skill for diagnosing agent spawn failures.

```bash
claude agents list   # List registered agents
```

### WorktreeCreate/WorktreeRemove hook (v2.1.50)

Lifecycle hook that fires on worktree creation/deletion.
Used for automatic setup/cleanup in `/breezing` parallel workflows.
Implemented in `scripts/hook-handlers/worktree-create.sh` and `worktree-remove.sh`.

### `claude remote-control` (v2.1.51)

Subcommand that enables external build systems and local environment serving.
Has potential for future use in Breezing cross-session control and CI integration.

### `/simplify` (v2.1.63)

Automatic code cleanup command added in CC 2.1.63 for after implementation.
Integrated as Phase 3.5 Auto-Refinement of `/work`, automatically simplifying and organizing code after implementation completes.
Combined with `code-simplifier` plugin for deep refactoring with `--deep-simplify` option.

### `/batch` (v2.1.63)

Command for parallel delegation of horizontal tasks (migrations that apply the same change to multiple files, etc.).
Used with `/breezing` to have the Breezing team run bulk migrations in parallel.
Effective for streamlining repetitive work and reducing human errors.

### `code-simplifier` plugin

External plugin responsible for the deep refactoring mode of `/simplify`.
Activates when `--deep-simplify` is specified, automatically decomposing complex logic, removing unnecessary abstractions, and improving naming.
Regular `/simplify` is lightweight; `--deep-simplify` performs more thorough refactoring.

### HTTP hooks (v2.1.63)

New hook format added in CC 2.1.63. The `http` type is now available in addition to existing `command` / `prompt` types.
POSTs JSON to a specified URL for integration with external services (Slack, dashboards, metrics collection, etc.).
See the "http Type" section in [.claude/rules/hooks-editing.md](../.claude/rules/hooks-editing.md) for details.

### Auto-memory worktree sharing (v2.1.63)

In CC 2.1.63, Agent Memory is now shared across worktrees when using `isolation: "worktree"`.
Parallel Implementers in `/breezing` can work in their own worktree isolation while referencing and updating the same MEMORY.md.
Enables knowledge sharing between Implementers and prevents duplicate handling of the same bug.

### `/clear` skill cache reset (v2.1.63)

Skill cache reset command added in CC 2.1.63.
Resolves the problem of running with an old cache after editing skill files (which occurs frequently during skill development) with `/clear`.
Incorporated into the cache issue diagnostics step of the `troubleshoot` skill.

### `ENABLE_CLAUDEAI_MCP_SERVERS` (v2.1.63)

Environment variable added in CC 2.1.63. Setting `false` disables MCP servers provided by claude.ai.
Intended for environments that need to restrict connections to external MCP servers for security policy reasons.
Added to the environment initialization checklist of the `setup` skill.

### Agent hooks (v2.1.68)

`type: "agent"` hook added in CC 2.1.68. LLM agents make hook decisions, enabling dynamic detection of code quality issues that are difficult to detect with regular expressions.
Harness adopts this in 3 limited locations, using `model: "haiku"` and `matcher` to narrow scope for cost management:

- **PreToolUse Write|Edit**: Guards against secret embedding, TODO stubs, and security vulnerabilities
- **Stop**: WIP task residual guard (confirms no `cc:WIP` tasks remain in Plans.md)
- **PostToolUse Write|Edit**: Async code review (quality, naming, single responsibility)

Designed to roll back to `command` type if effectiveness is insufficient.

### Effort levels + ultrathink (v2.1.68)

In CC 2.1.68, Opus 4.6 changed to **medium effort** as default. The `ultrathink` keyword enables high effort (extended thinking) for a single turn.
The `harness-work` skill calculates a score using multi-factor scoring (number of changed files, target directory, keywords, failure history, explicit PM specification) and automatically injects `ultrathink` at the beginning of the Worker spawn prompt when the score is 3 or above.
See the "Effort Level Control" section in `skills/harness-work/SKILL.md` for details.

### Opus 4/4.1 removed (v2.1.68)

Opus 4 and Opus 4.1 were removed from the first-party API in CC 2.1.68. When Harness specifies `model: opus` equivalent for target agents, they are auto-migrated to Opus 4.6.
Worker/Reviewer agents use `model: sonnet` so no impact. Only Lead (when using Opus) is affected by the change to medium effort as default.

### `${CLAUDE_SKILL_DIR}` variable (v2.1.69)

The base path variable `${CLAUDE_SKILL_DIR}` for skill execution was introduced in CC 2.1.69.
Harness unifies links from `SKILL.md` that reference `references/*.md` to `${CLAUDE_SKILL_DIR}/references/...`, maintaining the same references in mirror configurations (codex/opencode).

### InstructionsLoaded hook (v2.1.69)

The `InstructionsLoaded` event was added in CC 2.1.69. Harness creates
`scripts/hook-handlers/instructions-loaded.sh` for lightweight tracking and pre-validation when instructions loading completes.

### `agent_id` / `agent_type` added (v2.1.69)

`agent_id` / `agent_type` were added to teammate-type events.
Harness guardrail was extended from `session_id` assumption to `agent_id` priority (fallback: `session_id`), stabilizing role guards.

### `{"continue": false}` teammate response (v2.1.69)

Can now return `{"continue": false, "stopReason": "..."}` from `TeammateIdle` / `TaskCompleted`.
Harness returns the same response when receiving a stop request and when all tasks are complete, making the breezing stop determination explicit.

### `/reload-plugins` (v2.1.69)

Added `/reload-plugins` to the development flow for applying skill/hook edits without session restart.
The standard procedure is: edit → `/reload-plugins` → re-execute.

### `includeGitInstructions: false` (v2.1.69)

Applying `includeGitInstructions: false` for tasks that do not need constant git instructions suppresses token consumption.
Harness recommends this for lightweight tasks (document updates, etc.) in breezing/work.

### `git-subdir` plugin source (v2.1.69)

The `git-subdir` method for managing plugin source in a monorepo subdirectory is now supported.
Harness currently does not enforce additional fields in `.claude-plugin/plugin.json` and operates by explicitly specifying `plugin source` at release time (compatibility first).

### Compaction image retention (v2.1.70)

In CC 2.1.70, summary requests during context compaction now retain images.
This maintains image context after Compaction in sessions that include screenshots or diagrams.
Prompt cache reuse rate also improved, increasing efficiency across all skills that handle images.

### Subagent final report conciseness (v2.1.70)

The final report on subagent completion was made more concise, reducing token consumption.
When launching many subagents in `breezing` or `harness-work`, the cumulative token savings are significant.

### `--resume` skill list re-injection removed (v2.1.70)

When resuming sessions with `--resume`, skill list re-injection was removed.
This saves approximately 600 tokens and lightens the resume flow in the `session` skill.

### Plugin hooks fix (v2.1.70)

Multiple Plugin hooks-related bugs were fixed in v2.1.70:
- `Stop` / `SessionEnd` hooks now fire correctly even after `/plugin` command execution
- Conflicts between hooks with the same template resolved
- `WorktreeCreate` / `WorktreeRemove` hooks confirmed to work correctly

### Teammate nesting prevention additional fix (v2.1.70)

Additional fix applied to the Teammate nesting prevention already addressed in v2.1.69.
Prevention of cascade problems where agents infinitely spawn other agents was strengthened.

### PostToolUseFailure hook (v2.1.70)

The `PostToolUseFailure` event was added in CC 2.1.70. A new hook event that fires when a tool call fails.
Harness uses this in the `hooks` skill and `error-recovery` for automatic escalation on consecutive failures (stops after 3 consecutive failures).

```json
"PostToolUseFailure": [{
  "hooks": [{
    "type": "command",
    "command": "...post-tool-failure.sh",
    "timeout": 10
  }]
}]
```

### `/loop` + Cron scheduling (v2.1.71)

The `/loop` command was added in CC 2.1.71. Specifying an interval and prompt like `/loop 5m <prompt>` enables Cron-style scheduling that executes commands periodically.
`breezing` uses `/loop 5m /sync-status` for periodic task progress checks.
Unlike the existing `TeammateIdle` (passive, event-driven), this enables active periodic monitoring.

### Background Agent output path fix (v2.1.71)

In CC 2.1.71, Background Agent completion notifications now include the output file path.
This makes it possible to safely recover background agent results even after compaction.
`run_in_background: true` in `breezing` and `parallel-workflows` becomes practical.

### `--print` team agent hang fix (v2.1.71)

Fixed the problem of team agents hanging in `--print` mode.
Improved team agent stability when running `claude --print` in CI pipelines.

### Plugin install parallel execution fix (v2.1.71)

Fixed state race conditions when multiple Claude Code instances install plugins simultaneously.
Improved plugin loading stability when multiple Teammates launch simultaneously in `breezing`.

### Marketplace improvements (v2.1.71)

Multiple improvements were made to Marketplace in CC 2.1.71:
- `@ref` parser fix: Accurate reference resolution of `owner/repo@vX.X.X` format
- Update merge conflict fix: Plugin updates are more stable
- MCP server deduplication: Prevents multiple registrations of the same MCP server
- `/plugin uninstall` uses `settings.local.json`: Accurate reflection to user-local settings

### Per-agent hooks (v2.1.69+)

A `hooks` field was added to agent definition frontmatter in CC 2.1.69.
Can define agent-specific hooks separately from global hooks.json.

Harness usage:
- **Worker**: Applies `pre-tool.sh` guardrail in `PreToolUse` on Write/Edit
- **Reviewer**: Logs review session completion in `Stop`

Hooks in agent definitions are only active during that agent's lifecycle and are automatically cleaned up on termination.

### Agent `isolation: worktree` (v2.1.50+)

Adding `isolation: worktree` to agent definition frontmatter causes
the agent to automatically create a git worktree on launch and work in an independent repository copy.
If there are no changes, the worktree is automatically cleaned up.

Harness adds `isolation: worktree` to the Worker agent.
Combined with `memory: project`, Agent Memory (MEMORY.md) is shared across worktrees,
allowing parallel Workers to reference and update the same learning content.

### Auto Mode rollout policy

Auto Mode is organized as a migration candidate to move Claude Code team execution toward a safer posture.
However, the shipped default is still `bypassPermissions`, and only permission modes listed in official docs are kept in project templates and frontmatter.

| Layer | Adopted value | Reason |
|---------|--------|------|
| project template (`permissions.defaultMode`) | `bypassPermissions` | `autoMode` is not included in documented permission modes |
| agent frontmatter (`permissionMode`) | `bypassPermissions` | Declarative settings only use documented values |
| teammate execution path | `bypassPermissions` (current) | To align shipped default with actual permission inheritance |
| `--auto-mode` | opt-in marker | Only attempt rollout when parent session has a compatible permission mode |

Default command examples:

```bash
/breezing all
/execute --breezing all
```

### Subagent `background` field

Adding `background: true` to agent definition frontmatter causes that agent to always run as a background task.
Even without explicitly specifying `run_in_background: true`, every launch via Agent tool becomes a background execution.

```yaml
---
name: long-running-analyzer
background: true
---
```

Harness may consider this when spawning Workers in `breezing`, but since Lead currently controls `run_in_background` explicitly, additional adoption is deferred to Phase 2 and beyond.

### Subagent `local` memory scope

`memory: local` saves to `.claude/agent-memory-local/<name>/`, a path that should be added to `.gitignore`.
Differences from `project`:

| Scope | Path | VCS commit | Use case |
|---------|------|-------------|------------|
| `user` | `~/.claude/agent-memory/<name>/` | Excluded | Cross-project common learning |
| `project` | `.claude/agent-memory/<name>/` | Shareable | Team-shared project knowledge |
| `local` | `.claude/agent-memory-local/<name>/` | Not recommended | Personal or sensitive learning |

Harness uses `memory: project` for both Worker and Reviewer. `local` is suitable for recording personal debug patterns, but current settings are maintained to prioritize team sharing.

### Agent Teams experimental flag

Agent Teams is enabled as an experimental feature with the `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` environment variable.
Can also be configured via settings.json:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

A validation step was added to confirm this environment variable is set during setup because Harness's `breezing` skill assumes Agent Teams functionality.

### Desktop Scheduled Tasks

Desktop app Scheduled Tasks are saved in `~/.claude/scheduled-tasks/<task-name>/SKILL.md`.
Define `name` and `description` in YAML frontmatter and write the prompt in the body.

Schedule settings (frequency, time, folder) are managed from the Desktop app UI.
Can be used for periodic execution of `/harness-work` or `/harness-review`.

### `/agents` command

Interactive agent management interface. Supports the following operations:
- List all available agents (built-in, user, project, plugin)
- Create agents with guidance or Claude generation
- Edit existing agent settings and tool access
- Delete custom agents

Non-interactive listing from CLI: `claude agents`

### `--agents` CLI flag

Passes agent definitions as JSON at session launch. Temporary configuration not saved to disk:

```bash
claude --agents '{
  "quick-reviewer": {
    "description": "Quick code review",
    "prompt": "Review for critical issues only",
    "tools": ["Read", "Grep", "Glob"],
    "model": "haiku"
  }
}'
```

Useful for temporary agent injection in CI/CD pipelines.

### `ExitWorktree` tool (v2.1.72)

The `ExitWorktree` tool was added in CC 2.1.72. Allows programmatically exiting a worktree session created by `EnterWorktree`.
Previously, the only option was manual selection at the worktree session end prompt, but now agents can automatically exit the worktree after implementation completes.

Harness usage:
- After `breezing` Worker completes work in `isolation: worktree`, explicitly close the worktree with `ExitWorktree`
- Improved reliability of worktree cleanup (can be combined with existing behavior of auto-deletion when there are no changes)

### Effort levels simplified (v2.1.72)

Effort levels were simplified to 3 levels (`low/medium/high`) in CC 2.1.72. The `max` level was removed and display symbols unified to `○ ◐ ●`. Can reset to default (medium) with `/effort auto`.

Impact on Harness:
- `ultrathink` keyword-based high effort injection continues to work (no changes)
- No changes needed to harness-work scoring logic (ultrathink → high effort mapping maintained)
- Unified references to `max` in documentation to `high`

### Agent tool `model` parameter restored (v2.1.72)

The `model` parameter was restored to Agent tool in CC 2.1.72. Can launch subagents with a specified model per-invocation.
Separate from the agent definition's `model` field, temporary model specification is possible on spawn.

Potential Harness usage:
- Spawn with `model: "haiku"` for lightweight tasks (document updates, format fixes, etc.) to reduce cost
- Spawn with `model: "opus"` for security reviews or architecture changes to maximize quality
- Currently Worker/Reviewer are both fixed at `model: sonnet`. Implementation for Lead to dynamically switch models based on task characteristics is deferred to Phase 2 and beyond

### `/plan` description argument (v2.1.72)

The `/plan` command now accepts an optional description argument in CC 2.1.72.
Can immediately enter plan mode with a description like `/plan fix the auth bug`.

Harness usage:
- Can be used complementarily with the `create` subcommand of the `harness-plan` skill
- Introduced as a shortcut when users want to quickly enter plan mode

### Parallel tool call fix (v2.1.72)

An important bug in parallel tool calls was fixed in CC 2.1.72.
Previously, if any of Read, WebFetch, or Glob failed, sibling calls running in parallel were also cancelled.
After the fix, only Bash errors cascade, and failures of other tools are processed independently.

Impact on Harness:
- Improved stability when running file reads and web searches in parallel in `breezing` and `harness-work`
- Issue of Read for a non-existent file cancelling other healthy Reads resolved
- Improved reliability during the exploration phase of Worker agents

### Worktree isolation fix (v2.1.72)

Two bugs related to worktree isolation were fixed in CC 2.1.72:

1. **Task resume cwd restoration**: Tasks resumed with the `resume` parameter now correctly restore the worktree working directory
2. **Background notification worktreePath**: Background task completion notifications now include the `worktreePath` field

Impact on Harness:
- Improved reliability when `breezing` Worker works in `isolation: worktree` and Lead collects results
- Can now obtain worktree path from completion notifications for Workers spawned with `run_in_background: true`

### `/clear` background agent retention (v2.1.72)

The behavior of `/clear` was changed in CC 2.1.72. Only foreground tasks are stopped; background-running agents and Bash tasks are no longer affected.

Impact on Harness:
- Background Workers continue even when the user runs `/clear` during `breezing` team execution
- Improved safety because running tasks are not interrupted even when Lead uses `/clear` to clean up context

### Hooks fix set (v2.1.72)

Multiple hook-related bugs were fixed in CC 2.1.72:

1. **transcript_path**: `transcript_path` is now correctly set in `--resume` / `--fork` sessions
2. **PostToolUse block reason double display**: Fixed issue where the reason message when PostToolUse hook blocks was displayed twice
3. **async hooks stdin**: Async hooks now correctly receive stdin
4. **skill hooks double-fire**: Fixed issue where skill hooks fired twice per event

Impact on Harness:
- `pre-tool.sh` / `post-tool.sh` guardrail hooks now fire exactly once, improving log reliability
- `session-memory` transcript references work correctly in `--resume` sessions

### HTML comments hidden (v2.1.72)

HTML comments (`<!-- ... -->`) in CLAUDE.md files are now hidden during auto-injection in CC 2.1.72.
Still visible when directly reading the file with the Read tool.

Impact on Harness:
- **No practical impact**: Practices that do not write important instructions or settings in HTML comments are followed

### Bash auto-approval additions (v2.1.72)

The following commands were added to the Bash auto-approval allow list in CC 2.1.72:
`lsof`, `pgrep`, `tput`, `ss`, `fd`, `fdfind`

Impact on Harness:
- Workers can now run process checks (`pgrep`) and file searches (`fd`) without permission prompts
- `pre-tool.sh` guardrails continue to pass these commands through (not blocking targets)

### Prompt cache fix (v2.1.72)

The prompt cache invalidation bug during SDK `query()` calls was fixed in CC 2.1.72.
Input token cost reduced by up to 12x.

Impact on Harness:
- Significantly reduced cost when spawning many subagents in `breezing` or `harness-work`
- Especially effective for repetitive API call patterns within the same session

### Output Styles (v2.1.72+)

The CC Output Styles feature allows customizing the system prompt itself.
A different layer from CLAUDE.md (added as a user message) or Skills (for specific tasks).

Harness provides `.claude/output-styles/harness-ops.md`:
- `keep-coding-instructions: true` — Optimizes operational flow while maintaining coding instructions
- Structured progress reporting format (Done / Current / Next)
- Tabular output for Quality Gate
- Structured format for review verdicts
- Standard output format for escalation (3-strike rule)

```bash
# Enable
/output-style harness-ops
```

### `permissionMode` in agent frontmatter (v2.1.72+)

`permissionMode` was documented as an official field in agent frontmatter in official documentation.

Reflected in Harness:
- Added `permissionMode: bypassPermissions` to all 3 agents: Worker/Reviewer/Scaffolder
- Achieves declarative permission management without relying on `mode` specification at spawn
- Auto Mode is organized as a rollout candidate; current shipped default is maintained as `bypassPermissions`

```yaml
# agents/worker.md frontmatter
permissionMode: bypassPermissions  # 追加
```

### Agent Teams 公式ベストプラクティス (v2.1.72+)

Claude Code 公式に `agent-teams.md` が独立ドキュメントとして整備された。
Harness の `docs/team-composition.md` に以下を反映:

1. **タスク粒度ガイドライン**: 5-6 tasks/teammate の推奨値
2. **`teammateMode` 設定**: `"auto"` / `"in-process"` / `"tmux"` の公式サポート
3. **Plan Approval パターン**: Worker に plan mode を要求する公式パターン
4. **Quality Gate Hooks**: `TeammateIdle`/`TaskCompleted` のexit 2 フィードバックパターン
5. **チームサイズ**: 3-5 teammates の推奨値（Harness の Worker 1-3 + Reviewer 1 と整合）

### Sandboxing (`/sandbox`)

Claude Code にネイティブ統合された OS レベルのサンドボックス機能。macOS は Seatbelt、Linux は bubblewrap を使用し、Bash コマンドのファイルシステム/ネットワークアクセスを制限する。

**2つのモード**:
- **Auto-allow mode**: サンドボックス内のコマンドは自動承認。制約外のアクセスは通常の権限フローへフォールバック
- **Regular permissions mode**: サンドボックス内でも全コマンドに承認が必要

**Harness での活用戦略**:
- `bypassPermissions` の **補完レイヤー** として位置づける（置換ではない）
- Worker エージェントの Bash コマンドに OS レベルの安全境界を追加
- `sandbox.filesystem.allowWrite` で Worker が書き込める範囲を明示制限
- `sandbox.network` で外部アクセスを信頼済みドメインに制限（エクスフィルトレーション防止）

**段階導入計画**:

| フェーズ | Worker 権限 | Sandbox |
|---------|-----------|---------|
| 現行 | `bypassPermissions` + hooks ガード | 未適用 |
| 検証フェーズ | `bypassPermissions` + hooks + sandbox auto-allow | Worker の Bash に適用 |
| 安定後 | sandbox auto-allow のみ（`bypassPermissions` 廃止検討） | 全 Bash に適用 |

```json
// settings.json (検証フェーズ用)
{
  "sandbox": {
    "enabled": true,
    "filesystem": {
      "allowWrite": ["~/.claude", "//tmp"]
    }
  }
}
```

> `@anthropic-ai/sandbox-runtime` が OSS として公開されており、MCP サーバーのサンドボックス化にも利用可能。

### `opusplan` モデルエイリアス

Plan mode では Opus、実行モードでは Sonnet に自動切替するハイブリッドエイリアス。

**Harness での活用**:
- Breezing の Lead セッションに最適: Plan フェーズ（タスク分解・アーキテクチャ決定）は Opus の推論力を活用し、Worker spawn 後の実行コーディネーションは Sonnet でコスト効率化
- `claude --model opusplan` または `/model opusplan` で有効化

**環境変数による制御**:
```bash
# opusplan の内部マッピングをカスタマイズ
ANTHROPIC_DEFAULT_OPUS_MODEL=claude-opus-4-6    # Plan 時
ANTHROPIC_DEFAULT_SONNET_MODEL=claude-sonnet-4-6  # 実行時
```

### `CLAUDE_CODE_SUBAGENT_MODEL` 環境変数

サブエージェント（Worker/Reviewer）のモデルを一括で指定する環境変数。

**Harness での活用**:
- 現状: Worker/Reviewer は `model: sonnet` をエージェント定義で固定
- 本環境変数を使うと、エージェント定義を変更せずにモデルを切り替え可能
- CI 環境でのコスト制御（`CLAUDE_CODE_SUBAGENT_MODEL=haiku` でテスト実行）に有用

```bash
# 全サブエージェントを haiku で実行（CI コスト削減）
export CLAUDE_CODE_SUBAGENT_MODEL=claude-haiku-4-5-20251001
```

### `availableModels` 設定

ユーザーが選択可能なモデルを制限する設定。managed/policy settings で設定すると、`/model`、`--model`、`ANTHROPIC_MODEL` のいずれでも制限が適用される。

**Harness での活用**:
- エンタープライズ環境でのモデルガバナンス: Worker/Reviewer が意図しないモデルを使用することを防止
- `availableModels` + `model` の組み合わせで全ユーザーのモデル体験を統制可能

```json
// managed settings
{
  "model": "sonnet",
  "availableModels": ["sonnet", "haiku", "opusplan"]
}
```

### Checkpointing (`/rewind`)

セッション中のファイル編集を自動追跡し、任意のポイントに巻き戻し可能にする機能。
各ユーザープロンプトでチェックポイントが自動作成される。

**操作方法**:
- `Esc + Esc` または `/rewind` でリワインドメニューを開く
- 選択肢: コード復元 / 会話復元 / 両方復元 / ここから要約

**Harness での活用**:
- `harness-work` のセルフレビューフェーズで問題発見時、実装前の状態に巻き戻し
- 「ここから要約」で冗長なデバッグセッションのコンテキスト窓を回収
- `/compact` との違い: チェックポイントは選択的に圧縮範囲を指定できる

**制限事項**:
- Bash コマンドによるファイル変更は追跡されない（`rm`, `mv`, `cp` 等）
- 外部の手動変更は追跡されない
- Git の代替ではなく、セッションレベルの「ローカル Undo」

### Code Review (managed service)

Anthropic インフラ上で動作するマルチエージェント PR レビューサービス。Teams/Enterprise 向け Research Preview。

**動作概要**:
1. PR 作成/更新時に自動起動
2. 複数の専門エージェントが並列で差分とコードベースを分析
3. 検証ステップで偽陽性をフィルタ
4. 重複排除・重要度ランク付け後にインラインコメントとして投稿

**重要度レベル**:
| マーカー | レベル | 意味 |
|---------|--------|------|
| 🔴 | Normal | マージ前に修正すべきバグ |
| 🟡 | Nit | 軽微な問題（ブロッキングではない） |
| 🟣 | Pre-existing | この PR 以前から存在するバグ |

**`REVIEW.md`**: リポジトリルートに配置するレビュー専用ガイダンスファイル。`CLAUDE.md` とは別に、レビュー時のみ適用されるルールを定義。

**Harness での活用**:
- `harness-review` スキルの Code Review 対応として `REVIEW.md` テンプレート生成を検討
- Harness の Worker セルフレビューと managed Code Review は補完的（ローカル + リモートの二重検査）
- 平均コスト $15-25/レビュー。`on-push` トリガーは push 回数分のコストが発生するため注意

### Status Line (`/statusline`)

Claude Code のターミナル下部に表示されるカスタマイズ可能な状態バー。シェルスクリプトに JSON セッションデータを渡し、出力テキストを表示。

**利用可能データ**:
- `model.id`, `model.display_name` — 現在のモデル
- `context_window.used_percentage` — コンテキスト使用率
- `cost.total_cost_usd` — セッションコスト
- `cost.total_duration_ms` — 経過時間
- `worktree.*` — ワークツリー情報
- `agent.name` — エージェント名
- `output_style.name` — 出力スタイル名

**Harness での活用**:
- `scripts/statusline-harness.sh` で Harness 専用ステータスライン提供
- モデル名・コンテキスト使用率・セッションコスト・git ブランチ・Harness バージョンを常時表示
- ANSI カラーでコンテキスト使用率のしきい値表示（70% 黄色、90% 赤）

### 1M Context Window (`sonnet[1m]`)

Opus 4.6 と Sonnet 4.6 で利用可能な 100 万トークンコンテキスト窓。200K トークンを超えると long-context pricing が適用される。

**Harness での活用**:
- `harness-review` の大規模コードベース分析に有用
- `breezing` で多数のファイルを同時に扱うセッション
- `/model sonnet[1m]` で有効化。`CLAUDE_CODE_DISABLE_1M_CONTEXT=1` で無効化可能

### Per-model Prompt Caching Control

モデル別にプロンプトキャッシュを制御する環境変数群。

| 環境変数 | 用途 |
|---------|------|
| `DISABLE_PROMPT_CACHING` | 全モデルのキャッシュ無効化 |
| `DISABLE_PROMPT_CACHING_HAIKU` | Haiku のみ無効化 |
| `DISABLE_PROMPT_CACHING_SONNET` | Sonnet のみ無効化 |
| `DISABLE_PROMPT_CACHING_OPUS` | Opus のみ無効化 |

**Harness での活用**:
- デバッグ時に特定モデルのキャッシュを無効化して挙動を確認
- クラウドプロバイダ（Bedrock/Vertex）でキャッシュ実装が異なる場合の選択的制御

### `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING`

Opus 4.6 / Sonnet 4.6 の Adaptive Reasoning を無効化し、`MAX_THINKING_TOKENS` で制御される固定 thinking budget に復帰する環境変数。

**Harness での活用**:
- トークンコストの予測可能性が必要な CI 環境で有用
- `harness-work` の effort スコアリングと排他的ではない（両方使用可能だが、通常は adaptive thinking を有効にしたまま ultrathink で制御する方が効果的）

### Chrome Integration (`--chrome`)

Claude Code の Chrome 拡張機能と連携し、ブラウザ自動化をターミナルから実行する beta 機能。
`--chrome` フラグでセッション起動、または `/chrome` でセッション内から有効化。

**主要機能**:
- ライブデバッグ: コンソールエラーを読み取り、原因コードを即座に修正
- UI テスト: フォーム検証、ビジュアルリグレッション確認、ユーザーフロー検証
- データ抽出: Web ページから構造化データを抽出しローカル保存
- GIF 記録: ブラウザ操作シーケンスを GIF として記録

**Harness での活用**:
- `harness-work` での UI コンポーネント実装後の自動検証
- `harness-review` での Web アプリケーションのビジュアルレビュー
- `/chrome` 有効化で Worker がブラウザテストを実行可能に

**制約**: Google Chrome / Microsoft Edge のみ。Brave, Arc 等は未対応。WSL 非対応。

### LSP サーバー統合 (`.lsp.json`)

Language Server Protocol サーバーを Plugin 経由で統合し、リアルタイムコード診断を提供。

**利用可能な LSP プラグイン**:
| プラグイン | Language Server | インストール |
|-----------|----------------|------------|
| `pyright-lsp` | Pyright (Python) | `pip install pyright` |
| `typescript-lsp` | TypeScript Language Server | `npm install -g typescript-language-server typescript` |
| `rust-lsp` | rust-analyzer | rust-analyzer 公式ガイド参照 |

**提供される機能**:
- 即座の診断: 編集後すぐにエラー/警告を表示
- コードナビゲーション: 定義ジャンプ、参照検索、ホバー情報
- 型情報: シンボルの型とドキュメント表示

**設定例** (`.lsp.json`):
```json
{
  "typescript": {
    "command": "typescript-language-server",
    "args": ["--stdio"],
    "extensionToLanguage": {
      ".ts": "typescript",
      ".tsx": "typescriptreact"
    }
  }
}
```

### `SubagentStart`/`SubagentStop` matcher

settings.json レベルでサブエージェントのライフサイクルを agent type 別に監視するフック。
公式ドキュメントで matcher にエージェント名を指定するパターンが文書化された。

**Harness の実装**:
- `SubagentStart`: Worker/Reviewer/Scaffolder/Video Generator の起動を個別にトラッキング
- `SubagentStop`: 各エージェントの完了を個別に記録
- 既存の `subagent-tracker` Node.js スクリプトに matcher を追加

```json
"SubagentStart": [
  { "matcher": "worker", "hooks": [{ "type": "command", "command": "...subagent-tracker start" }] },
  { "matcher": "reviewer", "hooks": [{ "type": "command", "command": "...subagent-tracker start" }] }
]
```

### Agent Teams: Task Dependencies

Agent Teams のタスクに依存関係を設定可能。依存タスク完了で blocked タスクが自動 unblock。

**動作**:
- タスクは `pending`, `in_progress`, `completed` の3状態
- 未解決の依存がある pending タスクは claimed 不可
- 依存完了時に自動 unblock（手動介入不要）
- ファイルロックで複数 teammate の同時 claim を防止

**Harness での活用**:
- Breezing の Lead がタスク分解時に依存関係を明示指定
- 例: 「API エンドポイント実装」→「テスト作成」→「ドキュメント更新」の順序保証

### `--teammate-mode` CLI フラグ

セッション単位で Agent Teams の表示モードを指定するフラグ。

```bash
claude --teammate-mode in-process  # 全 teammate を同一ターミナル
claude --teammate-mode tmux        # 各 teammate に個別ペイン
```

settings.json の `teammateMode` 設定を上書き。VS Code 統合ターミナルでは `in-process` が推奨。

### `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS`

`=1` で全バックグラウンドタスク機能を無効化する環境変数。

**Harness での活用**:
- セキュリティポリシーでバックグラウンド実行を制限する環境向け
- Breezing のバックグラウンド Worker spawn も無効化されるため、使用時は要注意

### `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`

サブエージェントの auto-compaction しきい値を調整する環境変数（デフォルト 95%）。

**Harness での活用**:
- `50` に設定で早期圧縮を有効化。長時間 Worker の安定性向上
- Breezing の Worker が大量のファイルを読み込む場合にコンテキスト溢れを防止

### `cleanupPeriodDays` 設定

サブエージェント transcript の自動クリーンアップ期間を制御する設定（デフォルト 30 日）。
transcript は `~/.claude/projects/{project}/{sessionId}/subagents/agent-{agentId}.jsonl` に保存。

### `/btw` サイドクエスチョン

現在のコンテキストを保持したまま短い質問を行うコマンド。
回答後にメインの会話履歴に残らないため、コンテキスト窓を消費しない。

**サブエージェントとの使い分け**:
- `/btw`: 現在のコンテキストで即答可能な質問（ツールアクセスなし）
- サブエージェント: 独立した調査・実装タスク（ツールアクセスあり）

### Plugin CLI コマンド群

プラグインの非対話的管理コマンド。スクリプトによる自動化に対応。

```bash
claude plugin install <plugin> [--scope user|project|local]
claude plugin uninstall <plugin> [--scope user|project|local]
claude plugin enable <plugin> [--scope user|project|local]
claude plugin disable <plugin> [--scope user|project|local]
claude plugin update <plugin> [--scope user|project|local|managed]
```

### Remote Control 強化

`/remote-control` (`/rc`) でセッション内から Remote Control を有効化可能に。

**新機能**:
- `--name "My Project"`: セッション名の指定
- `--sandbox` / `--no-sandbox`: サンドボックスの有効化/無効化
- `--verbose`: 詳細ログ表示
- `/mobile`: QR コード表示で iOS/Android アプリに素早く接続
- 自動再接続: ネットワーク断からの自動復帰（10 分以内）
- `/config` → "Enable Remote Control for all sessions" で常時有効化

### `skills` フィールド in agent frontmatter

サブエージェントの frontmatter に `skills` フィールドを追加し、起動時にスキルの全コンテンツをプリロード。
親会話のスキルは継承されないため、明示的にリストする必要がある。

**Harness の実装状況**:
- Worker: `skills: [harness-work, harness-review]` — 実装とセルフレビューのスキルをプリロード
- Reviewer: `skills: [harness-review]` — レビュースキルをプリロード
- Scaffolder: `skills: [harness-setup, harness-plan]` — セットアップと計画スキルをプリロード

> `skills` in skill (`context: fork`) の逆パターン。skill が agent を制御するのではなく、agent が skill を読み込む。

### `modelOverrides` 設定 (v2.1.73)

CC 2.1.73 で追加された設定。モデルピッカー（`/model` メニュー）のエントリを、カスタムプロバイダのモデル ID にマッピングできる。
Bedrock ARN や Vertex AI のモデル ID など、プロバイダ固有の識別子を指定可能。

**Harness での活用**:
- エンタープライズ環境で Bedrock/Vertex 経由の Anthropic モデルを使用する場合、`modelOverrides` でモデルピッカーの表示名と実際のプロバイダモデル ID を対応付け
- Worker/Reviewer の `model: sonnet` がプロバイダ固有の ARN に自動解決される
- `availableModels` と組み合わせて、チーム全体のモデル体験を統制可能

```json
// settings.json
{
  "modelOverrides": {
    "sonnet": "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-sonnet-4-6-20250514-v1:0",
    "opus": "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-opus-4-6-20250610-v1:0"
  }
}
```

### `/output-style` 非推奨化 (v2.1.73)

CC 2.1.73 で `/output-style` コマンドが非推奨となり、出力スタイルの選択は `/config` メニューに統合された。
既存の `/output-style harness-ops` 等は引き続き動作するが、公式には `/config` 経由の選択が推奨される。

**Harness への影響**:
- ドキュメント上の `/output-style harness-ops` への言及を `/config` 経由に更新推奨
- `.claude/output-styles/harness-ops.md` 自体は引き続き有効（設定ファイルの配置場所に変更なし）
- スキル内で `/output-style` を実行している箇所があれば `/config` に切り替え検討

### Bedrock/Vertex Opus 4.6 デフォルト化 (v2.1.73)

CC 2.1.73 でクラウドプロバイダ（Amazon Bedrock / Google Vertex AI）上のデフォルト Opus モデルが 4.1 から 4.6 に更新された。
first-party API では v2.1.68 時点で Opus 4.6 がデフォルトだったが、クラウドプロバイダ経由でも統一された。

**Harness への影響**:
- Bedrock/Vertex 環境でも Lead（Opus 使用時）が medium effort デフォルトで動作
- `opusplan` エイリアスが Bedrock/Vertex 環境でも Opus 4.6 を参照
- `ANTHROPIC_DEFAULT_OPUS_MODEL` 環境変数による上書きは引き続き有効

### `autoMemoryDirectory` 設定 (v2.1.74)

CC 2.1.74 で追加された設定。自動メモリ（auto-memory）の保存ディレクトリをカスタマイズ可能。
デフォルトの `~/.claude/` 配下からプロジェクト固有のパスに変更できる。

**Harness での活用**:
- 複数プロジェクトで Harness を使用する場合、プロジェクトごとに自動メモリを分離
- CI 環境で一時ディレクトリにメモリを保存し、セッション終了時にクリーンアップ
- Agent Memory（`memory: project`）とは異なるレイヤー（自動メモリはユーザーレベルの学習）

```json
// settings.json (プロジェクトレベル)
{
  "autoMemoryDirectory": ".claude/auto-memory"
}
```

### `CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS` (v2.1.74)

CC 2.1.74 で追加された環境変数。`SessionEnd` フックのタイムアウトをミリ秒単位で指定可能。
従来は固定 1.5 秒で kill されていたため、重いクリーンアップ処理が完了前に中断される問題があった。

**Harness での活用**:
- `SessionEnd` フックで `harness-mem` のセッション記録や JSONL ローテーションを実行する場合、十分なタイムアウトを確保
- 推奨値: `5000`（5秒）。複雑なクリーンアップが必要な場合は `10000`（10秒）まで

```bash
export CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS=5000
```

### Full model ID 修正 (v2.1.74)

CC 2.1.74 で `claude-opus-4-6`、`claude-sonnet-4-6` 等の完全なモデル ID（ハイフン区切り形式）がエージェント frontmatter および JSON config で正しく認識されるようになった。
従来はエイリアス（`opus`, `sonnet`）のみが安定して動作していた。

**Harness への影響**:
- エージェント定義の `model` フィールドに完全モデル ID を指定可能に（例: `model: claude-sonnet-4-6`）
- `--agents` CLI フラグの JSON 内でも完全モデル ID が使用可能
- 現状 Harness はエイリアス（`sonnet`, `opus`）を使用しており即時影響なし。Bedrock/Vertex 環境でフル ID 指定が必要な場合に有用

```yaml
# agents/worker.md frontmatter（完全モデル ID 使用例）
model: claude-sonnet-4-6
```

### Streaming API メモリリーク修正 (v2.1.74)

CC 2.1.74 でストリーミング API レスポンスバッファの無制限 RSS（Resident Set Size）増大が修正された。
長時間のストリーミングセッションで Node.js プロセスのメモリ使用量が際限なく増加する問題が解消。

**Harness への影響**:
- `breezing` の長時間チームセッションでの安定性が向上
- `harness-work` で大量のファイル読み書きを含む長時間 Worker セッションのメモリ消費が安定化
- v2.1.50〜v2.1.63 のメモリリーク修正シリーズ（LSP 診断、ツール出力、ファイル履歴等）に続く追加修正
- Harness 側の JSONL ローテーション対策（独自のメモリ管理）と組み合わせて、二重の安定性確保

### `--remote` / Cloud Sessions

CC の `--remote` フラグでターミナルからクラウドセッションを起動できる。タスクは Anthropic 管理の隔離 VM 上で実行され、完了後に PR 作成が可能。

**Harness での活用**:
- `breezing` の大規模タスクをクラウドに委任し、ローカルリソースを節約
- `--remote` で複数タスクを並列起動（各タスクが独立したクラウドセッション）
- `/teleport` でクラウドの成果物をローカルに取り込み、後続の `/harness-review` に接続

```bash
# クラウドでタスク実行
claude --remote "Fix the authentication bug in src/auth/login.ts"

# 完了後にローカルに取り込み
/teleport
```

### `/teleport` (`/tp`)

クラウドセッションをローカルターミナルに取り込むコマンド。`/teleport` または `/tp` で対話的にセッションを選択、`claude --teleport <session-id>` で直接指定も可能。

**前提条件**:
- ローカルの git working directory がクリーンであること
- 同一リポジトリから実行すること
- 同一 Claude.ai アカウントで認証されていること

### `CLAUDE_CODE_REMOTE` 環境変数

クラウドセッション内では `CLAUDE_CODE_REMOTE=true` が設定される。Harness の `session-env-setup.sh` はこの値を `HARNESS_IS_REMOTE` として永続化し、他のフックハンドラがローカル専用処理をスキップする判定に使用可能。

```bash
# フックスクリプト内でのクラウド検出例
if [ "$HARNESS_IS_REMOTE" = "true" ]; then
  # クラウド環境ではローカル専用処理をスキップ
  exit 0
fi
```

### `CLAUDE_ENV_FILE` SessionStart 永続化

CC の `SessionStart` フックは `CLAUDE_ENV_FILE` 環境変数が指すファイルに `KEY=VALUE` を書き込むことで、後続の Bash コマンドにも環境変数を永続化できる。

Harness の `session-env-setup.sh` はこの機構を活用し、`HARNESS_VERSION`、`HARNESS_AGENT_TYPE`、`HARNESS_IS_REMOTE` 等をセッション全体で利用可能にしている。

### Slack Integration (`@Claude`)

Slack チャネルで `@Claude` にコーディングタスクをメンションすると、自動的にクラウドセッションが作成される。GitHub リポジトリとの連携が前提。

**Harness との関係**:
- Harness の HTTP hooks（`type: "http"`）を Slack Webhook URL に設定することで、タスク完了時の Slack 通知が可能
- クラウドセッション内でも `.claude/settings.json` のフックが動作するため、Harness のガードレールは Slack 経由のタスクにも適用される

### Server-managed settings (public beta)

Claude.ai の管理画面からチーム全体の Claude Code 設定をサーバー配信する機能。Teams/Enterprise 向け。

**Harness での活用**:
- チーム全体の `permissions.deny` ルールを一括管理
- Harness のフック設定をサーバー経由で配信（ただしフック設定はセキュリティ確認ダイアログが表示される）
- `availableModels` + `model` の組み合わせでチームのモデル体験を統制

### Microsoft Foundry

Azure ベースの新クラウドプロバイダ。Bedrock / Vertex に続く第3のサードパーティプロバイダとして追加。
`modelOverrides` 設定で Foundry のモデル ID にマッピング可能。

### `PreCompact` hook

コンテキスト圧縮が実行される直前に発火するフックイベント。Harness では以下の2層で実装済み:

1. **`pre-compact-save.js`**: セッション状態（進捗、メトリクス）を永続化
2. **agent hook**: `cc:WIP` タスクが残っていないかチェックし、警告メッセージを注入

```json
"PreCompact": [
  { "hooks": [
    { "type": "command", "command": "...pre-compact-save.js" },
    { "type": "agent", "prompt": "Check Plans.md for WIP tasks...", "model": "haiku" }
  ]}
]
```

### `Notification` hook event

Claude Code が通知を発行する際に発火するフックイベント。プラグインリファレンスに記載。
外部監視ツールやダッシュボードへの通知転送に活用可能。

### `--plugin-dir` 仕様変更 (v2.1.76, breaking)

**変更内容**: `--plugin-dir` が1つのパスのみを受け付けるように変更。複数ディレクトリは繰り返し指定。

```bash
# 旧（非対応に）
claude --plugin-dir path1,path2

# 新
claude --plugin-dir path1 --plugin-dir path2
```

**Harness への影響**: Harness プラグインのみを使用する一般的な構成では影響なし。
複数プラグインを同時使用する場合のみ構文変更が必要。

---

## Claude Code 2.1.76 新機能

### MCP Elicitation サポート

**動作概要**: MCP サーバーがタスク実行中にユーザーへ構造化された入力を要求できるプロトコル。フォームフィールドまたはブラウザ URL を通じてインタラクティブなダイアログを表示する。

**Harness での活用**:
- Breezing のバックグラウンド Worker/Reviewer は UI 対話不能なため、`Elicitation` フックで自動スキップを実装
- 通常セッションではそのまま通過（ユーザーが対話で応答）
- Go hookhandler が旧互換ログ `.claude/state/elicitation-events.jsonl` に加えて、`elicitation-event.v1` を `.claude/state/elicitation/events.jsonl` に append-only 記録
- harness-mem が healthy な時だけ `/v1/events/record` へ `event_type: "elicitation_event"` として best-effort 転送し、不達時は local ledger に silent fallback

**制約事項**:
- バックグラウンドエージェントでは elicitation に応答不能（フックによる自動処理が必須）
- MCP サーバー側が elicitation をサポートしている必要がある
- Claude-harness は harness-mem DB を直接読まない

### `Elicitation`/`ElicitationResult` フック

**動作概要**: MCP Elicitation の前後でインターセプト可能な2つの新フックイベント。`Elicitation` はレスポンスが MCP サーバーに返される前に、`ElicitationResult` は返された後に発火する。

**Harness での活用**:
- `Elicitation`: Breezing セッション中の自動スキップ判定 + ログ記録 + `capability_probe` event 記録
- `ElicitationResult`: 結果のログ記録（`.claude/state/elicitation-events.jsonl`）+ `eval_result` event 記録
- hooks.json に両イベントのハンドラを登録

**制約事項**:
- `Elicitation` フックでブロック（deny）するとMCPサーバーへの入力が届かない
- 推奨 timeout: Elicitation 10s / ElicitationResult 5s

### `PostCompact` フック

**動作概要**: コンテキストコンパクション完了後に発火する新フックイベント。`PreCompact` フック（既存）と対になる。

**Harness での活用**:
- コンパクション後のコンテキスト再注入（WIP タスク状態の復元）
- `.claude/state/compaction-events.jsonl` にイベント記録
- 長時間セッションでの状態継続性向上
- PreCompact（状態保存）→ PostCompact（状態復元）の対称構造

**制約事項**:
- 推奨 timeout: 15s
- コンパクション失敗時（circuit breaker 発動時）は PostCompact が発火しない可能性あり

### `-n`/`--name` CLI フラグ

**動作概要**: セッション起動時に表示名を設定する CLI フラグ。`claude -n "auth-refactor"` のように使用し、セッション一覧での識別に活用する。

**Harness での活用**:
- Breezing セッションに `breezing-{timestamp}` 形式の名前を自動設定
- セッション一覧でのフィルタリング・追跡に活用
- ログ分析時のセッション特定が容易に

**コード例**:
```bash
claude -n "breezing-$(date +%Y%m%d-%H%M%S)"
```

### `worktree.sparsePaths` 設定

**動作概要**: 大規模モノレポで `claude --worktree` 使用時に、git sparse-checkout を通じて必要なディレクトリのみをチェックアウトする設定。ワークツリー作成のパフォーマンスを大幅に改善する。

**Harness での活用**:
- Breezing の並列 Worker 起動時間を短縮（大規模リポジトリ）
- `.claude/settings.json` で設定:
```json
{
  "worktree": {
    "sparsePaths": ["src/", "tests/", "package.json"]
  }
}
```

**制約事項**:
- sparse-checkout されていないパスのファイルは Worker からアクセス不可
- 依存関係のあるディレクトリはすべて sparsePaths に含める必要がある

### `/effort` スラッシュコマンド

**動作概要**: セッション中に effort レベル（low/medium/high）を切り替えるスラッシュコマンド。`/effort auto` でデフォルトにリセット。

**Harness での活用**:
- harness-work の多要素スコアリングと連携し、タスク複雑度に応じた effort 制御が可能
- 複雑なタスクでは `/effort high`（ultrathink 有効化）を手動で設定可能
- 簡易タスクでは `/effort low` でトークン消費を抑制

### `--worktree` 起動高速化

**動作概要**: git refs の直接読み取りと、リモートブランチが利用可能な場合の冗長な `git fetch` スキップにより、`--worktree` の起動時間を短縮。

**Harness での活用**:
- Breezing の Worker 起動オーバーヘッドが自動的に削減
- 特に多数の Worker を同時起動する場合に恩恵が大きい

### バックグラウンドエージェント部分結果保持

**動作概要**: バックグラウンドエージェントが kill された場合にも、部分的な結果が会話コンテキストに保存される。

**Harness での活用**:
- Breezing の Worker がタイムアウトや手動停止で中断された場合、作業の一部が Lead に伝達される
- Worker の途中成果物を活用した再割り当てが可能に
- 「やり直し」の無駄が削減

### stale worktree 自動クリーンアップ

**動作概要**: 中断された並列実行で残った stale ワークツリーが自動的にクリーンアップされる。

**Harness での活用**:
- `worktree-remove.sh` による手動クリーンアップの補完
- Breezing セッションのクラッシュ後も自動回復
- ディスク容量の無駄な消費を防止

### 自動コンパクション circuit breaker

**動作概要**: 自動コンパクションが連続して失敗した場合、3回で停止するサーキットブレーカーが導入された。無限リトライによるトークン浪費を防止する。

**Harness での活用**:
- Harness の「3回ルール」（CI失敗時の3回制限）と一致する設計思想
- 長時間 Breezing セッションでの予期せぬコスト増加を防止
- circuit breaker 発動時は PostToolUseFailure フックと連携してエスカレーション

### Deferred Tools スキーマ修正

**動作概要**: `ToolSearch` で読み込んだツールがコンパクション後に入力スキーマを失い、配列・数値パラメータが型エラーで拒否される問題を修正。

**Harness での活用**:
- 長時間セッションでの ToolSearch 経由ツールの安定性が向上
- Breezing のコンパクション後もMCPツールが正常に動作

### `/context` コマンド (v2.1.74)

**動作概要**: コンテキスト窓の消費状況を分析し、コンテキストを圧迫しているツールやメモリを特定する。アクション可能な最適化提案（不要な MCP サーバーの切断、肥大化したメモリの整理等）を表示する。

**Harness での活用**:
- 長時間 Breezing セッションでの「なぜコンパクションが頻繁に起きるのか」の原因特定
- 大量の hooks や MCP サーバーが接続された環境でのコンテキスト最適化
- セッション中に `/context` を実行するだけで即座に分析結果が得られる

**制約事項**:
- セッション中のみ利用可能（バッチモードでは非対応）
- サブエージェント内では利用不可

### `maxTurns` エージェント安全制限

**動作概要**: サブエージェントの最大ターン数を制限する frontmatter フィールド。設定ターン数に到達すると、エージェントは自動的に停止して結果を返す。CC 公式ドキュメントで推奨されている安全機構。

**Harness での活用**:
- Worker: `maxTurns: 100` — 複雑な実装タスク向け。十分な余裕を持ちつつ暴走を防止
- Reviewer: `maxTurns: 50` — Read-only 分析に特化。50 ターンで完了しない場合は問題あり
- Scaffolder: `maxTurns: 75` — 足場構築と状態更新の中間的な複雑度

**設計判断**:
- 上限に達した場合、Lead が途中結果を回収して判断可能
- `bypassPermissions` と組み合わせることで、暴走時の安全弁として機能

### `Notification` フック実装

**動作概要**: Claude Code が通知を発行する際に発火するフックイベント。`permission_prompt`（権限確認）、`idle_prompt`（アイドル通知）、`auth_success`（認証成功）等のイベントをインターセプトする。

**Harness での活用**:
- `notification-handler.sh` で全通知イベントを `.claude/state/notification-events.jsonl` にログ記録
- Breezing のバックグラウンド Worker で発生した `permission_prompt` を追跡（事後分析用）
- hooks-editing.md では v3.10.3 からドキュメント化済みだったが、hooks.json への実装が今回完了

**ログ形式**:
```json
{"event":"notification","notification_type":"permission_prompt","session_id":"...","agent_type":"worker","timestamp":"2026-03-15T..."}
```

### Output token limits 64k/128k (v2.1.77)

CC 2.1.77 で Opus 4.6 と Sonnet 4.6 のデフォルト最大出力トークンが 64k に引き上げられ、上限が 128k トークンまで拡張された。

**Harness への影響**:
- 長い実装コードや大規模リファクタリングの出力がトランケートされにくくなった
- Worker エージェントが大量のファイル変更を一度に出力する場合の信頼性が向上
- 128k 出力はコスト増大につながるため、コスト管理にも留意が必要

### `allowRead` sandbox 設定 (v2.1.77)

`sandbox.filesystem.denyRead` で広範囲をブロックしつつ、`allowRead` で特定パスの読み取りを再許可できるようになった。

**Harness での活用**:
- Reviewer エージェントのサンドボックスで `/etc/` を denyRead しつつ、特定の設定ファイルだけ allowRead する
- セキュリティレビュー時に機密ディレクトリの制限付き読み取りアクセスを提供

### PreToolUse `allow` が `deny` を尊重 (v2.1.77)

CC 2.1.77 で PreToolUse フックが `"allow"` を返しても、settings.json の `deny` パーミッションルールが引き続き適用されるようになった。以前はフックの `allow` がグローバル `deny` を上書きしていた。

**Harness への影響**:
- guardrails のセキュリティモデルが強化された
- `deny: ["mcp__codex__*"]` を settings.json に設定すれば、PreToolUse フックの判断に関わらず確実にブロック
- `.claude/rules/codex-cli-only.md` のフックベース MCP ブロックに加え、settings.json deny が推奨パターンに

### Agent `resume` → `SendMessage` (v2.1.77)

CC 2.1.77 で Agent tool の `resume` パラメータが廃止された。停止中のエージェントを再開するには `SendMessage({to: agentId})` を使用する。`SendMessage` は停止中のエージェントを自動でバックグラウンド再開する。

**Harness での影響**:
- `breezing` スキルの Lead が Worker/Reviewer と通信する際は `SendMessage` を使用
- `team-composition.md` の Lead Phase B で `SendMessage` が正式なコミュニケーション手段として記載

### `/branch` (旧 `/fork`) (v2.1.77)

CC 2.1.77 で `/fork` コマンドが `/branch` にリネームされた。`/fork` はエイリアスとして引き続き機能する。

### `claude plugin validate` 強化 (v2.1.77)

CC 2.1.77 で `claude plugin validate` がスキル・エージェント・コマンドの YAML frontmatter と hooks.json の構文を検証するようになった。

**Harness での活用**:
- CI パイプラインに `claude plugin validate` を追加し、frontmatter エラーを早期検出
- `tests/validate-plugin.sh` の補完として活用可能

### `StopFailure` hook event (v2.1.78)

CC 2.1.78 で `StopFailure` イベントが追加された。API エラー（レート制限 429、認証失敗 401 等）でセッション停止が失敗した際に発火する。

**Harness での活用**:
- `stop-failure.sh` ハンドラーでエラー情報を `.claude/state/stop-failures.jsonl` にログ記録
- Breezing の Worker がレート制限で停止失敗した場合の事後分析に使用
- 10 秒タイムアウトの軽量ハンドラーとして実装（復旧処理は不要）

### Hooks conditional `if` field (v2.1.85)

CC 2.1.85 で、hooks 定義に `if` 条件を付けて「どんな入力のときだけ hook を走らせるか」を細かく絞れるようになった。Permission rule syntax を使うので、`Bash(git status*)` のようにツール名と入力パターンをまとめて指定できる。

**Harness での活用**:
- `PermissionRequest` を 2 系統に分割し、`Edit|Write|MultiEdit` は常時評価、`Bash` は安全コマンド候補だけを `if` で事前フィルタする
- `hooks/permission.sh` 自体の安全判定は残しつつ、そもそも不要な Bash permission hook の起動数を減らす
- `MultiEdit` も matcher に含め、core guardrail では対応済みだった自動承認の取りこぼしを hooks 側でもなくした

**ユーザー体験の改善**:
- 今まで: Bash の権限確認は広く hook が走り、最終的にスルーされるケースでも起動コストがかかっていた
- 今後: safe-read / test 系の Bash だけに hook が走るため、応答ノイズと無駄な評価を減らしつつ、自動承認の精度は維持できる

### `${CLAUDE_PLUGIN_DATA}` 変数 (v2.1.78)

CC 2.1.78 で `${CLAUDE_PLUGIN_DATA}` ディレクトリ変数が追加された。プラグイン更新でも永続するステートストレージとして使用できる。

**Harness での活用余地**:
- 現在は `${CLAUDE_PLUGIN_ROOT}/.claude/state/` を使用しているが、プラグイン更新で消える可能性
- 長期的にはメトリクス・通知ログ等の永続データを `${CLAUDE_PLUGIN_DATA}` に移行を検討
- 移行パターン: `STATE_DIR="${CLAUDE_PLUGIN_DATA:-${CLAUDE_PLUGIN_ROOT}/.claude/state}"`

### Agent frontmatter: `effort`/`maxTurns`/`disallowedTools` (v2.1.78)

CC 2.1.78 でプラグインエージェント定義の frontmatter に `effort`, `maxTurns`, `disallowedTools` が公式サポートされた。

**Harness での現状**:
- `maxTurns`: v3.10.4 で既に実装済み（Worker: 100, Reviewer: 50, Scaffolder: 75）
- `disallowedTools`: Worker は `[Agent]`、Reviewer は `[Write, Edit, Bash, Agent]` で実装済み
- `effort`: 未使用。Worker/Reviewer 定義に `effort` フィールドを追加して、デフォルト thinking レベルを宣言的に制御可能

### `deny: ["mcp__*"]` 修正 (v2.1.78)

CC 2.1.78 で settings.json の `deny` パーミッションルールが MCP サーバーツールに対して正しく機能するように修正された。

**Harness での活用**:
- `.claude/rules/codex-cli-only.md` で推奨している Codex MCP ブロックを、フックベースから settings.json `deny` に移行可能
- `"permissions": { "deny": ["mcp__codex__*"] }` がクリーンなパターン

### `--console` auth フラグ (v2.1.79)

CC 2.1.79 で `claude auth login --console` フラグが追加され、Anthropic Console API 課金での認証に対応。

### SessionEnd hooks `/resume` 修正 (v2.1.79)

CC 2.1.79 で対話的 `/resume` セッション切替時に `SessionEnd` フックが正常に発火するようになった。以前はセッション切替時に SessionEnd が発火しなかったため、cleanup 処理が実行されないケースがあった。

### `PermissionDenied` hook event (v2.1.89)

CC 2.1.89 で auto mode classifier がコマンドを拒否した際に `PermissionDenied` フックが発火するようになった。`{retry: true}` を返すとモデルにリトライ可能であることを伝えられる。拒否されたコマンドは `/permissions` → Recent タブにも表示される。

**Harness での活用**:
- `permission-denied-handler.sh` を新規実装し、拒否イベントを `permission-denied.jsonl` に telemetry 記録
- Breezing Worker が拒否された場合、Lead に `systemMessage` で通知し代替アプローチの検討を促す
- `agent_id` / `agent_type` フィールドを活用して、どのエージェントが何を拒否されたかを追跡

**ユーザー体験の改善**:
- 今まで: auto mode の拒否は通知だけで記録に残らず、同じ拒否が繰り返されやすかった
- 今後: 拒否パターンが蓄積され、Breezing では Lead が即座に認知して対応できる

### `"defer"` permission decision (v2.1.89)

CC 2.1.89 で PreToolUse フックから `"defer"` permission decision を返せるようになった。ヘッドレスセッション（`-p` モード）でフックが defer を返すとセッションが一時停止し、`claude -p --resume` で再開時にフックが再評価される。

**Harness での活用余地**:
- Breezing Worker が本番環境への書き込みや外部サービスへのリクエストなど、判断困難な操作に遭遇した際の安全弁
- `pre-tool.sh` の guardrail に「defer 条件」を追加し、特定パターンで Worker を一時停止→Lead が判断
- 現時点では機能の文書化のみ。具体的な defer ルールは運用パターンの蓄積後に設計

### Hook output >50K disk save (v2.1.89)

CC 2.1.89 でフック出力が 50K 文字を超える場合、コンテキストへの直接注入ではなくディスクに保存され、ファイルパス＋プレビューとして参照される。

**Harness への影響**:
- 大量の出力を返す可能性のあるフック（quality-pack, ci-status-checker 等）はこの挙動を前提に設計
- 現状の Harness フックは出力が軽量のため直接影響は小さいが、将来の拡張時の設計制約として文書化

### PreToolUse exit 2 JSON fix (v2.1.90)

CC 2.1.90 で PreToolUse フックが JSON を stdout に出力して exit code 2 で終了する際のブロック動作が修正された。以前はこのパターンでブロックが正しく機能しないバグがあった。

**Harness への影響**:
- `pre-tool.sh` は deny 時に JSON + exit 2 パターンを使用しており、v2.1.90 以降で guardrail の deny がより確実に動作
- 既存のガードレールが「deny を出したのにツールが実行された」ケースがあった場合、このバグが原因だった可能性

### Built-in slash commands を Skill tool から呼ぶ際の Harness 影響 (v2.1.108)

CC 2.1.108 以降、モデルが `Skill` tool を通じて `/init`、`/review`、`/security-review` などの
built-in slash commands を呼び出せるようになった。これにより Harness スキルが CC の組み込み機能を
内部から呼び出す構成が可能になるが、Harness 独自の `/harness-review` との役割重複に注意が必要。
具体的には、`Skill` tool 経由で `/review` を呼び出した場合、Harness の guardrails（R01-R13）が
適用されない CC ネイティブのレビューが実行される。Harness のレビューフローでは
`/harness-review` または `codex-companion.sh review` を経由させることで guardrails の保護と
`review-result.v1` 形式への正規化が維持される。built-in slash command の Skill tool 呼び出しは
軽量な inline レビューや初期化処理に限定し、品質ゲートを要するレビューには使用しない。

## v2.1.99-v2.1.110 + Opus 4.7 詳細セクション（Phase 44.11.1）

> このセクションは `.claude/rules/cc-update-policy.md` の 3 カテゴリ分類（A/B/C）に準拠。
> B 分類は **0 件**。A = 実装あり、C = CC 自動継承。

### PreCompact hook 3-way decision API (v2.1.99)

**付加価値**: `A: 実装あり`（hooks/hooks.json PreCompact エントリ、Phase 44.13 で確認済み）

CC 2.1.99 で PreCompact フックが `"block"` / `"allow"` / `"defer"` の 3-way decision API に対応した。
それまでは `block` / `allow` の 2 択のみで、「後で判断」の選択肢がなかった。

**Harness での活用**:
- Breezing Worker が cc:WIP 状態のとき compaction を `"block"` し、WIP 完了後に `"allow"` するパターンが安全に実装できる
- `hooks/hooks.json` の PreCompact ハンドラは `bin/harness pre-compact` 経由で Plans.md の cc:WIP を検出し block を返す
- `"defer"` はヘッドレス環境での条件付き延期に活用予定（現在は block/allow の 2-way を使用）

**ユーザー体験の改善**:
- 今まで: WIP 中の compaction を防ぐには `block` しかなく、長時間 Worker では不要な compaction 抑止が続く問題があった
- 今後: `defer` で「今はダメだが resume 後に再評価」を指示でき、Worker 完了と同時に compaction が適切に走る

### ENABLE_PROMPT_CACHING_1H opt-in (v2.1.108)

**付加価値**: `A: 実装あり`（`scripts/enable-1h-cache.sh`、Phase 44.6.1 で実装済み）

CC 2.1.108 で `ENABLE_PROMPT_CACHING_1H=1` 環境変数による 1 時間 prompt cache TTL が追加された。
デフォルトの 5 分 TTL では 30 分超のセッションでキャッシュミスが頻発しコスト増大していた。

**Harness での活用**:
- `scripts/enable-1h-cache.sh` を実行すると `env.local` に `ENABLE_PROMPT_CACHING_1H=1` を idempotent に追記
- `skills/breezing/SKILL.md` と `skills/harness-loop/SKILL.md` の開始前推奨として記載
- `docs/long-running-harness.md` に選択基準テーブル（セッション 30 分超なら 1h cache）を追加

**ユーザー体験の改善**:
- 今まで: 長時間 Breezing セッションで cache miss が増え、同じ CLAUDE.md や hooks.json が繰り返し課金されていた
- 今後: 1h TTL でキャッシュヒット率が大幅向上。長時間タスクのコストを削減できる

### /undo (rewind alias) (v2.1.108)

**付加価値**: `A: 実装あり`（`.claude/rules/commit-safety.md`、Phase 44.7.1 で実装済み）

CC 2.1.108 で `/rewind` のエイリアスとして `/undo` が追加された。セッション内の直前ツール呼び出しを取り消す。

**Harness での活用**:
- `.claude/rules/commit-safety.md` に `/undo` の動作定義・利用制約・禁止パターンを明記
- Worker / Reviewer が自律的に `/undo` を実行する禁止条件（git commit 後の取り消しは `git revert` を使う）を文書化
- commit 済みの変更を間違えて `/undo` で消すリスクを防止

**ユーザー体験の改善**:
- 今まで: `/rewind` と `/undo` の使い分けが曖昧で、エージェントが誤用するリスクがあった
- 今後: Harness ルールで「`/undo` = セッション内ファイル変更の取り消し」「commit 後は `git revert`」と明確に分離

### PermissionRequest updatedInput / additionalContext (v2.1.110)

**付加価値**: `A: 実装あり`（`go/internal/guardrail/cc2110_regression_test.go`、Phase 44.3.1 で実装済み）

CC 2.1.110 で PermissionRequest フックに `updatedInput` と `additionalContext` フィールドが追加・整備された。
`updatedInput` で CC が再評価した入力を渡し、`setMode: dontAsk` で mode 変更後も deny ルールが再適用される。

**Harness での活用**:
- `go/internal/guardrail/cc2110_regression_test.go` に 3 グループのリグレッションテストを追加
  - `updatedInput` + `setMode` → deny ルール（R01, R02, R06）が再評価後も適用されることを検証
  - `additionalContext` が JSON round-trip で保持されることを確認（R09 警告パス）
  - Bash bypass ベクター（`;`, `&&`, `||`, サブシェル等）の検出強化
- `helpers.go` の `hasSudo()` をシェルメタキャラクタを含むコンテキストにも対応

**ユーザー体験の改善**:
- 今まで: CC が入力を更新した後、guardrail の deny が再評価されない抜け穴が理論的に存在した
- 今後: `updatedInput` 後も R01-R13 全ルールが再適用され、guardrail の完全性が保証される

### /recap と built-in slash command discovery (v2.1.108)

**付加価値**: `C: CC 自動継承`（Harness 側変更不要）

CC 2.1.108 で `/recap` コマンドが追加され、resume 前にセッション内容を要約して確認できるようになった。
built-in slash command の Skill tool 経由呼び出しも同バージョンで実現。

**Harness での活用**:
- `/recap` は長時間の `--resume` 時にセッション記憶を確認する手順として `skills/session-memory/SKILL.md` に記載
- CC 本体の機能として自動利用可能。Harness 側の実装変更は不要

### EnterWorktree path 引数 / stale worktree 自動クリーンアップ (v2.1.105)

**付加価値**: `A: 実装あり`（`scripts/reenter-worktree.sh`、Phase 44.7.1 で実装済み）

CC 2.1.105 で `EnterWorktree` フックに worktree パスが引数として渡されるようになった。
それまでは worktree パスをスクリプト内で自力特定する必要があった。

**Harness での活用**:
- `scripts/reenter-worktree.sh` で EnterWorktree パス引数を活用した worktree 再入ヘルパーを実装
- worktree 登録確認と `worktree-info.json` 照合を含む安全な再入フロー
- Breezing の Worker が一時停止後に正しい worktree に再入できることを保証

**ユーザー体験の改善**:
- 今まで: Worker の worktree 再入は環境依存の worktree パス特定が必要で不安定だった
- 今後: フックから直接パスを受け取り、worktree-info.json との照合で確実に正しいコンテキストに再入

---

## Opus 4.7 詳細セクション（Phase 44.11.1）

> このセクションでは Opus 4.7 固有機能の Harness への統合状況を詳述する。
> 付加価値分類: A = 実装あり、C = CC 自動継承。B 分類は 0 件。

### 1. Literal Instruction Following

**付加価値**: `A: 実装あり`（`.claude/rules/opus-4-7-prompt-audit.md`、Phase 44.4.1 + 44.4.2 で実装済み）

Opus 4.7 は「指示を文字通り実行する」能力が大幅に向上した。曖昧な表現を補完して意図を推測するのではなく、指示された内容だけを実行する。

**Harness での活用**:
- `.claude/rules/opus-4-7-prompt-audit.md` を新設。エージェントプロンプトの品質基準を定義
  - 行動指示には実行コマンド名 / ファイルパス / JSON schema 名 / 数値閾値のいずれかを必須化
  - 回数制御は `最大 3 回` のように数字で記述
  - `必要に応じて` / `適宜` 等の曖昧語には直後に条件補足を必須化
- `agents/worker.md`, `agents/reviewer.md`, `agents/advisor.md` のプロンプトを監査基準に適合

**ユーザー体験の改善**:
- 今まで: エージェントプロンプトの曖昧表現がモデルの誤解釈を招き、意図しない動作が発生した
- 今後: 監査基準に合格したプロンプトはモデルが文字通りに解釈し、一貫した動作が保証される

### 2. xhigh Effort

**付加価値**: `A: 実装あり`（`agents/reviewer.md`, `agents/advisor.md`, `docs/effort-level-policy.md`、Phase 44.5.1 で実装済み）

Opus 4.7 では `xhigh` effort レベルが追加された（CC v2.1.111 frontmatter として受け付け可能）。
`high` より thinking 強度が高く、複雑なレビューや設計判断に適する。

**Harness での活用**:
- `agents/reviewer.md`: `effort: medium` → `effort: xhigh` に変更（レビューの深度向上）
- `agents/advisor.md`: `effort: high` → `effort: xhigh` に変更（判断の正確性向上）
- `docs/effort-level-policy.md`: CC frontmatter effort と Anthropic API effort の対応マトリクスを整備
- `harness-work` スキルの多要素スコアリングで `ultrathink` を Worker に注入する仕組みは維持

**ユーザー体験の改善**:
- 今まで: Reviewer は medium effort で動作し、複雑なアーキテクチャ変更のレビューが浅くなるケースがあった
- 今後: xhigh effort で Reviewer の thinking 品質が向上し、critical/major 指摘の検出率が上がる

### 3. Task Budgets（採用見送り）

**付加価値**: `C: 採用見送り`（`docs/task-budgets-research.md`、Phase 44.10.1 で調査済み）

Anthropic Task Budgets (public beta) はタスク単位でトークン・ツール呼び出し数を制限する機能。

**Harness での活用**:
- `docs/task-budgets-research.md` に仕様要約・Harness 既存機構との競合関係分析を記録
- 既存の `maxTurns` (Worker: 100, Reviewer: 50) および `MAX_REVIEWS` と機能が重複するため本 Phase では採用見送り
- GA 昇格時の再評価トリガー条件（Harness 独自制御との統合設計が確定した時点）を明記

**採用見送り理由**:
- Harness は既に `maxTurns` と `MAX_REVIEWS` で Worker の実行制限を管理
- Task Budgets との二重管理は設定の複雑性を増やすリスクがある
- Public beta 段階での採用より GA 後の安定 API を待つ判断

### 4. Tokenizer 改善

**付加価値**: `C: CC 自動継承`（Harness 側変更不要）

Opus 4.7 の新 tokenizer により、同一プロンプトのトークン数が削減される。特に日本語・コード混在コンテンツで効果が大きい。

**Harness への影響**:
- CLAUDE.md、スキルファイル、エージェントプロンプトのトークン消費が自動的に削減
- スキルバジェット（コンテキスト窓の 2%）の実効文字数が増加
- Harness 側の変更は不要。モデル更新で自動的に恩恵を受ける

### 5. Vision 2576px 対応

**付加価値**: `A: 実装あり`（`docs/opus-4-7-vision-usage.md`, `skills/harness-review/references/vision-high-res-flow.md`、Phase 44.9.1 で実装済み）

Opus 4.7 では画像の短辺上限が 2576px まで拡大された。PDF・設計図・UI スクリーンショットのレビュー品質が向上。

**Harness での活用**:
- `docs/opus-4-7-vision-usage.md`: 高解像度レビューの運用ガイドを新設（3 種のシナリオ: PDF レビュー / 設計図解析 / UI スクリーンショット）
- `skills/harness-review/references/vision-high-res-flow.md`: 2576px 上限の運用フロー（リサイズ判定・多ページ PDF の分割戦略）を整備
- `/harness-review` で画像添付時の自動上限チェックを組み込み

**ユーザー体験の改善**:
- 今まで: 高解像度スクリーンショットは自動リサイズで品質が低下し、細部の UI 問題を見落とすケースがあった
- 今後: 2576px まで原寸でレビュー可能。UI のピクセルレベルの問題や設計図の微細なラベルも検出できる

### 6. Memory 機能拡張

**付加価値**: `C: CC 自動継承`（auto-memory システムが既存。Harness 側変更不要）

Opus 4.7 の Memory 機能拡張（自動メモリ記録の精度向上・長期記憶の圧縮品質改善）は Harness の既存 Agent Memory 基盤と自動的に統合される。

**Harness での活用**:
- `memory: project` frontmatter によるエージェント固有メモリは引き続き機能
- CC の自動メモリ精度向上により、Worker / Reviewer / Scaffolder の学習品質が自動的に向上
- `.claude/agent-memory/` の既存エントリとの互換性は維持

### 7. /ultrareview（並立維持方針）

**付加価値**: `A: 実装あり`（`docs/ultrareview-policy.md`, `skills/harness-review/SKILL.md`、Phase 44.8.1 で実装済み）

CC v2.1.111 で `/ultrareview` が built-in operator entrypoint として追加された。cloud 多エージェントレビューを実行する。

**Harness での活用（方針 B: 並立維持）**:
- `docs/ultrareview-policy.md`: `/ultrareview` は ad-hoc レビューに限定、Harness automation flow には組み込まない方針を確立
- Harness の review automation は `review-result.v1` 契約ベースの `codex-companion.sh review`（優先）+ reviewer agent（フォールバック）を維持
- `skills/harness-review/SKILL.md` に役割分担セクションを追加

**ユーザー体験の改善**:
- 今まで: `/ultrareview` の登場で Harness の `/harness-review` との役割が曖昧になっていた
- 今後: `/ultrareview` = 人間の ad-hoc レビュー向け / `/harness-review` = 自動化フロー向け と明確に分離

### 8. Auto Mode 拡大

**付加価値**: `C: opt-in 扱い`（`skills/breezing/SKILL.md` の `--auto-mode` フラグ説明）

CC v2.1.111 で Auto Mode が `--enable-auto-mode` フラグなしでも利用可能になった。

**Harness での活用**:
- `skills/breezing/SKILL.md` の `--auto-mode` オプションは「Harness 側の Auto Mode rollout を明示」する opt-in フラグとして説明を維持
- CC 本体での Auto Mode 拡大は自動的に継承されるが、Harness の `bypassPermissions` ベースの実装と混在しないよう注意
- operator entrypoint としての `--auto-mode` は呼び出し側が選ぶ設計を維持。agent 定義側に `autoMode` 値は書かない

**ユーザー体験の改善**:
- 今まで: Auto Mode には `--enable-auto-mode` フラグが必要で、Breezing との組み合わせが複雑だった
- 今後: CC 本体で Auto Mode が常設化されたが、Harness では `--auto-mode` を明示 opt-in として扱い続けることで予測可能な挙動を維持

## Phase 65 (cognitive-load 3 surface) — 2026-05-09 〜 2026-05-10

| Feature | Skill / Component | Purpose | 付加価値 |
|---------|-------------------|---------|---------|
| Plan Brief HTML (1st surface) | `harness-plan-brief` | 着工前の Claude 理解・選択肢・リスク・受け入れ条件・確信度を 1 枚 HTML で施主に承認確認 | A: 実装あり (Phase 65.1) |
| Acceptance Demo HTML (2nd surface) | `harness-accept` | 引き渡し時の ship/wait/reject 判定 + 受け入れ条件検証 + 過去問題パターン表示 | A: 実装あり (Phase 65.2) |
| Progress Tracker HTML (3rd surface) | `harness-progress` | 進捗 % + WIP/TODO/完了一覧 + 5 種 drift alert + PostToolUse 自動再生成 (60s rate limit) | A: 実装あり (Phase 65.4) |
| 3-Layer Redaction | `redact-by-{dictionary,ner}.sh` + `final-scan-redaction.py` + `render-html.sh --with-redaction` | Layer 2a 辞書 + 2b NER (fugashi) + 3 final scan で固有名詞 leakage を 3 層防御 | A: 実装あり (Phase 65.3) |
| Cross-Project Group | `cross-project-groups.yaml` + `load-cross-project-groups.sh` | 横断検索の opt-in グループ定義 (default OFF) | A: 実装あり (Phase 65.3.1) |
| Cross-Project Audit Log | `cross-project-audit-log.sh` | 横断検索 1 回ごとに 1 行 JSON Lines (privacy: query_hash のみ) | A: 実装あり (Phase 65.3.6) |
| Audit-trail UI | 3 HTML templates 共通追加 | 各 surface 末尾「🔍 この artifact の根拠」セクション (検索範囲 / 参照 ID / redact 件数 / log link) | A: 実装あり (Phase 65.5.2) |
| user_request_hash join | `personal-preference.v1` + `acceptance-decision.v1` の sha256 fields | Plan Brief ↔ Acceptance を同 hash で graph join 可能に | A: 実装あり (Phase 65.1.4 / 65.2.3) |

**ユーザー体験の改善**:
- 今まで: Plans.md (200 行) + git log を読まないと進捗・判断根拠が見えなかった。エンジニアじゃない発注者は完全にブラックボックス
- 今後: ブラウザで 1 枚 HTML を開けば 3 秒で「何を作る予定か (Plan Brief) / 今どこか (Progress) / 受け取れるか (Acceptance)」が判断できる
- 横断検索を有効化しても 3 層 redaction で他プロジェクトの固有名詞は漏れない (fail-safe)
- 詳細: [cognitive-load-surfaces.md](./cognitive-load-surfaces.md) / [cross-project-safety.md](./cross-project-safety.md)

## 関連ドキュメント

- [CLAUDE.md](../CLAUDE.md) - 開発ガイド（Feature Table の要約版）
- [CLAUDE-skill-catalog.md](./CLAUDE-skill-catalog.md) - スキルカタログ
- [CLAUDE-commands.md](./CLAUDE-commands.md) - コマンドリファレンス
- [ARCHITECTURE.md](./ARCHITECTURE.md) - アーキテクチャ概要
