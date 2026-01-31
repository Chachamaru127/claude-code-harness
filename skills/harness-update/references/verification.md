# Phase 3: Verification and Completion

## Step 1: Post-Update Re-verification

**Important**: Run `template-tracker.sh check` again after update to confirm all files are now latest.

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/claude-code-harness}"

VERIFY_RESULT=$(bash "$PLUGIN_ROOT/scripts/template-tracker.sh" check 2>/dev/null)

REMAINING_UPDATES=$(echo "$VERIFY_RESULT" | jq -r '.updatesCount // 0')
REMAINING_INSTALLS=$(echo "$VERIFY_RESULT" | jq -r '.installsCount // 0')
REMAINING_TOTAL=$((REMAINING_UPDATES + REMAINING_INSTALLS))

if [ "$REMAINING_TOTAL" -gt 0 ]; then
  echo "⚠️ Some files not yet updated: ${REMAINING_TOTAL} files"
else
  echo "✅ All files updated to latest"
fi
```

**If remaining files:**

> **Some files not updated**
>
> | File | Status | Reason |
> |------|--------|--------|
> {{remaining files list}}
>
> **Options:**
> 1. **Retry** - Re-run update process
> 2. **Manual** - Manually merge localized files
> 3. **Skip** - End as-is (re-detected on next `/harness-update`)

## Step 2: Syntax Check

```bash
# settings.json syntax check
if command -v jq >/dev/null 2>&1; then
  jq empty .claude/settings.json 2>/dev/null && echo "✅ settings.json: Valid" || echo "⚠️ settings.json: Syntax error"
fi

# Verify version file
[ -f .claude-code-harness-version ] && echo "✅ version file: Exists" || echo "⚠️ version file: Missing"
```

## Step 3: Update Completion Report

```
📊 Update Report

Processing results:
├── Updated: N files
├── Created: N files
├── Skipped: N files (with reasons)
└── Manual: N files

File-by-file results:
├── [1/5] ✅ CLAUDE.md - Overwrite complete
├── [2/5] ✅ AGENTS.md - Overwrite complete
├── [3/5] ✅ .claude/rules/workflow.md - Overwrite complete
├── [4/5] ✅ .claude/settings.json - Merge complete
└── [5/5] 🔧 Plans.md - Manual merge recommended
```

## Completion Message

> **Update complete!**
>
> **Update summary:**
> - Version: v{{CURRENT}} → v{{LATEST}}
> - Files processed: {{processed}}/{{total}} files
> - Update method: Overwrite {{N}} / Merge {{N}} / Manual {{N}}
> - Backup: `.claude-code-harness/backups/{{TIMESTAMP}}/`
>
> **File-by-file results:**
>
> | File | Result | Method |
> |------|--------|--------|
> {{file-by-file results list}}
>
> **Next steps:**
> - "`/sync-status`" → Check current status
> - "`/plan-with-agent` I want to build XXX" → Add new tasks
> - "`/work`" → Execute Plans.md tasks
>
> **If issues occur:**
> ```bash
> # Restore from backup
> cp -r .claude-code-harness/backups/{{TIMESTAMP}}/* .
> ```

---

## Troubleshooting

### Q: Settings disappeared after update

A: Restore from backup:
```bash
cp -r .claude-code-harness/backups/{{TIMESTAMP}}/* .
```

### Q: Permission syntax error occurs

A: Manually fix `.claude/settings.json` or run `/harness-update` again.
Correct syntax: `"Bash(npm run:*)"` / Wrong: `"Bash(npm run *)"`

### Q: I want to update only specific files

A: Select "custom" during update and choose only needed files.
