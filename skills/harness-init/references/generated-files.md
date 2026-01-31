# Generated Files

## Workflow Files

| File | Purpose |
|------|---------|
| `AGENTS.md` | Development flow overview |
| `CLAUDE.md` | Claude Code settings |
| `Plans.md` | Task management |

## Settings Files

| File | Purpose |
|------|---------|
| `.claude/settings.json` | Permission & safety settings |
| `.claude/memory/decisions.md` | Decision records |
| `.claude/memory/patterns.md` | Reusable patterns |

## Quality Protection Rules

| File | Content |
|------|---------|
| `.claude/rules/test-quality.md` | Test tampering prohibition |
| `.claude/rules/implementation-quality.md` | Hollow implementation prohibition |

## 2-Agent Mode Files (if applicable)

| File | Purpose |
|------|---------|
| `.cursor/commands/start-session.md` | Start session |
| `.cursor/commands/plan-with-cc.md` | Create plan |
| `.cursor/commands/handoff-to-claude.md` | Task request |
| `.cursor/commands/review-cc-work.md` | Implementation review |

## Completion Report Template

```
✅ **Setup complete!**

### 📋 Auto-determined Settings

| Item | Value | How to Change |
|------|-------|---------------|
| Language | **ja** | Change in config |
| Mode | **{{Solo / 2-Agent}}** | Re-run with --mode |
| Tech stack | **{{stack}}** | Select "Detailed settings" |
| Skills Gate | **{{skills}}** | `/skills-update` |
| Project name | **{{name}}** | Edit package.json |

### 🚀 Next Steps

- `/planning I want to create XXX` → Create plan
- `/work` → Execute tasks in Plans.md
- `npm run dev` → Start dev server
```
