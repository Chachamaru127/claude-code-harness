# Smart Defaults

To reduce questions, use auto-determination or default values.

## Default Values

| Item | Default | Auto-determination Condition |
|------|---------|----------------------------|
| Language | ja | Can change in config file |
| Mode | Solo | 2-Agent if .cursor/ exists |
| Tech stack | next-supabase | In auto mode |
| Skills Gate | Auto-configured | Adjust later with `/skills-update` |

## Config Override

Overridable in `claude-code-harness.config.json`:

```json
{
  "i18n": { "language": "en" },
  "scaffolding": {
    "tech_choice_mode": "fixed",
    "base_stack": "rails-postgres"
  }
}
```

## Mode-specific Settings

### Solo Mode

No additional settings. Complete as is.

### 2-Agent Mode (when .cursor/ detected)

Automatically add:
- .cursor/commands/ (5 files)
- .claude/rules/workflow.md

**How to use 2-Agent**:
1. Consult with Cursor "want to create XXX"
2. Request task to Claude Code with `/handoff-to-claude`
3. Implement in Claude Code → Report with `/handoff-to-cursor`
