# cursor-cc-plugins

### Cursor ↔ Claude Code 2-Agent Development Workflow

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code Plugin](https://img.shields.io/badge/Claude%20Code-Plugin-blue)](https://docs.anthropic.com/en/docs/claude-code)
[![2-Agent](https://img.shields.io/badge/2--Agent-Workflow-orange)](docs/usage-2agent.md)
[![Version](https://img.shields.io/badge/version-0.4.8-green)](CHANGELOG.md)

**Cursor (PM) plans. Claude Code (Worker) builds. Two AIs, one seamless workflow.**

This plugin enables a **2-agent development workflow** where Cursor handles planning, task breakdown, and review, while Claude Code handles implementation, testing, and staging deployment. Solo mode (Claude Code only) is also available as a fallback.

[English](README.md) | [日本語](README.ja.md)

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
/install cursor-cc-plugins
```

### Step 2: Setup

```bash
/setup-2agent
```

This creates:
```
./
├── AGENTS.md              # Development flow overview (shared)
├── CLAUDE.md              # Claude Code specific settings
├── Plans.md               # Task management (shared)
├── .cursor-cc-version     # Version tracking
├── .cursor/
│   └── commands/          # Cursor PM commands
│       ├── start-session.md
│       ├── handoff-to-claude.md
│       ├── review-cc-work.md
│       ├── plan-with-cc.md
│       └── project-overview.md
└── .claude/
    ├── rules/             # Workflow rules (v0.4.0+)
    │   ├── workflow.md
    │   └── coding-standards.md
    └── memory/            # Session memory
        ├── session-log.md
        ├── decisions.md
        └── patterns.md
```

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
         │   /handoff-to-claude                   │
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

## Features

### Core Features
- **2-Agent Workflow**: PM/Worker separation with clear responsibilities
- **Safety First**: dry-run mode by default, protected branches, 3-retry rule
- **VibeCoder Friendly**: Natural language interface for non-technical users
- **Incremental Updates**: `/update-2agent` for seamless version upgrades

### v0.4.0+ New Features
- **Claude Rules** (`.claude/rules/`): Conditional rules with YAML frontmatter `paths:` support
- **Plugin Hooks** (`hooks/hooks.json`): SessionStart and PostToolUse hooks for automation
- **Named Sessions**: Use `/rename {name}` and `/resume {name}` for session tracking
- **Session Memory** (`.claude/memory/`): Persist decisions, patterns, and session logs
- **CI Consistency Check**: Automated validation of plugin integrity
- **Self-Healing CI**: `scripts/ci/diagnose-and-fix.sh` for automatic issue detection and fixes

### Auto Cleanup (v0.3.7+)
- PostToolUse hooks for automatic file size monitoring
- Configurable thresholds via `.cursor-cc-config.yaml`

---

## Solo Mode (Fallback)

No Cursor? Claude Code works alone too:

```bash
"I want to build a Todo app"
```

Solo mode is simpler but lacks the PM/Worker separation and cross-review benefits.

> Details: [docs/usage-solo.md](docs/usage-solo.md)

---

## Updating

When a new version is released:

```bash
/update-2agent
```

This preserves your tasks in Plans.md while updating templates and commands.

---

## Documentation

| Document | Description |
|----------|-------------|
| [2-Agent Guide](docs/usage-2agent.md) | Full workflow details |
| [Solo Guide](docs/usage-solo.md) | Claude Code only |
| [Admin Guide](docs/ADMIN_GUIDE.md) | Team setup, safety config |
| [Changelog](CHANGELOG.md) | Version history |

---

## Links

- [GitHub](https://github.com/Chachamaru127/cursor-cc-plugins)
- [Issues](https://github.com/Chachamaru127/cursor-cc-plugins/issues)

MIT License
