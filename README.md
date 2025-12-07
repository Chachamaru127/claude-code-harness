# cursor-cc-plugins v2.2

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code Plugin](https://img.shields.io/badge/Claude%20Code-Plugin-blue)](https://docs.anthropic.com/en/docs/claude-code)

**Build high-quality projects using only natural language.**

A 2-agent workflow plugin for Cursor ↔ Claude Code collaboration, designed for VibeCoders who want to develop without deep technical knowledge.

---

## Features

### v2.2 (Latest)
- 🎯 **One-Command Setup**: `/setup-2agent` instantly configures the Cursor + Claude Code 2-agent system
- 🔧 **Troubleshooting**: Say "it's broken" or "not working" for automatic diagnosis and repair
- 📋 **Enhanced Cursor Integration**: PM commands auto-deployed to `.cursor/`

### v2.1
- 🔧 **Auto Error Recovery**: Detects build/test errors and auto-fixes up to 3 times
- ⚡ **Parallel Processing**: Independent tasks run in parallel (up to 67% faster)
- 🧠 **Session Memory**: Automatically records and recalls previous work and decisions

### v2.0
- 🚀 **Plan → Work → Review Cycle**: Fully automated planning, implementation, and review
- 🏗️ **Real Project Generation**: Automatically runs `create-next-app`, etc.
- 🔍 **Code Review**: Automated security, performance, and quality checks
- 🪝 **Lifecycle Hooks**: Auto-checks project state on session start
- 💡 **VibeCoder Guide**: Ask "what should I do?" to get next action suggestions

---

## Who Is This For?

- **VibeCoders**: Build apps without technical expertise using natural language
- **Teams**: Coordinate work between Cursor (PM) and Claude Code (Worker)
- **Developers**: Automate the plan → implement → review cycle

---

## Installation

```bash
# Add the marketplace
/plugin marketplace add Chachamaru127/cursor-cc-plugins

# Install the plugin
/plugin install cursor-cc-plugins
```

### Project-Level Configuration (Team Sharing)

Add to your project's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "cursor-cc-marketplace": {
      "source": {
        "source": "github",
        "repo": "Chachamaru127/cursor-cc-plugins"
      }
    }
  },
  "enabledPlugins": {
    "cursor-cc-plugins@cursor-cc-marketplace": true
  }
}
```

---

## Quick Start

### For VibeCoders (No Technical Knowledge Required)

```
You: "I want to build a blog"

Claude Code:
1. Asks a few questions (Who will use it? Similar services?)
2. Suggests tech stack (Next.js + Supabase recommended)
3. Auto-generates the project
4. Say "run it" to start the dev server
```

### Commands

| Command | Purpose | Example Phrase |
|---------|---------|----------------|
| `/init` | Start a project | "I want to build a blog" |
| `/setup-2agent` | Setup 2-agent system | "Setup Cursor integration" |
| `/plan` | Convert feature to plan | "Add authentication" |
| `/work` | Execute the plan | "Start phase 1" |
| `/review` | Code review | "Review the code" |
| `/start-task` | Start next task | "Next task" |
| `/handoff-to-cursor` | Report completion | "Done" |
| `/sync-status` | Check status | "What's the status?" |

---

## Plan → Work → Review Cycle

```
┌─────────────────────────────────────────────────────────┐
│                      /plan                              │
│  "I want to build X" → Structured task list             │
│  - WebSearch for latest tech recommendations            │
│  - Adds phased tasks to Plans.md                        │
└─────────────────────┬───────────────────────────────────┘
                      ▼
┌─────────────────────────────────────────────────────────┐
│                      /work                              │
│  Execute plan → Generate actual code                    │
│  - Track progress with TodoWrite                        │
│  - Run create-next-app, etc.                            │
│  - Generate files                                       │
└─────────────────────┬───────────────────────────────────┘
                      ▼
┌─────────────────────────────────────────────────────────┐
│                      /review                            │
│  Check code quality                                     │
│  - Security                                             │
│  - Performance                                          │
│  - Code quality                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Agents

| Agent | Purpose |
|-------|---------|
| project-analyzer | Detects new vs existing projects |
| project-scaffolder | Auto-generates project structure |
| code-reviewer | Multi-aspect code quality review |
| ci-cd-fixer | Auto-fixes CI failures (up to 3 attempts) |
| project-state-updater | Syncs Plans.md state |
| error-recovery | Detects and auto-repairs errors |

---

## Skills

| Skill | Trigger Phrases |
|-------|-----------------|
| session-init | "start session", "begin work" |
| workflow-guide | "explain the workflow" |
| plans-management | "add a task" |
| vibecoder-guide | "what should I do?", "what's next?" |
| session-memory | "what did we do last time?", "continue from before" |
| parallel-workflows | "run in parallel", "do these together" |
| troubleshoot | "it's broken", "not working", "diagnose" |

---

## Natural Language Phrases

| What You Want | What to Say |
|---------------|-------------|
| Start a project | "I want to build X" |
| Continue work | "continue", "next" |
| Run the app | "run it", "show me" |
| Add a feature | "add X feature" |
| Review code | "check it", "review" |
| Get help | "what should I do?" |
| Delegate everything | "do everything", "take over" |
| Fix errors | "fix it", "repair the error" |
| Resume previous work | "continue from last time" |
| Speed up | "do these together", "run in parallel" |
| Troubleshoot | "it's broken", "diagnose" |
| Setup 2-agent | "setup Cursor integration" |

---

## Plans.md Markers

| Marker | Meaning |
|--------|---------|
| `cursor:requested` | Requested by Cursor |
| `cc:TODO` | Not started |
| `cc:WIP` | Work in progress |
| `cc:done` | Completed (awaiting review) |
| `cursor:verified` | Verified by Cursor |

---

## 2-Agent Architecture

```
Cursor (PM)              Claude Code (Worker)
    │                           │
    │  Task Request             │
    │──────────────────────────>│
    │                           │
    │                           │ Implement, Test, Commit
    │                           │
    │  Completion Report        │
    │<──────────────────────────│
    │                           │
    │ Review & Deploy Decision  │
    │                           │
```

### Roles

| Agent | Role | Responsibilities |
|-------|------|------------------|
| **Cursor (PM)** | Project Manager | Planning, review, production deployment decisions |
| **Claude Code (Worker)** | Developer | Coding, testing, staging deployment |

---

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## License

MIT License - see [LICENSE](LICENSE) for details.

---

## Links

- [GitHub Repository](https://github.com/Chachamaru127/cursor-cc-plugins)
- [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code)
- [Report Issues](https://github.com/Chachamaru127/cursor-cc-plugins/issues)
