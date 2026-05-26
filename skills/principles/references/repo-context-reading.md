---
name: core-read-repo-context
description: "Read and understand the repository context (README, Plans.md, existing code). Use at session start, before beginning a new task, or whenever understanding the project structure is needed."
allowed-tools: ["Read", "Grep", "Glob"]
---

# Read Repository Context

A skill for understanding the structure and context of a repository.
Use before starting work or before implementing a new feature.

---

## Inputs

- **Required**: Access to the repository root directory
- **Optional**: Focus specification for particular files or directories

---

## Output

Structured context information including an understanding of the repository

---

## Execution Steps

### Step 1: Understand the Basic Structure

```bash
# Directory structure
ls -la
find . -maxdepth 2 -type d | head -20

# Check key files
cat README.md 2>/dev/null | head -50
cat package.json 2>/dev/null | head -20
```

### Step 2: Review Workflow Files

```bash
# Plans.md status
cat Plans.md 2>/dev/null || echo "Plans.md not found"

# Role assignments in AGENTS.md
cat AGENTS.md 2>/dev/null | head -100 || echo "AGENTS.md not found"

# Settings in CLAUDE.md
cat CLAUDE.md 2>/dev/null | head -50 || echo "CLAUDE.md not found"
```

### Step 3: Identify the Tech Stack

```bash
# Frontend
[ -f package.json ] && cat package.json | grep -E '"(react|vue|angular|next|nuxt)"'

# Backend
[ -f requirements.txt ] && head -10 requirements.txt
[ -f Gemfile ] && head -10 Gemfile
[ -f go.mod ] && head -10 go.mod

# Configuration files
[ -f tsconfig.json ] && echo "TypeScript project"
[ -f .eslintrc* ] && echo "ESLint configured"
[ -f tailwind.config.* ] && echo "Tailwind CSS"
```

### Step 4: Check Git Status

```bash
git status -sb
git log --oneline -5
git branch -a | head -10
```

---

## Output Format

```markdown
## Repository Context

### Basic Info
- **Project name**: {{name}}
- **Tech stack**: {{framework}} + {{language}}
- **Current branch**: {{branch}}

### Workflow Status
- **Plans.md**: {{present/absent, task count}}
- **AGENTS.md**: {{present/absent}}
- **CLAUDE.md**: {{present/absent}}

### Recent Changes
{{3 most recent commits}}

### Key Files
{{List of important files to be aware of}}
```

---

## When to Use

1. **At session start**: understand the current state
2. **Before implementing a new feature**: confirm consistency with existing code
3. **When investigating errors**: identify related files
4. **During reviews**: understand the scope of impact from changes

---

## Notes

- **Large repositories**: narrow focus to important parts when there are many files
- **Sensitive information**: do not read the contents of .env or secrets/
- **Leverage caching**: minimize re-reads within the same session
