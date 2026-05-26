# Harness v4 Go Rewrite — Specification

> The authoritative reference to keep Phase 35 specifications from drifting. Consult this before implementing, and cross-check against it after implementing.

Last updated: 2026-04-06
CC version confirmed: 2.1.92

> **Internal fork note (v1)**: non-Claude runtime surfaces (Codex, OpenCode, Cursor) are archived for v1.
> Codex/OpenCode/Cursor references below are historical upstream context unless explicitly marked active.

---

## 1. Scope Definition

### What changes

| Target | Before | After |
|------|--------|-------|
| Hook execution path | bash → node → TypeScript | Direct Go binary invocation |
| Config file management | 5-6 files manual sync | harness.toml → `harness sync` auto-generation |
| State management | TypeScript + better-sqlite3 | Go + pure-Go SQLite |
| Scripts | 127 .sh + 7 .js files | Gradually absorbed into Go subcommands |

### What does not change (CC plugin protocol compliance)

| Target | Format | Reason |
|------|------|------|
| `plugin.json` | JSON | CC required |
| `hooks/hooks.json` | JSON | CC required |
| `settings.json` | JSON | CC required |
| `agents/*.md` | YAML frontmatter + Markdown | CC required. Body is Markdown so TOML conversion is inappropriate |
| `skills/*/SKILL.md` | YAML frontmatter + Markdown | CC required |
| `.mcp.json`, `.lsp.json` | JSON | CC required |
| `output-styles/` | Markdown | CC required |

### Incremental migration policy

"Zero-base rewrite" is a design philosophy, not "atomic switch." Migration is done incrementally per hook.

- Each hook has **exactly one authoritative implementation** (Go or shell)
- No fallback is provided (Node.js fallback removed in Phase 35.0)
- Unmigrated hooks remain with shell as the authority
- `harness doctor --migration` detects mixed-mode and warns

---

## 2. Protocol Truth Table

Field-by-field classification based on the official CC hook specification.

### HookInput (stdin JSON)

| Field | Classification | CC Version | Go Type |
|-------|------|-------------|-------|
| `session_id` | documented | - | `string` |
| `transcript_path` | documented | - | `string` |
| `cwd` | documented | - | `string` |
| `permission_mode` | documented | - | `string` |
| `hook_event_name` | documented | - | `string` |
| `tool_name` | documented (required) | - | `string` |
| `tool_input` | documented (required) | - | `map[string]interface{}` |
| `plugin_root` | harness-private | - | `string` |

**Unknown field policy**: Ignored during JSON decoding (default behavior of `json.Decoder`). Not stripped. Does not hard-fail.

### PreToolUse hookSpecificOutput

| Field | Classification | Output condition | Go Type |
|-------|------|---------|-------|
| `hookEventName` | documented | Always `"PreToolUse"` | `string` |
| `permissionDecision` | documented | Always | `"allow"\|"deny"\|"ask"\|"defer"` |
| `permissionDecisionReason` | documented | On deny/ask | `string` |
| `updatedInput` | documented (v2.1.89+) | When input changes | `json.RawMessage` |
| `additionalContext` | documented | On warn | `string` |

**Exit code**: deny → exit 2, others → exit 0

### PostToolUse hookSpecificOutput

| Field | Classification | Output condition | Go Type |
|-------|------|---------|-------|
| `hookEventName` | documented | Always `"PostToolUse"` | `string` |
| `additionalContext` | documented | On warning | `string` |
| `updatedMCPToolOutput` | **experimental (undocumented)** | **Not implemented** | - |

### PermissionRequest hookSpecificOutput

| Field | Classification | Go Type |
|-------|------|-------|
| `hookSpecificOutput.hookEventName` | documented | `"PermissionRequest"` |
| `hookSpecificOutput.decision.behavior` | documented | `"allow"\|"deny"` |
| `hookSpecificOutput.decision.updatedInput` | documented (v2.1.89+) | `map[string]interface{}` |
| `hookSpecificOutput.decision.updatedPermissions` | documented | `[]interface{}` |

Last confirmed: 2026-04-06 (CC v2.1.92, code.claude.com/docs/en/hooks)

---

## 3. Hook Ownership Matrix

| Hook Event | Authority | Phase | Notes |
|-----------|------|-------|------|
| **PreToolUse** (guard) | **Go** | 35.0 ✅ | bin/harness hook pre-tool |
| **PostToolUse** (guard) | **Go** | 35.0 ✅ | bin/harness hook post-tool |
| **PermissionRequest** | **Go** | 35.0 ✅ | bin/harness hook permission |
| SessionStart | shell | 35.3 | session-env-setup + memory-bridge + init |
| SessionEnd | shell | 35.3 | session-cleanup |
| UserPromptSubmit | shell | 35.3 | memory-bridge + policy + tracking |
| PostToolUse (non-guard) | shell | 35.3 | log-toolname, commit-cleanup, track-changes, etc. |
| Stop | shell | 35.3 | session-summary + memory-bridge + evaluator |
| SubagentStart/Stop | shell | 35.4 | subagent-tracker |
| TeammateIdle | shell | 35.4 | teammate-idle handler |
| TaskCompleted/Created | shell | 35.4 | task-completed + runtime-reactive |
| PreCompact/PostCompact | shell | 35.3 | pre-compact-save + post-compact |
| Elicitation/Result | shell | 35.3 | elicitation-handler |
| WorktreeCreate/Remove | shell | 35.6 | worktree lifecycle |
| Notification | shell | 35.3 | notification-handler |
| PermissionDenied | shell | 35.3 | permission-denied-handler |
| StopFailure | shell | 35.3 | stop-failure handler |
| InstructionsLoaded | shell | 35.3 | instructions-loaded |
| ConfigChange/CwdChanged/FileChanged | shell | 35.3 | runtime-reactive |

**Canary order**: PreToolUse (35.0✅) → PermissionRequest (35.0✅) → PostToolUse (35.0✅) → SessionStart → Stop → UserPromptSubmit → all remaining

---

## 4. settings.json Actual Schema

The official documentation states "only the `agent` key," but in practice the following keys are recognized by CC (confirmed in existing `.claude-plugin/settings.json`):

```jsonc
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  // Default agent
  "agent": "string",
  // Environment variable injection
  "env": {
    "KEY": "value"
  },
  // Permission control
  "permissions": {
    "deny": ["Bash(sudo:*)", "mcp__codex__*", "Read(./.env)"],
    "ask": ["Bash(rm -r:*)", "Bash(git push -f:*)"]
  },
  // Sandbox configuration
  "sandbox": {
    "failIfUnavailable": true,
    "network": {
      "deniedDomains": ["169.254.169.254", "metadata.google.internal"]
    },
    "filesystem": {
      "denyRead": [".env", "secrets/**", "**/*.pem"],
      "allowRead": [".env.example", "docs/**"]
    }
  }
}
```

---

## 5. harness.toml → CC File Mapping Table

| harness.toml section | Generated target | CC key |
|------------------------|--------|--------|
| `[project]` name, version, description, author | `plugin.json` | name, version, description, author |
| `[hooks]` | `hooks/hooks.json` + `.claude-plugin/hooks.json` | hooks |
| `[safety.permissions]` deny, ask | `settings.json` | permissions.deny, permissions.ask |
| `[safety.sandbox]` | `settings.json` | sandbox |
| `[agent]` default | `settings.json` | agent |
| `[env]` | `settings.json` | env |
| `[telemetry]` | **harness internal config** (not generated) | N/A |
| `[state]` | **harness internal config** (not generated) | N/A |

### Rejected / Unsupported

The following keys produce **explicit errors** in `harness sync`:

- `userConfig` — does not exist in CC
- `channels` — does not exist in CC
- Unknown keys in `settings.json` — keys not in the CC schema are not generated

---

## 6. SQLite Driver Selection

| Item | `modernc.org/sqlite` | `mattn/go-sqlite3` |
|------|---------------------|-------------------|
| CGO | **Not required** (pure Go) | Required |
| Cross-compile | Complete with `GOOS=x go build` | Requires C compiler for target |
| Binary size increase | +3-5MB | +1-2MB |
| WAL mode | ✅ | ✅ |
| File locking | POSIX (flock) | POSIX (flock) |
| Performance | 10-30% slower (pure Go) | Native speed |
| Stability | High (Go translation of official SQLite C code) | High (official SQLite C code directly) |

**Selection: `modernc.org/sqlite`**

Reasons:
- Cross-compilation is a prerequisite for Phase 35.7
- No CGO greatly simplifies build and CI
- Performance difference is absorbed by the design that does not use SQLite in the hook hot path (5ms without SQLite achieved in Phase 35.0)
- `busy_timeout=5000` mitigates lock contention

---

## 7. CLI Command Specification

### `harness hook <event>`

```
stdin:  Hook JSON (sent by CC)
stdout: hookSpecificOutput JSON (interpreted by CC)
exit:   0 = allow/warn, 2 = deny/block
```

| Subcommand | Function |
|------------|------|
| `harness hook pre-tool` | PreToolUse guardrail (R01-R13) |
| `harness hook post-tool` | PostToolUse tampering detection + security check |
| `harness hook permission` | PermissionRequest auto-approval |

### `harness sync`

```
stdin:  none
stdout: generation log
exit:   0 = success, 1 = harness.toml parse error or unsupported key
```

Reads harness.toml and generates:
- `hooks/hooks.json`
- `.claude-plugin/hooks.json` (same content)
- `.claude-plugin/plugin.json`
- `.claude-plugin/settings.json`

### `harness init`

```
stdin:  none
stdout: generation log
exit:   0 = success
```

Generates a `harness.toml` template in the current directory.

### `harness validate [skills|agents|all]`

```
stdout: validation results
exit:   0 = all PASS, 1 = errors found
```

### `harness doctor [--migration]`

```
stdout: diagnostic results
exit:   0 = normal, 1 = problems found
```

`--migration`: Detects Go/shell mixed-mode and displays migration status.

### `harness version`

```
stdout: version string
exit:   0
```

---

## 8. State Machine Definition

### Normal path

```
SPAWNING → RUNNING → REVIEWING → APPROVED → COMMITTED
```

### Error path

```
SPAWNING → FAILED        (startup failure)
RUNNING  → FAILED        (runtime error, exceeded 3 retries)
RUNNING  → CANCELLED     (user interrupt, Ctrl+C)
REVIEWING → FAILED       (error during review)
REVIEWING → CANCELLED    (user interrupt)
RUNNING  → STALE         (auto-transition after 24h)
REVIEWING → STALE        (auto-transition after 24h)
FAILED   → RECOVERING    (recovery started)
RECOVERING → RUNNING     (recovery succeeded)
RECOVERING → ABORTED     (recovery failed, human intervention required)
```

### 4-stage recovery

| Stage | Trigger | Action |
|------|---------|----------|
| 1. Self-repair | First failure | Error analysis → auto-fix → retry |
| 2. Peer repair | Self-repair failed | Delegate task to another Worker |
| 3. Commander intervention | Peer repair failed | Escalate to Lead session |
| 4. Halt | Commander intervention failed | ABORTED state, user notification |

---

## 9. State Storage Contract

### Path priority

```
1. ${CLAUDE_PLUGIN_DATA}/state.db    (persistent across CC v2.1.78+ updates)
2. ${PROJECT_ROOT}/.harness/state.db (fallback)
3. ${PROJECT_ROOT}/.claude/state/    (for shell scripts, read-only)
```

### Migration strategy

| Operation | Command | Description |
|------|---------|------|
| Export | `harness state export` | Dump current state.db to JSON |
| Import | `harness state import` | Restore from JSON to new state.db |
| Rollback | `HARNESS_STATE_PATH=old.db` | Override path with environment variable |

### Retention period

| Table | TTL | Cleanup |
|---------|-----|-------------|
| `work_states` | 24h | Automatic (expires_at) |
| `sessions` | Unlimited | Manual |
| `signals` | 7d after consumed | Automatic |
| `task_failures` | Unlimited | Manual |
| `assumptions` | Unlimited | Manual |

---

## 10. Guardrail Rule Specification

| ID | Tool | Condition | Action | Bypass |
|----|--------|------|----------|---------|
| R01 | Bash | `sudo` detected | deny | None |
| R02 | Write/Edit/MultiEdit | Protected paths (.env, .git/, *.pem, *.key, id_rsa, etc.) | deny | None |
| R03 | Bash | Redirection / `tee` to `> .env`, `tee .git/`, etc. | deny (TOML ask-list `.env` / `.env.*` exact match + reason → ask only) | `[[safety.guardrail.protectedPathAskList]]` |
| R04 | Write/Edit/MultiEdit | Absolute path outside project root | ask | workMode |
| R05 | Bash | `rm -rf` / `rm --recursive` | ask | workMode |
| R06 | Bash | `git push --force` / `-f` | deny | None |
| R07 | Write/Edit/MultiEdit | Direct write during codexMode *(historical: codexMode is a Codex companion guard; archived for v1)* | deny | None |
| R08 | Write/Edit/MultiEdit/Bash | Write/mutating commands by breezing reviewer | deny | None |
| R09 | Read | Sensitive files (.env, id_rsa, *.pem, secrets/) | approve + warn | None |
| R10 | Bash | `--no-verify` / `--no-gpg-sign` | deny | None |
| R11 | Bash | `git reset --hard` on protected branch | deny | None |
| R12 | Bash | Direct push to main/master | ask (configurable deny / allow) | `protected_branch_push` |
| R13 | Write/Edit/MultiEdit | package.json, Dockerfile, workflow, etc. | approve + warn | None |

R03 target extraction is redirection / `tee` based. In-place write detection like `sed -i` is out of v1 scope.

Test IDs: `TestR01_*` ~ `TestR13_*` (go/internal/guard/rules_test.go)

---

## 11. CC Version Compatibility Matrix

| Feature | Minimum CC Version | Notes |
|------|-------------------|------|
| `bin/` PATH auto-add | v2.1.91 | Added to PATH for Bash tool |
| `${CLAUDE_PLUGIN_DATA}` | v2.1.78 | Persistent across plugin updates |
| exit code 2 blocking | v2.1.90 | Bug in v2.1.89 and earlier |
| `permissionDecision: "defer"` | v2.1.89 | Headless mode pause |
| `updatedInput` | v2.1.89 | Input rewriting |
| `additionalContext` | v2.1.89 | Additional context for Claude |
| PreToolUse `allow` does not override settings.json `deny` | v2.1.77 | Security hardening |
| `settings.json` permissions/sandbox | v2.1.77+ | Confirmed in practice |

**Minimum recommended CC version: v2.1.91** (required for bin/ PATH)

---

## 12. Package Boundaries

### hook-fastpath (within 5ms)

```
internal/guard/     — rule evaluation, tampering detection, security checks
internal/hook/      — stdin/stdout codec
pkg/protocol/       — type definitions
```

**Constraints**:
- File I/O prohibited (SQLite reference only for BuildContext, optional)
- Network I/O prohibited
- goroutine launch prohibited
- External process launch prohibited

### worker-runtime (long-lived)

```
internal/state/       — SQLite store
internal/session/     — session lifecycle
internal/breezing/    — concurrent orchestration
internal/hookhandler/ — hook handler group (including OTel export, broadcast)
internal/lifecycle/   — session state tracking + recovery
internal/ci/          — CI integration utilities
pkg/config/           — config parser (harness.toml)
```

**Constraints**:
- goroutines managed with `context.Context`
- Graceful shutdown required
- Must not import `hook-fastpath` packages (reverse direction is allowed)

### API boundary

```
hook-fastpath ←── protocol (shared)
                       ↓
worker-runtime ←── protocol (shared)
```

`hook-fastpath` and `worker-runtime` do not directly import each other.
Shared types are placed only in `pkg/protocol/`.

---

## Decision: codex-companion.sh

> **Archived for v1**: codex-companion.sh and Codex CLI are non-Claude runtimes and are out of scope for v1.
> The following is a historical design decision — kept as a cherry-pick reference from upstream.

**Policy**: **Out of scope for Go integration.** Maintain the shell wrapper.

Reasons:
- codex-companion.sh is a wrapper for calling Codex CLI (external process)
- Codex CLI itself is frequently updated and the API is not stable
- Shell wrapper is easier to track Codex CLI changes
- Consistent with DESIGN.md D2 policy

Go integration targets are limited to Harness internal logic (guardrails, state management, config generation).
