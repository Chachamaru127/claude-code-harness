# Migration Guide: v3 → v4.0 "Hokage"

## For Most Users (Non-Engineers / VibeCoders)

**Nothing to do.** Just update the plugin:

```
/plugin update claude-code-harness
```

That's it. Your hooks are now 20x faster. No configuration changes needed.

---

## What Changed

### Performance

| Component | v3 (bash + Node.js) | v4 "Hokage" (Go) |
|-----------|---------------------|-------------------|
| PreToolUse | 40–60 ms | 1–3 ms |
| SessionStart | 500–800 ms (4 sequential scripts) | 10–15 ms (1 parallel call) |
| PostToolUse | 20–30 ms | 1–2 ms |

### Dependencies

| | v3 | v4 |
|---|---|---|
| Node.js | Required (18+) | **Not needed** |
| TypeScript | Used for guardrails | **Removed** |
| Go binary | Optional (via shim) | **Required** (bundled) |

### Architecture

- **v3**: `hooks.json` → bash shim → Node.js → TypeScript guardrails
- **v4**: `hooks.json` → Go binary (direct)

The Go binary (`bin/harness`) is pre-built and bundled with the plugin. No local Go installation is required for most users.

---

## For Fork Owners (44 forks)

If you have a fork with custom hooks, follow these steps.

### Step 1: Check your customizations

```bash
harness doctor --migration
```

This reports which hooks reference the old bash shims and need updating.

### Step 2: Update hooks.json

Your custom `hooks.json` entries need to change from:

```json
"command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/your-script.sh\""
```

to:

```json
"command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook your-event"
```

Agent-type hooks (`"type": "agent"`) are unchanged — no edits needed for those.

### Step 3: Sync plugin files

```bash
harness sync
harness doctor
```

`harness doctor` should report no warnings before you merge your fork.

---

## Rollback

If you encounter issues after upgrading, pin back to v3:

```
/plugin install claude-code-harness@3.17.1
```

Your `harness.toml` is unaffected by version changes and does not need to be restored.

---

## Removed Files

The following files were removed in v4.0. If your fork references them, update those references before upgrading.

| Removed | Replaced by |
|---------|-------------|
| `core/` — TypeScript guardrail engine | `go/internal/guardrail/` |
| `hooks/pre-tool.sh`, `post-tool.sh`, `permission.sh` — bash shims | `bin/harness hook <event>` |
| `scripts/postinstall.js` — Node.js installer | `bin/harness` launcher |
| `scripts/run-hook.sh`, `scripts/run-script.js` — Node.js hook runtime | `bin/harness` launcher |
| `package.json` — npm dependency manifest | Go module (`go/go.mod`) |

---

## Troubleshooting

### "harness: command not found"

The Go binary may not be in your PATH. Verify it is present:

```bash
ls -la "${CLAUDE_PLUGIN_ROOT}/bin/harness"
```

If missing, re-run the plugin installer:

```
/plugin update claude-code-harness
```

### Hooks not firing

Run diagnostics to identify the issue:

```bash
harness doctor
```

Common causes: stale `hooks.json` entries pointing to removed bash shims, or `bin/harness` missing execute permission.

### Unsupported platform

Pre-built binaries are provided for macOS (arm64/amd64), Linux (amd64), and Windows (amd64). Git Bash, MSYS, and Cygwin shells resolve `bin/harness-windows-amd64.exe`; WSL2 resolves the Linux binary. If you are on an unsupported platform (e.g., Windows ARM), build from source:

```bash
cd go && make install
```

Requires Go 1.22+.

---

## Questions?

Open an issue: https://github.com/Chachamaru127/claude-code-harness/issues
