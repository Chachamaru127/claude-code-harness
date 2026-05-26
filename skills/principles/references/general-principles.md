---
name: core-general-principles
description: "Provides fundamental development principles and safety rules. Basic guidelines that apply to all tasks."
---

# General Principles

Fundamental principles for using claude-code-harness. Applied across all workflows.

---

## Safety Principles

### 1. Verify Before Modifying

Before editing a file, always confirm:

- **Review contents with the Read tool**: understand existing code before making changes
- **Understand the scope of impact**: consider how the change affects other files
- **Consider backups**: check `git status` before important changes

### 2. Edit with Minimal Diffs

```
❌ Bad: Rewrite the entire file
✅ Good: Use the Edit tool to change only the necessary parts
```

### 3. Respect Configuration Files

Follow the settings in `claude-code-harness.config.json`:

- `safety.mode`: dry-run / apply-local / apply-and-push
- `paths.protected`: do not modify protected paths
- `paths.allowed_modify`: only modify permitted paths

---

## Work Principles

### 1. Always Update Plans.md

- When starting a task: `cc:TODO` → `cc:WIP`
- When completing a task: `cc:WIP` → `cc:完了`
- When blocked: add `blocked` with the reason

### 2. Progress Incrementally

```
1. Research & understand → 2. Plan → 3. Implement → 4. Verify → 5. Report
```

### 3. Handling Errors

- Up to 3 automatic retries
- If unresolved, escalate (report)
- Clearly describe the error and the remedies attempted

---

## Communication Principles

### VibeCoder Support

Make things understandable even without technical knowledge:

- **Avoid jargon**: or provide an explanation alongside it
- **Present the next action**: "Next, please say ..."
- **Visualize progress**: clearly show what's done and what remains

### Coordination with PM (Cursor)

- **Share state via Plans.md**: maintain as the single source of truth
- **Use `/handoff-to-cursor` for completion reports**: follow the format
- **Respect scope**: confirm before doing work outside the requested scope

---

## Prohibited Actions

1. **Deploying directly to production** (staging only)
2. **Hardcoding sensitive information** (use .env)
3. **Modifying protected paths** (.github/, secrets/, etc.)
4. **Destructive operations without user confirmation** (rm -rf, etc.)
