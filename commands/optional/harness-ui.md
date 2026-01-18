---
description: Open harness-ui dashboard and check status
description-en: Open harness-ui dashboard and check status
---

# /harness-ui - Dashboard Display

Open harness-ui dashboard and check project status.

## VibeCoder Phrases

- "**Open the dashboard**" → this command
- "**I want to see harness-ui**" → this command
- "**Check status in UI**" → this command

## Deliverables

- Open harness-ui in browser
- Check server status
- Display registered projects list

---

## Execution Flow

### Step 1: License Key Check

```bash
# Check environment variable
echo $HARNESS_BETA_CODE
```

**If key is set (not empty):**
→ Proceed to Step 2

**If key is not set or empty:**

> 🔑 **License key required to use harness-ui**
>
> Run `/harness-ui-setup YOUR-LICENSE-KEY` to set up.
>
> If you don't have a license key, please contact administrator.

**End processing**

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

## Related Commands

- `/harness-ui-setup` - Initial setup (license key configuration)
- `/validate` - Plugin validation

---

## Troubleshooting

### Server won't start

1. Restart Claude Code
2. Check if port 37778 is in use: `lsof -i :37778`
3. Check if environment variable `HARNESS_BETA_CODE` is set

### Want to reset license key

```
/harness-ui-setup NEW-LICENSE-KEY
```
