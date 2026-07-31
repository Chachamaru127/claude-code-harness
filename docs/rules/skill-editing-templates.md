# Skill Editing — Templates & Command Migration Reference

`.claude/rules/skill-editing.md` の常時ロード本文を Phase 124.1 (常時ロード context 棚卸し) で
圧縮した際に切り出した補足資料。SKILL.md/reference の雛形と、Commands → Skills 移行の対比表を
そのまま保持する（内容は元のまま、要約・改変なし）。

## Skill File Structure Template

### SKILL.md Template

```markdown
---
name: skill-name
description: "Description with trigger phrases. Use when... Do NOT load for..."
allowed-tools: ["Read", "Write", "Edit", "Bash"]
argument-hint: "[subcommand|option]"
---

# Skill Name

Overview description of the skill.

## Quick Reference

- "**trigger phrase 1**" → this skill
- "**trigger phrase 2**" → this skill

## Features / Deliverables

| Feature | Reference |
|---------|-----------|
| **Feature 1** | See [feature1.md](${CLAUDE_SKILL_DIR}/references/feature1.md) |
| **Feature 2** | See [feature2.md](${CLAUDE_SKILL_DIR}/references/feature2.md) |

## Execution Flow

1. Parse user request
2. Load appropriate reference file
3. Execute steps from reference
4. Report results

## Related Skills

- `related-skill-1` - Description
- `related-skill-2` - Description
```

### Reference File Template

```markdown
# Feature Name Reference

Detailed documentation for this feature.

## When to Use

- Condition 1
- Condition 2

## Execution Steps

### Step 1: ...

### Step 2: ...

## Examples

### Example 1

...

## Troubleshooting

### Issue 1

**Cause**: ...
**Solution**: ...
```

## Migration from Commands

Commands have been migrated to skills. Key differences:

| Aspect | Commands (Legacy) | Skills (Current) |
|--------|-------------------|------------------|
| Location | `commands/` | `skills/` |
| Structure | Single file | Directory with SKILL.md + references |
| Frontmatter | `description` only | Full skill configuration |
| Auto-loading | Limited | Full description-based matching |
| Supporting files | Not supported | `references/` subdirectory |

Legacy command file conventions (frontmatter format, naming, structure template) were retired
in Phase 124.1 along with `.claude/rules/command-editing.md` (already DEPRECATED since v2.17.0).
