---
description: Project setup (environment check → file generation → SSOT sync → validation)
---

# /harness-init - Project Setup

Sets up a project so VibeCoder can start development with natural language only.
**Completes with minimum 1 question**, ready to start development immediately.

## VibeCoder Quick Reference

- "**Want to launch a new project fastest**" → this command
- "**Leave it to you**" "**Quickly**" → proceed with defaults, no questions
- "**With Next.js + Supabase**" → technology specification is also possible
- "**Introduce harness to existing project**" → analyze existing code and add workflow

## Deliverables

- Real project generation (e.g., create-next-app) + initial setup
- Prepare `Plans.md` / `AGENTS.md` / `CLAUDE.md` / `.claude/` etc.
- **Environment diagnosis** → **SSOT initialization** → **Final validation** all at once
- → **Ready to run Plan→Work→Review immediately**

---

## 🚀 Optimized Flow

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

---

## Execution Flow

### Step 0: Argument Check and Fast Track Judgment

**Determine by arguments or trigger words**:

| Input | Action |
|-------|--------|
| `leave it to me` `quickly` `all defaults` | → Fast track (skip Step 1) |
| `/harness-init blog --mode=solo` | → Parse arguments, skip specified items |
| No arguments | → Go to Step 1 |

**Fast track defaults**:
- Language: ja
- Mode: Solo (if no .cursor/), 2-Agent (if .cursor/ exists)
- Tech: auto (next-supabase base)
- Skills Gate: Auto-determine from project type

### Step 1: Unified Question (Complete in 1 time)

**Start project analysis in background** while showing questions:

```bash
# Background analysis (parallel execution)
CODE_COUNT=$(find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.py" \) \
  ! -path "*/node_modules/*" ! -path "*/.venv/*" 2>/dev/null | wc -l | tr -d ' ')
HAS_CURSOR=$([ -d .cursor ] && echo "true" || echo "false")
HAS_PACKAGE=$([ -f package.json ] && echo "true" || echo "false")
```

**Present 3 questions simultaneously with AskUserQuestion**:

```json
{
  "questions": [
    {
      "question": "What are you building? (Select 'Existing project' for existing projects)",
      "header": "Project",
      "options": [
        {"label": "Web app (blog, EC, etc.)", "description": "Build with Next.js + Supabase"},
        {"label": "API / Backend", "description": "Build with Express / FastAPI"},
        {"label": "Introduce to existing project", "description": "Add workflow files only"},
        {"label": "Other", "description": "Specify freely"}
      ],
      "multiSelect": false
    },
    {
      "question": "Who will use it?",
      "header": "Target Users",
      "options": [
        {"label": "Myself only", "description": "Personal project"},
        {"label": "Team", "description": "Internal tools / collaborative development"},
        {"label": "Public", "description": "Public service"}
      ],
      "multiSelect": false
    },
    {
      "question": "Choose setup method",
      "header": "Mode",
      "options": [
        {"label": "Leave it to me (Recommended)", "description": "Auto-configure with optimal defaults"},
        {"label": "Detailed settings", "description": "Specify tech stack and project name"}
      ],
      "multiSelect": false
    }
  ]
}
```

**Wait for response** (only once)

### Step 2: Additional Questions (Only for Detailed Settings)

**Skip this step** when "Leave it to me" is selected.

Only when "Detailed settings" is selected:

```json
{
  "questions": [
    {
      "question": "Which tech stack?",
      "header": "Tech",
      "options": [
        {"label": "Next.js + Supabase (Recommended)", "description": "Full-stack, free to start"},
        {"label": "Next.js + FastAPI", "description": "More flexible backend"},
        {"label": "Other", "description": "Specify Rails, Django, etc."}
      ],
      "multiSelect": false
    },
    {
      "question": "Enter project name",
      "header": "Name",
      "options": [
        {"label": "Auto-generate", "description": "Generate in my-app-XXXXXX format"},
        {"label": "Specify", "description": "Enter your preferred name"}
      ],
      "multiSelect": false
    }
  ]
}
```

**Wait for response**

---

## Smart Defaults

To reduce questions, use auto-determination or default values for the following:

| Item | Default | Auto-determination Condition |
|------|---------|----------------------------|
| Language | ja | Can change in config file |
| Mode | Solo | 2-Agent if .cursor/ exists |
| Tech stack | next-supabase | In auto mode |
| Skills Gate | Auto-configured | Adjust later with `/skills-update` |

**Overridable in config** (`claude-code-harness.config.json`):
```json
{
  "i18n": { "language": "en" },
  "scaffolding": {
    "tech_choice_mode": "fixed",
    "base_stack": "rails-postgres"
  }
}
```

---

## Phase 2: Project Analysis and Branching

### Project Determination (3 values)

```
Combine Step 1 response + background analysis result

"Introduce to existing" selected → project_type: "existing"
"Web app" or "API" selected → directory analysis:
  ├── Empty or .git only → project_type: "new"
  ├── Code 10+ → project_type: "existing" (show warning)
  └── Code 1-9 → project_type: "ambiguous"
```

**Ambiguous case confirmation** (only for ambiguous):

> ⚠️ Files exist in directory ({{CODE_COUNT}} files)
>
> 🅰️ **Continue as new** (keep existing files while setting up)
> 🅱️ **Treat as existing** (add workflow files only)

---

## Phase 3: Setup Execution

### New Project (project_type: "new")

1. **Project generation** (can parallelize with Task tool)
   ```bash
   npx create-next-app@latest {{PROJECT_NAME}} --typescript --tailwind --eslint --app --src-dir
   cd {{PROJECT_NAME}}
   npm install @supabase/supabase-js lucide-react
   ```

2. **Workflow file generation**
   - AGENTS.md, CLAUDE.md, Plans.md
   - .claude/settings.json (non-destructive merge)
   - .claude/memory/ (decisions.md, patterns.md)

3. **Quality protection rules deployment**
   - .claude/rules/test-quality.md
   - .claude/rules/implementation-quality.md

### Existing Project (project_type: "existing")

1. **Check existing files**
   ```bash
   [ -f AGENTS.md ] && echo "AGENTS.md: exists" || echo "missing"
   [ -f CLAUDE.md ] && echo "CLAUDE.md: exists" || echo "missing"
   [ -f Plans.md ] && echo "Plans.md: exists" || echo "missing"
   ```

2. **Add only missing files** (don't touch existing)

3. **.claude/settings.json is non-destructive merge**

---

## Phase 4: Environment Diagnosis (Auto-execute)

```bash
# Git
command -v git >/dev/null 2>&1 && echo "✅ git" || echo "❌ git"

# Node.js (if applicable)
command -v node >/dev/null 2>&1 && echo "✅ node $(node -v)" || echo "⚠️ node"

# GitHub CLI (optional)
command -v gh >/dev/null 2>&1 && echo "✅ gh" || echo "⚠️ gh"
```

Show warning if issues exist. **No questions** (information only).

### Phase 4.5: Hooks Permission Check (Auto-execute)

**Auto-fix execution permissions for shell scripts in `.claude/hooks/`**:

```bash
# Check and fix .claude/hooks/*.sh execution permissions
if [ -d .claude/hooks ]; then
  FIXED_COUNT=0
  for script in .claude/hooks/*.sh; do
    [ -f "$script" ] || continue
    if [ ! -x "$script" ]; then
      chmod +x "$script"
      echo "✅ Fixed permission: $script"
      FIXED_COUNT=$((FIXED_COUNT + 1))
    fi
  done
  if [ "$FIXED_COUNT" -gt 0 ]; then
    echo "ℹ️ Fixed execution permissions for $FIXED_COUNT shell script(s)"
  fi
fi
```

**Why this matters**: Shell scripts without execution permission (`chmod +x`) will fail to run as hooks, causing silent failures or errors.

---

## Phase 5: Completion Report (Detailed Summary)

After work completion, **explicitly show auto-determined content** for transparency:

> ✅ **Setup complete!**
>
> ---
>
> ### 📋 Auto-determined Settings
>
> | Item | Value | How to Change |
> |------|-------|---------------|
> | Language | **ja** | Change in `claude-code-harness.config.json` |
> | Mode | **{{Solo / 2-Agent}}** | {{.cursor/ detection result}} |
> | Tech stack | **{{next-supabase etc.}}** | Select "Detailed settings" when re-running |
> | Skills Gate | **{{impl, review etc.}}** | Adjust with `/skills-update` |
> | Project name | **{{my-app-XXXXXX}}** | Edit `package.json` |
>
> ---
>
> ### 📁 Generated Files
>
> **Workflow**:
> | File | Purpose | Size |
> |------|---------|------|
> | `AGENTS.md` | Development flow overview | {{XX lines}} |
> | `CLAUDE.md` | Claude Code settings | {{XX lines}} |
> | `Plans.md` | Task management | {{XX lines}} |
>
> **Settings**:
> | File | Purpose |
> |------|---------|
> | `.claude/settings.json` | Permission & safety settings |
> | `.claude/memory/decisions.md` | Decision records |
> | `.claude/memory/patterns.md` | Reusable patterns |
>
> **Quality protection rules**:
> | File | Content |
> |------|---------|
> | `.claude/rules/test-quality.md` | Test tampering prohibition |
> | `.claude/rules/implementation-quality.md` | Hollow implementation prohibition |
>
> {{If 2-Agent mode}}
> **Cursor commands**:
> | File | Purpose |
> |------|---------|
> | `.cursor/commands/start-session.md` | Start session |
> | `.cursor/commands/plan-with-cc.md` | Create plan |
> | `.cursor/commands/handoff-to-claude.md` | Task request |
> | `.cursor/commands/review-cc-work.md` | Implementation review |
>
> ---
>
> ### ⚙️ To Change Later
>
> | What to Change | Command/Method |
> |----------------|----------------|
> | Add/remove Skills Gate skills | `/skills-update` |
> | Switch to 2-Agent mode | `/harness-init --mode=2agent` (or say "want to start 2-agent operation") |
> | Change tech stack | Manual file edit or recreate project |
> | Change language setting | Edit `claude-code-harness.config.json` |
>
> ---
>
> ### 🚀 Next Steps
>
> - "`/plan-with-agent` I want to create XXX" → Create plan
> - "`/work`" → Execute tasks in Plans.md
> - "`npm run dev`" → Start dev server (if applicable)
>
> 💡 **If stuck** ask "what should I do?"

---

## Mode-specific Additional Settings

### Solo Mode

No additional settings. Complete as is.

### 2-Agent Mode (when .cursor/ detected)

Automatically add:
- .cursor/commands/ (5 files)
- .claude/rules/workflow.md

> 💡 **How to use 2-Agent**:
> 1. Consult with Cursor "want to create XXX"
> 2. Request task to Claude Code with `/handoff-to-claude`
> 3. Implement in Claude Code → Report with `/handoff-to-cursor`

---

## Argument Support

```bash
# Full specification (no questions)
/harness-init "blog" --mode=solo --stack=next-supabase --name=my-blog

# Partial specification (only ask for missing)
/harness-init --stack=rails-postgres

# Help
/harness-init --help
```

| Argument | Description | Example |
|----------|-------------|---------|
| `[project description]` | What to build | `"EC site"` |
| `--mode` | solo / 2agent | `--mode=solo` |
| `--stack` | Tech stack | `--stack=next-supabase` |
| `--name` | Project name | `--name=my-app` |
| `--lang` | Language | `--lang=en` |

---

## VibeCoder Hints

Phrases available anytime after setup:

| What You Want | How to Say |
|---------------|------------|
| Continue | "continue" "next" |
| Check operation | "run it" "show me" |
| Add feature | "add XXX" |
| Stuck | "what should I do?" |
| Leave everything | "do everything" |

---

## Notes

- **Minimum questions**: 1 for "leave it to me", 2 for "detailed settings"
- **Tech choices are auto-suggested**: Recommend defaults so VibeCoder doesn't get confused
- **Existing files are protected**: Non-destructive merge, no overwriting
- **Skills Gate adjustable later**: Reduce initial burden
