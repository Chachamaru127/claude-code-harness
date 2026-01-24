# Claude Harness

English | [日本語](README_ja.md)

![Claude Harness](docs/images/claude-harness-logo-with-text.png)

**Turn Claude Code into a self-correcting development team.**

Claude Harness runs Claude Code in an autonomous **Plan → Work → Review** cycle,
catching mistakes before they ship.

[![Version: 2.9.24](https://img.shields.io/badge/version-2.9.24-blue.svg)](VERSION)
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

## Key Features

### Parallel Full-Cycle Automation

```bash
/work --full --parallel 3
```

Runs **implement → self-review → fix → commit** in parallel for each task.
Each worker reviews its own code before marking done.

### 8-Expert Code Review

```bash
/harness-review
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
/session-broadcast "API changed: userId → user"
/session-inbox   # Check messages from other sessions
```

Real-time messaging between sessions. When you change an API in Session A, Session B gets notified automatically.

### MCP Server (Multi-Client Support)

```bash
/mcp-setup   # Configure for Claude Code, Codex, or Cursor
```

Use Harness from **Codex**, **Cursor**, or any MCP-compatible client. Share sessions across different AI tools working on the same project.

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

### Operations

| Command | Purpose |
|---------|---------|
| `/harness-init` | Initialize project |
| `/harness-update` | Update plugin files |
| `/codex-review` | Codex-only second opinion |
| `/skill-list` | Show all 67 skills |

### Session & Multi-Client

| Command | Purpose |
|---------|---------|
| `/session-broadcast` | Send message to all sessions |
| `/session-inbox` | Check messages from other sessions |
| `/session-list` | List active sessions |
| `/mcp-setup` | Configure MCP for Codex/Cursor |
| `/webhook-setup` | Setup GitHub Actions automation |

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

**67 skills across 22 categories.** Run `/skill-list` to see all.

---

## Architecture

```
claude-code-harness/
├── commands/     # 21 slash commands
├── skills/       # 67 skills (22 categories)
├── agents/       # 6 sub-agents (parallel workers)
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
