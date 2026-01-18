---
description: Show available skills with descriptions
description-en: Show available skills with descriptions
---

# /skill-list - Skill List

Displays available skills. Skills are automatically invoked during conversation, so explicit command execution is not required.

> **Claude Code 2.1.0+**: Skills support hot reload. Additions and changes are reflected immediately (no restart needed).

---

## Usage

```
/skill-list
```

Or in natural language:
- "Show available skills"
- "Skill list"
- "What can you do?"

---

## Skill List

Output the skill list in the following format at execution.

### Output Format

```markdown
## Available Skills

### Core (Core Features)

| Skill | Description | Trigger Example |
|-------|-------------|-----------------|
| session-init | Environment check at session start | "start work" "check status" |
| plans-management | Plans.md management | "add a task" |
| session-memory | Memory management between sessions | auto |
| parallel-workflows | Parallel execution of multiple tasks | "execute in parallel" |
| troubleshoot | Problem diagnosis and resolution | "investigate the error" |

### Optional (Extensions)

| Skill | Description | Trigger Example |
|-------|-------------|-----------------|
| analytics | Analytics integration (GA/Vercel) | "add analytics" |
| auth | Authentication (Clerk/Supabase) | "add login feature" |
| auto-fix | Auto-fix review issues | "auto-fix the issues" |
| component | UI component generation | "create a hero section" |
| deploy-setup | Deploy setup (Vercel/Netlify) | "make it deployable" |
| feedback | Feedback feature | "add a feedback form" |
| health-check | Environment diagnosis | "check the environment" |
| notebooklm-yaml | NotebookLM YAML generation | "create slide design YAML" |
| payments | Payment feature (Stripe) | "want to add payments" |
| setup-cursor | Cursor integration setup | "want to start 2-agent operation" |

---

💡 **Usage**: Skills are automatically invoked during conversation.
Just speak like the "Trigger Example" above.
```

---

## Execution Steps

1. Scan `skills/` directory
2. Extract `name` and `description` from each skill's `SKILL.md`
3. Organize by category (core / optional)
4. Output in above format

---

## Implementation (Instructions for LLM)

Get skill information with the following commands:

```bash
# List skill directories
find "${CLAUDE_PLUGIN_ROOT}/skills" -name "SKILL.md" -type f

# Extract name and description from each skill
for f in $(find "${CLAUDE_PLUGIN_ROOT}/skills" -name "SKILL.md"); do
  echo "=== $f ==="
  grep -E "^name:|^description:" "$f" | head -2
done
```

Format the obtained information into the above format and output.
