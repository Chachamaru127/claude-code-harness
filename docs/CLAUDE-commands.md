# Key Commands Reference

A list of commands and handoffs used during Claude harness development.

## Primary commands (used during development)

| Command | Purpose |
|---------|------|
| `/plan-with-agent` | Add improvement tasks to Plans.md |
| `/work` | Implement tasks (auto-scope detection, --codex support) |
| `/breezing` | Full parallel run with Agent Teams (--codex support) |
| `/reload-plugins` | Immediately apply changes after editing skills/hooks (no restart needed) |
| `/harness-review` | Review changes |
| `/validate` | Validate plugin |
| `/remember` | Record learnings |

## Handoffs

| Command | Purpose |
|---------|------|
| `/handoff-to-cursor` | Completion report when running Cursor |

**Skills (auto-triggered in conversation)**:
- `handoff-to-impl` - "Hand off to implementation" → PM → Impl delegation
- `handoff-to-pm` - "Report completion to PM" → Impl → PM completion report

## Related documents

- [CLAUDE.md](../CLAUDE.md) - Project development guide
- [docs/CLAUDE-skill-catalog.md](./CLAUDE-skill-catalog.md) - Skill catalog
- [docs/CLAUDE-feature-table.md](./CLAUDE-feature-table.md) - New feature utilization table
