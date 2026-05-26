---
name: health-check
description: "Environment diagnostics (checking dependencies, configuration, and available features). Use when you want to verify that your environment is correctly set up."
allowed-tools: ["Read", "Bash"]
---

# Health Check Skill

A skill for diagnosing whether the environment is correctly set up before using the plugin.

---

## Trigger Phrases

- "Check if this environment works"
- "What's missing?"
- "Diagnose the environment"
- "Tell me what features are available"

---

## Check Items

### Required Tools
- Git
- Node.js / npm (if applicable)
- GitHub CLI (optional)

### Configuration Files
- Existence and validity of `claude-code-harness.config.json`
- Existence of `.claude/settings.json`

### Workflow Files
- Existence of `Plans.md`
- Existence of `AGENTS.md`
- Existence of `CLAUDE.md`

---

## Output Format

```
## Environment Diagnostic Report

### Required Tools
✅ git (2.40.0)
✅ node (v20.10.0)
⚠️ gh (not installed — required for CI auto-fix)

### Configuration Files
✅ claude-code-harness.config.json
✅ .claude/settings.json

### Available Features
✅ /work, /plan-with-agent, /sync-status
⚠️ CI auto-fix (requires gh)
```
