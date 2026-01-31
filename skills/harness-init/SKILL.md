---
name: harness-init
description: "Project setup with environment check, file generation, SSOT sync, and validation. Use when user mentions '/harness-init', new project setup, launch a project, or introduce harness to existing project. Do NOT load for: implementation, reviews, or planning."
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash", "Task"]
argument-hint: "[project-name] [--mode=solo|2agent] [--stack=next-supabase] [--name=app-name]"
disable-model-invocation: true
---

# Harness Init Skill

Sets up a project so VibeCoder can start development with natural language only.
**Completes with minimum 1 question**, ready to start development immediately.

## Quick Reference

- "**Want to launch a new project fastest**" → this skill
- "**Leave it to you**" / "**Quickly**" → proceed with defaults, no questions
- "**With Next.js + Supabase**" → technology specification
- "**Introduce harness to existing project**" → analyze existing code

## Deliverables

- Real project generation (e.g., create-next-app) + initial setup
- Prepare `Plans.md` / `AGENTS.md` / `CLAUDE.md` / `.claude/`
- **Environment diagnosis** → **SSOT initialization** → **Final validation**
- → **Ready to run Plan→Work→Review immediately**

## Usage

```bash
/harness-init                              # Interactive setup (min 1 question)
/harness-init blog --mode=solo             # With partial specification
/harness-init --stack=next-supabase        # Specify tech stack
```

## Feature Details

| Feature | Reference |
|---------|-----------|
| **Execution Flow** | See [references/execution-flow.md](references/execution-flow.md) |
| **Smart Defaults** | See [references/smart-defaults.md](references/smart-defaults.md) |
| **Generated Files** | See [references/generated-files.md](references/generated-files.md) |

## Optimized Flow

**Before**: Up to 11 dialogue rounds
**After**: Minimum 1, maximum 2 dialogue rounds

```
Step 1: Unified question (1 time)
  ├─ What are you building?
  ├─ Who will use it?
  └─ Leave it to me or detailed settings?

Step 2: Confirmation (skip if "leave it to me")
  └─ Tech stack + project name

→ Execute setup (includes background analysis)

Step 3: Completion report
```

## Arguments

| Argument | Description | Example |
|----------|-------------|---------|
| `[project description]` | What to build | `"EC site"` |
| `--mode` | solo / 2agent | `--mode=solo` |
| `--stack` | Tech stack | `--stack=next-supabase` |
| `--name` | Project name | `--name=my-app` |
| `--lang` | Language | `--lang=en` |

## Smart Defaults

| Item | Default | Auto-determination |
|------|---------|-------------------|
| Language | ja | Config file |
| Mode | Solo | 2-Agent if .cursor/ exists |
| Tech stack | next-supabase | In auto mode |
| Skills Gate | Auto-configured | Adjust with `/skills-update` |

## Next Steps

After setup:
- "`/planning` I want to create XXX" → Create plan
- "`/work`" → Execute tasks in Plans.md
- "`npm run dev`" → Start dev server
