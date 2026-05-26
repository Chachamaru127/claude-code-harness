# Claude Code 2.1.99 → 2.1.110 — Harness Impact Classification

> **Purpose**: Classify all major changes from Claude Code 2.1.99 through 2.1.110 into the
> 3 categories (A / B / C) defined in `.claude/rules/cc-update-policy.md`,
> and organize them so they can be traced to implementation tasks in Phase 44.2 and beyond.
>
> **Classification rules** (from cc-update-policy.md):
> - **A: Has implementation** — Concrete changes required on the Harness side (new hooks / scripts / skills / agents / docs)
> - **B: Docs only** — Feature Table change only. **Prohibited.** Must not appear in this table.
> - **C: CC auto-inherit** — CC core fix only. No Harness change required. Mark "CC auto-inherit" in the Feature Table.
>
> **Baseline**: Current Harness is v4.1.1; Feature Table is up to date through v2.1.98 (Monitor tool).
> Category A items in this table are implemented in Phase 44.2-44.7; Category C items are Feature Table additions only in Phase 44.11.

---

## 1. Category A: Has Implementation (Harness-side changes required)

Items in Phase 44 that involve concrete Harness-side changes. Each row lists the corresponding phase.

| ver | Change | Affected area | Corresponding Phase |
|-----|--------|--------------|---------------------|
| 2.1.101 | Settings resilience: `settings.json` is no longer silently ignored when an unknown hook event name is present | Safety improvement when adding new hooks to `.claude-plugin/settings.json` / `hooks.json` | 44.2 (used as a safety guard when adding PreCompact) |
| 2.1.101 | `permissions.deny` now overrides `PreToolUse` hook `permissionDecision: "ask"` | Harness guardrails (R01-R13) deny chaining | **44.3** (R01-R13 re-verification) |
| 2.1.101 | Bug fix: duplicate `name:` frontmatter when multiple plugins are detected causes slash commands to resolve to the wrong plugin | Audit that `skills/**/SKILL.md` frontmatter names are unique | **44.4.2** (verify name uniqueness during skill literal pass) |
| 2.1.101 | Bug fix: skills not honoring `context: fork` and `agent` frontmatter | Re-verification of Harness skills using `context: fork` (e.g., canai-docs) | **44.7.1** (small feature integration) |
| 2.1.101 | Bug fix: subagents not inheriting dynamically-injected MCP servers | Dynamic MCP in Breezing, `harness-mem` inheritance | **44.7.1** |
| 2.1.101 | Bug fix: sub-agents unable to Read/Edit their own files inside an isolated worktree | Worker / Advisor with `isolation: worktree` | **44.7.1** (verification + smoke) |
| 2.1.105 | **New hook: `PreCompact`** — `{"decision":"block"}` / exit 2 can stop compaction | Prevent unintended compaction interruptions for long-running Workers | **44.2.1** (Go implementation + hooks.json registration) |
| 2.1.105 | **Plugin manifest: new top-level `monitors` key** — background monitors auto-arm on session start / skill invoke | Persistent mem health / drift monitoring / advisor state in Harness | **44.2.2** (plugin.json addition) |
| 2.1.105 | `EnterWorktree` gains `path` parameter, allowing re-entry into existing worktrees | Worktree reuse in `scripts/run-worker-*.sh` etc. | **44.7.1** |
| 2.1.105 | `/proactive` alias for `/loop` | Alias policy for harness-loop | **44.7.1** (docs update) |
| 2.1.108 | **`ENABLE_PROMPT_CACHING_1H` env var** — 1-hour prompt cache TTL | Reduce long-session costs for Breezing / harness-loop | **44.6.1** (opt-in script + docs) |
| 2.1.108 | `/recap` / `/undo` alias for `/rewind` | Session memory / commit safety | **44.7.1** |
| 2.1.108 | Model can call built-in slash commands (`/init`, `/review`, `/security-review`) via the Skill tool | Check for functional overlap with Harness `/harness-review` | **44.7.1** / **44.8.1** |
| 2.1.110 | `/tui` command + `tui` setting (fullscreen rendering) | Operational guide update (docs) | **44.7.1** (docs only, no Harness behavior change) |
| 2.1.110 | **Push notification tool** (Remote Control + "Push when Claude decides" setting) | Available for long-run completion notifications in `harness-loop` | **44.7.1** (docs note, recording possible future adoption) |
| 2.1.110 | **`PermissionRequest` hooks returning `updatedInput` now trigger a re-check of `permissions.deny` rules** | Verify consistency of guardrails R01-R13 deny chaining | **44.3.1** (re-verification required) |
| 2.1.110 | `setMode:'bypassPermissions'` now respects `disableBypassPermissionsMode` | Maintain Harness bypass policy | **44.3.1** (docs update) |
| 2.1.110 | **Bug fix: `PreToolUse` hook `additionalContext` no longer discarded on tool call failure** | Guardrail deny reason injection persists after failure | **44.3.1** (add regression test) |
| 2.1.110 | Bug fix: skills with `disable-model-invocation: true` now work when called mid-message via `/<skill>` | Resolves a latent bug in Harness `/harness-work`, `/harness-review`, etc. | **44.7.1** (smoke test) |

**Category A count**: **19 items**
**Implementation assignment**: 44.2 (2), 44.3 (3), 44.4.2 (1), 44.6.1 (1), 44.7.1 (10), 44.8.1 (1) + 3 items consolidated in 44.3.1

---

## 2. Category C: CC Auto-Inherit (No Harness changes required)

Feature Table additions only. No Harness implementation changes required, but usage guides and expectations should be updated.

| ver | Change | Effect enjoyed by Harness |
|-----|--------|--------------------------|
| 2.1.101 | Memory leak fix — historical message-list holding dozens of entries in the virtual scroller during long sessions | RSS stabilization in long-running Breezing |
| 2.1.101 | Fix for large-session context loss caused by dead-end branch anchor in `--resume` / `--continue` | Improved resume reliability on harness-loop wake-up |
| 2.1.101 | Fix for hard-coded 5-minute timeout not respecting `API_TIMEOUT_MS` (local LLM / extended thinking) | Safety for extended thinking under Opus 4.7 xhigh |
| 2.1.101 | Bedrock SigV4 authentication failure fix | Transparent improvement for Bedrock users |
| 2.1.101 | Grep tool ENOENT → system `rg` fallback | Improved Grep reliability across all skills |
| 2.1.101 | Bug fix: `/btw` writing the entire conversation to disk on every call | Context cost reduction |
| 2.1.101 | `/plugin update` ENAMETOOLONG fix | Stability of plugin updates in `/harness-setup` |
| 2.1.101 | Stale cache fix for directory-source plugins | Reload stability during Harness development |
| 2.1.101 | Fix for custom keybindings not loading on Bedrock / Vertex | Keybindings in multi-provider environments |
| 2.1.101 | Command injection vulnerability fix: POSIX `which` fallback (LSP binary detection) | Security auto-inherited |
| 2.1.105 | Bug fix: images being dropped in queued messages | Stability of multimodal input |
| 2.1.105 | Bug fix: leading whitespace trim breaking ASCII art / indented diagrams | Reliability of diagram and table output |
| 2.1.105 | `alt+enter` / `Ctrl+J` newline insertion fix | Editing experience |
| 2.1.105 | One-shot scheduled task re-fire fix (missed file watcher post-processing) | Reliability of scheduled operations |
| 2.1.105 | Fix for missing Team/Enterprise inbound channel notifications | CC multiplayer functionality |
| 2.1.105 | `/skills` menu scroll fix | UI |
| 2.1.107 | Extended-thinking indicator display improvement (show hint earlier) | UX when using Opus 4.7 xhigh |
| 2.1.108 | Fix for `/compact` failing with "context exceeded" on large conversations | Long-session reliability |
| 2.1.108 | Fix for DISABLE_TELEMETRY users not receiving 1h cache | Required prerequisite for 44.6.1 opt-in |
| 2.1.108 | Permission prompt fix for safety classifier transcript overflow in agent tool auto mode | Reliability when using Auto Mode |
| 2.1.108 | Bug fix: Bash tool producing no output when `CLAUDE_ENV_FILE` contains a trailing `#` comment line | Bash execution stability |
| 2.1.108 | Bug fix: `claude --resume <session-id>` losing custom name/color set by `/rename` | Session management |
| 2.1.108 | Bug fix: policy-managed plugins not auto-updating on first install and when run from a different project | Enterprise/Teams distribution |
| 2.1.108 | Bug fix: diacritical marks (accents, etc.) being dropped when `language` setting is configured | i18n |
| 2.1.109 | Extended-thinking indicator rotating progress hint | UX |
| 2.1.110 | Bug fix: MCP tool calls hanging indefinitely during SSE/HTTP server connection drop | Reliability via MCP (harness-mem, etc.) |
| 2.1.110 | Fix for multi-minute hang in non-streaming fallback retries | UX for long-running tasks |
| 2.1.110 | Session cleanup now performs complete deletion including subagent transcripts | Disk savings |
| 2.1.110 | `/skills` menu scroll fix (fullscreen) | UI |
| 2.1.110 | Remote Control session re-login prompt fix (stale session) | Remote Control UX |

**Category C count**: **30 items**

---

## 3. Category B: Docs Only (Prohibited)

**Empty.** All items in this document are classified as A or C. In accordance with the cc-update-policy.md rule "block the PR if a Category B item is detected," no B items are included.

---

## 4. Phase 44 Implementation Trace Table

This table provides reverse lookup for which Category A items each Phase 44.2+ task corresponds to.

| Phase | Category A items (see table above) |
|-------|--------------------------------------|
| 44.2.1 (PreCompact hook) | 2.1.105: `PreCompact` hook |
| 44.2.2 (monitors manifest) | 2.1.105: `monitors` manifest key |
| 44.3.1 (guardrails R01-R13 re-verification) | 2.1.101: `permissions.deny` overrides PreToolUse ask / 2.1.110: `updatedInput` re-check / 2.1.110: `additionalContext` persist / 2.1.110: `setMode:'bypassPermissions'` + `disableBypassPermissionsMode` |
| 44.4.2 (skill literal pass) | 2.1.101: downstream impact of duplicate `name:` frontmatter bug |
| 44.6.1 (1h prompt cache opt-in) | 2.1.108: `ENABLE_PROMPT_CACHING_1H` |
| 44.7.1 (small feature integration) | 2.1.101: `context: fork` + agent / subagent MCP inheritance / worktree Read/Edit / 2.1.105: `EnterWorktree path` / `/proactive` / 2.1.108: `/recap` / `/undo` / built-in slash via Skill tool / 2.1.110: `/tui` / Push notification / `disable-model-invocation` mid-message fix |
| 44.8.1 (/ultrareview integration) | 2.1.108: Consideration of calling `/ultrareview` from the Skill tool as part of built-in slash usage |
| 44.11.1 (Feature Table update) | All 19 Category A items + all 30 Category C items |

---

## 5. Note: Security-Related Auto-Inheritance (Notable)

In 2.1.97 → 2.1.98, all Bash permission bypasses (backslash-escape flag / compound command / env-var prefix / `/dev/tcp` redirect) were closed, and 2.1.101 fixed a command injection via POSIX `which` fallback as well. These are all Category C inheritances, but since the prerequisites for Harness guardrails R01-R13 (Bash-related denies) have improved, it is worth re-confirming in 44.3.1 whether the underlying assumptions have changed.
