---
description: Safely update harness-enabled projects to latest version (version detection → backup → non-destructive update)
---

# /harness-update - Harness Update

Safely update projects with existing harness to the latest harness version.
**Version detection → Backup → Non-destructive update** flow preserves existing settings and tasks while introducing latest features.

## When to Use

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

## Execution Flow

### Phase 1: Version Detection and Confirmation

#### Step 1: Check Harness Installation Status

Check `.claude-code-harness-version` file:

```bash
if [ -f .claude-code-harness-version ]; then
  CURRENT_VERSION=$(grep "^version:" .claude-code-harness-version | cut -d' ' -f2)
  echo "Detected version: $CURRENT_VERSION"
else
  echo "⚠️ Harness not installed in this project"
  echo "→ Use /harness-init instead"
  exit 1
fi
```

**If harness not installed:**
> ⚠️ **Harness is not installed in this project**
>
> `/harness-update` is for projects with existing harness.
> Use `/harness-init` for new installation.

**If installed:** → Step 2

#### Step 2: Version Comparison

Compare with plugin's latest version:

```bash
PLUGIN_VERSION=$(cat "$CLAUDE_PLUGIN_ROOT/claude-code-harness/VERSION" 2>/dev/null || echo "unknown")

if [ "$CURRENT_VERSION" = "$PLUGIN_VERSION" ]; then
  echo "ℹ️ Version is latest (v$PLUGIN_VERSION)"
  echo "→ Running file content check..."
else
  echo "📦 Update available: v$CURRENT_VERSION → v$PLUGIN_VERSION"
fi
```

**If versions differ:** → Step 3

**If versions same:** → Step 2.5 (content check)

> ⚠️ **Important**: Even if versions match, individual file content may be outdated.
> Step 2.5 runs `template-tracker.sh check` to detect content-level updates.

#### Step 2.5: File Content Check (When Version Same)

Check for outdated file content even with same version:

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/claude-code-harness}"

# Content-based update check with template-tracker.sh check
CHECK_RESULT=$(bash "$PLUGIN_ROOT/scripts/template-tracker.sh" check 2>/dev/null)

# Get update counts from JSON
NEEDS_CHECK=$(echo "$CHECK_RESULT" | jq -r '.needsCheck // false')
UPDATES_COUNT=$(echo "$CHECK_RESULT" | jq -r '.updatesCount // 0')
INSTALLS_COUNT=$(echo "$CHECK_RESULT" | jq -r '.installsCount // 0')

if [ "$NEEDS_CHECK" = "true" ]; then
  echo "📦 File content updates needed"
  echo "   - Updates: ${UPDATES_COUNT} files"
  echo "   - New: ${INSTALLS_COUNT} files"
else
  echo "✅ All files are up to date"
fi
```

**If files need updates:**

> 📦 **File content updates detected**
>
> Version is v{{VERSION}} (same), but the following file content is outdated:
>
> | File | Status | Action |
> |------|--------|--------|
> {{update target list}}
>
> Continue with update? (yes / no / show details)

**Wait for response**

- **yes** → Step 3 (carry over update target list)
- **no** → End
- **show details** → Show `template-tracker.sh status` details, then confirm again

**If all files up to date:**

> ✅ **Project is completely up to date**
>
> - Version: v{{VERSION}}
> - All file content: Up to date
>
> No update needed.

#### Step 3: Template Update Check

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

#### Step 4: Confirm Update Scope

Identify target files and confirm with user:

> 📦 **Update: v{{CURRENT}} → v{{LATEST}}**
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

---

## Phase 1.5: Breaking Changes Detection and Confirmation

**Important**: Detect existing settings issues and confirm with user before update.

### Step 1: Inspect .claude/settings.json

Load existing `.claude/settings.json` and check:

```bash
# Check if settings.json exists
if [ ! -f .claude/settings.json ]; then
  echo "ℹ️ .claude/settings.json doesn't exist (will be created)"
  # → Phase 2 (no breaking changes)
fi

# Load with JSON parser (jq or python)
if command -v jq >/dev/null 2>&1; then
  SETTINGS_CONTENT=$(cat .claude/settings.json)
else
  echo "⚠️ jq not found. Manual check needed"
fi
```

### Step 2: Detect Issues

Detect the following issues:

#### 🔴 Issue 1: Incorrect Permission Syntax

```bash
# Search for incorrect syntax patterns
WRONG_PATTERNS=(
  'Bash\([^:)]+\s\*\)'     # "Bash(npm run *)" pattern
  'Bash\([^:)]+\*\)'       # "Bash(git diff*)" pattern (no colon)
  'Bash\(\*[^:][^)]*\*\)'  # "Bash(*credentials*)" pattern
)

FOUND_ISSUES=()

# Check each pattern
if echo "$SETTINGS_CONTENT" | grep -E 'Bash\([^:)]+\s\*\)'; then
  FOUND_ISSUES+=("incorrect_prefix_syntax_with_space")
fi

if echo "$SETTINGS_CONTENT" | grep -E 'Bash\([^:)]+\*\)' | grep -v ':'; then
  FOUND_ISSUES+=("incorrect_prefix_syntax_no_colon")
fi

if echo "$SETTINGS_CONTENT" | grep -E 'Bash\(\*[^:][^)]*\*\)'; then
  FOUND_ISSUES+=("incorrect_substring_syntax")
fi
```

#### 🔴 Issue 2: Deprecated Settings

```bash
# Check for disableBypassPermissionsMode
if echo "$SETTINGS_CONTENT" | grep -q '"disableBypassPermissionsMode"'; then
  FOUND_ISSUES+=("deprecated_disable_bypass_permissions")
fi
```

#### 🔴 Issue 3: Old Hook Settings (Harness-originated only)

```bash
# Detect only hooks with commands containing "claude-code-harness"
# User's custom hooks (different paths) are excluded
PLUGIN_EVENTS=("PreToolUse" "SessionStart" "UserPromptSubmit" "PermissionRequest")
OLD_HARNESS_EVENTS=()

if command -v jq >/dev/null 2>&1; then
  for event in "${PLUGIN_EVENTS[@]}"; do
    if jq -e ".hooks.${event}" "$SETTINGS_FILE" >/dev/null 2>&1; then
      # Extract command paths and check for "claude-code-harness"
      COMMANDS=$(jq -r ".hooks.${event}[]?.hooks[]?.command // .hooks.${event}[]?.command // empty" "$SETTINGS_FILE" 2>/dev/null)
      if echo "$COMMANDS" | grep -q "claude-code-harness"; then
        OLD_HARNESS_EVENTS+=("$event")
      fi
    fi
  done

  if [ ${#OLD_HARNESS_EVENTS[@]} -gt 0 ]; then
    FOUND_ISSUES+=("legacy_hooks_in_settings")
    echo "Old harness hook settings: ${OLD_HARNESS_EVENTS[*]}"
  fi
fi
```

### Step 3: Display Detection Results

If issues found, show details to user:

> ⚠️ **Issues found in existing settings**
>
> **🔴 Issue 1: Incorrect Permission Syntax (3 items)**
>
> ```diff
> - "Bash(npm run *)"      ❌ Wrong (space+asterisk)
> + "Bash(npm run:*)"      ✅ Correct (colon+asterisk)
>
> - "Bash(pnpm *)"         ❌ Wrong
> + "Bash(pnpm:*)"         ✅ Correct
>
> - "Bash(git diff*)"      ❌ Wrong (no colon)
> + "Bash(git diff:*)"     ✅ Correct
> ```
>
> **Impact**: Current permission settings are not working correctly.
> Claude Code may not be able to execute these commands.
>
> ---
>
> **🔴 Issue 2: Deprecated Settings (1 item)**
>
> ```diff
> - "disableBypassPermissionsMode": "disable"   ❌ Deprecated (since v2.5.0)
> (Remove this setting)
> ```
>
> **Reason**: Harness changed to allow bypassPermissions since v2.5.0.
> Only dangerous operations are controlled via `permissions.deny` / `permissions.ask`.
>
> **Impact**: With current settings, confirmation prompts appear for every Edit/Write, reducing productivity.
>
> ---
>
> **🔴 Issue 3: Old Hook Settings (N items)**
>
> ```diff
> - "hooks": { ... }   ❌ Duplicates plugin hooks.json
> (Remove this setting)
> ```
>
> **Reason**: claude-code-harness plugin manages hooks via `hooks/hooks.json`.
> Having `hooks` in project's `.claude/settings.json` may cause unintended duplicate behavior.
>
> **Recommendation**: Remove `hooks` section from project and use only plugin hooks.
>
> ---
>
> **Auto-fix these issues?**
>
> - **yes** - Auto-fix all issues above and continue update
> - **review** - Review each issue individually before fixing
> - **skip** - Continue update without fixing (not recommended)
> - **cancel** - Abort update

**Wait for response**

#### Choice Processing

- **yes** → Auto-fix all issues → Phase 2
- **review** → Step 4 (individual review)
- **skip** → Phase 2 (continue without fixing, show warning)
- **cancel** → Abort update

### Step 4: Individual Review (When "review" selected)

Review each issue individually:

> **Issue 1/2: Incorrect Permission Syntax**
>
> Fix these 3 items?
> - `"Bash(npm run *)"` → `"Bash(npm run:*)"`
> - `"Bash(pnpm *)"` → `"Bash(pnpm:*)"`
> - `"Bash(git diff*)"` → `"Bash(git diff:*)"`
>
> (yes / no)

**Wait for response** → Add to fix list if yes

> **Issue 2/2: Deprecated Settings**
>
> Remove `disableBypassPermissionsMode`?
>
> (yes / no)

**Wait for response** → Add to delete list if yes

After all confirmations → Phase 2

---

## Phase 2: Backup and Update

> **Design principle**: Create update target list first, continue until all files processed. No early termination.

### Step 0: Create Update Target List (At Phase 2 start)

**Manage files detected in Phase 1 or Step 2.5 as list** and continue until all processed:

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/claude-code-harness}"

# Get template-tracker.sh check results
CHECK_RESULT=$(bash "$PLUGIN_ROOT/scripts/template-tracker.sh" check 2>/dev/null)

# Create update target lists
UPDATE_LIST=()
INSTALL_LIST=()

if command -v jq >/dev/null 2>&1; then
  # Files needing update
  while IFS= read -r line; do
    [ -n "$line" ] && UPDATE_LIST+=("$line")
  done < <(echo "$CHECK_RESULT" | jq -r '.updates[]?.path // empty')

  # Files needing creation
  while IFS= read -r line; do
    [ -n "$line" ] && INSTALL_LIST+=("$line")
  done < <(echo "$CHECK_RESULT" | jq -r '.installs[]?.path // empty')
fi

TOTAL_COUNT=$((${#UPDATE_LIST[@]} + ${#INSTALL_LIST[@]}))
COMPLETED_COUNT=0

echo "📋 Update target list: ${TOTAL_COUNT} files"
echo "   - Updates: ${#UPDATE_LIST[@]} files"
echo "   - New: ${#INSTALL_LIST[@]} files"
```

**Progress tracking**:

```
Update target list (5 files)
├── [1/5] ⏳ CLAUDE.md - Waiting
├── [2/5] ⏳ AGENTS.md - Waiting
├── [3/5] ⏳ .claude/rules/workflow.md - Waiting
├── [4/5] ⏳ .claude/settings.json - Waiting
└── [5/5] ⏳ Plans.md - Waiting
```

### Step 1: Create Backup Directory

```bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR=".claude-code-harness/backups/$TIMESTAMP"
mkdir -p "$BACKUP_DIR"

# Copy backup target files
[ -f .claude/settings.json ] && cp .claude/settings.json "$BACKUP_DIR/"
[ -f AGENTS.md ] && cp AGENTS.md "$BACKUP_DIR/"
[ -f CLAUDE.md ] && cp CLAUDE.md "$BACKUP_DIR/"
[ -f Plans.md ] && cp Plans.md "$BACKUP_DIR/"
[ -d .claude/rules ] && cp -r .claude/rules "$BACKUP_DIR/"
[ -d .cursor/commands ] && cp -r .cursor/commands "$BACKUP_DIR/"

echo "✅ Backup created: $BACKUP_DIR"
```

### Step 2: Update Settings File

**`.claude/settings.json` update**

Fix issues detected in Phase 1.5 before running `generate-claude-settings` skill.

#### Step 2.1: Apply Breaking Changes (If approved in Phase 1.5)

Apply user-approved fixes:

```bash
# Load settings.json
SETTINGS_FILE=".claude/settings.json"

# Issue 1: Fix permission syntax
if [ -f "$SETTINGS_FILE" ]; then
  # Replace space+asterisk with colon+asterisk
  # e.g.: "Bash(npm run *)" → "Bash(npm run:*)"
  sed -i.bak 's/Bash(\([^:)]*\) \*)/Bash(\1:*)/g' "$SETTINGS_FILE"

  # Replace colon-less asterisk with colon+asterisk
  # e.g.: "Bash(git diff*)" → "Bash(git diff:*)"
  # (skip if already has :)
  sed -i.bak 's/Bash(\([^:)]*\)\*)/Bash(\1:*)/g' "$SETTINGS_FILE"

  # Fix substring matching
  # e.g.: "Bash(*credentials*)" → "Bash(:*credentials:*)"
  sed -i.bak 's/Bash(\*\([^:][^)]*\)\*)/Bash(:*\1:*)/g' "$SETTINGS_FILE"

  echo "✅ Fixed permission syntax"
fi

# Issue 2: Remove deprecated settings
if [ -f "$SETTINGS_FILE" ]; then
  # Remove disableBypassPermissionsMode (using jq)
  if command -v jq >/dev/null 2>&1; then
    jq 'del(.permissions.disableBypassPermissionsMode)' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
    mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
    echo "✅ Removed disableBypassPermissionsMode"
  else
    # Use Python if jq not available
    python3 -c "
import json
with open('$SETTINGS_FILE', 'r') as f:
    data = json.load(f)
if 'permissions' in data and 'disableBypassPermissionsMode' in data['permissions']:
    del data['permissions']['disableBypassPermissionsMode']
with open('$SETTINGS_FILE', 'w') as f:
    json.dump(data, f, indent=2)
" && echo "✅ Removed disableBypassPermissionsMode"
  fi
fi

# Issue 3: Remove only harness-originated hook settings (identify by path)
# Preserve user's custom hooks
if [ -f "$SETTINGS_FILE" ]; then
  PLUGIN_EVENTS=("PreToolUse" "SessionStart" "UserPromptSubmit" "PermissionRequest")
  DELETED_EVENTS=()

  if command -v jq >/dev/null 2>&1; then
    for event in "${PLUGIN_EVENTS[@]}"; do
      if jq -e ".hooks.${event}" "$SETTINGS_FILE" >/dev/null 2>&1; then
        # Delete only if command path contains "claude-code-harness"
        COMMANDS=$(jq -r ".hooks.${event}[]?.hooks[]?.command // .hooks.${event}[]?.command // empty" "$SETTINGS_FILE" 2>/dev/null)
        if echo "$COMMANDS" | grep -q "claude-code-harness"; then
          jq "del(.hooks.${event})" "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
          mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
          DELETED_EVENTS+=("$event")
        fi
      fi
    done

    # Delete .hooks itself if empty
    if jq -e '.hooks | length == 0' "$SETTINGS_FILE" >/dev/null 2>&1; then
      jq 'del(.hooks)' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
      mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
    fi

    if [ ${#DELETED_EVENTS[@]} -gt 0 ]; then
      echo "✅ Removed old harness hook settings: ${DELETED_EVENTS[*]} (using plugin hooks.json)"
    fi
  else
    # Use Python if jq not available
    python3 -c "
import json
with open('$SETTINGS_FILE', 'r') as f:
    data = json.load(f)
if 'hooks' in data:
    plugin_events = ['PreToolUse', 'SessionStart', 'UserPromptSubmit', 'PermissionRequest']
    deleted = []
    for event in plugin_events:
        if event in data['hooks']:
            # Check if command path contains 'claude-code-harness'
            hooks_list = data['hooks'][event]
            is_harness = any('claude-code-harness' in str(h) for h in hooks_list)
            if is_harness:
                del data['hooks'][event]
                deleted.append(event)
    if not data['hooks']:
        del data['hooks']
    if deleted:
        print(f'✅ Removed old harness hook settings: {\" \".join(deleted)}')
with open('$SETTINGS_FILE', 'w') as f:
    json.dump(data, f, indent=2)
"
  fi
fi
```

#### Step 2.2: Run generate-claude-settings Skill

- Preserve `env`, `model`, `enabledPlugins` (`hooks` already removed)
- Merge `permissions.allow|ask|deny` with latest policy + deduplicate
- Preserve correct syntax fixed in Phase 1.5
- Add new recommended settings

### Step 3: Update Workflow Files (Template Tracking Support)

**Update processing based on template tracking status**:

Branch processing based on each file's status:

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/claude-code-harness}"

# Get template tracking check results
CHECK_RESULT=$(bash "$PLUGIN_ROOT/scripts/template-tracker.sh" check 2>/dev/null)

# Process files needing update using jq
if command -v jq >/dev/null 2>&1; then
  echo "$CHECK_RESULT" | jq -r '.updates[]? | "\(.path)|\(.localized)"' | while IFS='|' read -r path localized; do
    if [ "$localized" = "false" ]; then
      # Not localized → overwrite
      echo "🔄 Overwriting: $path"
      # Generate from template and overwrite
      # → Run generate-* skill
    else
      # Localized → merge support
      echo "🔧 Merge support: $path"
      # Show diff and confirm with user
    fi
  done
fi
```

**For not localized (🔄 Overwrite OK)**:

Auto-replace with latest template:
- `AGENTS.md` / `CLAUDE.md`: Overwrite with latest template
- `.claude/rules/*.md`: Overwrite with latest rule templates

**For localized (🔧 Merge needed)**:

> 🔧 **`Plans.md` is localized**
>
> This file contains project-specific changes.
>
> **Options:**
> 1. **Show diff** - View differences from template
> 2. **Merge support** - Claude suggests merge
> 3. **Skip** - Skip this file
>
> Select:

**Wait for response**

If merge support selected:
- Maintain latest template structure
- Re-position user's custom parts (tasks, settings) appropriately
- Show diff and get final confirmation

**After update recording:**

```bash
# Record updated files in generated-files.json
bash "$PLUGIN_ROOT/scripts/template-tracker.sh" record "$path"
```

### Step 4: Update Rule Files

`.claude/rules/` update:

**Safely update using marker + hash method for localization detection.**

```bash
PLUGIN_PATH="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/claude-code-harness}"
PLUGIN_VERSION=$(cat "$PLUGIN_PATH/VERSION" 2>/dev/null || echo "unknown")
SKILLS_CONFIG=".claude/state/skills-config.json"

# Check Skills Gate status
SKILLS_GATE_ENABLED="false"
if [ -f "$SKILLS_CONFIG" ]; then
  if command -v jq >/dev/null 2>&1; then
    SKILLS_GATE_ENABLED=$(jq -r '.enabled // false' "$SKILLS_CONFIG")
  fi
fi

# Process each rule template
for template in "$PLUGIN_PATH/templates/rules"/*.template; do
  [ -f "$template" ] || continue

  rule_name=$(basename "$template" .template)
  output_file=".claude/rules/$rule_name"

  # Check conditional template (get condition from template-registry.json)
  TEMPLATE_KEY="rules/$(basename "$template")"
  CONDITION=""
  if command -v jq >/dev/null 2>&1; then
    CONDITION=$(jq -r ".templates[\"$TEMPLATE_KEY\"].condition // \"\"" "$PLUGIN_PATH/templates/template-registry.json" 2>/dev/null)
  fi

  # Evaluate conditional templates
  if [ -n "$CONDITION" ]; then
    case "$CONDITION" in
      "skills_gate.enabled")
        if [ "$SKILLS_GATE_ENABLED" != "true" ]; then
          # Condition not met
          if [ -f "$output_file" ]; then
            echo "🗑️ Suggest deletion: $output_file (Skills Gate disabled)"
          else
            echo "⏭️ Skip: $rule_name (Skills Gate disabled)"
          fi
          continue
        fi
        ;;
    esac
  fi

  # Create new if file doesn't exist
  if [ ! -f "$output_file" ]; then
    cp "$template" "$output_file"
    sed -i '' "s/{{VERSION}}/$PLUGIN_VERSION/g" "$output_file" 2>/dev/null || \
    sed -i "s/{{VERSION}}/$PLUGIN_VERSION/g" "$output_file"
    echo "🆕 Created: $output_file"
    continue
  fi

  # Check marker (is it harness-originated)
  if grep -q "^_harness_template:" "$output_file" 2>/dev/null; then
    # Harness-originated → detect localization and update
    # Compare hash of content after frontmatter
    INSTALLED_VERSION=$(grep "^_harness_version:" "$output_file" | sed 's/_harness_version: "//;s/"//')

    if [ "$INSTALLED_VERSION" != "$PLUGIN_VERSION" ]; then
      # Different version → update target
      # (Localization detection delegated to template-tracker.sh)
      echo "🔄 Updating: $output_file ($INSTALLED_VERSION → $PLUGIN_VERSION)"
      cp "$template" "$output_file"
      sed -i '' "s/{{VERSION}}/$PLUGIN_VERSION/g" "$output_file" 2>/dev/null || \
      sed -i "s/{{VERSION}}/$PLUGIN_VERSION/g" "$output_file"
    else
      echo "✅ Latest: $output_file"
    fi
  else
    # No marker → user custom, protect
    echo "🛡️ Protected: $output_file (user custom)"
  fi
done
```

**Decision logic:**

| Marker | Condition | Action |
|--------|-----------|--------|
| Yes | No condition / condition met | Update (localization detection) |
| Yes | Condition not met | Suggest deletion |
| No | - | Protect (user custom) |

#### Skills Gate Enablement Proposal

If Skills Gate is disabled and `skills-gate.md` doesn't exist, propose enablement.

```bash
# If Skills Gate disabled, propose enablement
if [ "$SKILLS_GATE_ENABLED" != "true" ]; then
  echo ""
  echo "💡 Enable Skills Gate?"
  echo ""
  echo "Skills Gate prompts skill usage before code editing."
  echo "- Rules: Make Claude recognize 'should use skills'"
  echo "- Hooks: Last line of defense if forgotten"
  echo ""
  echo "If enabled:"
  echo "- skills-gate.md rule will be added"
  echo "- Skill usage becomes habitual, improving work quality"
  echo ""
fi
```

**Wait for response**

- **yes** → Enable Skills Gate and add `skills-gate.md`
- **no** → Skip

```bash
# If user selected yes
if [ "$USER_CHOICE" = "yes" ]; then
  # Enable skills-config.json
  if [ -f "$SKILLS_CONFIG" ]; then
    jq '.enabled = true' "$SKILLS_CONFIG" > tmp.json && mv tmp.json "$SKILLS_CONFIG"
  else
    mkdir -p .claude/state
    cat > "$SKILLS_CONFIG" << EOF
{
  "version": "1.0",
  "enabled": true,
  "skills": ["impl", "review"],
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
  fi

  # Add skills-gate.md
  cp "$PLUGIN_PATH/templates/rules/skills-gate.md.template" ".claude/rules/skills-gate.md"
  sed -i '' "s/{{VERSION}}/$PLUGIN_VERSION/g" ".claude/rules/skills-gate.md" 2>/dev/null || \
  sed -i "s/{{VERSION}}/$PLUGIN_VERSION/g" ".claude/rules/skills-gate.md"
  echo "✅ Skills Gate enabled"
  echo "✅ Created: .claude/rules/skills-gate.md"
fi
```

### Step 4.5: Skills Settings Diff Detection and Update

Compare plugin skills with project settings to detect and propose diffs.

#### Step 4.5.1: Get Plugin Skills List

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/claude-code-harness}"
SKILLS_CONFIG=".claude/state/skills-config.json"
mkdir -p .claude/state

# Get available skills list from plugin
AVAILABLE_SKILLS=()
if [ -d "$PLUGIN_ROOT/skills" ]; then
  for skill_dir in "$PLUGIN_ROOT/skills"/*/; do
    if [ -d "$skill_dir" ]; then
      skill_name=$(basename "$skill_dir")
      AVAILABLE_SKILLS+=("$skill_name")
    fi
  done
fi

echo "📦 Plugin available skills: ${AVAILABLE_SKILLS[*]}"
```

#### Step 4.5.2: Get Project Settings

```bash
if [ -f "$SKILLS_CONFIG" ]; then
  # Get skills list from existing settings
  if command -v jq >/dev/null 2>&1; then
    CURRENT_SKILLS=$(jq -r '.skills[]?' "$SKILLS_CONFIG" 2>/dev/null | tr '\n' ' ')
  else
    CURRENT_SKILLS=""
  fi
  echo "📋 Project registered skills: $CURRENT_SKILLS"
else
  CURRENT_SKILLS=""
  echo "📋 Project registered skills: (not configured)"
fi
```

#### Step 4.5.3: Detect Diffs

```bash
NEW_SKILLS=()
REMOVED_SKILLS=()

# Skills in plugin but not in project (new candidates)
for skill in "${AVAILABLE_SKILLS[@]}"; do
  if ! echo "$CURRENT_SKILLS" | grep -qw "$skill"; then
    NEW_SKILLS+=("$skill")
  fi
done

# Skills in project but not in plugin (removal candidates)
for skill in $CURRENT_SKILLS; do
  found=false
  for avail in "${AVAILABLE_SKILLS[@]}"; do
    if [ "$skill" = "$avail" ]; then
      found=true
      break
    fi
  done
  if [ "$found" = false ]; then
    REMOVED_SKILLS+=("$skill")
  fi
done
```

#### Step 4.5.4: Propose If Diffs Found

**If new skills detected:**

> 🆕 **New skills available**
>
> The following skills have been added:
> {{NEW_SKILLS list and descriptions}}
>
> **Add them?**
> - **yes** - Add all
> - **select** - Select individually
> - **skip** - Don't add now

**Wait for response**

- **yes** → Add all new skills to skills-config.json
- **select** → Review each skill individually
- **skip** → Don't update skills-config.json

**If removed skills detected:**

> ⚠️ **The following skills have been removed from plugin**
>
> {{REMOVED_SKILLS list}}
>
> Remove from settings? (yes / no)

**Wait for response**

#### Step 4.5.5: Update skills-config.json

```bash
if [ -f "$SKILLS_CONFIG" ]; then
  # Preserve existing settings while adding new skills
  if command -v jq >/dev/null 2>&1; then
    # Add approved new skills
    for skill in "${APPROVED_NEW_SKILLS[@]}"; do
      jq --arg s "$skill" '.skills += [$s] | .skills |= unique' "$SKILLS_CONFIG" > tmp.json
      mv tmp.json "$SKILLS_CONFIG"
    done

    # Remove deleted skills
    for skill in "${APPROVED_REMOVED_SKILLS[@]}"; do
      jq --arg s "$skill" '.skills -= [$s]' "$SKILLS_CONFIG" > tmp.json
      mv tmp.json "$SKILLS_CONFIG"
    done

    # Update version and timestamp
    jq '.version = "1.0" | .updated_at = "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"' "$SKILLS_CONFIG" > tmp.json
    mv tmp.json "$SKILLS_CONFIG"
    echo "✅ skills-config.json: Updated"
  else
    echo "⚠️ jq not found. Skills settings auto-update skipped"
    echo "   Run /skills-update manually or install jq"
  fi
else
  # Create new (default skills + approved new skills)
  DEFAULT_SKILLS='["impl", "review"]'
  cat > "$SKILLS_CONFIG" << SKILLSEOF
{
  "version": "1.0",
  "enabled": true,
  "skills": $DEFAULT_SKILLS,
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
SKILLSEOF
  echo "✅ skills-config.json: Created"
fi
```

> 💡 **About Skills Diff Detection**
> - When plugin update adds new skills, auto-detected and proposed
> - Existing skill settings preserved
> - Individual skill add/remove also available with `/skills-update` command

### Step 5: Update Cursor Commands (For 2-Agent mode)

Update only if `.cursor/commands/` exists.

**IMPORTANT: Cursor commands are ALWAYS overwritten, never merged.**

Unlike other workflow files, Cursor command templates:
- Are **not localized** (users should not modify them)
- Should be **completely replaced** with latest plugin templates
- Do **NOT read existing files** before updating

**Update procedure**:

1. **Do NOT read** existing `.cursor/commands/*.md` files
2. **Read only** from plugin templates: `templates/cursor/commands/*.md`
3. **Overwrite** target files completely with template content

```bash
if [ -d .cursor/commands ]; then
  PLUGIN_PATH="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/claude-code-harness}"

  # OVERWRITE (not merge) with latest command templates
  for cmd in "$PLUGIN_PATH/templates/cursor/commands"/*.md; do
    if [ -f "$cmd" ]; then
      # Skip CLAUDE.md (claude-mem context file)
      [ "$(basename "$cmd")" = "CLAUDE.md" ] && continue
      cp "$cmd" .cursor/commands/
      echo "✅ Overwritten: $(basename $cmd)"
    fi
  done
fi
```

**Target files** (5 commands):
- `start-session.md` - Session start
- `plan-with-cc.md` - Plan creation
- `handoff-to-claude.md` - Task handoff
- `review-cc-work.md` - Implementation review
- `project-overview.md` - Project overview

### Step 6: Hooks Permission Check (Auto-execute)

**Auto-fix execution permissions for shell scripts in `.claude/hooks/`**:

```bash
# Check and fix .claude/hooks/*.sh execution permissions
if [ -d .claude/hooks ]; then
  FIXED_COUNT=0
  for script in .claude/hooks/*.sh; do
    [ -f "$script" ] || continue
    if [ ! -x "$script" ]; then
      chmod +x "$script"
      echo "✅ Fixed permission: $script"
      FIXED_COUNT=$((FIXED_COUNT + 1))
    fi
  done
  if [ "$FIXED_COUNT" -gt 0 ]; then
    echo "ℹ️ Fixed execution permissions for $FIXED_COUNT shell script(s)"
  fi
fi
```

**Why this matters**: Shell scripts without execution permission (`chmod +x`) will fail to run as hooks, causing silent failures or errors.

### Step 7: Update Version File

Update `.claude-code-harness-version` to latest:

```bash
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

---

## Phase 2A: Selective Update (Custom selection)

> 📋 **Which files to update?**
>
> 1. `.claude/settings.json` - Security policy and permission syntax
> 2. `AGENTS.md` / `CLAUDE.md` / `Plans.md` - Workflow files
> 3. `.claude/rules/` - Rule templates
> 4. `.cursor/commands/` - Cursor commands (2-Agent mode)
> 5. All
>
> Select by number (multiple ok, comma-separated):

**Wait for response**

Execute only selected files' Phase 2 steps.

---

## Phase 3: Verification and Completion

### Step 1: Post-Update Re-verification (Confirm All Files Latest)

**Important**: Run `template-tracker.sh check` again after update to **confirm all files are now latest**.

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/claude-code-harness}"

# Re-verify
VERIFY_RESULT=$(bash "$PLUGIN_ROOT/scripts/template-tracker.sh" check 2>/dev/null)

REMAINING_UPDATES=$(echo "$VERIFY_RESULT" | jq -r '.updatesCount // 0')
REMAINING_INSTALLS=$(echo "$VERIFY_RESULT" | jq -r '.installsCount // 0')
REMAINING_TOTAL=$((REMAINING_UPDATES + REMAINING_INSTALLS))

if [ "$REMAINING_TOTAL" -gt 0 ]; then
  echo "⚠️ Some files not yet updated: ${REMAINING_TOTAL} files"
  echo "   Retry update or manual intervention needed"
else
  echo "✅ All files updated to latest"
fi
```

**If remaining:**

> ⚠️ **Some files not updated**
>
> | File | Status | Reason |
> |------|--------|--------|
> {{remaining files list}}
>
> **Options:**
> 1. **Retry** - Re-run update process
> 2. **Manual** - Manually merge localized files
> 3. **Skip** - End as-is (re-detected on next `/harness-update`)

**Wait for response**

- **Retry** → Return to Phase 2, process remaining files
- **Manual** → Show list and instructions for manual intervention files
- **Skip** → Step 2 (include warning in completion report)

### Step 2: Syntax Check

```bash
# settings.json syntax check
if command -v jq >/dev/null 2>&1; then
  jq empty .claude/settings.json 2>/dev/null && echo "✅ settings.json: Valid" || echo "⚠️ settings.json: Syntax error"
fi

# Verify version file
[ -f .claude-code-harness-version ] && echo "✅ version file: Exists" || echo "⚠️ version file: Missing"
```

### Step 3: Update Completion Report

**Processing results summary**:

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

> ✅ **Update complete!**
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

## Phase 2B: Selective Update (Custom selection)

Update only user-selected files.

---

## Notes

- **Backup required**: Always create backup before update
- **Existing data preserved**: Plans.md tasks, settings.json custom settings preserved
- **Non-destructive merge**: Existing files merged, not overwritten
- **Don't forget verification**: Check status with `/sync-status` after update

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

A: Select "custom" and choose only needed files.

---

## Related Commands

- `/harness-init` - New project setup
- `/sync-status` - Check current project status
- `/validate` - Validate project structure
