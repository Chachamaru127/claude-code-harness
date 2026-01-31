# Phase 1: Version Detection and Confirmation

## Step 1: Check Harness Installation Status

Check `.claude-code-harness-version` file:

```bash
if [ -f .claude-code-harness-version ]; then
  CURRENT_VERSION=$(grep "^version:" .claude-code-harness-version | cut -d' ' -f2)
  echo "Detected version: $CURRENT_VERSION"
else
  echo "Harness not installed in this project"
  echo "→ Use /harness-init instead"
  exit 1
fi
```

**If harness not installed:**

> **Harness is not installed in this project**
>
> `/harness-update` is for projects with existing harness.
> Use `/harness-init` for new installation.

## Step 2: Version Comparison

Compare with plugin's latest version:

```bash
PLUGIN_VERSION=$(cat "$CLAUDE_PLUGIN_ROOT/claude-code-harness/VERSION" 2>/dev/null || echo "unknown")

if [ "$CURRENT_VERSION" = "$PLUGIN_VERSION" ]; then
  echo "Version is latest (v$PLUGIN_VERSION)"
  echo "→ Running file content check..."
else
  echo "Update available: v$CURRENT_VERSION → v$PLUGIN_VERSION"
fi
```

## Step 2.5: File Content Check (When Version Same)

> **Important**: Even if versions match, individual file content may be outdated.

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/claude-code-harness}"

# Content-based update check with template-tracker.sh check
CHECK_RESULT=$(bash "$PLUGIN_ROOT/scripts/template-tracker.sh" check 2>/dev/null)

# Get update counts from JSON
NEEDS_CHECK=$(echo "$CHECK_RESULT" | jq -r '.needsCheck // false')
UPDATES_COUNT=$(echo "$CHECK_RESULT" | jq -r '.updatesCount // 0')
INSTALLS_COUNT=$(echo "$CHECK_RESULT" | jq -r '.installsCount // 0')

if [ "$NEEDS_CHECK" = "true" ]; then
  echo "File content updates needed"
  echo "   - Updates: ${UPDATES_COUNT} files"
  echo "   - New: ${INSTALLS_COUNT} files"
else
  echo "All files are up to date"
fi
```

**If files need updates, confirm with user:**

> **File content updates detected**
>
> Version is v{{VERSION}} (same), but the following file content is outdated:
>
> | File | Status | Action |
> |------|--------|--------|
> {{update target list}}
>
> Continue with update? (yes / no / show details)

## Step 3: Template Update Check

Run `template-tracker.sh status` to show template update status:

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/claude-code-harness}"
bash "$PLUGIN_ROOT/scripts/template-tracker.sh" status
```

**Example output:**

```
=== Template Tracking Status ===

Plugin version: 2.5.25
Last checked at: 2.5.20

File                                      Recorded     Latest       Status
----                                      --------     ------       ------
CLAUDE.md                                 2.5.20       2.5.25       🔄 Overwrite OK
AGENTS.md                                 unknown      2.5.25       ⚠️ Needs check
Plans.md                                  2.5.20       2.5.25       🔧 Merge needed
.claude/rules/workflow.md                 2.5.20       2.5.25       ✅ Latest

Legend:
  ✅ Latest      : No update needed
  🔄 Overwrite OK: Not localized, can overwrite
  🔧 Merge needed: Localized, requires merge
  ⚠️ Needs check : Unknown version, check recommended
```

## Step 4: Confirm Update Scope

> **Update: v{{CURRENT}} → v{{LATEST}}**
>
> **Files to update:**
> - `.claude/settings.json` - Update security policy and latest syntax
> - `AGENTS.md` / `CLAUDE.md` / `Plans.md` - Update to latest format (existing tasks preserved)
> - `.claude/rules/` - Update to latest rule templates
> - `.cursor/commands/` - Update Cursor commands (for 2-Agent mode)
> - `.claude-code-harness-version` - Update version info
>
> **Existing data preserved:**
> - ✅ Incomplete tasks in Plans.md
> - ✅ Custom settings in .claude/settings.json (hooks, env, model, etc.)
> - ✅ SSOT data in .claude/memory/
>
> **Backup:**
> - Pre-change files saved to `.claude-code-harness/backups/{{TIMESTAMP}}/`
>
> Execute update? (yes / no / custom)
>
> **Custom**: Select "custom" to update only specific files

**Wait for response**

- **yes** → Phase 1.5 (breaking changes check)
- **no** → End
- **custom** → Phase 2A (selective update)
