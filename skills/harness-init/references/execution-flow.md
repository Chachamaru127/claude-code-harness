# Execution Flow

## Step 0: Argument Check and Fast Track Judgment

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

## Step 1: Unified Question (Complete in 1 time)

**Start project analysis in background** while showing questions:

```bash
# Background analysis (parallel execution)
CODE_COUNT=$(find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.py" \) \
  ! -path "*/node_modules/*" ! -path "*/.venv/*" 2>/dev/null | wc -l | tr -d ' ')
HAS_CURSOR=$([ -d .cursor ] && echo "true" || echo "false")
HAS_PACKAGE=$([ -f package.json ] && echo "true" || echo "false")
```

**Present 3 questions simultaneously with AskUserQuestion**:
1. What are you building? (Web app / API / Existing project / Other)
2. Who will use it? (Myself / Team / Public)
3. Setup method (Leave it to me / Detailed settings)

## Step 2: Additional Questions (Only for Detailed Settings)

**Skip this step** when "Leave it to me" is selected.

Only when "Detailed settings" is selected:
- Which tech stack?
- Enter project name

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

## Phase 3: Setup Execution

### New Project (project_type: "new")

1. **Project generation**
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
2. **Add only missing files** (don't touch existing)
3. **.claude/settings.json is non-destructive merge**

## Phase 4: Environment Diagnosis (Auto-execute)

```bash
# Git
command -v git >/dev/null 2>&1 && echo "✅ git" || echo "❌ git"

# Node.js (if applicable)
command -v node >/dev/null 2>&1 && echo "✅ node $(node -v)" || echo "⚠️ node"

# GitHub CLI (optional)
command -v gh >/dev/null 2>&1 && echo "✅ gh" || echo "⚠️ gh"
```

### Phase 4.5: Hooks Permission Check (Auto-execute)

**Auto-fix execution permissions for shell scripts in `.claude/hooks/`**:

```bash
if [ -d .claude/hooks ]; then
  for script in .claude/hooks/*.sh; do
    [ -f "$script" ] || continue
    if [ ! -x "$script" ]; then
      chmod +x "$script"
      echo "✅ Fixed permission: $script"
    fi
  done
fi
```

## Phase 5: Completion Report

Show auto-determined settings for transparency:
- Language, Mode, Tech stack, Skills Gate, Project name
- Generated files list
- How to change settings later
- Next steps
