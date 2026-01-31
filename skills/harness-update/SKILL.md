---
name: harness-update
description: "Safely update harness-enabled projects to latest version. Version detection → backup → non-destructive update. Use when user mentions '/harness-update', update harness, update version, or template updates."
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep"]
disable-model-invocation: true
---

# Harness Update Skill

Safely update projects with existing harness to the latest harness version.
**Version detection → Backup → Non-destructive update** flow preserves existing settings and tasks while introducing latest features.

## Quick Reference

- "I want to update harness to the latest version"
- "I want to add new features to existing project"
- "I want to update config file format to latest version"
- "I want to fix incorrect permission syntax"
- "I was notified of template updates"

## Deliverables

- Version detection via `.claude-code-harness-version`
- **Template update detection and localization judgment**
- Identify files needing update
- Auto-backup creation
- Non-destructive settings/workflow file updates
- **No localization → overwrite / Localized → merge support**
- **Skills diff detection** - Auto-detect and propose new skills
- Post-update verification

---

## Execution Flow Overview

| Phase | Reference | Description |
|-------|-----------|-------------|
| Phase 1 | [references/version-detection.md](references/version-detection.md) | Version detection and confirmation |
| Phase 1.5 | [references/breaking-changes.md](references/breaking-changes.md) | Breaking changes detection and fix |
| Phase 2 | [references/backup-and-update.md](references/backup-and-update.md) | Backup creation and file updates |
| Phase 3 | [references/verification.md](references/verification.md) | Verification and completion |

---

## Phase Summary

### Phase 1: Version Detection

1. Check `.claude-code-harness-version` file
2. Compare with plugin's latest version
3. Run `template-tracker.sh check` for content-level updates
4. Confirm update scope with user

**If harness not installed**: Suggest using `/harness-init` instead.

### Phase 1.5: Breaking Changes Detection

Detect and fix existing settings issues:
- Incorrect permission syntax (e.g., `Bash(npm run *)` → `Bash(npm run:*)`)
- Deprecated settings (e.g., `disableBypassPermissionsMode`)
- Old hook settings in project files (should use plugin hooks.json)

### Phase 2: Backup and Update

1. Create backup in `.claude-code-harness/backups/{timestamp}/`
2. Update `.claude/settings.json` (merge permissions, fix syntax)
3. Update workflow files based on localization status:
   - Not localized → overwrite
   - Localized → merge support with user confirmation
4. Update rule files with marker/hash method
5. Skills diff detection and update proposal
6. Update Cursor commands (always overwrite)
7. Update version file

### Phase 3: Verification

1. Post-update re-verification with `template-tracker.sh check`
2. Syntax check for JSON files
3. Generate completion report with file-by-file results

---

## Important Preserved Data

These are **never** overwritten:
- ✅ Incomplete tasks in Plans.md
- ✅ Custom settings in .claude/settings.json (hooks, env, model, etc.)
- ✅ SSOT data in .claude/memory/

---

## Related Commands

- `/harness-init` - New project setup
- `/sync-status` - Check current project status
- `/setup-tools` - Setup development tools
