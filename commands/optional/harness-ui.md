---
description: Open harness-ui dashboard (auto-setup if needed)
description-en: Open harness-ui dashboard (auto-setup if needed)
---

# /harness-ui - Dashboard Display & Setup

Open harness-ui dashboard. Automatically switches to setup mode if not configured.

## VibeCoder Phrases

- "**Open the dashboard**" → this command
- "**I want to see harness-ui**" → this command
- "**Check status in UI**" → this command
- "**Enable harness-ui**" → this command (auto-setup)
- "**I want to use the dashboard**" → this command (auto-setup)
- "**I want to see health score in UI**" → this command (auto-setup)

## Deliverables

- Open harness-ui in browser
- Check server status
- Display registered projects list
- Auto-setup if license key is not configured

---

## Execution Flow

### Step 1: License Key Check (Mode Detection)

```bash
# Check environment variable
echo $HARNESS_BETA_CODE
```

**If key is set (not empty):**
→ Proceed to **Dashboard Mode (Step 2)**

**If key is not set or empty:**
→ Proceed to **Setup Mode (Step S1)**

---

## Dashboard Mode

### Step 2: Server Status Check

```bash
# Check harness-ui server status
curl -s --connect-timeout 2 http://localhost:37778/api/status
```

**If server is running:**
→ Proceed to Step 3

**If server is not running:**

> ⚠️ **harness-ui server is not running**
>
> Restart Claude Code to auto-start.
>
> Or to start manually:
> ```bash
> cd {plugin directory}/harness-ui && npm run dev
> ```

**End processing**

### Step 3: Get Project Information

```bash
# Get registered projects list
curl -s http://localhost:37778/api/projects
```

### Step 4: Display Information

Display the following information:

> 📊 **harness-ui Dashboard**
>
> **URL**: http://localhost:37778
>
> **Server Status**: ✅ Running
>
> **Registered Projects**:
> | Project | Path |
> |---------|------|
> | {name1} | {path1} |
> | {name2} | {path2} |
>
> 💡 Open http://localhost:37778 in your browser to view the dashboard.

### Step 5: Open in Browser (Optional)

Ask user:

> Open dashboard in browser? (Y/n)

**If Y:**
```bash
open http://localhost:37778  # macOS
# or
xdg-open http://localhost:37778  # Linux
```

---

## Setup Mode

> 🔑 **License key not found. Starting harness-ui setup...**

### Step S1: License Key Input

**If command has argument (e.g., `/harness-ui YOUR-KEY`):**
→ Use the argument as license key, proceed to Step S2

**If no argument:**

> 🔑 **Please enter your Polar license key**
>
> If you don't have a license key, please request one from the administrator as this is a beta version.
>
> Enter key:

**Wait for response**

### Step S2: License Key Validation

Validate key with Polar API:

```typescript
// POST https://api.polar.sh/v1/customer-portal/license-keys/validate
{
  "key": "user's key",
  "organization_id": "54443411-11a2-45b0-9473-7aa37f96a677"
}
```

**If validation succeeds:**
→ Proceed to Step S3

**If validation fails:**

> ❌ **Invalid license key**
>
> Reason: {error reason}
>
> Please verify the correct key or contact administrator.

**End processing**

### Step S3: Set Environment Variable

Add environment variable to user's shell config file (`~/.zshrc` or `~/.bashrc`):

```bash
export HARNESS_BETA_CODE="user's license key"
```

### Step S3.5: Add MCP Settings (Enable harness-ui)

Create `.mcp.json` in plugin root to enable harness-ui MCP server.

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
> Only users who run setup can use the harness-ui MCP.

### Step S4: Install Dependencies

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

### Step S5: Apply Environment Variables and Verify Server Startup

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

### Step S6: Register Current Project

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

### Step S7: Plans.md Format Check (If needed)

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

### Step S8: Completion Message → Dashboard Mode

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
> 💡 **Hint**: If dropdown shows only "All Projects", re-run project registration from Step S6.

After setup completion, automatically proceed to **Dashboard Mode (Step 2)** to show current status.

---

## Related Commands

- `/validate` - Plugin validation
- `/harness-update` - Plugin update
- `/harness-init` - Project initialization (auto Plans.md generation)

---

## Troubleshooting

### Server won't start

1. Restart Claude Code
2. Check if port 37778 is in use: `lsof -i :37778`
3. Check if environment variable `HARNESS_BETA_CODE` is set

### Want to reset license key

Run `/harness-ui --force YOUR-NEW-KEY` to reconfigure.

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
2. Re-run `/harness-ui YOUR-KEY`

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
/init
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

## Notes

- License key is validated online via Polar API
- harness-ui won't start with invalid key
- Developers can bypass with `HARNESS_UI_DEV=true`

## Security

License key is managed via environment variable (`HARNESS_BETA_CODE`).

- **Do not include in repository**: Add `.env` file to `.gitignore`
- **Shell config file**: `~/.zshrc` is normally outside Git management, so it's safe
- **For team development**: Recommend each member obtains individual license key
