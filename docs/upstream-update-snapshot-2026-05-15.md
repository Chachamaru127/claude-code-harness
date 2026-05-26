# Claude Code upstream snapshot - 2026-05-15

This snapshot confirms **`2.1.133`-`2.1.142`** (10 versions in total) published after
`2.1.112`-`2.1.132` already tracked in Phase 62, as Phase 69,
and records the implementation as Harness Tier 1 (5 items) + Tier 2 (5 items).

Confirmed on:

- 2026-05-15 (Asia/Tokyo)

Local verification:

- `claude --version`: `2.1.142 (Claude Code)` (expected)
- (CHANGELOG confirmed from official GitHub source)

Existing Harness tracking baseline:

- Claude Code `2.1.112`-`2.1.132` (Phase 62, `docs/upstream-update-snapshot-2026-05-07.md`)

Primary sources:

- Claude Code GitHub CHANGELOG: <https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md>
- Claude Code docs CHANGELOG: <https://code.claude.com/docs/en/changelog>

Classifications:

- `A: Validation strengthening`: Fixed in current Phase 69 via snapshot / Feature Table / CHANGELOG / tests / implementation.
- `C: Automatic inheritance`: Receive Claude Code core fixes as-is. Do not overlay Harness wrappers.
- `P: Plans`: Has value for Harness, but do not implement at runtime in this snapshot; cut into follow-up tasks.
- `B: Documentation-only`: **0 items** (this snapshot does not create `B`). All classified as `A` / `C` / `P`.

## Version-by-version breakdown

| Version | Upstream item | How it improves | Category | Harness surface | Harness action |
|---------|---------------|-----------------|----------|-----------------|----------------|
| Claude Code `2.1.133` | `worktree.baseRef` setting (`fresh` \| `head`) | Can explicitly set the starting point for `--worktree` / `EnterWorktree` / agent-isolation worktrees | A | `templates/claude/settings.security.json.template` (`.claude-plugin/settings.json` is self-protect deny, so operator applies manually) | Phase 69.1.1: specify `fresh` as baseline in template. Fix base ref for breezing / Worker isolation at `origin/<default>` and present `head` as opt-in for teams that want to carry unpushed commits into new worktrees. Plugin's `.claude-plugin/settings.json` cannot be rewritten by agents due to self-write deny in CLAUDE.md Permission Boundaries, so operator merges manually at release |
| Claude Code `2.1.133` | `sandbox.bwrapPath` / `sandbox.socatPath` managed settings | Can specify the bwrap/socat binary explicitly on Linux/WSL | C | sandbox runtime | Harness holds no fixed values. Rely on CC core resolution logic |
| Claude Code `2.1.133` | `parentSettingsBehavior` admin-tier key | Can opt in to policy merge in SDK `managedSettings` | P | docs (admin governance) | Harness for individual developers does not force merge. Document when enterprise context arises |
| Claude Code `2.1.133` | Hooks receive `effort.level` JSON + `$CLAUDE_EFFORT` env | Hook can branch based on current effort | A | `scripts/hook-handlers/*.sh`, `.claude/rules/hooks-2.1.139-plus.md` | Phase 69.1.2: document `$CLAUDE_EFFORT` as an opt-in branching axis in rules. Unify the premise that any hook can reference it and `$CLAUDE_EFFORT` is also referenceable from Bash |
| Claude Code `2.1.133` | parallel sessions credential race / `Edit`/`Write` allow-rule on drive root / `--add-dir` mapped drives etc. | Runtime bug fix | C | runtime | Auto-inherit |
| Claude Code `2.1.133` | `/effort` cross-session leak fix | Effort becomes independent between sessions | C | runtime | Auto-inherit |
| Claude Code `2.1.133` | Subagents skill not found fix / `claude --help` `--remote-control` addition | Runtime fix | C | runtime | Auto-inherit |
| Claude Code `2.1.134` | (no changelog entries) | --- | C | --- | Auto-inherit |
| Claude Code `2.1.135` | (no changelog entries) | --- | C | --- | Auto-inherit |
| Claude Code `2.1.136` | `settings.autoMode.hard_deny` unconditional block rule | Auto Mode classifier can handle "always deny regardless of approval intent" | A | `templates/claude/settings.security.json.template` (`.claude-plugin/settings.json` is self-protect deny, so operator applies manually) | Phase 69.1.3: specify baseline 7 items (`Bash(sudo:*)` / `Bash(rm -rf:*)` / `Bash(rm -fr:*)` / `Bash(git push -f:*)` / `Bash(git push --force:*)` / `Bash(git reset --hard:*)` / `mcp__codex__*`) as hard_deny in template. Operator merges `.claude-plugin/settings.json` manually at release |
| Claude Code `2.1.136` | `CLAUDE_CODE_ENABLE_FEEDBACK_SURVEY_FOR_OTEL` | Feedback collection via OTel | C | OTel | Harness does not force OTel pipeline. Enterprise opt-in is interpreted by CC core |
| Claude Code `2.1.136` | MCP server `/clear` missing fix / OAuth refresh race fix / extended thinking redaction 400 fix | Runtime stabilization | C | MCP / auth | Auto-inherit |
| Claude Code `2.1.136` | `--resume`/`--continue` underscore path / plan mode `Edit(...)` allow obstruction / WSL2 image paste / `SessionStart` `CLAUDE_ENV_FILE` re-injection | Runtime fix | C | runtime | Auto-inherit |
| Claude Code `2.1.136` | Visual consistency (slash dialog unification, markdown color, CJK ellipsis, jump-to-bottom artifact, etc.) | UX improvement | C | UX | Auto-inherit |
| Claude Code `2.1.137` | VSCode extension activation Windows fix | Runtime | C | IDE | Auto-inherit |
| Claude Code `2.1.138` | Internal fixes | Runtime | C | runtime | Auto-inherit |
| Claude Code `2.1.139` | Agent view (`claude agents`) Research Preview | Can monitor all CC sessions in one screen | A | `agents/worker.md`, `agents/team-composition.md`, `docs/agent-view-policy.md` | Phase 69.2.2: policy `claude agents` as a 1st-class operator entrypoint independent from breezing teammates. Harness internal spawning remains Lead-only |
| Claude Code `2.1.139` | `/goal` command | Completion condition persists across turns | A | `docs/codex-plugin-workflows-policy.md`, `skills/harness-plan/SKILL.md`, `skills/harness-work/SKILL.md` | Phase 69.2.1: same as Codex `/goal`, CC native `/goal` **limited to session continuation memo use**. `Plans.md` / DoD remains the single task SSOT. Add grep gate to rules to prevent `/goal` and Plans.md duplication |
| Claude Code `2.1.139` | `/scroll-speed` | Mouse wheel UX | C | UX | Auto-inherit |
| Claude Code `2.1.139` | `claude plugin details <name>` | Visualize plugin component breakdown and token cost | A | `scripts/ci/check-consistency.sh`, `docs/plugin-managed-settings-policy.md` | Phase 69.2.4: position `claude plugin details` output as supplementary information for `bin/harness doctor` / consistency check, and document response steps when token cost exceeds session budget threshold for a single plugin |
| Claude Code `2.1.139` | Transcript view navigation (`?`, `{`/`}`, `v`) | UX | C | UX | Auto-inherit |
| Claude Code `2.1.139` | Hook `args: string[]` (exec form) | Can spawn command directly without going through shell | A | `.claude/rules/hooks-2.1.139-plus.md` | Phase 69.1.4: codify exec form usage conditions in rules: prioritize exec form for hooks containing path placeholders; maintain existing `type: "command"` only when shell metacharacter expansion is needed |
| Claude Code `2.1.139` | Hook `continueOnBlock` for PostToolUse | Can return hook rejection reason to Claude and continue the turn | A | `.claude/rules/hooks-2.1.139-plus.md` | Phase 69.1.4: add rule limiting `continueOnBlock` to "safe diagnostic feedback" use cases. Maintain `continueOnBlock: false` for mandatory-deny guard rails (R01-R13) |
| Claude Code `2.1.139` | MCP stdio receives `CLAUDE_PROJECT_DIR` | MCP server can resolve project dir | C | MCP | Auto-inherit |
| Claude Code `2.1.139` | Compaction prompt retains user instructions | Rules during session less likely to be lost on compaction | C | compaction | Auto-inherit |
| Claude Code `2.1.139` | `x-claude-code-agent-id` / `parent-agent-id` headers + OTEL `agent_id` attrs | Subagent observability improves | C | OTel/telemetry | Auto-inherit |
| Claude Code `2.1.139` | `ANTHROPIC_API_KEY` set disables Remote Control etc. | Enterprise auth boundary becomes clear | C | auth | Auto-inherit |
| Claude Code `2.1.139` | hook writing to terminal causes prompt corruption → no terminal access | Hook stabilization | C | runtime | Auto-inherit |
| Claude Code `2.1.139` | `Skill(name *)` wildcard prefix match | Permission rule expressive power | C | permission | Auto-inherit |
| Claude Code `2.1.140` | `subagent_type` case-/separator-insensitive matching | Resilience to agent name notation variation | C | agent | Auto-inherit |
| Claude Code `2.1.140` | Updated agent color palette | UX | C | UX | Auto-inherit |
| Claude Code `2.1.140` | `/goal` silent hang fix on `disableAllHooks` | Runtime fix | C | runtime | Auto-inherit |
| Claude Code `2.1.140` | Settings hot-reload symlink fix / `/loop` redundant wakeups / Windows where.exe stall | Runtime fix | C | runtime | Auto-inherit |
| Claude Code `2.1.140` | Plugins warn when default folder silently ignored | Plugin lifecycle visibility | C | plugin | Auto-inherit |
| Claude Code `2.1.141` | `terminalSequence` field for hook JSON output | Hook can fire desktop notifications / window title / bell without controlling terminal | A | `scripts/hook-handlers/webhook-notify.sh`, `scripts/hook-handlers/notification-handler.sh`, `.claude/rules/hooks-2.1.139-plus.md` | Phase 69.1.5: implement `HARNESS_TERMINAL_NOTIFY` env (0/1/`bell`/`title`/`osc9`) opt-in so `task-completed`-type hooks can produce local notifications without an external webhook |
| Claude Code `2.1.141` | `CLAUDE_CODE_PLUGIN_PREFER_HTTPS` | Plugin clone possible without SSH key | C | plugin | Auto-inherit |
| Claude Code `2.1.141` | `ANTHROPIC_WORKSPACE_ID` (workload identity federation) | Token scoping | P | enterprise auth | Document via `docs/plugin-managed-settings-policy.md` if enterprise context arises |
| Claude Code `2.1.141` | `claude agents --cwd <path>` | Can scope session list to a directory | A | `docs/agent-view-policy.md` | Bundled with Phase 69.2.2: document operations to isolate agent view per project |
| Claude Code `2.1.141` | `/feedback` includes recent sessions | Cross-session bug reporting | C | feedback | Auto-inherit |
| Claude Code `2.1.141` | Rewind "Summarize up to here" | Context compression intermediate state preservation | C | session | Auto-inherit (consistent with `/undo` policy in `.claude/rules/commit-safety.md`) |
| Claude Code `2.1.141` | Auto mode dialog explains `permissions.ask` origin | Permission UX | C | permission | Auto-inherit |
| Claude Code `2.1.141` | IDE diff view restore on file-edit permission prompt | IDE | C | IDE | Auto-inherit |
| Claude Code `2.1.141` | Background agents preserve permission mode | Agent started with `/bg` / `←←` does not revert to default | A | `agents/worker.md`, `agents/team-composition.md`, `docs/agent-view-policy.md` | Phase 69.2.3: explicitly state expected permission mode for breezing teammates / Worker isolation worktrees |
| Claude Code `2.1.141` | `claude agents` Completed state for background-shell-leaking sessions | Agent view display | C | agent | Auto-inherit |
| Claude Code `2.1.141` | Spinner 10s amber warm-up / plugin menu nav / many hooks / MCP / Remote Control / SDK / Bedrock / VSCode fixes | Runtime fix | C | runtime | Auto-inherit |
| Claude Code `2.1.141` | hooks `transcript_path` invalidation fix after `EnterWorktree` | Runtime fix | C | hook | Auto-inherit (confirmed that Harness has no places that trust `transcript_path`) |
| Claude Code `2.1.142` | `claude agents` new flags (`--add-dir`, `--settings`, `--mcp-config`, `--plugin-dir`, `--permission-mode`, `--model`, `--effort`, `--dangerously-skip-permissions`) | Dispatched background session configuration becomes declarative | A | `docs/agent-view-policy.md`, `agents/team-composition.md` | Bundled with Phase 69.2.2: codify usage conditions for each flag and conflicts with Harness deny rules (e.g., `--dangerously-skip-permissions` should not be used on protected branches) in rules |
| Claude Code `2.1.142` | Fast mode Opus 4.7 default + `CLAUDE_CODE_OPUS_4_6_FAST_MODE_OVERRIDE` | Fast mode always runs on Opus 4.7 | C | model | Auto-inherit (Harness already treats Opus 4.7 as default; no Harness-side changes needed) |
| Claude Code `2.1.142` | Plugins with root-level `SKILL.md` and no `skills/` subdir surfaced | Single-SKILL plugins are recognized | C | plugin | Auto-inherit (Harness uses `skills/` as SSOT; no impact) |
| Claude Code `2.1.142` | `/plugin` details + `claude plugin details` now show LSP servers | LSP visibility | C | plugin | Auto-inherit |
| Claude Code `2.1.142` | `/web-setup` warns before replacing GitHub App connection | Safety | C | web setup | Auto-inherit |
| Claude Code `2.1.142` | `MCP_TOOL_TIMEOUT` raises per-request fetch timeout for HTTP/SSE | MCP long-running calls work | C | MCP | Auto-inherit |
| Claude Code `2.1.142` | Background sessions recognize pre-existing worktrees / macOS sleep/wake / daemon binary upgrade cleanup / Chrome extension shim, many other fixes | Runtime stabilization | C | runtime | Auto-inherit |
| Claude Code `2.1.142` | Hook config error: prompt/agent type hooks cause errors on SessionStart/Setup/SubagentStart | Hook config errors detected early | A | `.claude/rules/hooks-2.1.139-plus.md` | Same rule as Phase 69.1.4: explicitly state "SessionStart/Setup/SubagentStart are command type only" and make Harness hooks.json corresponding sections grep-able |
| Claude Code `2.1.142` | Improved reactive compaction (first summarize seeds from overflow size) | Compaction efficiency | C | session | Auto-inherit |
| Claude Code `2.1.142` | Removed stale `/model claude-sonnet-4-20250514` suggestion | UX | C | runtime | Auto-inherit |

---

## Tier 1 (Phase 69.1.1-69.1.5) - Directly update settings / hooks / rules

| ID | Phase | Content | Primary artifact |
|----|-------|---------|-----------------|
| 69.1.1 | settings | Explicitly specify `worktree.baseRef: "fresh"` in `templates/claude/settings.security.json.template` (plugin settings applied manually by operator) | `templates/claude/settings.security.json.template` |
| 69.1.2 | hooks | Document the reference policy for `effort.level` JSON + `$CLAUDE_EFFORT` env in rules | `.claude/rules/hooks-2.1.139-plus.md` |
| 69.1.3 | settings | Add baseline 7 items for `autoMode.hard_deny` to template baseline (plugin settings applied manually by operator) | `templates/claude/settings.security.json.template` |
| 69.1.4 | hooks | Codify hook `args:` exec form / `continueOnBlock` / `SessionStart`/`Setup`/`SubagentStart` command-only constraint into rules | `.claude/rules/hooks-2.1.139-plus.md` |
| 69.1.5 | hooks | Implement `terminalSequence` opt-in in `webhook-notify.sh` / `notification-handler.sh` (`HARNESS_TERMINAL_NOTIFY`) | `scripts/hook-handlers/webhook-notify.sh`, `scripts/hook-handlers/notification-handler.sh` |

## Tier 2 (Phase 69.2.1-69.2.5) - Update policy / docs / agent contract

| ID | Phase | Content | Primary artifact |
|----|-------|---------|-----------------|
| 69.2.1 | docs | Policy CC native `/goal` as "session continuation memo only" (same policy as Codex `/goal`) | `docs/codex-plugin-workflows-policy.md` (rename or augment) |
| 69.2.2 | docs | Harness safe operation policy for `claude agents` operator entrypoint + new flags | `docs/agent-view-policy.md` (new) |
| 69.2.3 | agent | Explicitly state expected values for background agent permission mode preservation in Worker / team composition | `agents/worker.md`, `agents/team-composition.md` |
| 69.2.4 | ci | Add usage examples for `claude plugin details` output to `scripts/ci/check-consistency.sh` notes | `scripts/ci/check-consistency.sh` |
| 69.2.5 | rules | Create Phase 69 rule SSOT and add to `opus-4-7-prompt-audit.md` checklist | `.claude/rules/hooks-2.1.139-plus.md` |

## Test additions / expectations

| Test | Location | Expectation |
|------|----------|-------------|
| settings baseline | Section 4 (settings) of `tests/validate-plugin.sh` | Assert presence of `worktree.baseRef` and `autoMode.hard_deny` |
| hook terminalSequence | `tests/test-terminal-notify.sh` (new) | `HARNESS_TERMINAL_NOTIFY=osc9` outputs `terminalSequence` field |
| rule grep gate | `tests/test-rule-presence.sh` (new or existing extend) | 5 required anchors in `.claude/rules/hooks-2.1.139-plus.md` exist |
| `/goal` SSOT gate | `tests/test-rule-presence.sh` | `docs/codex-plugin-workflows-policy.md` or equivalent doc contains "do not use `/goal` (CC native) for Plans.md SSOT" |

## Rollback notes

- `worktree.baseRef: "fresh"` matches CC 2.1.133's default. Teams that want `head` override with project-level settings.
- `autoMode.hard_deny` baseline is **required core 7 items only** — not a superset of existing `permissions.deny`. Projects that don't use auto mode see no impact.
- `HARNESS_TERMINAL_NOTIFY` is disabled when unset. Independent from existing `HARNESS_WEBHOOK_URL`.
- `.claude/rules/hooks-2.1.139-plus.md` is a new rule. No changes to existing rules (orthogonal addition).

## Operator action item (.claude-plugin/settings.json manual application)

Due to Harness self-write guardrail (`.claude/rules/self-audit.md`, CLAUDE.md Permission Boundaries),
the plugin's `.claude-plugin/settings.json` cannot be rewritten by agents.
The operator manually adds the following block at release time:

```json
"worktree": {
  "baseRef": "fresh"
},
"autoMode": {
  "hard_deny": [
    "Bash(sudo:*)",
    "Bash(rm -rf:*)",
    "Bash(rm -fr:*)",
    "Bash(git push -f:*)",
    "Bash(git push --force:*)",
    "Bash(git reset --hard:*)",
    "mcp__codex__*"
  ]
}
```

The template (`templates/claude/settings.security.json.template`) already has this written as a baseline.
When the template is expanded into a project during new project setup with `harness setup`, it is automatically applied.

## Related docs

- `docs/upstream-update-snapshot-2026-05-07.md` (Phase 62, 2.1.112-2.1.132)
- `docs/upstream-update-snapshot-2026-05-10.md` (Phase 67, Codex 0.130.0)
- `.claude/rules/hooks-2.1.139-plus.md` (newly created in Phase 69)
- `docs/agent-view-policy.md` (newly created in Phase 69)
- `.claude/rules/cc-update-policy.md` (SSOT for 3-category classification)
