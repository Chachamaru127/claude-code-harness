# Command File Editing Rules

SSOT (Single Source of Truth) rules for editing command files (`commands/core/` and `commands/optional/`).

## SSOT Principles

### 1. YAML Frontmatter Format (Required)

**All command files must use unified YAML frontmatter**:

```yaml
---
description: Brief description
description-en: English brief description
---
```

**Prohibited**:
- ❌ Adding `name:` field (automatically determined from filename)
- ❌ Adding custom fields (only description and description-en allowed)
- ❌ Omitting frontmatter

**Exceptions**:
- Only `harness-mem.md` has no frontmatter for historical reasons (planned for future unification)

### 2. File Naming Conventions

**Core Commands** (`commands/core/`):
- `harness-` prefix recommended (e.g., `harness-init.md`, `harness-review.md`)
- Naming that indicates plugin-specific functionality

**Optional Commands** (`commands/optional/`):
- **Harness integration**: `harness-` prefix (e.g., `harness-mem.md`, `harness-update.md`)
- **Feature setup**: `{feature}-setup` pattern (e.g., `ci-setup.md`, `lsp-setup.md`)
- **Operations**: `{action}-{target}` pattern (e.g., `sync-status.md`, `sync-ssot-from-memory.md`)

### 3. Fully Qualified Name Generation

The plugin system generates fully qualified names in the following format:

```
{plugin-name}:{category}:{command-name}
```

**Examples**:
- `commands/core/harness-init.md` → `claude-code-harness:core:harness-init`
- `commands/optional/cursor-mem.md` → `claude-code-harness:optional:cursor-mem`
- `commands/optional/ci-setup.md` → `claude-code-harness:optional:ci-setup`

## Command File Structure Template

### Standard Template

```markdown
---
description: Japanese description (one line, concise)
description-en: English description (one line, concise)
---

# {Command Name}

Overview description of the command.

## Quick Reference (Optional)

- "{keyword1}" → this command
- "{keyword2}" → this command

## Deliverables

- Description of deliverable 1
- Description of deliverable 2

## Usage

### Basic Usage

```bash
/{command-name}
```

### Execution with Options

```bash
/{command-name} --option1
/{command-name} --option2
```

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `--option1` | Description of option 1 | Default value |

## Execution Details

This command executes the following:

1. Step 1
2. Step 2
3. Step 3

## Related Commands

- `/related-command1` - Description of related command
- `/related-command2` - Description of related command
```

## Editing Checklist

Checklist when creating or editing command files:

- [ ] YAML frontmatter in standard format (`description` + `description-en`)
- [ ] No `name:` field
- [ ] Filename follows naming conventions
- [ ] Fully qualified name generates correctly (`{plugin}:{category}:{name}`)
- [ ] Consistent with existing commands
- [ ] Add entry to CHANGELOG.md (for new commands)
- [ ] Bump VERSION (automatic or manual)

## Known Exceptions

### harness-mem.md

**Current State**:
```markdown
# /harness-mem - Claude-mem Integration Setup

Customize Claude-mem to harness specifications...

---
```

**Reason**: No frontmatter for historical reasons

**Future Plans**: Planned for unification to standard format

## Related Documentation

- [CLAUDE.md](../../CLAUDE.md) - Project Development Guide
- [.claude/memory/decisions.md](../memory/decisions.md) - Architecture Decision Records
- [.claude/memory/patterns.md](../memory/patterns.md) - Reusable Patterns
