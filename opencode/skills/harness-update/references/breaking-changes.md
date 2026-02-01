# Phase 1.5: Breaking Changes Detection and Confirmation

**Important**: Detect existing settings issues and confirm with user before update.

## Step 1: Inspect .claude/settings.json

```bash
if [ ! -f .claude/settings.json ]; then
  echo ".claude/settings.json doesn't exist (will be created)"
  # → Phase 2 (no breaking changes)
fi

if command -v jq >/dev/null 2>&1; then
  SETTINGS_CONTENT=$(cat .claude/settings.json)
else
  echo "jq not found. Manual check needed"
fi
```

## Step 2: Detect Issues

### Issue 1: Incorrect Permission Syntax

> **Note (v2.1.20+)**: `Bash(*)` is now treated as equivalent to `Bash` (full wildcard).
> Only prefix patterns without colons are incorrect.

```bash
FOUND_ISSUES=()

# Check incorrect space+asterisk pattern
if echo "$SETTINGS_CONTENT" | grep -E 'Bash\([^:)]+\s\*\)'; then
  FOUND_ISSUES+=("incorrect_prefix_syntax_with_space")
fi

# Check colon-less asterisk pattern (e.g., "Bash(git diff*)")
if echo "$SETTINGS_CONTENT" | grep -oE 'Bash\([^)]+\)' | grep -E 'Bash\([^:)]+\*\)'; then
  FOUND_ISSUES+=("incorrect_prefix_syntax_no_colon")
fi

# Check incorrect substring pattern
if echo "$SETTINGS_CONTENT" | grep -E 'Bash\(\*[^:][^)]*\*\)'; then
  FOUND_ISSUES+=("incorrect_substring_syntax")
fi
```

### Issue 2: Deprecated Settings

```bash
if echo "$SETTINGS_CONTENT" | grep -q '"disableBypassPermissionsMode"'; then
  FOUND_ISSUES+=("deprecated_disable_bypass_permissions")
fi
```

### Issue 3: Old Hook Settings (Harness-originated only)

```bash
# Detect only hooks with commands containing "claude-code-harness"
PLUGIN_EVENTS=("PreToolUse" "SessionStart" "UserPromptSubmit" "PermissionRequest")
OLD_HARNESS_EVENTS=()

if command -v jq >/dev/null 2>&1; then
  for event in "${PLUGIN_EVENTS[@]}"; do
    if jq -e ".hooks.${event}" "$SETTINGS_FILE" >/dev/null 2>&1; then
      COMMANDS=$(jq -r ".hooks.${event}[]?.hooks[]?.command // .hooks.${event}[]?.command // empty" "$SETTINGS_FILE" 2>/dev/null)
      if echo "$COMMANDS" | grep -q "claude-code-harness"; then
        OLD_HARNESS_EVENTS+=("$event")
      fi
    fi
  done

  if [ ${#OLD_HARNESS_EVENTS[@]} -gt 0 ]; then
    FOUND_ISSUES+=("legacy_hooks_in_settings")
  fi
fi
```

## Step 3: Display Detection Results

If issues found:

> **Issues found in existing settings**
>
> **Issue 1: Incorrect Permission Syntax (3 items)**
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
>
> ---
>
> **Issue 2: Deprecated Settings (1 item)**
>
> ```diff
> - "disableBypassPermissionsMode": "disable"   ❌ Deprecated (since v2.5.0)
> (Remove this setting)
> ```
>
> **Reason**: Harness changed to allow bypassPermissions since v2.5.0.
>
> ---
>
> **Issue 3: Old Hook Settings (N items)**
>
> ```diff
> - "hooks": { ... }   ❌ Duplicates plugin hooks.json
> (Remove this setting)
> ```
>
> **Reason**: Plugin manages hooks via `hooks/hooks.json`.
>
> ---
>
> **Auto-fix these issues?**
>
> - **yes** - Auto-fix all issues above and continue update
> - **review** - Review each issue individually before fixing
> - **skip** - Continue update without fixing (not recommended)
> - **cancel** - Abort update

## Step 4: Individual Review (When "review" selected)

For each issue, confirm individually:

> **Issue 1/2: Incorrect Permission Syntax**
>
> Fix these items?
> - `"Bash(npm run *)"` → `"Bash(npm run:*)"`
> - `"Bash(pnpm *)"` → `"Bash(pnpm:*)"`
>
> (yes / no)

After all confirmations → Phase 2
