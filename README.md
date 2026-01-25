# Claude Harness

English | [日本語](README_ja.md)

![Claude Harness](docs/images/claude-harness-logo-with-text.png)

**Turn Claude Code into a self-correcting development team.**

Claude Harness runs Claude Code in an autonomous **Plan → Work → Review** cycle,
catching mistakes before they ship.

[![Version: 2.11.0](https://img.shields.io/badge/version-2.11.0-blue.svg)](VERSION)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE.md)
[![Claude Code](https://img.shields.io/badge/Claude_Code-v2.1.6+-purple.svg)](docs/CLAUDE_CODE_COMPATIBILITY.md)

---

## See It In Action

```bash
/plan-with-agent   # Brainstorm → Create a plan
/work              # Execute the plan (with parallel workers)
/harness-review    # Multi-perspective code review
```

**That's it.** Three commands turn a rough idea into reviewed, production-ready code.

---

## Why Claude Harness?

Solo developers face 4 recurring problems. Claude Harness solves all of them:

| Problem | What Happens | How Harness Fixes It |
|---------|--------------|---------------------|
| **Confusion** | "Where do I start?" | `/plan-with-agent` breaks ideas into actionable tasks |
| **Sloppiness** | Code quality drops under pressure | `/harness-review` runs 8 expert reviewers in parallel |
| **Accidents** | Dangerous commands slip through | Hooks auto-block `rm -rf`, protect `.env`, guard secrets |
| **Forgetfulness** | Past decisions lost between sessions | SSOT files + Claude-mem preserve context forever |

---

## Quick Start

**Requirements**: Claude Code v2.1.6+ ([compatibility guide](docs/CLAUDE_CODE_COMPATIBILITY.md))

### One-Liner Install

```bash
curl -fsSL https://raw.githubusercontent.com/Chachamaru127/claude-code-harness/main/scripts/quick-install.sh | bash
```

With development tools (AST-Grep, LSP):
```bash
curl -fsSL https://raw.githubusercontent.com/Chachamaru127/claude-code-harness/main/scripts/quick-install.sh | bash -s -- --with-dev-tools
```

### Manual Install

```bash
# 1. Open your project in Claude Code
cd /path/to/your-project && claude

# 2. Install the plugin
/plugin marketplace add Chachamaru127/claude-code-harness
/plugin install claude-code-harness@claude-code-harness-marketplace

# 3. Initialize
/harness-init
```

**Done.** Start with `/plan-with-agent` to create your first plan.

<details>
<summary>Alternative: Local Clone</summary>

```bash
git clone https://github.com/Chachamaru127/claude-code-harness.git ~/claude-plugins/claude-code-harness
cd /path/to/your-project
claude --plugin-dir ~/claude-plugins/claude-code-harness
```

</details>

---

## What's New in v2.11

### Video Generation (v2.11.0)

**Auto-generate product demo, architecture, and release note videos from your codebase.**

```bash
/remotion-setup    # One-time Remotion setup
/generate-video    # Analyze → Plan → Generate (parallel)
```

| Video Type | Auto-detected When | Structure |
|------------|-------------------|-----------|
| Product Demo | New project, UI changes | Intro → Feature Demo → CTA |
| Architecture | Major refactoring | Overview → Details → Data Flow |
| Release Notes | CHANGELOG updated | Version → Changes → New Feature Demo |

- **Codebase analysis**: Auto-detects framework, features, UI components
- **Smart scenario**: Suggests optimal video structure with AskUserQuestion
- **Parallel generation**: Up to 5 agents generate scenes simultaneously
- **Playwright integration**: Captures real UI interactions

> ⚠️ Remotion may require a paid license for commercial use

---

## What's New in v2.10

### OpenCode.ai Compatibility (v2.10.0)

**Use the Harness workflow with any LLM: o3, Gemini, Grok, DeepSeek, and more.**

```bash
/setup opencode   # One-command installation
```

All core commands work in OpenCode.ai:
- `/harness-init` → Project initialization
- `/plan-with-agent` → Task planning
- `/work` → Parallel task execution
- `/harness-review` → Multi-perspective review

See [OpenCode Compatibility Guide](docs/OPENCODE_COMPATIBILITY.md) for details.

---

## Key Features

### Parallel Full-Cycle Automation

```bash
/work                  # Full automation with smart parallel (default)
/work --parallel 5     # Force 5 parallel workers
```

Runs **implement → self-review → fix → commit** in parallel for each task.
Each worker reviews its own code before marking done.

### Code Intelligence (AST-Grep + LSP)

```bash
/setup dev-tools   # One-time setup
```

Enables structural code search and semantic analysis:
- Find code patterns: `console.log`, empty catch blocks, unused async
- Impact analysis: Find all references before refactoring
- Diagnostics: Type errors and warnings

### 8-Expert Code Review

```bash
/review
```

Security, performance, accessibility, maintainability—8 specialists review your code simultaneously. Optionally add [Codex](https://github.com/openai/codex) for a second opinion.

### Safety Hooks

| Protected | Action |
|-----------|--------|
| `.git/`, `.env`, secrets | Write blocked |
| `rm -rf`, `sudo`, `git push --force` | Confirmation required |
| `git status`, `npm test` | Auto-allowed |

### Session Continuity

- **SSOT files**: `decisions.md` (why) + `patterns.md` (how)
- **Claude-mem integration**: Past learnings persist across sessions
- **Session resume**: `/resume` restores your exact work state

### Cross-Session Communication

```bash
/session broadcast "API changed: userId → user"
/session inbox   # Check messages from other sessions
```

Real-time messaging between sessions. When you change an API in Session A, Session B gets notified automatically.

### MCP Server (Multi-Client Support)

```bash
/setup mcp   # Configure for Claude Code, Codex, or Cursor
```

Use Harness from **Codex**, **Cursor**, or any MCP-compatible client. Share sessions across different AI tools working on the same project.

### OpenCode Compatibility

Harness works with [opencode.ai](https://opencode.ai/) too. Use the same workflow with GPT, Gemini, or any supported model:

```bash
# Quick setup (no Claude Code required)
curl -fsSL https://raw.githubusercontent.com/Chachamaru127/claude-code-harness/main/scripts/setup-opencode.sh | bash

# Or from Claude Code
/setup opencode
```

See [opencode/README.md](opencode/README.md) for full setup instructions.

---

## Who Is This For?

| You | Benefit |
|-----|---------|
| **Solo developers** | Ship faster without sacrificing quality |
| **Freelancers** | Deliver review reports as proof of quality |
| **VibeCoder** | Build apps with natural language |
| **Cursor users** | 2-Agent workflow separates planning from coding |

---

## Commands

### Core Workflow

| Command | Purpose |
|---------|---------|
| `/plan-with-agent` | Turn ideas into plans |
| `/work` | Execute tasks from Plans.md |
| `/harness-review` | Multi-expert code review |
| `/sync-status` | Check progress, get next action |

### Setup & Operations

| Command | Purpose |
|---------|---------|
| `/harness-init` | Initialize project |
| `/setup` | Setup optional tools (ci, lsp, mcp, dev-tools, opencode, webhook) |
| `/harness-update` | Update plugin files |
| `/codex-review` | Codex-only second opinion |

### Session (Inter-session Communication)

| Command | Purpose |
|---------|---------|
| `/session list` | List active sessions |
| `/session inbox` | Check messages from other sessions |
| `/session broadcast` | Send message to all sessions |

### 2-Agent Workflow (Cursor)

| Command | Purpose |
|---------|---------|
| `/handoff-to-cursor` | Send completion report to PM |
| `/plan-with-cc` | (Cursor) Plan, then hand to Claude Code |
| `/review-cc-work` | (Cursor) Review implementation |

---

## Skills

Skills auto-trigger based on your request:

| Skill | Triggers |
|-------|----------|
| `impl` | "implement", "add feature", "build" |
| `review` | "review", "check security", "audit" |
| `verify` | "build", "fix errors", "recover" |
| `auth` | "login", "Stripe", "payment" |
| `deploy` | "deploy", "Vercel", "production" |
| `ui` | "hero section", "component", "form" |

Skills auto-trigger based on context. Run `/skill-list` to see all available skills.

---

## Architecture

```
claude-code-harness/
├── commands/     # Slash commands (core + optional)
├── skills/       # Auto-triggered skills
├── agents/       # Sub-agents (parallel workers)
├── hooks/        # Safety & automation hooks
├── scripts/      # Guard scripts
└── templates/    # Generation templates
```

---

## Documentation

| Guide | Description |
|-------|-------------|
| [Changelog](CHANGELOG.md) | What's new in each version |
| [Implementation Guide](IMPLEMENTATION_GUIDE.md) | Deep dive into internals |
| [Development Flow](DEVELOPMENT_FLOW_GUIDE.md) | How to extend the harness |
| [Cursor Integration](docs/CURSOR_INTEGRATION.md) | 2-Agent workflow setup |
| [Claude Code Compatibility](docs/CLAUDE_CODE_COMPATIBILITY.md) | Version requirements |

---

## Acknowledgments

- **Hierarchical Skill Structure**: [AI Masao](https://note.com/masa_wunder)
- **Test Tampering Prevention**: [Beagle](https://github.com/beagleworks) (Claude Code Meetup Tokyo 2025.12.22)

---

## License

**MIT License** — Free to use, modify, and commercialize.

[English](LICENSE.md) | [日本語](LICENSE.ja.md)
