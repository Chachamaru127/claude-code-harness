---
description: Claude-mem integration setup for OpenCode
description-en: Claude-mem integration setup for cross-session memory in OpenCode
---

# /opencode-mem - Claude-mem Integration for OpenCode

Set up Claude-mem for cross-session memory in OpenCode.

---

## VibeCoder Phrases

- "**Enable memory for OpenCode**" → this command
- "**Set up Claude-mem for OpenCode**" → this command
- "**OpenCode memory integration**" → this command

## Deliverables

- **OpenCode plugin for Claude-mem**: Automatic context injection and observation recording
- **MCP server configuration**: Claude-mem as an MCP tool in OpenCode
- **Cross-session learning**: Utilize past session context in future sessions

---

## Prerequisites

1. **OpenCode installed** - https://opencode.ai
2. **Bun installed** - Required for Claude-mem worker

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        OpenCode                              │
├─────────────────────────────────────────────────────────────┤
│  Plugin Layer                                                │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ claude-mem-plugin.ts                                 │   │
│  │ - onSessionStart: Inject previous context            │   │
│  │ - onToolResult: Record observations                  │   │
│  │ - onSessionEnd: Generate summary                     │   │
│  └───────────────────────────┬─────────────────────────┘   │
│                              │                               │
│  MCP Layer                   │                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ claude-mem MCP Server                                │   │
│  │ - mem-search tool for explicit memory queries        │   │
│  └───────────────────────────┬─────────────────────────┘   │
│                              │                               │
└──────────────────────────────┼──────────────────────────────┘
                               │ HTTP API
                               ▼
┌─────────────────────────────────────────────────────────────┐
│              Claude-mem Worker (port 37777)                  │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ SQLite Database (~/.claude-mem/claude-mem.db)        │   │
│  │ - Sessions, Observations, Summaries                  │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

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

### Step 1: Check Bun Installation

```bash
if command -v bun &> /dev/null; then
  echo "✅ Bun is installed: $(bun --version)"
else
  echo "⚠️ Bun is not installed"
fi
```

**If Bun is not installed**:

**macOS / Linux**:

```bash
curl -fsSL https://bun.sh/install | bash
source ~/.bashrc  # or source ~/.zshrc
bun --version
```

**Windows (PowerShell)**:

```powershell
powershell -c "irm bun.sh/install.ps1 | iex"
bun --version
```

---

### Step 2: Install Claude-mem via npm

Unlike Claude Code which uses the plugin marketplace, OpenCode uses npm packages.

```bash
# Install claude-mem globally
npm install -g claude-mem

# Or install the MCP server directly
npm install -g claude-mem-mcp
```

**Verify installation**:

```bash
# Check if claude-mem-mcp is available
which claude-mem-mcp || npx -y claude-mem-mcp --version
```

---

### Step 3: Deploy Harness Mode Files

Deploy harness-specific mode configuration for enhanced observation types.

```bash
# Mode file destination
CLAUDE_MEM_MODES_DIR="$HOME/.claude-mem/modes"

# Create directory if it doesn't exist
mkdir -p "$CLAUDE_MEM_MODES_DIR"

# Copy harness.json (from harness repository)
# If you have claude-code-harness cloned:
cp /path/to/claude-code-harness/templates/modes/harness.json "$CLAUDE_MEM_MODES_DIR/"

# Or download directly
curl -o "$CLAUDE_MEM_MODES_DIR/harness.json" \
  https://raw.githubusercontent.com/Chachamaru127/claude-code-harness/main/templates/modes/harness.json
```

**For Japanese localization**:

```bash
cp /path/to/claude-code-harness/templates/modes/harness--ja.json "$CLAUDE_MEM_MODES_DIR/"
# Or download
curl -o "$CLAUDE_MEM_MODES_DIR/harness--ja.json" \
  https://raw.githubusercontent.com/Chachamaru127/claude-code-harness/main/templates/modes/harness--ja.json
```

---

### Step 4: Configure OpenCode Plugin

Create or update the OpenCode plugin configuration.

**Option A: Project-level plugin (recommended)**

Create `.opencode/plugin/claude-mem-plugin.ts` in your project:

```bash
mkdir -p .opencode/plugin

# Copy the plugin file from harness
cp /path/to/claude-code-harness/opencode/plugin/claude-mem-plugin.ts .opencode/plugin/
```

**Option B: Global plugin**

Install globally for all projects:

```bash
mkdir -p ~/.config/opencode/plugin

# Copy the plugin file
cp /path/to/claude-code-harness/opencode/plugin/claude-mem-plugin.ts ~/.config/opencode/plugin/
```

---

### Step 5: Configure MCP Server

Add Claude-mem as an MCP server in your `opencode.json`:

**Project-level** (`.opencode/opencode.json` or `opencode.json`):

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "claude-mem": {
      "type": "local",
      "enabled": true,
      "command": ["npx", "-y", "claude-mem-mcp"],
      "env": {
        "CLAUDE_MEM_MODE": "harness"
      }
    }
  }
}
```

**Global** (`~/.config/opencode/opencode.json`):

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "claude-mem": {
      "type": "local",
      "enabled": true,
      "command": ["npx", "-y", "claude-mem-mcp"],
      "env": {
        "CLAUDE_MEM_MODE": "harness"
      }
    }
  }
}
```

**For Japanese mode**:

```json
{
  "env": {
    "CLAUDE_MEM_MODE": "harness--ja"
  }
}
```

---

### Step 6: Configure Claude-mem Settings

Update Claude-mem settings file:

```bash
# Create settings file if it doesn't exist
mkdir -p ~/.claude-mem
cat > ~/.claude-mem/settings.json << 'EOF'
{
  "CLAUDE_MEM_MODE": "harness"
}
EOF
```

**For Japanese**:

```bash
cat > ~/.claude-mem/settings.json << 'EOF'
{
  "CLAUDE_MEM_MODE": "harness--ja"
}
EOF
```

---

### Step 7: Start Claude-mem Worker

The worker service must be running for memory features to work.

```bash
# Start the worker
npx -y claude-mem-mcp worker start

# Or if installed globally
claude-mem worker start
```

**Verify worker is running**:

```bash
curl http://127.0.0.1:37777/health
# Should return: {"status":"ok",...}
```

---

### Step 8: Verify Setup

> ✅ **OpenCode Claude-mem integration complete!**
>
> **Configuration Summary:**
> - Plugin: `.opencode/plugin/claude-mem-plugin.ts`
> - MCP Server: `opencode.json` with claude-mem
> - Mode: `harness` (or `harness--ja`)
> - Worker: Running on port 37777
>
> **Verification:**
> 1. Start OpenCode in your project
> 2. Check for "[claude-mem] Session started" message
> 3. Use `mem-search` to query previous sessions

---

## Available MCP Tools

Once configured, these tools are available in OpenCode:

| Tool | Description |
|------|-------------|
| `mem-search` | Search previous session observations |
| `mem-timeline` | Get chronological context around results |
| `mem-get-observations` | Fetch full observation details by ID |

**Example usage in OpenCode**:

```
Use mem-search to find how we handled authentication in previous sessions
```

---

## Windows-Specific Notes

### PowerShell Configuration

If running on Windows native (not WSL), update the MCP configuration:

```json
{
  "mcp": {
    "claude-mem": {
      "type": "local",
      "enabled": true,
      "command": ["cmd", "/c", "npx", "-y", "claude-mem-mcp"],
      "env": {
        "CLAUDE_MEM_MODE": "harness"
      }
    }
  }
}
```

### WSL Recommended

For best compatibility, run OpenCode inside WSL:

```bash
wsl
cd /home/user/projects/myproject
opencode
```

---

## Troubleshooting

### Worker not starting

```bash
# Check if port is occupied
lsof -i :37777  # Linux/macOS
netstat -ano | findstr 37777  # Windows

# Kill zombie processes
pkill -f "claude-mem"

# Restart worker
npx -y claude-mem-mcp worker restart
```

### Plugin not loading

1. Check plugin file exists:
   ```bash
   ls -la .opencode/plugin/claude-mem-plugin.ts
   ```

2. Check for TypeScript errors:
   ```bash
   bun check .opencode/plugin/claude-mem-plugin.ts
   ```

3. Verify OpenCode plugin discovery:
   ```bash
   opencode --list-plugins
   ```

### MCP server not connecting

```bash
# Test MCP server directly
npx -y claude-mem-mcp

# Check OpenCode config
cat opencode.json | jq '.mcp'

# Verify environment
echo $CLAUDE_MEM_MODE
```

---

## Differences from Claude Code Integration

| Feature | Claude Code | OpenCode |
|---------|-------------|----------|
| Installation | Plugin marketplace | npm + plugin file |
| Plugin location | `~/.claude/plugins/` | `.opencode/plugin/` |
| Config file | `.mcp.json` | `opencode.json` |
| Hooks | hooks.json | Plugin TypeScript exports |
| Context injection | Automatic via hooks | Via plugin onSessionStart |

---

## Integration with Cursor

If you also use Cursor, you can share the same Claude-mem database:

1. Both tools use the same worker on port 37777
2. Both use the same SQLite database
3. Memory is shared across all integrated tools

See `/harness-mem` for Cursor-specific setup.

---

## Related Commands

| Command | Purpose |
|---------|---------|
| `/harness-mem` | Claude Code / Cursor Claude-mem setup |
| `/sync-ssot-from-memory` | Promote observations to SSOT |
| `/sync-status` | Check harness integration status |
