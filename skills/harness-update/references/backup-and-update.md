# Phase 2: Backup and Update

> **Design principle**: Create update target list first, continue until all files processed. No early termination.

## Step 0: Create Update Target List

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/claude-code-harness}"

CHECK_RESULT=$(bash "$PLUGIN_ROOT/scripts/template-tracker.sh" check 2>/dev/null)

UPDATE_LIST=()
INSTALL_LIST=()

if command -v jq >/dev/null 2>&1; then
  while IFS= read -r line; do
    [ -n "$line" ] && UPDATE_LIST+=("$line")
  done < <(echo "$CHECK_RESULT" | jq -r '.updates[]?.path // empty')

  while IFS= read -r line; do
    [ -n "$line" ] && INSTALL_LIST+=("$line")
  done < <(echo "$CHECK_RESULT" | jq -r '.installs[]?.path // empty')
fi

TOTAL_COUNT=$((${#UPDATE_LIST[@]} + ${#INSTALL_LIST[@]}))
echo "Update target list: ${TOTAL_COUNT} files"
```

## Step 1: Create Backup Directory

```bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR=".claude-code-harness/backups/$TIMESTAMP"
mkdir -p "$BACKUP_DIR"

[ -f .claude/settings.json ] && cp .claude/settings.json "$BACKUP_DIR/"
[ -f AGENTS.md ] && cp AGENTS.md "$BACKUP_DIR/"
[ -f CLAUDE.md ] && cp CLAUDE.md "$BACKUP_DIR/"
[ -f Plans.md ] && cp Plans.md "$BACKUP_DIR/"
[ -d .claude/rules ] && cp -r .claude/rules "$BACKUP_DIR/"
[ -d .cursor/commands ] && cp -r .cursor/commands "$BACKUP_DIR/"

echo "✅ Backup created: $BACKUP_DIR"
```

## Step 2: Update Settings File

### Step 2.1: Apply Breaking Changes Fixes

```bash
SETTINGS_FILE=".claude/settings.json"

if [ -f "$SETTINGS_FILE" ]; then
  # Fix permission syntax
  sed -i.bak 's/Bash(\([^:)]*\) \*)/Bash(\1:*)/g' "$SETTINGS_FILE"
  sed -i.bak 's/Bash(\([^:)]*\)\*)/Bash(\1:*)/g' "$SETTINGS_FILE"
  sed -i.bak 's/Bash(\*\([^:][^)]*\)\*)/Bash(:*\1:*)/g' "$SETTINGS_FILE"
  echo "✅ Fixed permission syntax"

  # Remove deprecated settings
  if command -v jq >/dev/null 2>&1; then
    jq 'del(.permissions.disableBypassPermissionsMode)' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
    mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
    echo "✅ Removed disableBypassPermissionsMode"
  fi

  # Remove harness-originated hooks (preserve user custom hooks)
  # ... (see full implementation in breaking-changes.md)
fi
```

### Step 2.2: Run generate-claude-settings Skill

- Preserve `env`, `model`, `enabledPlugins`
- Merge `permissions.allow|ask|deny` with latest policy + deduplicate
- Add new recommended settings

## Step 3: Update Workflow Files

Based on template tracking status:

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/claude-code-harness}"

CHECK_RESULT=$(bash "$PLUGIN_ROOT/scripts/template-tracker.sh" check 2>/dev/null)

echo "$CHECK_RESULT" | jq -r '.updates[]? | "\(.path)|\(.localized)"' | while IFS='|' read -r path localized; do
  if [ "$localized" = "false" ]; then
    echo "🔄 Overwriting: $path"
    # Generate from template and overwrite
  else
    echo "🔧 Merge support: $path"
    # Show diff and confirm with user
  fi
done
```

**For not localized (🔄 Overwrite OK)**:
- Auto-replace with latest template

**For localized (🔧 Merge needed)**:

> **`Plans.md` is localized**
>
> This file contains project-specific changes.
>
> **Options:**
> 1. **Show diff** - View differences from template
> 2. **Merge support** - Claude suggests merge
> 3. **Skip** - Skip this file

## Step 4: Update Rule Files

```bash
PLUGIN_PATH="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/claude-code-harness}"
PLUGIN_VERSION=$(cat "$PLUGIN_PATH/VERSION" 2>/dev/null || echo "unknown")

for template in "$PLUGIN_PATH/templates/rules"/*.template; do
  [ -f "$template" ] || continue

  rule_name=$(basename "$template" .template)
  output_file=".claude/rules/$rule_name"

  # Check marker for harness-originated files
  if [ -f "$output_file" ] && grep -q "^_harness_template:" "$output_file" 2>/dev/null; then
    INSTALLED_VERSION=$(grep "^_harness_version:" "$output_file" | sed 's/_harness_version: "//;s/"//')
    if [ "$INSTALLED_VERSION" != "$PLUGIN_VERSION" ]; then
      echo "🔄 Updating: $output_file ($INSTALLED_VERSION → $PLUGIN_VERSION)"
      cp "$template" "$output_file"
      sed -i "s/{{VERSION}}/$PLUGIN_VERSION/g" "$output_file"
    fi
  elif [ ! -f "$output_file" ]; then
    echo "🆕 Created: $output_file"
    cp "$template" "$output_file"
    sed -i "s/{{VERSION}}/$PLUGIN_VERSION/g" "$output_file"
  else
    echo "🛡️ Protected: $output_file (user custom)"
  fi
done
```

## Step 5: Skills Diff Detection

Compare plugin skills with project settings:

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/claude-code-harness}"
SKILLS_CONFIG=".claude/state/skills-config.json"

# Get available skills from plugin
AVAILABLE_SKILLS=()
for skill_dir in "$PLUGIN_ROOT/skills"/*/; do
  [ -d "$skill_dir" ] && AVAILABLE_SKILLS+=("$(basename "$skill_dir")")
done

# Compare with project settings
# ... detect new and removed skills
```

**If new skills detected:**

> **New skills available**
>
> The following skills have been added:
> {{NEW_SKILLS list}}
>
> **Add them?**
> - **yes** - Add all
> - **select** - Select individually
> - **skip** - Don't add now

## Step 6: Update Cursor Commands

**IMPORTANT: Cursor commands are ALWAYS overwritten, never merged.**

```bash
if [ -d .cursor/commands ]; then
  PLUGIN_PATH="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/claude-code-harness}"

  for cmd in "$PLUGIN_PATH/templates/cursor/commands"/*.md; do
    if [ -f "$cmd" ]; then
      [ "$(basename "$cmd")" = "CLAUDE.md" ] && continue
      cp "$cmd" .cursor/commands/
      echo "✅ Overwritten: $(basename $cmd)"
    fi
  done
fi
```

## Step 7: Update Version File

```bash
PLUGIN_VERSION=$(cat "$CLAUDE_PLUGIN_ROOT/claude-code-harness/VERSION")

cat > .claude-code-harness-version <<EOF
# claude-code-harness version tracking
# This file is auto-generated by /harness-update
# DO NOT manually edit - used for update detection

version: $PLUGIN_VERSION
installed_at: $(grep "^installed_at:" .claude-code-harness-version | cut -d' ' -f2)
updated_at: $(date +%Y-%m-%d)
last_setup_command: harness-update
EOF

echo "✅ Version updated: v$CURRENT_VERSION → v$PLUGIN_VERSION"
```
