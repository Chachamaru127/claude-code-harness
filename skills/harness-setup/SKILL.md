---
name: harness-setup
description: "HAR: Project init, tool setup, agent config, memory setup, skill mirror sync. Trigger: setup, init, new project, CI/Codex setup, harness-mem, mirror. Do NOT load for: implementation, review, release, planning."
description-en: "HAR: Project init, tool setup, agent config, memory setup, skill mirror sync. Trigger: setup, init, new project, CI/Codex setup, harness-mem, mirror. Do NOT load for: implementation, review, release, planning."
kind: workflow
purpose: "Initialize and repair Harness project configuration"
trigger: "setup, init, new project, CI/Codex setup, harness-mem, mirror"
shape: workflow
role: generator
pair: harness-sync
owner: harness-core
since: "2026-05-05"
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash"]
argument-hint: "[init|ci|codex|harness-mem|mirrors|agents|localize]"
user-invocable: true
effort: medium
---

# Harness Setup

The integrated setup skill for Harness.
Consolidates the following legacy skills:

- `setup` — integrated setup hub
- `harness-init` — project initialization
- `harness-update` — Harness updates
- `maintenance` — file organization and cleanup

## Quick Reference

| Subcommand | Action |
|------------|--------|
| `/harness-setup init` | Initialize a new project (CLAUDE.md + Plans.md + hooks + sync + doctor) |
| `/harness-setup ci` | Configure CI/CD pipeline |
| `/harness-setup codex` | Install and configure Codex CLI |
| `/harness-setup harness-mem` | Integrate harness-mem and configure memory |
| `/harness-setup mirrors` | Update skills/ → public mirror bundle |
| `/harness-setup agents` | Configure agents/ |
| `/harness-setup localize` | Localize CLAUDE.md rules |

> **Built-in slash discovery (CC 2.1.108+)**:
> Built-in slash commands such as `/init` are also discovered.
> Use `/harness-setup init` only when Harness-specific bootstrap is needed.

> **Claude Code setup guidance (CC 2.1.120+)**:
> MCP `alwaysLoad`, `${CLAUDE_EFFORT}`, `claude plugin prune`, `claude project purge`,
> `ANTHROPIC_BEDROCK_SERVICE_TIER`, `claude_code.skill_activated.invocation_trigger`,
> Windows PowerShell primary shell, and deferred tools for forked skills / subagents are
> governed by `docs/claude-code-setup-mcp-telemetry-provider.md` as the canonical source.

> **Codex plugin workflows**:
> Do not dual-manage Codex `/goal` and `Plans.md`.
> Plugin-bundled hooks are opt-in, external agent imports must declare ownership,
> MultiAgentV2 / `agents.max_threads = 8` is treated as a ceiling,
> and sticky environments / app-server artifacts should prefer safe defaults.
> The `codex remote-control`, large thread pagination, selected-environment `view_image`,
> live app-server config refresh, accurate turn diffs, plugin details bundled hooks,
> and sharing discoverability controls introduced in Codex `0.130.0` stable are
> governed by `docs/codex-plugin-workflows-policy.md` as the canonical source.
> See `docs/codex-plugin-workflows-policy.md` for details.

## Subcommand Details

### init — Project Initialization

Introduces Harness to a new project.

**Generated files**:
```
project/
├── CLAUDE.md            # Project configuration
├── Plans.md             # Task management (empty template)
├── .claude/
│   ├── settings.json    # Claude Code settings
│   └── hooks.json       # Hook configuration (Go binary)
└── hooks/
    ├── pre-tool.sh      # Thin shim (→ core/src/index.ts)
    └── post-tool.sh     # Thin shim (→ core/src/index.ts)
```

**Flow**:
1. Detect project type (Node.js / Python / Go / Rust / other)
2. Generate a minimal CLAUDE.md
3. Generate the Plans.md template
4. Place hooks.json
5. **Go binary verification**: confirm the binary is available with `harness version` (Node.js is not required since v4.0)
6. **Plugin file sync**: sync files under `.claude-plugin/` to the latest state with `harness sync`
7. **Health check**: pass all checks in `harness doctor`. Present fix suggestions if issues are found.

### Go Binary Verification

```bash
# Confirm binary existence and operation
harness version
# e.g.: harness v4.0.0 (go1.22.0, darwin/arm64)
```

Since v4.0, the Harness core engine has migrated to a Go binary.
Node.js is not required. The binary is at `bin/harness` (or `harness` on PATH).

### Plugin File Sync

```bash
# Sync files under .claude-plugin/ to the latest state
harness sync

# Check sync contents only (no changes)
harness sync --dry-run
```

`harness sync` propagates changes from the SSOT in `skills/` to each mirror
(`codex/.codex/skills/`, `opencode/skills/`). Always run after init.

### Health Check

```bash
# Run all check items
harness doctor
```

`harness doctor` verifies the following:

| Check item | Content |
|------------|---------|
| Binary | Does `harness version` return normally? |
| Plugin config | Is `.claude-plugin/plugin.json` in the correct format? |
| Hooks placement | Are hooks present at the correct paths? |
| Mirror sync | Do the contents of `skills/` and the mirror match? |
| CLAUDE.md | Are the required sections present? |

If issues are detected, fix commands are presented.

### ci — CI/CD Configuration

Configures GitHub Actions workflows.

```yaml
# Example of generated .github/workflows/ci.yml
name: CI
on:
  push:
    branches: [main]
  pull_request:
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci && npm test
```

### codex — Codex CLI Configuration

```bash
# Verify installation (Codex CLI is Node.js-based — separate from Harness itself)
which codex || npm install -g @openai/codex

# Verify timeout command (macOS)
TIMEOUT=$(command -v timeout || command -v gtimeout || echo "")
# macOS: brew install coreutils
```

> **Note**: The Harness v4.0 core (`harness` command) is a Node.js-free Go binary.
> The Codex CLI (`codex` command) is a separate tool that still requires Node.js.

### Codex provider / model metadata policy (0.123.0+ / 0.130.0)

Provider / model guidance for Codex `0.123.0`+ and Bedrock `aws login` guidance for
Codex `0.130.0` stable are governed by `docs/codex-provider-setup-policy.md` as the canonical source.

Key points:

- When using Bedrock, use Codex's built-in `amazon-bedrock` provider.
- Place the AWS profile in the user / project Codex config under `[model_providers.amazon-bedrock.aws]`.
- AWS console-login credentials from `aws login` profiles are treated as AWS-side profile material.
- Harness does not write AWS credentials, console-login cache, or provider endpoints.
- Harness distribution Codex config does not fix `model = "gpt-5.4"` as the setup default.
- Harness distribution Codex config does not fix `model_provider = "amazon-bedrock"` as the setup default either.
- `gpt-5.4` is treated as Codex's current model metadata; do not leave old examples such as `gpt-5.2-codex` as recommended samples.
- Do not mix Claude Code's `CLAUDE_CODE_USE_BEDROCK` / `ANTHROPIC_DEFAULT_*` / `modelOverrides` guidance with Codex's `model_provider = "amazon-bedrock"`.

Only users / projects using Bedrock add the following as needed:

```toml
model_provider = "amazon-bedrock"

[model_providers.amazon-bedrock.aws]
profile = "codex-bedrock"
```

For Claude Code provider / MCP / telemetry guidance, see
`docs/claude-code-setup-mcp-telemetry-provider.md`.
In particular, `ANTHROPIC_BEDROCK_SERVICE_TIER` should only be handled in Bedrock-user
provider environments and must not be included in Harness plugin defaults / templates /
shared project settings.

### Codex app-server / plugin workflow policy (0.130.0)

App-server / plugin workflow guidance for Codex `0.130.0` stable
(`rust-v0.130.0`, published `2026-05-08T23:09:55Z`) is governed by
`docs/codex-plugin-workflows-policy.md` as the canonical source.

Key points:

- `codex remote-control` is the explicit launch entrypoint for a headless remotely controllable app-server. Harness setup does not write remote-control defaults to config.
- App-server clients can page large threads. Check the necessary page range for long loops / Breezing transcripts.
- `view_image` can resolve files via selected environments in multi-environment sessions. Include the environment / workdir in artifact reports.
- Live app-server threads pick up config changes without restart. Handle changes to secrets / provider / hook policy with diffs and verification.
- Turn diffs stay accurate across `apply_patch` including partial failures. Use `git diff` and tests for the final determination.
- Plugin details now show bundled hooks. Verify bundled hooks before install / share; keep Harness bundled hooks opt-in.
- Plugin sharing exposes link metadata and discoverability controls. Verify scope and metadata as a release surface.
- Configurable OpenTelemetry trace metadata is limited to debugging / triage assistance; do not include personal information, customer data, or secrets.
- Built-in MCPs are treated as Codex runtime-owned surfaces; do not mix ownership with plugin-provided MCPs.
- `CODEX_HOME` environments TOML provider is a user-level environment source. Report the selected environment and fix write turns to a single primary environment.
- Do not rely on the skills list extra roots; use Harness mirror install or explicit `[[skills.config]]` path-based loading.

### Codex MCP diagnostics / plugin loading (0.123.0+)

MCP diagnostics / plugin MCP loading guidance for Codex `0.123.0`+ is governed by
`docs/codex-mcp-diagnostics.md` as the canonical source.

Key points:

- In the Codex TUI, normally use `/mcp` to lightly check server status only.
- Use `/mcp verbose` only when an MCP server is not visible, resources are not shown, or resource templates cannot be read.
- With `/mcp verbose`, check diagnostics / resources / resource templates.
- Guide `.mcp.json` inside plugins to support both the `mcpServers` format and the top-level server map format.
- Prefer the `mcpServers` format for easy sharing in new plugins.
- If an existing plugin uses the top-level server map format, leverage Codex's improved loading and avoid unnecessary rewrites.
- Do not mix with Claude Code's `claude mcp ...`, `.claude/mcp.json`, or hook `type: "mcp_tool"` guidance.

`mcpServers` format:

```json
{
  "mcpServers": {
    "docs": {
      "command": "node",
      "args": ["server.js"]
    }
  }
}
```

Top-level server map format:

```json
{
  "docs": {
    "command": "node",
    "args": ["server.js"]
  }
}
```

### Codex sandbox / execution policy (0.123.0+)

`remote_sandbox_config` and `codex exec` shared flags guidance for Codex `0.123.0`+ are
governed by `docs/codex-sandbox-execution-policy.md` as the canonical source.

Key points:

- Guide `remote_sandbox_config` as a host-specific sandbox policy in `requirements.toml`.
- Determine `allowed_sandbox_modes` by comparing them for each remote environment: remote devbox / ephemeral CI runner / shared host.
- Host matching is a convenient classification but is not strong device authentication. Avoid broad wildcards in high-risk environments.
- Do not write organization-specific `remote_sandbox_config` in the Harness distribution `codex/.codex/config.toml`.
- Since Codex `0.123.0`, `codex exec` inherits root-level shared flags; do not add duplicate `--approval-policy` / `--sandbox` pairs on the wrapper side.
- `scripts/codex-companion.sh task --write` appending `--sandbox workspace-write` converts Harness's "write task" intent to exec-local and is not a duplicate forwarding of root shared flags.
- `--full-auto` in `scripts/codex/codex-exec-wrapper.sh` is retained in 53.2.4. If changed, add regression tests for approval / sandbox behavior in a separate task.

Requirements example:

```toml
allowed_sandbox_modes = ["read-only"]

[[remote_sandbox_config]]
hostname_patterns = ["devbox-*.corp.example.com"]
allowed_sandbox_modes = ["read-only", "workspace-write"]
```

**Usage pattern** (via official plugin):
```bash
bash scripts/codex-companion.sh task --write "task content"
# or via stdin
cat /tmp/prompt.md | bash scripts/codex-companion.sh task --write
```

### harness-mem — Memory Configuration

Configures Unified Harness Memory.

```bash
# Create memory directories
mkdir -p .claude/agent-memory/claude-code-harness-worker
mkdir -p .claude/agent-memory/claude-code-harness-reviewer

# Place MEMORY.md template
cat > .claude/agent-memory/claude-code-harness-worker/MEMORY.md << 'EOF'
# Worker Agent Memory

## Project Context
[Project overview]

## Patterns
[Learned patterns]
EOF
```

### mirrors — Public Skill Bundle Sync

On Windows with `core.symlinks=false`, repository symlinks become regular files and
`harness-*` skills may disappear from the command list. The public bundle is synced
as a real-directory mirror.

```bash
./scripts/sync-skill-mirrors.sh
./scripts/sync-skill-mirrors.sh --check
```

Update targets:

- `skills/`
- `codex/.codex/skills/`
- `opencode/skills/`

### agents — Agent Configuration

Configures the 3-agent structure in `agents/`.

```
agents/
├── worker.md      # Implementation (task-worker + codex-implementer + error-recovery)
├── reviewer.md    # Review (code-reviewer + plan-critic)
└── scaffolder.md  # Scaffolding (project-analyzer + scaffolder)
```

### localize — Rule Localization

Adapts rules under `.claude/rules/` to the current project.

```bash
# List available rules
ls .claude/rules/

# Add project-specific rules
cat >> .claude/rules/project-rules.md << 'EOF'
# Project-Specific Rules
[Project-specific rules here]
EOF
```

## Plugin Installation (v2.1.71+ Marketplace)

Marketplace stability was greatly improved in v2.1.71.
Plugin / managed settings policy from Claude Code 2.1.117–2.1.118 onward is governed by
`docs/plugin-managed-settings-policy.md` as the canonical source.

### Recommended Installation Method

```bash
# Version-pinned with @ref form (recommended)
claude plugin install owner/repo@v4.0.0

# Latest version
claude plugin install owner/repo
```

The `owner/repo@vX.X.X` form is recommended. With the `@ref` parser fix, tags, branches,
and commit hashes are all resolved accurately.

### Updates

```bash
claude plugin update owner/repo
```

The merge conflict on update was fixed in v2.1.71, enabling stable updates.

### Other Improvements

- MCP server deduplication: automatically prevents registering the same MCP server multiple times
- `/plugin uninstall` uses `settings.local.json`: accurately reflected in user-local settings

### Managed marketplace / dependency policy (v2.1.117+)

When controlling the plugin marketplace for enterprise use, use Claude Code's own managed settings.
Harness does not layer its own marketplace or dependency resolvers on top.

| Item | Purpose | Harness handling |
|------|---------|-----------------|
| `extraKnownMarketplaces` | Guide and register recommended marketplaces for the team | Prefer this in normal onboarding |
| `blockedMarketplaces` | Block specific marketplace sources | Managed settings only. Do not include in normal-user defaults |
| `strictKnownMarketplaces` | Allow only approved marketplace sources to be added | Managed settings only. Do not include in normal-user defaults |
| Plugin dependency auto-resolve | Auto-install `dependencies` / missing dependency hints | Delegate to Claude Code itself. Do not add a Harness custom resolver |
| Plugin `themes/` directory | Plugin ships a theme | Future task for now. Harness does not bundle themes |

`DISABLE_AUTOUPDATER` stops automatic updates.
`DISABLE_UPDATES` stops even manual `claude update`, intended for enterprise fixed-version operations.
Do not include either in Harness project defaults; organizations that need them configure them via managed settings or device management.

If a dependency is missing, first check Claude Code's `/plugin` Errors, `/doctor`, and
`claude plugin list --json`. If the marketplace is not registered, register it with
`/plugin marketplace add` or `claude plugin marketplace add` and delegate to the core auto-resolve.

## Maintenance — File Organization

Periodic maintenance tasks:

| Task | Command |
|------|---------|
| Delete old logs | `find .claude/logs -mtime +30 -delete` |
| Compact Plans.md | Move completed tasks to archive section |
| Delete old traces | `tail -1000 .claude/state/agent-trace.jsonl > /tmp/trace && mv /tmp/trace .claude/state/agent-trace.jsonl` |

## Related Skills

- `harness-plan` — Create a project plan after setup
- `harness-work` — Execute tasks after setup
- `harness-review` — Review setup configuration
