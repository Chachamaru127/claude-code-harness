---
description: "[Optional] Set up harness-ui dashboard"
description-en: "[Optional] Set up harness-ui dashboard"
---

# /harness-ui-setup - harness-ui Dashboard Setup

Enable harness-ui (browser-based dashboard).

## VibeCoder Phrases

- "**Enable harness-ui**" → this command
- "**I want to use the dashboard**" → this command
- "**I want to see health score in UI**" → this command

## Deliverables

- **Enable MCP settings** - Register harness-ui MCP server to plugin
- Access via browser at http://localhost:37778
- Visualize health score, usage, and skills
- Auto-start when Claude Code launches

---

## Usage

### With argument (Recommended)

```
/harness-ui-setup YOUR-LICENSE-KEY
```

→ Auto-set license key to environment variable

### Without argument

```
/harness-ui-setup
```

→ You will be prompted to enter the license key

---

## Execution Flow

### Step 0: Check Existing Settings

**First check environment variable `HARNESS_BETA_CODE`:**

```bash
echo $HARNESS_BETA_CODE
```

**If already set (value exists):**

> ✅ **License key is already set**
>
> Current key: {first 8 characters}...
>
> harness-ui is already available. Access http://localhost:37778.
>
> To reset the key, run `/harness-ui-setup --force`.

**End processing** (unless `--force` option is present)

### Step 1: License Key Confirmation

**If key is passed as argument:**
→ Proceed to Step 2

**If no argument:**

> 🔑 **Please enter your Polar license key**
>
> If you don't have a license key, please request one from the administrator as this is a beta version.
>
> Enter key:

**Wait for response**

### Step 2: License Key Validation

Validate key with Polar API:

```typescript
// POST https://api.polar.sh/v1/customer-portal/license-keys/validate
{
  "key": "user's key",
  "organization_id": "54443411-11a2-45b0-9473-7aa37f96a677"
}
```

**If validation succeeds:**
→ Proceed to Step 3

**If validation fails:**

> ❌ **Invalid license key**
>
> Reason: {error reason}
>
> Please verify the correct key or contact administrator.

**End processing**

### Step 3: Set Environment Variable

Add environment variable to user's shell config file (`~/.zshrc` or `~/.bashrc`):

```bash
export HARNESS_BETA_CODE="user's license key"
```

### Step 3.5: Add MCP Settings (Enable harness-ui)

Create `.mcp.json` in plugin root to enable harness-ui MCP server.

**This step is only executed in harness-ui-setup** (not in harness-init).

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/claude-code-harness}"
TEMPLATE_PATH="$PLUGIN_ROOT/templates/mcp/harness-ui.mcp.json.template"
TARGET_PATH="$PLUGIN_ROOT/.mcp.json"

# Check if template exists
if [ -f "$TEMPLATE_PATH" ]; then
  # Create .mcp.json (overwrite if exists)
  cp "$TEMPLATE_PATH" "$TARGET_PATH"
  echo "✅ MCP settings created: $TARGET_PATH"
else
  echo "⚠️ Template not found: $TEMPLATE_PATH"
  echo "Please create .mcp.json manually"
fi
```

**Generated `.mcp.json` content:**

```json
{
  "harness-ui": {
    "command": "bun",
    "args": ["${CLAUDE_PLUGIN_ROOT}/harness-ui/src/mcp/server.ts"],
    "env": {
      "PROJECT_ROOT": "${CLAUDE_PLUGIN_ROOT}",
      "HARNESS_BETA_CODE": "${HARNESS_BETA_CODE}"
    }
  }
}
```

> 💡 **Why is this step necessary?**
>
> harness-ui is an optional feature, so it's not registered as an MCP server by default.
> Only users who run `/harness-ui-setup` can use the harness-ui MCP.

### Step 4: Install Dependencies

Install harness-ui dependencies:

```bash
cd ${CLAUDE_PLUGIN_ROOT}/harness-ui && bun install
```

**If Bun is not installed:**

```bash
# macOS / Linux
curl -fsSL https://bun.sh/install | bash

# Windows (PowerShell)
powershell -c "irm bun.sh/install.ps1 | iex"
```

**Verify successful installation:**

```bash
ls ${CLAUDE_PLUGIN_ROOT}/harness-ui/node_modules | head -5
```

→ Success if package names are displayed

### Step 5: Apply Environment Variables and Verify Server Startup

```bash
# Apply environment variables
source ~/.zshrc  # or source ~/.bashrc

# Manually start harness-ui server (for verification)
cd ${CLAUDE_PLUGIN_ROOT}/harness-ui && bun run dev &
```

**Verify startup:**

```bash
curl -s http://localhost:37778/api/status
```

→ Success if `{"status":"ok"...}` is returned

### Step 6: Register Current Project

After server starts, register current project to dropdown:

```bash
# Get current project
PROJECT_PATH=$(pwd)
PROJECT_NAME=$(basename "$PROJECT_PATH")

# Register project
curl -s -X POST http://localhost:37778/api/projects \
  -H "Content-Type: application/json" \
  -d "{\"name\": \"$PROJECT_NAME\", \"path\": \"$PROJECT_PATH\"}"
```

**Success response:**

```json
{"project":{"id":"proj_xxx","name":"your-project","path":"/path/to/project"}}
```

**If already registered:**

```json
{"error":"Project with path \"/path/to/project\" already exists"}
```

→ No problem even with error (existing project will be used)

### Step 7: Plans.md Format Check (If needed)

If Plans.md has old format (`cursor:WIP` / `cursor:completed`), migrate to appropriate markers **based on context**.

**Migration approach:**

| Old Marker | Context | New Marker |
|------------|---------|------------|
| `cursor:WIP` | Claude Code is working | `cc:WIP` |
| `cursor:WIP` | PM (Cursor) is working | `pm:requested` or keep |
| `cursor:completed` | Implementation complete | `cc:done` |
| `cursor:completed` | PM confirmed | `pm:confirmed` |

**For 2-Agent operation:**
- `cursor:requested` / `cursor:confirmed` remain valid (same as `pm:*`)
- No need to force conversion

**If migration is needed:**
Ask Claude Code to "migrate old format markers in Plans.md to new format based on context".

### Step 8: Completion Message

> ✅ **harness-ui setup complete!**
>
> 📋 **Settings:**
> - License key: {first 8 characters of key}...
> - Customer ID: {customer ID}
> - Environment variable: Added `HARNESS_BETA_CODE` to ~/.zshrc
> - **MCP settings**: `.mcp.json` created
> - Dependencies: Installed
> - Project registration: Complete
>
> **Verification:**
> 1. **Restart Claude Code** (to apply MCP settings)
> 2. Access http://localhost:37778 in browser
> 3. Verify current project name appears in top-right dropdown
> 4. From next time, auto-start & auto-register when Claude Code launches
>
> 💡 **Hint**: If dropdown shows only "All Projects", re-run project registration from Step 6.

---

## Troubleshooting

### Error: Cannot find module / node_modules not found

**Cause**: Dependencies not installed

**Solution**:
```bash
cd ${CLAUDE_PLUGIN_ROOT}/harness-ui
bun install
```

### Error: bun: command not found

**Cause**: Bun is not installed

**Solution**:
```bash
# macOS / Linux
curl -fsSL https://bun.sh/install | bash
source ~/.bashrc  # or source ~/.zshrc

# Verify
bun --version
```

### Error: Invalid license key

**Cause**: Key is incorrect or expired

**Solution**:
1. Re-verify the received key
2. Re-run `/harness-ui-setup YOUR-KEY`

### Error: harness-ui won't start

**Cause**: Environment variable not set, or Claude Code not restarted

**Solution**:
```bash
# Check environment variable
echo $HARNESS_BETA_CODE

# If not set
source ~/.zshrc

# Restart Claude Code
Ctrl+C to exit → restart with claude
```

### Error: Port 37778 in use

**Cause**: Another process is using the port

**Solution**:
```bash
lsof -i :37778
kill -9 {PID}
```

### Project not showing in dropdown

**Cause**: Project not registered

**Solution**:
```bash
# Verify server is running
curl -s http://localhost:37778/api/status

# Manually register project
PROJECT_PATH=$(pwd)
PROJECT_NAME=$(basename "$PROJECT_PATH")
curl -s -X POST http://localhost:37778/api/projects \
  -H "Content-Type: application/json" \
  -d "{\"name\": \"$PROJECT_NAME\", \"path\": \"$PROJECT_PATH\"}"

# Check registered projects list
curl -s http://localhost:37778/api/projects | jq
```

---

## Plans.md Format Requirements

harness-ui auto project registration requires one of the following:

### Method 1: Run `/harness-init` (Recommended)

```bash
/harness-init
```

→ `.claude-code-harness-version` marker file is created and auto-recognized.

### Method 2: Include correct markers in Plans.md

Include the following markers in Plans.md:

**New format (Recommended):**

| Marker | Meaning |
|--------|---------|
| `cc:TODO` | Pending task |
| `cc:WIP` | In-progress task |
| `cc:done` | Completed task |
| `cc:blocked` | Blocked |
| `pm:requested` | Requested by PM |
| `pm:confirmed` | Confirmed by PM |

**Old format (compatible, deprecated):**

| Marker | Migration target |
|--------|------------------|
| `cursor:WIP` → | `cc:WIP` |
| `cursor:completed` → | `cc:done` |

**Template:**

```markdown
# Plans.md

## Task List

- [ ] Task 1 `cc:TODO`
- [x] Task 2 `cc:done`
```

---

## Related Commands

- `/validate` - Plugin validation
- `/harness-update` - Plugin update
- `/harness-init` - Project initialization (auto Plans.md generation)

---

## Notes

- License key is validated online via Polar API
- harness-ui won't start with invalid key
- Developers can bypass with `HARNESS_UI_DEV=true`

## Security

License key is managed via environment variable (`HARNESS_BETA_CODE`).

- **Do not include in repository**: Add `.env` file to `.gitignore`
- **Shell config file**: `~/.zshrc` is normally outside Git management, so it's safe
- **For team development**: Recommend each member obtains individual license key
