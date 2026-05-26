# Skill Catalog

Reference document for the skill hierarchy, all skill categories, and development skills.

## Skill Evaluation Flow

> 💡 For heavy tasks (parallel reviews, CI fix loops), skills spawn sub-agents from `agents/` in parallel via the Task tool.

**Before starting any work, always follow this flow:**

1. **Evaluate**: Check available skills and assess whether any match the current request
2. **Invoke**: If a matching skill exists, launch it with the Skill tool before starting work
3. **Execute**: Follow the skill's steps to complete the work

```
User request
    ↓
Evaluate skills (is there a match?)
    ↓
YES → Invoke with Skill tool → Follow the skill's steps
NO  → Handle with normal reasoning
```

## Skill Hierarchy

Skills are organized in a **parent skill (category)** and **child skill (specific function)** hierarchy.

```
skills/
├── impl/                  # Implementation (feature additions, test creation)
├── harness-review/        # Review (quality, security, performance)
├── verify/                # Verification (builds, error recovery, fix application)
├── setup/                 # Integrated setup hub (project init, tool config, 2-Agent, harness-mem, Codex CLI, rule localization)
├── memory/                # Memory management (SSOT, decisions.md, patterns.md, SSOT promotion, memory search)
├── troubleshoot/          # Diagnostics & repair (errors, CI failures)
├── principles/            # Principles & guidelines (VibeCoder, diff editing)
├── auth/                  # Authentication & payments (Clerk, Supabase, Stripe)
├── deploy/                # Deployment (Vercel, Netlify, analytics)
├── ui/                    # UI (components, feedback)
├── handoff/               # Workflow (handoff, auto-fix)
├── notebookLM/            # Documentation (NotebookLM, YAML)
└── maintenance/           # Maintenance (cleanup)
```

**How to use:**
1. Launch the parent skill with the Skill tool
2. The parent skill routes to the appropriate child skill (doc.md) based on user intent
3. Follow the child skill's steps to complete the work

## All Skill Categories

| Category | Purpose | Trigger Examples |
|---------|---------|-----------------|
| work | Task implementation (auto-scope detection, --codex support) | "implement", "do it all", "/work" |
| breezing | Full automated run with Agent Teams (--codex support) | "run with team", "breezing" |
| impl | Implementation, feature additions, test creation | "implement", "add feature", "write code" |
| harness-review | Code review, quality checks | "review", "security", "performance" |
| verify | Build verification, error recovery | "build", "error recovery", "verify" |
| setup | Setup integration hub (project init, tool config, 2-Agent, harness-mem, Codex CLI, rule localization) | "setup", "CLAUDE.md", "initialize", "CI setup", "2-Agent", "Cursor config", "harness-mem", "codex-setup" |
| memory | SSOT management, memory search, SSOT promotion, Cursor-linked memory | "SSOT", "decisions.md", "merge", "SSOT promotion", "memory search", "harness-mem" |
| principles | Development principles, guidelines | "principles", "VibeCoder", "safety" |
| auth | Authentication, payment features | "login", "Clerk", "Stripe", "payments" |
| deploy | Deployment, analytics | "deploy", "Vercel", "GA" |
| ui | UI component generation | "component", "hero", "form" |
| handoff | Handoff, auto-fix | "handoff", "report to PM", "auto-fix" |
| notebookLM | Documentation generation | "documentation", "NotebookLM", "slides" |
| troubleshoot | Diagnostics and repair (including CI failures) | "not working", "error", "CI failed" |
| maintenance | File organization | "organize", "cleanup" |
| harness-plan-brief | Pre-work Plan Brief HTML generation (Phase 65.1) | "plan brief", "plan summary", "plan review" |
| harness-accept | Handoff Acceptance Demo HTML generation (Phase 65.2) | "acceptance decision", "ship/wait/reject", "acceptance review" |
| harness-progress | Progress Tracker HTML generation + auto-regeneration (Phase 65.4) | "progress check", "progress board", "dashboard" |

## Development Skills (Private)

The following skills are for development and experimentation and are not included in the repository (excluded via .gitignore):

```
skills/
├── test-*/      # Test skills
└── x-promo/     # X (Twitter) post creation skill (development use)
```

These skills should only be used in individual development environments and must not be included in plugin distributions.

## Related Documentation

- [CLAUDE.md](../CLAUDE.md) - Project development guide (overview)
- [docs/CLAUDE-feature-table.md](./CLAUDE-feature-table.md) - Claude Code feature utilization table
- [docs/CLAUDE-commands.md](./CLAUDE-commands.md) - Key command reference
- [.claude/rules/skill-editing.md](../.claude/rules/skill-editing.md) - Skill file editing rules
