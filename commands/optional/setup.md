---
description: Setup optional tools (ci, lsp, mcp, dev-tools, opencode, webhook)
description-en: Setup optional tools (ci, lsp, mcp, dev-tools, opencode, webhook)
---

# /setup - Optional Tools Setup

Setup various optional tools and integrations for enhanced development experience.

## Quick Reference

| What You Want | Command |
|---------------|---------|
| Add CI/CD | `/setup ci` |
| Code intelligence (AST-Grep + LSP) | `/setup dev-tools` |
| LSP only | `/setup lsp` |
| MCP server (cross-client) | `/setup mcp` |
| OpenCode.ai compatibility | `/setup opencode` |
| GitHub Actions webhook | `/setup webhook` |
| See all options | `/setup` (no args) |

---

## Usage

```bash
/setup              # Show available options
/setup ci           # Setup CI/CD (GitHub Actions)
/setup dev-tools    # Setup AST-Grep + LSP (recommended)
/setup lsp          # Setup LSP only
/setup mcp          # Setup MCP server
/setup opencode     # Setup OpenCode.ai compatibility
/setup webhook      # Setup GitHub Actions webhook
```

---

## Subcommands

### `/setup ci` - CI/CD Setup

Setup GitHub Actions for automated testing and deployment.

**Features**:
- Lint (ESLint, Prettier)
- Type Check (TypeScript)
- Unit Test (Jest, Vitest)
- E2E Test (Playwright)
- Build Check

**Deliverables**: `.github/workflows/*.yml`

---

### `/setup dev-tools` - Development Tools (Recommended)

Setup AST-Grep and LSP for advanced code intelligence.

**Why MCP?**
- Claude can use `harness_ast_search` for structural code search
- `/harness-review` automatically uses code smell detection
- Better refactoring impact analysis

**Tools enabled**:
| Tool | Purpose |
|------|---------|
| `harness_ast_search` | Structural code pattern search |
| `harness_lsp_diagnostics` | Type errors, warnings |
| `harness_lsp_references` | Find all references |

---

### `/setup lsp` - LSP Only

Setup Language Server Protocol without AST-Grep.

**Use when**: You only need type checking and references, not structural search.

---

### `/setup mcp` - MCP Server

Setup Harness MCP server for cross-client communication.

**Enables**:
- Session sharing between Claude Code, Codex, Cursor
- Inter-session messaging
- Unified workflow across AI tools

---

### `/setup opencode` - OpenCode.ai Compatibility

Setup project for [opencode.ai](https://opencode.ai/) compatibility.

**Enables**:
- Use Harness workflow with GPT, Gemini, Grok, DeepSeek
- All core commands work: `/harness-init`, `/plan-with-agent`, `/work`, `/harness-review`

---

### `/setup webhook` - GitHub Actions Webhook

Setup webhook triggers for GitHub Actions automation.

**Use when**: You want automated workflows triggered by GitHub events.

---

## Execution Flow

### Step 1: Show Options (if no subcommand)

```
🔧 Available Setup Options

| Option | Description |
|--------|-------------|
| ci | CI/CD with GitHub Actions |
| dev-tools | AST-Grep + LSP (recommended for code intelligence) |
| lsp | Language Server only |
| mcp | MCP server for cross-client communication |
| opencode | OpenCode.ai compatibility |
| webhook | GitHub Actions webhook triggers |

Which would you like to setup?
```

### Step 2: Execute Selected Setup

Route to the appropriate setup logic based on subcommand.

---

## Notes

- **dev-tools is recommended**: Enables advanced code intelligence in `/harness-review`
- **mcp is optional**: Only needed for multi-client workflows
- **ci is project-specific**: Analyzes your project to suggest appropriate checks
