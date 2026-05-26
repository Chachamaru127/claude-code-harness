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

> **CC v2.1.69+ recommended**: When linking to reference files from `SKILL.md`,
> use `${CLAUDE_SKILL_DIR}/references/...` rather than relative paths like `references/...`.
> This ensures stable referencing regardless of where the skill is executed.

### 2. YAML Frontmatter Format (Required)

**All SKILL.md files must use this frontmatter**:

```yaml
---
name: skill-name
description: "English description for auto-loading. Include trigger phrases."
allowed-tools: ["Read", "Write", "Edit", "Bash", ...]
---
```

### 3. Available Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Skill identifier (matches directory name) |
| `description` | Yes | English description for auto-loading (include trigger phrases). Token-efficient. |
| `allowed-tools` | No | Tools the skill can use |
| `argument-hint` | No | Usage hint (e.g., `"[option1|option2]"`) |
| `disable-model-invocation` | No | Set `true` for dangerous operations |
| `user-invocable` | No | Set `false` for internal-only skills |
| `context` | No | `fork` for isolated context |
| `hooks` | No | Event hooks configuration |

### 4. File Size Guidelines

| Guideline | Recommendation |
|-----------|----------------|
| SKILL.md | Recommended 500 lines or fewer |
| Large content | Split into `references/` files |
| References | Use descriptive filenames |

> **Note (CC 2.1.32+)**: The character budget for skills is automatically scaled to **2%** of the context window.
> 500 lines is a recommendation only; the effective upper limit depends on the model's context window size.
> Large skill files may be automatically trimmed, so place important information near the top of SKILL.md
> and split details into `references/`.

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

## Editing Checklist

When creating or editing skill files:

- [ ] SKILL.md has required frontmatter (`name`, `description`)
- [ ] `name` matches directory name
- [ ] `description` includes trigger phrases and exclusions
- [ ] SKILL.md is recommended 500 lines or fewer (use references for large content; 2% budget scaling applies)
- [ ] References are under `references/` and linked via `${CLAUDE_SKILL_DIR}/references/...`
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

## Auto-start Pattern for `context: fork` + `disable-model-invocation: true`

Skills with `context: fork` run in an isolated context and do not inherit the host project's CLAUDE.md.
In practice, however, host session-start rules have been observed to leak into the fork context, causing the skill
to stop with "task is unclear" — a phenomenon observed 6 times in total (Issue #84). This section defines the countermeasure pattern.

### fork Inheritance Specification

- A `context: fork` skill creates a new isolated context at launch
- The parent session's CLAUDE.md / session-start rules are in principle not inherited
- However, based on the CC implementation, cases where the host project's rules flow into the fork have been confirmed (#84)
- Leaked rules trigger a stop condition such as "first confirm the task is clear"

### Implementation Guide for the auto-start Pattern

When immediate automatic start is needed for a `context: fork` skill, implement the following 3 items at the top of Step 0 in SKILL.md:

#### (1) Place machine-readable conditions literally within the first 3 lines

```
if $ARGUMENTS == "":
  → begin {the content of the automatic processing}
  → "task is unclear" and "waiting for additional instructions" are prohibited actions
```

Placing this condition block within 3 lines of the Step 0 heading ensures that,
even if other rules leak in, the conditional branch is read mechanically first.

#### (2) Explicitly enumerate prohibited actions

List at least 3 stop patterns in specific wording.
Rather than a vague "do not stop," enumerate the observed patterns literally
(e.g., "task is unclear", "waiting for additional instructions", etc.)
to textually override any host rules that may have leaked in.

#### (3) Document the `*_AUTOSTART` marker contract

Write a contract that, when called without arguments, the first response must always include an identifying marker:

```
REVIEW_AUTOSTART: base_ref={ref}, type=code
```

This contract has the following effects:
- Humans and monitoring scripts can confirm automatic start
- The action contract of outputting the marker pins the very first step of the response to "execute" rather than "stop"
- Implementation gaps can be inspected with `grep -c 'REVIEW_AUTOSTART' skills/*/SKILL.md`

### Reference: harness-review Implementation Example

Step 0 of `skills/harness-review/SKILL.md` is the reference implementation of the above 3 patterns.
Apply the same pattern if the same problem occurs in other skills.

## Related Documentation

- [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills)
- [command-editing.md](./command-editing.md) - Legacy command rules (deprecated)
- [CLAUDE.md](../../CLAUDE.md) - Project Development Guide
