# Skill File Editing Rules

SSOT (Single Source of Truth) rules for editing skill files (`skills/<skill-name>/`).

> **Note**: As of v2.17.0, custom slash commands have been migrated to skills.
> Skills are the preferred approach for new functionality.

## SSOT Principles

### 1. Directory Structure

Each skill lives in its own directory:

```
skills/
└── <skill-name>/
    ├── SKILL.md           # Main skill definition (required)
    └── references/        # Supporting files (optional)
        ├── feature1.md
        ├── feature2.md
        └── ...
```

### 2. YAML Frontmatter Format (Required)

**All SKILL.md files must use this frontmatter**:

```yaml
---
name: skill-name
description: "Brief description for auto-loading. Include trigger phrases."
allowed-tools: ["Read", "Write", "Edit", "Bash", ...]
---
```

### 3. Available Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Skill identifier (matches directory name) |
| `description` | Yes | Description for auto-loading (include trigger phrases) |
| `allowed-tools` | No | Tools the skill can use |
| `argument-hint` | No | Usage hint (e.g., `"[option1|option2]"`) |
| `disable-model-invocation` | No | Set `true` for dangerous operations |
| `user-invocable` | No | Set `false` for internal-only skills |
| `context` | No | `fork` for isolated context |
| `hooks` | No | Event hooks configuration |

### 4. File Size Guidelines

| Guideline | Recommendation |
|-----------|----------------|
| SKILL.md | Keep under 500 lines |
| Large content | Split into `references/` files |
| References | Use descriptive filenames |

### 5. Description Best Practices

The `description` field is critical for auto-loading. Include:
- What the skill does
- Trigger phrases (e.g., "Use when user mentions...")
- What NOT to load for (e.g., "Do NOT load for: ...")

**Good example**:
```yaml
description: "Manages CI/CD failures. Use when user mentions CI failures, build errors, or test failures. Do NOT load for: local builds or standard implementation."
```

**Bad example**:
```yaml
description: "CI skill"
```

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
| **Feature 1** | See [references/feature1.md](references/feature1.md) |
| **Feature 2** | See [references/feature2.md](references/feature2.md) |

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

## Editing Checklist

When creating or editing skill files:

- [ ] SKILL.md has required frontmatter (`name`, `description`)
- [ ] `name` matches directory name
- [ ] `description` includes trigger phrases and exclusions
- [ ] SKILL.md under 500 lines (use references for large content)
- [ ] References in `references/` subdirectory
- [ ] Related skills documented
- [ ] Add entry to CHANGELOG.md (for new skills)
- [ ] Bump VERSION (automatic or manual)

## Migration from Commands

Commands have been migrated to skills. Key differences:

| Aspect | Commands (Legacy) | Skills (Current) |
|--------|-------------------|------------------|
| Location | `commands/` | `skills/` |
| Structure | Single file | Directory with SKILL.md + references |
| Frontmatter | `description` only | Full skill configuration |
| Auto-loading | Limited | Full description-based matching |
| Supporting files | Not supported | `references/` subdirectory |

## Related Documentation

- [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills)
- [command-editing.md](./command-editing.md) - Legacy command rules (deprecated)
- [CLAUDE.md](../../CLAUDE.md) - Project Development Guide
