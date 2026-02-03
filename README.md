<p align="center">
  <img src="docs/images/claude-harness-logo-with-text.png" alt="Claude Harness" width="400">
</p>

<p align="center">
  <strong>Plan. Work. Review. Ship.</strong><br>
  <em>Turn Claude Code into a disciplined development partner.</em>
</p>

<p align="center">
  <a href="VERSION"><img src="https://img.shields.io/badge/version-2.17.1-blue.svg" alt="Version"></a>
  <a href="LICENSE.md"><img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License"></a>
  <a href="docs/CLAUDE_CODE_COMPATIBILITY.md"><img src="https://img.shields.io/badge/Claude_Code-v2.1+-purple.svg" alt="Claude Code"></a>
  <img src="https://img.shields.io/badge/Skills-42-orange.svg" alt="Skills">
</p>

<p align="center">
  English | <a href="README_ja.md">日本語</a>
</p>

---

## Why Harness?

Claude Code is powerful—but sometimes it needs structure.

```mermaid
graph LR
    A[Your Idea] --> B["/plan-with-agent"]
    B --> C["Plans.md"]
    C --> D["/work"]
    D --> E["Code + Self-Review"]
    E --> F["/harness-review"]
    F --> G["Ship It"]
```

**Three commands. One workflow. Production-ready code.**

> **For VibeCoders**: Just say "I want a login form with email validation" and Harness handles planning, implementation, and review automatically.

---

## 🪄 Ultrawork — The Magic Word

> **⚠️ Experimental**: Powerful, but understand it before using.

**"Plan it, implement in parallel, review it, commit it"**

...is tedious to say every time. So:

```
ultrawork
```

**One word. Harness does the rest.**

```mermaid
graph LR
    A["ultrawork"] --> B["Generate Plan"]
    B --> C["Parallel Implementation"]
    C --> D["Self-Review"]
    D --> E["Quality Gate"]
    E --> F["Auto-Commit"]
```

### Before → After

| Before | After |
|--------|-------|
| `/plan-with-agent` → approve → `/work` → `/harness-review` → `git commit` | `ultrawork` |
| 5 command inputs | **1** |
| Press "yes" every time | **Auto-proceeds after plan approval** |
| Confirm every rm -rf | **Whitelist-based auto-approval** |

### Usage

```bash
# Basic (specify task)
ultrawork create a login form

# Specify parallelism
ultrawork --parallel 3 add 5 API endpoints

# Execute all Plans.md tasks
ultrawork --all
```

### Why "Experimental"?

- `rm -rf` and `git push` **only auto-approved for paths specified in plan**
- Auto-expires in 24 hours (runaway prevention)
- Quality gate blocks commit if issues found

**In other words**: Once you approve the plan, Claude takes responsibility to completion.

> 💡 **For busy people**: Type `ultrawork`, approve the plan, go get coffee. Code's ready when you're back.

---

## Requirements

Before installing, ensure you have:

- **Claude Code v2.1+** ([Install Guide](https://docs.anthropic.com/claude-code))
- **Node.js 18+** (for safety hooks)

---

## Install in 30 Seconds

```bash
# Start Claude Code in your project
claude

# Add the marketplace & install
/plugin marketplace add Chachamaru127/claude-code-harness
/plugin install claude-code-harness@claude-code-harness-marketplace

# Initialize your project
/harness-init
```

That's it. Start with `/plan-with-agent`.

---

## The Core Loop

### 1. Plan

Turn ideas into structured tasks.

```bash
/plan-with-agent
```

> "I want a login form with email validation"

Harness creates `Plans.md` with clear acceptance criteria.

### 2. Work

Execute tasks with parallel workers.

```bash
/work              # Auto-detect parallelism
/work --parallel 5 # 5 workers simultaneously
```

Each worker implements, self-reviews, and reports.

### 3. Review

4-perspective code review in parallel.

```bash
/harness-review
```

| Perspective | Focus |
|-------------|-------|
| Security | Vulnerabilities, injection, auth |
| Performance | Bottlenecks, memory, scaling |
| Quality | Patterns, naming, maintainability |
| Accessibility | WCAG compliance, screen readers, UX |

---

## What Changes

| Without Harness | With Harness |
|-----------------|--------------|
| Jumps into code immediately | Plans first, then executes |
| Reviews only when asked | Auto-reviews every change |
| Forgets past decisions | SSOT files preserve context |
| `rm -rf` runs without warning | Dangerous commands blocked |
| Manual git operations | Auto-commits when approved |
| One task at a time | Parallel workers |

> **SSOT** (Single Source of Truth): Files that store decisions and patterns across sessions.

---

## Safety First

Harness protects your codebase with hooks (automatic safety checks):

| Protected | Action |
|-----------|--------|
| `.git/`, `.env`, secrets | Write blocked |
| `rm -rf`, `sudo`, `--force` | Confirmation required |
| `git status`, `npm test` | Auto-allowed |
| Test tampering | Warning triggered |

---

## 42 Skills, Zero Config

Skills are capabilities that auto-load based on context. Use slash commands or just describe what you want.

| Say This | Skill Activates |
|----------|-----------------|
| "implement login" | `impl` |
| "review this code" | `harness-review` |
| "fix the build error" | `verify` |
| "add Stripe payments" | `auth` |
| "deploy to Vercel" | `deploy` |
| "create a hero section" | `ui` |

> **Note**: All skills can be invoked via `/skill-name` command or natural language.

---

## Who Is This For?

| You Are | Harness Helps You |
|---------|-------------------|
| **Developer** | Ship faster with built-in QA |
| **Freelancer** | Deliver review reports to clients |
| **Indie Hacker** | Move fast without breaking things |
| **VibeCoder** | Build apps with natural language |
| **Team Lead** | Enforce standards across projects |

---

## Commands at a Glance

### Core Workflow

| Command | What It Does |
|---------|--------------|
| `/plan-with-agent` | Ideas → `Plans.md` |
| `/work` | Execute tasks in parallel |
| `/harness-review` | 4-perspective review |

### Operations

| Command | What It Does |
|---------|--------------|
| `/harness-init` | Initialize project |
| `/harness-update` | Update plugin |
| `/sync-status` | Check progress |
| `/maintenance` | Clean up old tasks |

### Memory

| Command | What It Does |
|---------|--------------|
| `/sync-ssot-from-memory` | Promote decisions to SSOT |
| `/memory` | Manage SSOT files |

> **How it works**: Skills replaced commands in v2.16. You can invoke them via `/command` or natural language—same functionality, smarter loading.

---

## Architecture

```
claude-code-harness/
├── skills/       # 42 skill definitions
├── agents/       # 8 sub-agents (parallel workers)
├── hooks/        # Safety & automation
├── scripts/      # Guard scripts
└── templates/    # Generation templates
```

---

## Advanced Features

<details>
<summary><strong>Parallel Execution</strong></summary>

```bash
/work --parallel 5
```

Each worker runs independently:
1. Implements assigned task
2. Runs self-review
3. Reports completion

Global review runs after all workers finish.

</details>

<details>
<summary><strong>2-Agent Mode (with Cursor)</strong></summary>

Use Cursor as PM, Claude Code as implementer.

```bash
/handoff       # Report to Cursor PM
```

Plans.md syncs between both.

</details>

<details>
<summary><strong>Codex Integration</strong></summary>

Add OpenAI Codex for second opinions:

```bash
/harness-review  # 4 perspectives + Codex
```

Codex selects 4 relevant experts from 16 specialist types.

> **Setup required**: Install [Codex CLI](https://github.com/openai/codex) and configure API key. This is an optional feature.

</details>

<details>
<summary><strong>Video Generation</strong></summary>

Generate product videos with Remotion:

```bash
/generate-video
```

AI-generated scenes, narration, and effects.

> **Dependencies**: Requires [Remotion](https://www.remotion.dev/) project setup and ffmpeg. This is an optional feature for advanced users.

</details>

<details>
<summary><strong>Agent Trace</strong></summary>

Automatically tracks AI-generated code edits:

```
.claude/state/agent-trace.jsonl
```

**What it does:**
- Records every Edit/Write operation with timestamps
- Shows project name, current task, and recent edits at session end
- Enables `/sync-status` to compare Plans.md with actual changes

**Session end output:**
```
📊 Session Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📁 Project: my-app
🎯 Current Task: Add login form
✅ Completed: 3 tasks
📄 Recent edits:
   - src/components/LoginForm.tsx
   - src/lib/auth.ts
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

No setup required—enabled by default.

</details>

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Command not found | Run `/harness-init` first |
| Plugin not loading | Clear cache: `rm -rf ~/.claude/plugins/cache/claude-code-harness-marketplace/` and restart |
| Hooks not working | Ensure Node.js 18+ is installed |

For more help, [open an issue](https://github.com/Chachamaru127/claude-code-harness/issues).

---

## Uninstall

```bash
/plugin uninstall claude-code-harness
```

This removes the plugin. Project files (Plans.md, SSOT files) remain unchanged.

---

## Documentation

| Resource | Description |
|----------|-------------|
| [Changelog](CHANGELOG.md) | Version history |
| [Claude Code Compatibility](docs/CLAUDE_CODE_COMPATIBILITY.md) | Requirements |
| [Cursor Integration](docs/CURSOR_INTEGRATION.md) | 2-Agent setup |

---

## Contributing

Issues and PRs welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

---

## Acknowledgments

- [AI Masao](https://note.com/masa_wunder) — Hierarchical skill design
- [Beagle](https://github.com/beagleworks) — Test tampering prevention patterns

---

## License

**MIT License** — Free to use, modify, commercialize.

[English](LICENSE.md) | [日本語](LICENSE.ja.md)
