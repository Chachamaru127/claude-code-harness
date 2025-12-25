# Claude harness

English | [日本語](README.md)

![Claude harness](docs/images/claude-harness-logo-with-text.png)

**Elevate Solo Development to Pro Quality**

A development harness that runs Claude Code in an autonomous "Plan → Work → Review" cycle,
systematically preventing **confusion, sloppiness, accidents, and forgetfulness**.

[![Version: 2.6.4](https://img.shields.io/badge/version-2.6.4-blue.svg)](VERSION)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE.md)
[![Harness Score](https://img.shields.io/badge/harness_score-92%2F100-brightgreen.svg)](#scoring-criteria)

---

## What's New in v2.6

### Quality Gate System (v2.6.2)

**Auto-suggest appropriate quality standards at the right time**

| Gate Type | Targets | Suggestion |
|-----------|---------|------------|
| **TDD** | `[feature]` tag, `src/core/` | "Would you like to write tests first?" |
| **Security** | Auth/API/Payments | Security checklist displayed |
| **a11y** | UI Components | Accessibility check |
| **Performance** | DB queries, loops | N+1 query warning |

- **Suggestions, not enforcement** (VibeCoder-friendly)
- Auto-assigns quality markers when creating plans with `/plan-with-agent`

### Claude-mem Integration (v2.6.0)

```bash
/harness-mem  # Integrate Claude-mem
```

**Learn from past mistakes and avoid repeating them**

- Auto-reference past test tampering warnings and build error solutions
- `impl` / `review` / `verify` skills leverage past knowledge
- Important learnings can be promoted to SSOT (decisions.md/patterns.md)

### Skill Hierarchy Reminder (v2.6.1)

When using a parent skill, **related child skills are auto-suggested**.
No more wondering "which skill should I read?"

---

## In 3 Lines

| Command | What it does | Result |
|---------|--------------|--------|
| `/plan-with-agent` | Brainstorm → Plan | **Plans.md** created |
| `/work` | Execute plan (parallel support) | Working code |
| `/harness-review` | Multi-perspective review | Pro quality |

![Quick Overview](docs/images/quick-overview.png)

---

## 4 Problems Solved

| Problem | Symptom | Solution |
|---------|---------|----------|
| **Confusion** | Don't know what to do | `/plan-with-agent` to organize |
| **Sloppiness** | Quality drops | `/harness-review` for multi-perspective check |
| **Accidents** | Dangerous operations | Hooks for auto-guard |
| **Forgetfulness** | Missing context | SSOT + Claude-mem for continuity |

![Four Walls](docs/images/four-walls.png)

---

## Get Started in 5 Minutes

### 1. Install

```bash
cd /path/to/your-project
claude

# Add marketplace → Install
/plugin marketplace add Chachamaru127/claude-code-harness
/plugin install claude-code-harness@claude-code-harness-marketplace
```

### 2. Initialize

```bash
/harness-init
```

### 3. Development Loop

```bash
/plan-with-agent  # Plan
/work             # Implement
/harness-review   # Review
```

<details>
<summary>Local Clone (for developers)</summary>

```bash
git clone https://github.com/Chachamaru127/claude-code-harness.git ~/claude-plugins/claude-code-harness
cd /path/to/your-project
claude --plugin-dir ~/claude-plugins/claude-code-harness
```

</details>

---

## Who Is This For?

| User | Benefit |
|------|---------|
| **Solo Developers** | Balance speed and quality |
| **Freelancers** | Submit review results as deliverables |
| **VibeCoder** | Drive development with natural language |
| **Cursor Users** | 2-Agent workflow for role separation |

---

## Features

### Safety (Hooks)

| Feature | Description |
|---------|-------------|
| **Protected Path Guard** | Reject writes to `.git/`, `.env`, secret keys |
| **Dangerous Command Confirmation** | Require confirmation for `git push`, `rm -rf`, `sudo` |
| **Safe Command Allow** | Auto-allow `git status`, `npm test` |

### Continuity (SSOT + Memory)

| Feature | Description |
|---------|-------------|
| **decisions.md** | Accumulate decisions (Why) |
| **patterns.md** | Accumulate reusable patterns (How) |
| **Claude-mem Integration** | Leverage past learnings across sessions |

### Quality Assurance (3-Layer Defense)

| Layer | Mechanism | Enforcement |
|-------|-----------|-------------|
| Layer 1 | Rules (test-quality.md, etc.) | Conscience-based |
| Layer 2 | Skills built-in guardrails | Contextual enforcement |
| Layer 3 | Hooks for tampering detection | Technical enforcement |

**Prohibited Patterns**: Changes to `it.skip()`, assertion deletion, hollow implementations

---

## Command Quick Reference

### Core (Plan → Work → Review)

| Command | Purpose |
|---------|---------|
| `/harness-init` | Initialize project |
| `/plan-with-agent` | Create plan |
| `/work` | Implement tasks (parallel support) |
| `/harness-review` | Multi-perspective review |
| `/skill-list` | List all skills |

### Quality & Operations

| Command | Purpose |
|---------|---------|
| `/validate` | Batch verify build & tests |
| `/harness-update` | Update plugin |
| `/cleanup` | Organize Plans.md, etc. |
| `/sync-status` | Check progress → Suggest next action |

### Knowledge & Collaboration

| Command | Purpose |
|---------|---------|
| `/remember` | Record learnings to Rules/Commands/Skills |
| `/harness-mem` | Claude-mem integration setup |
| `/handoff-to-cursor` | Report completion to Cursor (PM) |

### Skills (Auto-triggered by conversation)

| Skill | Trigger Examples |
|-------|-----------------|
| `impl` | "implement", "add feature" |
| `review` | "review", "security check" |
| `verify` | "build", "error recovery" |
| `auth` | "login feature", "Stripe payment" |
| `deploy` | "deploy to Vercel" |
| `ui` | "create a hero section" |

Use `/skill-list` to see all 67 skills.

---

## Cursor 2-Agent Workflow (Optional)

Say "I want to start 2-agent workflow" for auto-setup.

| Role | Responsibility |
|------|----------------|
| **Cursor (PM)** | Planning, Review, Task Management |
| **Claude Code (Worker)** | Implementation, Testing, Debugging |

**Workflow**:

```
Cursor: /plan-with-cc → /handoff-to-claude
Claude Code: /work → /handoff-to-cursor
Cursor: /review-cc-work → Approve or Request Fixes
```

---

## Architecture

```
claude-code-harness/
├── commands/     # Slash commands (21)
├── skills/       # Skills (67 / 22 categories)
├── agents/       # Sub-agents (6)
├── hooks/        # Lifecycle hooks
├── scripts/      # Guard & automation scripts
├── templates/    # Generation templates
└── docs/         # Documentation
```

### 3-Layer Design

| Layer | File | Role |
|-------|------|------|
| Profile | `profiles/claude-worker.yaml` | Persona definition |
| Workflow | `workflows/default/*.yaml` | Work flow |
| Skill | `skills/**/SKILL.md` | Specific functionality |

---

## Validation

```bash
# Validate plugin structure
./tests/validate-plugin.sh

# Consistency check
./scripts/ci/check-consistency.sh
```

---

## Scoring Criteria

| Category | Max | Score |
|----------|----:|------:|
| Onboarding | 15 | 14 |
| Workflow Design | 20 | 19 |
| Safety | 15 | 15 |
| Continuity | 10 | 9 |
| Automation | 10 | 9 |
| Extensibility | 10 | 8 |
| Quality Assurance | 10 | 8 |
| Documentation | 10 | 10 |
| **Total** | **100** | **92 (S)** |

---

## Documentation

- [Implementation Guide](IMPLEMENTATION_GUIDE.md)
- [Development Flow Guide](DEVELOPMENT_FLOW_GUIDE.md)
- [Memory Policy](docs/MEMORY_POLICY.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Cursor Integration](docs/CURSOR_INTEGRATION.md)
- [Changelog](CHANGELOG.md) | [Japanese](CHANGELOG.ja.md)

---

## Acknowledgments

- **Hierarchical Skill Structure**: Implemented based on feedback from [AI Masao](https://note.com/masa_wunder)
- **Test Tampering Prevention**: [Beagle](https://github.com/beagleworks) "Techniques to prevent Claude Code from taking shortcuts with tests" (Claude Code Meetup Tokyo 2025.12.22)

---

## References

- [Claude Code Plugins (Official)](https://docs.claude.com/en/docs/claude-code/plugins)
- [anthropics/claude-code](https://github.com/anthropics/claude-code)
- [davila7/claude-code-templates](https://github.com/davila7/claude-code-templates)

---

## License

**MIT License** - Free to use, modify, distribute, and commercialize.

- [English](LICENSE.md) | [Japanese](LICENSE.ja.md)
