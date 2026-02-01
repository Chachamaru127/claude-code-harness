---
name: setup-tools
description: "Unified setup command for CI, LSP, MCP, dev-tools, and other development tools. Use when user mentions '/setup', tool setup, CI setup, LSP setup, MCP setup, webhook setup, remotion setup, or opencode setup. Do NOT load for: app setup screens, onboarding flows, CI concept questions."
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob"]
argument-hint: "[ci|dev-tools|lsp|mcp|opencode|webhook|ui|remotion|skills]"
disable-model-invocation: true
---

# Setup Tools Skill

Consolidates all tool setup commands into one unified interface.

## Usage

```bash
/setup-tools              # Show available options
/setup-tools ci           # Setup CI/CD (GitHub Actions)
/setup-tools dev-tools    # Setup AST-Grep + LSP (recommended)
/setup-tools lsp          # Setup LSP only
/setup-tools mcp          # Setup MCP server
/setup-tools opencode     # Setup OpenCode.ai compatibility
/setup-tools webhook      # Setup GitHub Actions webhook
/setup-tools ui           # Setup Harness UI
/setup-tools remotion     # Setup Remotion video generation
/setup-tools skills       # Update skills settings
```

---

## Subcommands Reference

| Subcommand | Reference | Description |
|------------|-----------|-------------|
| `ci` | [references/ci-setup.md](references/ci-setup.md) | CI/CD (GitHub Actions) |
| `dev-tools` | [references/dev-tools-setup.md](references/dev-tools-setup.md) | AST-Grep + LSP |
| `lsp` | [references/lsp-setup.md](references/lsp-setup.md) | LSP only |
| `mcp` | [references/mcp-setup.md](references/mcp-setup.md) | MCP server |
| `opencode` | [references/opencode-setup.md](references/opencode-setup.md) | OpenCode.ai |
| `webhook` | [references/webhook-setup.md](references/webhook-setup.md) | GitHub Actions webhook |
| `remotion` | [references/remotion-setup.md](references/remotion-setup.md) | Remotion video |

---

## Execution Flow

1. Parse subcommand from $ARGUMENTS
2. If no subcommand, show available options and ask user
3. Load corresponding reference file
4. Execute setup steps from reference
5. Verify configuration

---

## Subcommand Details

### `/setup-tools ci` - CI/CD Setup

Sets up GitHub Actions for automated testing and deployment.

**Features**: Lint, TypeScript check, Unit tests, E2E tests, Build check

See: [references/ci-setup.md](references/ci-setup.md)

---

### `/setup-tools dev-tools` - Development Tools (Recommended)

Sets up AST-Grep and LSP for enhanced code intelligence.

**Why recommended**: Structural code search + type-aware navigation = better review accuracy

See: [references/dev-tools-setup.md](references/dev-tools-setup.md)

---

### `/setup-tools lsp` - LSP Only

Sets up Language Server Protocol support without AST-Grep.

See: [references/lsp-setup.md](references/lsp-setup.md)

---

### `/setup-tools mcp` - MCP Server

Sets up Model Context Protocol servers for cross-client communication.

See: [references/mcp-setup.md](references/mcp-setup.md)

---

### `/setup-tools opencode` - OpenCode.ai Compatibility

Sets up compatibility with OpenCode.ai for multi-LLM development.

See: [references/opencode-setup.md](references/opencode-setup.md)

---

### `/setup-tools webhook` - GitHub Actions Webhook

Sets up webhooks for PR auto-review and Plans.md consistency check.

See: [references/webhook-setup.md](references/webhook-setup.md)

---

### `/setup-tools ui` - Harness UI

Sets up the Harness UI dashboard. Redirects to `/harness-ui` which auto-detects setup needs.

---

### `/setup-tools remotion` - Remotion Video

Sets up Remotion programmatic video generation environment.

**Options**:
- `--with-templates` - Include Harness templates
- `--brownfield` - Add to existing project
- `--with-narration` - Include Aivis narration
- `--with-image-gen` - Include AI image generation

See: [references/remotion-setup.md](references/remotion-setup.md)

---

### `/setup-tools skills` - Skills Settings

Updates Skills Gate settings.

**Actions**:
- `list` - Show current settings
- `add <skill>` - Add a skill
- `remove <skill>` - Remove a skill
- `enable` - Enable Skills Gate
- `disable` - Disable Skills Gate

```bash
/setup-tools skills list
/setup-tools skills add auth
/setup-tools skills enable
```

---

## Related Skills

- `ci` - CI/CD configuration and failure analysis
- `setup` - Project initialization and workflow files
- `harness-update` - Update harness to latest version
