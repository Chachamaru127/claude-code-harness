---
description: Claude-mem integration setup for cross-session memory
---

# /harness-mem - Claude-mem Integration Setup

Customize Claude-mem for harness specifications to enhance cross-session quality and context maintenance.

---

## VibeCoder Phrases

- "**Integrate with Claude-mem**" → this command
- "**Enable cross-session memory**" → this command
- "**Set up harness-mem**" → this command

## Deliverables

- **Harness-specific mode settings for Claude-mem**: Auto-record guardrail activations, Plans.md updates, and SSOT changes
- **Cross-session learning**: Utilize past mistakes and solutions in future sessions
- **Japanese localization option**: Record observations and summaries in Japanese

---

## Prerequisites

Claude-mem plugin must be installed.
If not installed, this command will support the installation.

---

## Execution Flow

### Step 0: OS Detection

```bash
# Detect OS
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ -n "$WINDIR" ]]; then
  OS_TYPE="windows"
elif [[ "$OSTYPE" == "darwin"* ]]; then
  OS_TYPE="mac"
else
  OS_TYPE="linux"
fi
echo "Detected OS: $OS_TYPE"
```

---

### Step 0.5: Bun Installation Check

Claude-mem v7.3.7 and later uses Bun-based workers, so Bun installation is required.

```bash
# Check if Bun is installed
if command -v bun &> /dev/null; then
  echo "✅ Bun is installed: $(bun --version)"
else
  echo "⚠️ Bun is not installed"
fi
```

**If Bun is not installed**:

> ⚠️ **Bun is not installed**
>
> Bun is required for Claude-mem operation.
>
> Install now?
> 1. **Yes** - Install now (Recommended)
> 2. **No** - Install manually

**If "Yes"** - OS-specific installation:

**macOS / Linux / WSL**:

```bash
# Official install script
curl -fsSL https://bun.sh/install | bash

# Apply path after installation
source ~/.bashrc  # or source ~/.zshrc

# Verify
bun --version
```

**Windows (PowerShell)**:

```powershell
# Official install script
powershell -c "irm bun.sh/install.ps1 | iex"

# Or install via npm
npm install -g bun

# Verify
bun --version
```

**After installation**: Proceed to Step 1

---

**If Windows is detected**:

```bash
# Check claude-mem version
cat ~/.claude/plugins/marketplaces/thedotmack/plugin/package.json | grep version
```

> **Recommendations vary by claude-mem version**
>
> | Version | Recommendation |
> |---------|----------------|
> | **v7.3.7+** | ✅ Can work natively on Windows (improved) |
> | **v7.3.6 or earlier** | ⚠️ WSL strongly recommended (port 37777 issues frequent) |
>
> ---
>
> ### For v7.3.7+
>
> Native Windows operation has been significantly improved:
> - Automatic zombie process cleanup
> - Extended worker startup timeout (30 seconds)
> - Bun-based worker wrapper
>
> **→ Proceed to Step 3.5 (Windows Settings).**
>
> ---
>
> ### For v7.3.6 or earlier
>
> **WSL usage is strongly recommended.**
>
> **Root causes**:
> - PowerShell script (.ps1) execution issues
> - Broken file associations
> - Zombie processes occupying ports
>
> **Why it doesn't occur in WSL**:
> - Shell scripts execute natively
> - No dependency on file associations
> - Unix standard process management
>
> | Option | Recommendation |
> |--------|----------------|
> | **Run Claude Code in WSL** | ⭐⭐⭐ Strongly recommended |
> | Windows native | ⚠️ High risk of issues |
>
> **→ Proceed to Step 3.6 (WSL Setup).**
>
> ---
>
> ### Upgrade Recommended
>
> If using v7.3.6 or earlier, upgrade to the latest version is recommended:
>
> ```bash
> /plugin marketplace remove thedotmack/claude-mem
> /plugin marketplace add thedotmack/claude-mem
> /plugin install claude-mem
> ```

---

### Step 1: Claude-mem Installation Detection

```bash
# Check if Claude-mem plugin exists
ls ~/.claude/plugins/marketplaces/thedotmack 2>/dev/null
```

**If installed**: Proceed to Step 2

**If not installed**:

> ⚠️ **Claude-mem is not installed**
>
> Claude-mem installation is required to use cross-session
> quality and context maintenance features.
>
> **What is Claude-mem?**
> - Plugin that persists context across sessions
> - Auto-records and enables search of past work history
> - Combined with harness, quality improves cumulatively
>
> Install now?
> 1. **Yes** - Install now (Recommended)
> 2. **No** - Continue without Claude-mem

**If "Yes"**:

```bash
# Add from marketplace
/plugin marketplace add thedotmack/claude-mem

# Install
/plugin install claude-mem
```

If successful, proceed to Step 2. If failed, display error message and manual installation instructions.

---

### Step 2: Japanese Localization Option

> 🌐 **Do you want Claude-mem records in Japanese?**
>
> | Option | Description |
> |--------|-------------|
> | **Japanese** | Observations, summaries, and search results recorded in Japanese |
> | **English** | Default setting (records in English) |
>
> 1. **Use Japanese** (Recommended for Japanese environments)
> 2. **Keep English**

**Record selection**: `$HARNESS_MEM_LANG` = `ja` or `en`

---

### Step 3: Mode File Deployment

Deploy harness-specific mode file to Claude-mem.

```bash
# Mode file destination (official location)
CLAUDE_MEM_MODES_DIR="$HOME/.claude-mem/modes"

# Create directory if it doesn't exist
mkdir -p "$CLAUDE_MEM_MODES_DIR"

# Copy harness.json
cp templates/modes/harness.json "$CLAUDE_MEM_MODES_DIR/"

# If Japanese version selected
if [ "$HARNESS_MEM_LANG" = "ja" ]; then
  cp templates/modes/harness--ja.json "$CLAUDE_MEM_MODES_DIR/"
fi
```

---

### Step 3.5: Windows-Specific Settings (Windows only)

> **claude-mem v7.3.7+**: Native Windows operation improved ✅
>
> **v7.3.6 or earlier**: The following issues may occur ⚠️
>
> | Issue | Cause | v7.3.7 Fix |
> |-------|-------|------------|
> | Worker startup failure | PowerShell (.ps1) execution issues | Migrated to Bun wrapper |
> | port 37777 timeout | Zombie processes | Auto process cleanup |
> | Startup wait timeout | Too short timeout | Extended to 30 seconds |
>
> **If using v7.3.6 or earlier**: Upgrade to latest version or proceed to Step 3.6 (WSL) recommended

Windows cannot directly execute `.sh` files, so additional configuration is required.

> ⚠️ **Windows environment detected**
>
> The following settings are required for Claude-mem to work correctly:
>
> 1. **MCP settings adjustment**: Use `cmd /c` wrapper
> 2. **Path format conversion**: Support Windows path format

**Settings file update**:

Add the following to project's `.mcp.json` or `~/.claude/mcp.json`:

```json
{
  "mcpServers": {
    "claude-mem": {
      "command": "cmd",
      "args": ["/c", "npx", "-y", "claude-mem-mcp"],
      "env": {
        "CLAUDE_MEM_MODE": "harness"
      }
    }
  }
}
```

**Alternative settings (npx full path)**:

If npx is not found, specify the full path:

```json
{
  "mcpServers": {
    "claude-mem": {
      "command": "C:\\Program Files\\nodejs\\npx.cmd",
      "args": ["-y", "claude-mem-mcp"],
      "env": {
        "CLAUDE_MEM_MODE": "harness"
      }
    }
  }
}
```

**If using WSL (Recommended)**:

If running Claude Code in WSL environment, Unix settings can be used as-is.

```json
{
  "mcpServers": {
    "claude-mem": {
      "command": "npx",
      "args": ["-y", "claude-mem-mcp"],
      "env": {
        "CLAUDE_MEM_MODE": "harness"
      }
    }
  }
}
```

---

### Step 3.6: WSL Environment Setup (Windows + WSL)

Detailed settings for running Claude Code in WSL instead of Windows native.

#### Prerequisites Check

```bash
# 1. Check if WSL2 is installed (run in PowerShell)
wsl --version

# 2. Check if Node.js is Linux version inside WSL
wsl -e bash -c "which node && which npm"
# Correct: /usr/bin/node, /usr/bin/npm
# Problem: /mnt/c/Program Files/nodejs/node (referencing Windows version)
```

#### Resolving "/bin/bash not found" Issue

**Symptom**:
```
/bin/bash: line 1: sh: command not found
```

**Cause**: WSL's PATH has Windows Node.js/npm prioritized

**Solution**:

```bash
# 1. Run inside WSL - Disable Windows PATH
echo '[interop]
appendWindowsPath = false' | sudo tee -a /etc/wsl.conf

# 2. Restart WSL (run in PowerShell)
wsl --shutdown

# 3. Install Node.js inside WSL (nvm recommended)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source ~/.bashrc
nvm install --lts
nvm use --lts

# 4. Verify
which node  # → /home/user/.nvm/versions/node/v20.x.x/bin/node
which npm   # → /home/user/.nvm/versions/node/v20.x.x/bin/npm
```

#### Resolving "Worker won't start on port 37777" Issue

**Symptom**:
```
Worker service failed to start on port 37777
Worker failed to start (readiness check timed out after 20000ms)
```

**Cause**: Zombie process occupying port, or previous worker didn't terminate properly

**Solution**:

```bash
# 1. Check port 37777 usage
# Inside WSL
lsof -i :37777
# Or Windows (PowerShell)
netstat -ano | findstr 37777

# 2. Terminate zombie processes
# Inside WSL
pkill -f "claude-mem"
pkill -f "bun"

# Windows (PowerShell - Administrator)
taskkill /F /IM bun.exe
taskkill /F /IM node.exe

# 3. Check worker log
cat ~/.claude-mem/logs/worker.log

# 4. Manually restart worker
cd ~/.claude/plugins/marketplaces/thedotmack
npm run worker:restart

# 5. Restart Claude Code
```

#### WSL File Performance Optimization

```bash
# Place projects inside WSL filesystem (recommended)
# ✅ Good example
cd ~/projects/my-app

# ❌ Bad example (slow)
cd /mnt/c/Users/username/projects/my-app
```

> ⚠️ Performance significantly degrades under `/mnt/c/`.
> Place projects under `~/`.

---

### Step 4: settings.json Update

Update Claude-mem settings file.

```bash
# settings.json path
CLAUDE_MEM_SETTINGS="$HOME/.claude-mem/settings.json"

# Create settings file if it doesn't exist
if [ ! -f "$CLAUDE_MEM_SETTINGS" ]; then
  mkdir -p "$HOME/.claude-mem"
  echo '{}' > "$CLAUDE_MEM_SETTINGS"
fi
```

**Settings content**:

```json
{
  "CLAUDE_MEM_MODE": "harness"  // or "harness--ja"
}
```

Set `"harness--ja"` if Japanese is selected.

---

### Step 5: Completion Confirmation

> ✅ **Claude-mem integration complete!**
>
> **Settings:**
> - Mode: `harness` (or `harness--ja`)
> - Mode file: `~/.claude-mem/modes/harness.json`
> - Settings file: `~/.claude-mem/settings.json`
>
> **Effective from next session.**
>
> **Verification:**
> - Claude-mem starts in harness mode at next session start
> - Check Claude-mem status with `/sync-status`
>
> **Usage:**
> - Search past work history with `mem-search` skill
> - Display past guardrail activation history at session-init
> - Promote important observations to SSOT with `/sync-ssot-from-memory`

---

## Content Recorded in Harness Mode

### observation_types

| Type | Description | Emoji |
|------|-------------|-------|
| `plan` | Task additions/updates to Plans.md | 📋 |
| `implementation` | Implementation following harness rules | 🛠️ |
| `guard` | Guardrail activation (test-quality, implementation-quality) | 🛡️ |
| `review` | Code review execution | 🔍 |
| `ssot` | decisions.md/patterns.md updates | 📚 |
| `handoff` | PM ↔ Impl role transitions | 🤝 |
| `workflow` | Workflow improvements/automation | ⚙️ |

### observation_concepts

| Concept | Description |
|---------|-------------|
| `test-quality` | Test tampering prevention/quality enforcement |
| `implementation-quality` | Stub/mock/hardcode prevention |
| `harness-pattern` | Harness-specific reusable patterns |
| `2-agent` | PM/Impl collaboration patterns |
| `quality-gate` | Quality gate activation points |
| `ssot-decision` | SSOT decision records |

---

## Use Cases

### 1. Cross-session Guardrails

```
Day 1: Block test tampering
Claude-mem: Record "guard: blocked it.skip()"

Day 3 (different session):
session-init: "This project has prevented test tampering 2 times in the past"
→ Warn about same mistake in advance
```

### 2. Long-term Task Context Maintenance

```
Week 1: Feature X design complete
Claude-mem: Record "plan: Feature X design complete, adopted RBAC"

Week 2 (different session):
session-init: "Previous: Feature X design complete. Next: Implementation phase"
→ Immediately continue from where left off
```

### 3. Debug Pattern Learning

```
Past: Resolved CORS error
Claude-mem: Record "bugfix: CORS - added Access-Control-Allow-Origin"

Present: Similar error occurs
mem-search: Hits past solution
→ Resolve in 5 minutes (previously 30 minutes)
```

---

## Troubleshooting

### WSL: /bin/bash not found

```
/bin/bash: line 1: sh: command not found
```

**Cause**: WSL inherits Windows PATH and references Windows version Node.js

**Solution**: See "Resolving /bin/bash not found Issue" in Step 3.6

**Related Issue**: [GitHub Issue #210](https://github.com/thedotmack/claude-mem/issues/210)

---

### WSL/Windows: Worker won't start on port 37777

```
Worker service failed to start on port 37777
Worker failed to start (readiness check timed out after 20000ms)
```

> **First check claude-mem version**
>
> ```bash
> cat ~/.claude/plugins/marketplaces/thedotmack/plugin/package.json | grep version
> ```
>
> | Version | Action |
> |---------|--------|
> | **v7.3.7+** | Can be resolved with troubleshooting below |
> | **v7.3.6 or earlier** | Strongly recommend upgrade to latest version |

**If issue occurs on v7.3.7+**:

```bash
# 1. Terminate zombie processes
taskkill /F /IM bun.exe       # Windows
taskkill /F /IM node.exe      # Windows

# 2. Delete PID file
del %USERPROFILE%\.claude-mem\worker.pid

# 3. Restart Claude Code
```

---

**For v7.3.6 or earlier (root causes)**:

| Cause | Details |
|-------|---------|
| **PowerShell execution issue** | `.ps1` file opens in Notepad, or execution policy restrictions |
| **Broken file associations** | `bun.ps1` wrapper doesn't execute correctly |
| **Zombie processes** | Previous `bun.exe` / `node.exe` occupying port |
| **Stale PID file** | `~/.claude-mem/worker.pid` holds old process info |

**Why it doesn't occur in WSL**:
- Shell scripts execute natively
- No dependency on file associations
- Unix standard process management (reliable signal handling)

**Recommended solutions**:
1. **Upgrade to latest version** (Recommended)
2. **Migrate to WSL** (See Step 3.6)

**Temporary workarounds for v7.3.6 or earlier** (limited effectiveness):

```bash
# 1. Check port usage
netstat -ano | findstr 37777  # Windows
lsof -i :37777                 # WSL/Linux

# 2. Terminate zombie processes
taskkill /F /IM bun.exe       # Windows
taskkill /F /IM node.exe      # Windows
pkill -f "claude-mem"          # WSL/Linux

# 3. Delete PID file
del %USERPROFILE%\.claude-mem\worker.pid  # Windows
rm ~/.claude-mem/worker.pid                # WSL/Linux

# 4. Manually restart worker
cd ~/.claude/plugins/marketplaces/thedotmack
npm run worker:restart

# 5. Or directly run bun.exe (bypass PowerShell)
%USERPROFILE%\.bun\bin\bun.exe plugin/scripts/worker-service.cjs
```

> ⚠️ **Note**: The above workarounds are temporary and not fundamental solutions.
> **WSL migration is strongly recommended.**

**Related Issues**:
- [Issue #380](https://github.com/thedotmack/claude-mem/issues/380) - Windows 11 port 37777 error
- [Issue #209](https://github.com/thedotmack/claude-mem/issues/209) - Worker won't start on Windows

---

### Windows: ENOENT Error

```
ENOENT: no such file or directory
C:\Users\user\AppData\Local\claude-cli-nodejs\Cache\...
```

**Cause**: Known issue with Windows path handling ([Issue #229](https://github.com/thedotmack/claude-mem/issues/229))

**Solution**:

1. **Use WSL** (Recommended)
   ```bash
   # Run Claude Code inside WSL
   wsl
   claude
   ```

2. **Manually create directory**
   ```powershell
   mkdir -p $env:LOCALAPPDATA\claude-cli-nodejs\Cache
   ```

3. **Wait for issue fix**
   - Watch [Issue #229](https://github.com/thedotmack/claude-mem/issues/229)

---

### Windows: npx not found

**Cause**: Node.js not included in PATH

**Solution**:

```json
// Specify absolute path in .mcp.json
{
  "mcpServers": {
    "claude-mem": {
      "command": "C:\\Program Files\\nodejs\\npx.cmd",
      "args": ["-y", "claude-mem-mcp"]
    }
  }
}
```

---

### Windows: .sh opens in VSCode/Cursor

**Cause**: Windows file association issue ([Issue #9758](https://github.com/anthropics/claude-code/issues/9758))

**Solution**: Use `bash` prefix in hooks.json

```json
// Before fix
"command": "${CLAUDE_PLUGIN_ROOT}/scripts/example.sh"

// After fix
"command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/example.sh"
```

> ⚠️ **Auto-applied in harness v2.6.7+**

---

### Claude-mem not working

```bash
# Check plugin list
/plugin list

# Check Claude-mem status
ls ~/.claude/plugins/marketplaces/thedotmack

# Reinstall
/plugin uninstall claude-mem
/plugin install claude-mem
```

### Mode not applied

```bash
# Check settings.json
cat ~/.claude-mem/settings.json

# Verify CLAUDE_MEM_MODE is set
# Correct: {"CLAUDE_MEM_MODE": "harness"}
```

### Not recording in Japanese

```bash
# Check if harness--ja mode is set
cat ~/.claude-mem/settings.json
# → Should be {"CLAUDE_MEM_MODE": "harness--ja"}

# Check if mode file exists
ls ~/.claude-mem/modes/harness--ja.json
```

---

## Disable

To disable harness mode in Claude-mem:

```bash
# Edit settings.json
# Change CLAUDE_MEM_MODE back to "code", or delete it
```

```json
{
  "CLAUDE_MEM_MODE": "code"
}
```

---

## Cursor Integration

> **v2.6.18+**: Use the official claude-mem v8.5.0+ feature for Cursor integration.
>
> ```bash
> # Run in claude-mem repository
> git clone https://github.com/thedotmack/claude-mem.git
> cd claude-mem
> bun install
> bun run cursor:install
> ```
>
> See [claude-mem CHANGELOG](https://github.com/thedotmack/claude-mem/blob/main/CHANGELOG.md) for details.

---

## Related Commands/Skills

| Command/Skill | Purpose |
|---------------|---------|
| `/sync-ssot-from-memory` | Promote important Claude-mem observations to SSOT |
| `mem-search` | Search past work history |
| `session-init` | Display past context at session start (with Claude-mem integration) |
| `/harness-init` | Project initialization (Claude-mem integration is separate via `/harness-mem`) |
