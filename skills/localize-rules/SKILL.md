---
name: localize-rules
description: "Localizes rule files to match project structure. Use when user mentions localizing rules, adapting rules to project, or customizing templates. Do NOT load for: app i18n/localization features, business rule implementation."
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep"]
disable-model-invocation: true
argument-hint: "[template-name]"
---

# Localize Rules Skill

Analyzes project structure and optimizes `.claude/rules/` rule files for the project.

## Quick Reference

- "**Adapt rules to this project**" → this skill
- "**Match rules to repo structure**" → auto-detects directories/language/test config
- "**I don't know what to decide**" → "detect→propose" first, confirm only needed items

## Deliverables

- Updates `.claude/rules/` to match actual project structure
- Prevents drift in "allowed locations/tests/conventions" for future work

---

## Purpose

Customize generic rule templates to match actual project structure:

- **paths:** adapted to actual source directories (`src/`, `app/`, `lib/`, etc.)
- Add language-specific rules (TypeScript, Python, React, etc.)
- Auto-detect test directories

---

## Execution

Run the localization script:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/localize-rules.sh"
```

Or dry-run to preview:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/localize-rules.sh" --dry-run
```

> Note: If `CLAUDE_PLUGIN_ROOT` is unavailable, run from plugin repo root: `bash ./scripts/localize-rules.sh`

---

## Detection Targets

| Item | Detection Method | Example |
|------|-----------------|---------|
| Source directories | `src/`, `app/`, `lib/` existence | `paths: ["src/**/*"]` |
| Language | package.json, requirements.txt, Cargo.toml | TypeScript, Python, Rust |
| Test framework | jest.config, vitest.config, pytest.ini | Jest, Vitest, pytest |
| Component library | package.json dependencies | React, Vue, Svelte |

---

## Updated Rules

| Rule File | Updates |
|-----------|---------|
| `workflow.md` | Source paths, test commands |
| `testing.md` | Test framework config |
| `code-style.md` | Language conventions |

---

## Related Skills

- `setup` - Initial project setup
- `harness-init` - Harness initialization
