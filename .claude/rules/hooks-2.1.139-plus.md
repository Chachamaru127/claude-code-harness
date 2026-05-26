# Hooks (Claude Code 2.1.133+) Rules

The SSOT for how Harness handles the additions to hook behavior introduced in CC `2.1.133`-`2.1.142`:
`$CLAUDE_EFFORT` env / `effort.level` JSON input, exec form (`args: string[]`), `continueOnBlock`,
`terminalSequence`, and the command-only constraint for SessionStart/Setup/SubagentStart.

This rule was introduced in Phase 69 (`docs/upstream-update-snapshot-2026-05-15.md`).
It is orthogonal to the existing rules (`opus-4-7-prompt-audit.md`, `skill-editing.md`, `commit-safety.md`)
and must be consulted whenever designing hooks.

## 1. `$CLAUDE_EFFORT` env / `effort.level` JSON Input

### Behavior (2.1.133+)

- All hooks' stdin JSON includes `effort: { level: "low" | "medium" | "high" }`.
- All hook subprocesses have the `$CLAUDE_EFFORT` environment variable exported.
- Subprocesses launched by the Bash tool also inherit `$CLAUDE_EFFORT`.

### Harness Usage Conditions

- Cases where a hook handler may vary behavior based on effort:
  - **Observation only**: Include effort in logs (e.g., jsonl recording in `notification-handler.sh`).
  - **Opt-in intensity switching**: Do not degrade the same rule based on effort.
    Example: running additional lint only at `high` is **prohibited**. The same rule must be maintained at `medium` as well.
- Prohibited:
  - Hooks that downgrade deny → ask based on effort (`pre-tool` rules R01-R13 and other guardrails apply regardless of effort).
  - Silent fallback to a different effort level's behavior when the effort string is empty (treat empty as "no effort information").

### Usage in Bash

- `"${CLAUDE_EFFORT:-unset}"` may be referenced within a hook's `command`.
- Validate the value (`low`/`medium`/`high`) on the calling side before branching behavior.

## 2. Hook exec form (`args: string[]`) (2.1.139+)

### Behavior

CC 2.1.139 added an exec form using `args: string[]` to hook definitions.
Because it spawns directly without going through a shell, path placeholders (e.g., `${CLAUDE_PROJECT_DIR}/scripts/foo.sh`)
can be passed without quoting.

```json
{
  "type": "command",
  "args": ["${CLAUDE_PROJECT_DIR}/scripts/hook-handlers/notification-handler.sh", "${event}"]
}
```

### Harness Usage Conditions (adoption criteria)

| Case | Recommended form | Reason |
|--------|-----------|------|
| Only simple expansion of `${CLAUDE_PROJECT_DIR}` / `${CLAUDE_PLUGIN_DATA}` | exec form (`args`) | Eliminates shell injection from quoting mistakes |
| Multiple commands need to be chained via `bash -c` | Existing `command` (shell form) | Required for `&&` / OR-shell / pipe / heredoc |
| Shell control flow like `if`/`for` is needed | Existing `command` (shell form) | Same reason |
| User input containing spaces or env var expansion (`$VAR`) in arguments | exec form (`args`) | Prevents shell injection |

### Migration Procedure (optional / incremental)

1. Prefer exec form when adding new hooks.
2. When rewriting an existing hook's `command` to exec form, verify whether the shell-via wrapper like `bash -c '...' _` can be dismantled. Leave it in place if shell control is needed for things like `valid_root` checks.
3. Verify behavioral differences of the migrated hook (env var expansion, PATH resolution, signal handling) with `tests/test-hooks-*.sh` before merging.

## 3. `PostToolUse.continueOnBlock` (2.1.139+)

### Behavior

When `continueOnBlock: true` is set in a PostToolUse hook, if the hook returns `permissionDecision: "deny"`,
the rejection reason is fed back to Claude and the turn can continue to retry.
The default is `false` (= turn stops, as before).

### Harness Usage Conditions

- **Cases where `continueOnBlock: true` is permitted**: "diagnostic feedback" use cases only.
  Example: lint hook feeds back "trailing whitespace found" → Claude retries with a fix.
- **Cases where `continueOnBlock: false` is required**:
  - **R01-R13 guardrails**: writing to protected paths, `git push --force`, `rm -rf`, etc.
    Deny is to prevent irreversible operations; Claude must not be allowed to retry.
  - **Secret detection**: denying changes that contain credentials. Retry risk of leakage remains.
  - **Policy violation**: rewriting protected configs like `.eslintrc*`.

### Implementation

When adding a new `PostToolUse` hook in `.claude-plugin/hooks.json`,
explicitly state `continueOnBlock` (do not rely on the default).

```json
{
  "matcher": "Write|Edit",
  "hooks": [
    { "type": "command", "command": "...", "continueOnBlock": false }
  ]
}
```

## 4. `terminalSequence` output field (2.1.141+)

### Behavior

Including `terminalSequence` in a hook's stdout JSON allows Claude Code to fire
desktop notifications / window title updates / bell sounds even when it does not have a
controlling terminal (background session, `--bg`).

The payload is an OSC (Operating System Command) sequence of
**ESC (0x1B) + `]` + number + `;` + content + BEL (0x07)**.
Use unicode escape (`` / ``) in JSON:

```json
{
  "decision": "approve",
  "terminalSequence": "]9;Build complete"
}
```

Common OSC sequences (`<ESC>` = 0x1B = ``, `<BEL>` = 0x07 = ``):

- `OSC 9`: `<ESC>]9;<text><BEL>` — macOS Terminal / iTerm notification (popup)
- `OSC 0`: `<ESC>]0;<title><BEL>` — window title
- `OSC 2`: `<ESC>]2;<title><BEL>` — window title (alternative notation)
- `OSC 777;notify`: `<ESC>]777;notify;<title>;<body><BEL>` — KDE/GNOME desktop notification
- `BEL` alone: `<BEL>` (0x07) — terminal bell only

### Harness Usage Conditions

- **Always opt-in**: Hook handlers must not output `terminalSequence` if the `HARNESS_TERMINAL_NOTIFY` env is not set.
  - `unset` / `0`: do not output (default)
  - `1` / `bell`: BEL only
  - `title`: window title update only
  - `osc9`: OSC 9 popup notification
  - `notify`: OSC 777 (Linux desktop notification)
- **Payload constraints**: The payload of `terminalSequence` is limited to ASCII characters + printable unicode.
  Do not include control characters other than the bell character (``) and the OSC terminator (prevents terminal corruption).
- **Do not include secrets**: Apply redact rules (`.claude/rules/cross-repo-handoff.md` Layer 2/3) before transcribing hook payload (e.g., PR title) into `terminalSequence`.

### Standard Implementation Helpers

**Runtime (Go binary)**:
- `go/internal/hookhandler/terminal_notify.go` — `BuildTerminalSequence` / `AugmentWithTerminalSequence`
- `go/internal/hookhandler/notification_handler.go` (Notification hook) — reads `HARNESS_TERMINAL_NOTIFY` and emits for the known 4 types (`permission_prompt` / `elicitation_dialog` / `idle_prompt` / `auth_success`)
- `go/internal/hookhandler/task_completed.go` (TaskCompleted hook) — attaches `terminalSequence` to all response paths

**Shell reference implementations**:
- `scripts/hook-handlers/webhook-notify.sh`
- `scripts/hook-handlers/notification-handler.sh`
- `scripts/lib/terminal-notify.sh`

The runtime launches the Go binary via `bin/harness hook ...` from `.claude-plugin/hooks.json`,
so actual `terminalSequence` output is handled by the Go implementation. The shell version is
maintained as a reference for when it is cited in Plans.md SSOT or operational docs.

## 5. SessionStart / Setup / SubagentStart Are Limited to command-type (2.1.142+)

### Behavior

Starting with CC 2.1.142, specifying `type: "prompt"` or `type: "agent"` for
`SessionStart` / `Setup` / `SubagentStart` hooks produces a "use a command-type hook instead" error at startup.

Reason: These hooks run during the session bootstrap phase, and the latency and
permission propagation of LLM-type hooks (prompt/agent) cannot be accommodated.

### Harness Usage Conditions

- **Hooks under `Setup`/`SessionStart`/`SubagentStart` matchers in `.claude-plugin/hooks.json` must always use `type: "command"`**.
- No exceptions. If LLM judgment is needed, handle it in `PreToolUse`.
- When editing existing `hooks.json`, verify with `grep -nE '"SessionStart"|"Setup"|"SubagentStart"' .claude-plugin/hooks.json` and confirm the `type:` value is `"command"`.

### CI gate

This constraint is enforced as a grep gate in `tests/validate-plugin.sh` (an extension of Section 4 settings parity).

## 6. Checklist (when adding / editing hooks)

- [ ] If referencing `effort.level` in a hook's input JSON, the fallback when effort is absent is explicitly stated
- [ ] If referencing `$CLAUDE_EFFORT` in a hook subprocess, an empty string is tolerated
- [ ] If the hook uses only path placeholders, exec form (`args`) is preferred
- [ ] `continueOnBlock` is explicitly stated for `PostToolUse` hooks (do not rely on the default)
- [ ] `continueOnBlock: false` is used for guardrails (R01-R13 / secret / protected config)
- [ ] Hooks that use `terminalSequence` are opt-in via the `HARNESS_TERMINAL_NOTIFY` env
- [ ] `terminalSequence` payload contains no secrets / non-printable control characters
- [ ] Hooks under `SessionStart` / `Setup` / `SubagentStart` use `type: "command"` only
- [ ] When changing hook behavior, the relevant section of `tests/validate-plugin.sh` PASS

## 7. Related

- `docs/upstream-update-snapshot-2026-05-15.md` — Phase 69 snapshot (basis for introducing this rule)
- `.claude/rules/opus-4-7-prompt-audit.md` — agent contracts and permission boundaries
- `.claude/rules/skill-editing.md` — skill editing SSOT
- `.claude/rules/commit-safety.md` — `/undo` policy (relationship to rewind compaction)
- `scripts/hook-handlers/webhook-notify.sh` — `terminalSequence` reference implementation
- `scripts/hook-handlers/notification-handler.sh` — `terminalSequence` reference implementation
