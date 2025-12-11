# cursor-cc-plugins

### Cursor ↔ Claude Code 2-Agent Development Workflow

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code Plugin](https://img.shields.io/badge/Claude%20Code-Plugin-blue)](https://docs.anthropic.com/en/docs/claude-code)
[![2-Agent](https://img.shields.io/badge/2--Agent-Workflow-orange)](docs/usage-2agent.md)
[![Version](https://img.shields.io/badge/version-0.3.9-green)](CHANGELOG.md)

**Cursor (PM) plans. Claude Code (Worker) builds. Two AIs, one seamless workflow.**

This plugin enables a **2-agent development workflow** where Cursor handles planning, task breakdown, and review, while Claude Code handles implementation, testing, and staging deployment. Solo mode (Claude Code only) is also available as a fallback.

[English](README.md) | [日本語](README.ja.md)

![Cursor plans, Claude Code builds](docs/images/workflow-en.png)

---

## How It Works

```
You: "I want to build a blog app"

    ↓ Cursor (PM) creates a plan

Cursor: "Tasks organized. Handing off to Claude Code."

    ↓ You copy & paste to Claude Code

Claude Code (Worker): "Implemented! Ready for review."

    ↓ You copy & paste back to Cursor

Cursor: "Review passed. Let's deploy."
```

**The Plan → Build → Review cycle, powered by two specialized AIs.**

---

## Quick Start

### Step 1: Install

```bash
/plugin marketplace add Chachamaru127/cursor-cc-plugins
/plugin install cursor-cc-plugins
```

### Step 2: Setup ⭐

```bash
/setup-2agent
```

Creates: `AGENTS.md`, `Plans.md`, `.cursor/commands/`

### Step 3: Start with Cursor

Open Cursor and describe what you want to build:

```
You → Cursor: "I want to build an e-commerce site"
Cursor: "Great! Let me break this down into tasks..."
```

When implementation is needed, Cursor outputs a task for Claude Code.

---

## The Workflow

```
┌─────────────────┐                      ┌─────────────────┐
│  Cursor (PM)    │                      │  Claude Code    │
│                 │                      │   (Worker)      │
│  • Plan         │   Plans.md (shared)  │  • Implement    │
│  • Review       │ ◄──────────────────► │  • Test         │
│  • Prod deploy  │                      │  • Staging      │
└────────┬────────┘                      └────────┬────────┘
         │   /handoff-to-claude                        │
         └───────────────────────────────────────►│
         │◄───────────────────────────────────────┘
         │   /handoff-to-cursor
```

**You bridge Cursor and Claude Code with copy & paste.** This keeps you in control and aware of everything happening.

---

## Commands

### Claude Code Commands

| Command | What It Does |
|---------|--------------|
| `/setup-2agent` | **First step.** Creates workflow files |
| `/update-2agent` | Updates existing setup to latest version |
| `/init` | Initialize a new project |
| `/plan` | Create a plan |
| `/work` | Implement tasks |
| `/review` | Review changes |
| `/start-task` | Receives task from Cursor |
| `/handoff-to-cursor` | Sends completion report to Cursor |
| `/sync-status` | Sync Plans.md status |
| `/health-check` | Environment diagnostics |
| `/cleanup` | Clean up files (Plans.md archiving, etc.) |

### Cursor Commands

| Command | What It Does |
|---------|--------------|
| `/handoff-to-claude` | Sends task to Claude Code |
| `/review-cc-work` | Reviews Claude Code's work |
| `/start-session` | Start session → plan → assign (automated flow) |
| `/project-overview` | View project overview |
| `/plan-with-cc` | Plan with Claude Code |

> For new projects from scratch, run `/init` after `/setup-2agent`.

---

## Solo Mode (Fallback)

No Cursor? Claude Code works alone too:

```bash
"I want to build a Todo app"
```

Solo mode is simpler but lacks the PM/Worker separation and cross-review benefits.

> Details: [docs/usage-solo.md](docs/usage-solo.md)

---

## Features

- **2-Agent Workflow**: PM/Worker separation with clear responsibilities
- **Safety First**: dry-run mode by default, protected branches, 3-retry rule
- **VibeCoder Friendly**: Natural language interface for non-technical users
- **Auto Cleanup** (v0.3.7+): PostToolUse hooks for automatic file size monitoring
- **Incremental Updates**: `/update-2agent` for seamless version upgrades
- **Configurable**: `cursor-cc.config.json` for team-specific settings

---

## Documentation

| Document | Description |
|----------|-------------|
| [2-Agent Guide](docs/usage-2agent.md) | Full workflow details |
| [Solo Guide](docs/usage-solo.md) | Claude Code only |
| [Admin Guide](docs/ADMIN_GUIDE.md) | Team setup, safety config |
| [Architecture](docs/ARCHITECTURE.md) | Technical internals |
| [Limitations](docs/LIMITATIONS.md) | Known constraints |

---

## Links

- [GitHub](https://github.com/Chachamaru127/cursor-cc-plugins)
- [Issues](https://github.com/Chachamaru127/cursor-cc-plugins/issues)

MIT License
