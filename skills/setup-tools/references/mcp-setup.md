# MCP Server Setup Reference

Setup Harness MCP server for cross-client communication between Claude Code, Codex, and Cursor.

## Quick Reference

- "**Codex と連携したい**" → MCP setup
- "**別のAIツールと一緒に使いたい**" → MCP setup
- "**セッション共有したい**" → Cross-client communication

## Deliverables

- MCP server configuration files
- Client-specific setup instructions
- Verification guide

---

## Execution Flow

### Step 1: Client Selection

> Which clients will use MCP?
> 1. Claude Code only
> 2. Claude Code + Codex
> 3. Claude Code + Cursor
> 4. All (Claude Code + Codex + Cursor)

**Wait for response**

### Step 2: Generate Configuration Files

#### Claude Code Configuration

Add to `.claude/settings.json`:

```json
{
  "mcpServers": {
    "harness": {
      "command": "node",
      "args": ["${CLAUDE_PLUGIN_ROOT}/mcp-server/dist/index.js"]
    }
  }
}
```

#### Codex Configuration (if selected)

Generate `~/.codex/mcp.json`:

```json
{
  "servers": {
    "harness": {
      "command": "node",
      "args": ["/path/to/claude-code-harness/mcp-server/dist/index.js"]
    }
  }
}
```

#### Cursor Configuration (if selected)

Generate `.cursor/mcp.json`:

```json
{
  "harness": {
    "command": "node",
    "args": ["/path/to/claude-code-harness/mcp-server/dist/index.js"]
  }
}
```

### Step 3: Build MCP Server

```bash
cd "${CLAUDE_PLUGIN_ROOT}/mcp-server"
npm install
npm run build
```

### Step 4: Verification

**Available tools after setup**:

| Tool | Description |
|------|-------------|
| `harness_session_list` | List active sessions |
| `harness_session_broadcast` | Notify all sessions |
| `harness_session_inbox` | Check received messages |
| `harness_workflow_plan` | Create plan |
| `harness_workflow_work` | Execute tasks |
| `harness_workflow_review` | Code review |
| `harness_status` | Project status |

**Verification steps**:
1. Restart Claude Code
2. Type "execute harness_session_list"
3. Success if session list displays

---

## Cross-Client Workflow Example

### Scenario: Working on same project with Claude Code and Codex

```
[Claude Code]
You: Execute harness_session_register, client: "claude-code"
Claude: Session registered: session-abc123 (claude-code)

You: I changed the API, broadcast it
Claude: Broadcast sent: "UserAPI: userId → user changed"

---

[Codex]
You: Check harness_session_inbox
Codex: 1 message(s):
       [10:30] claude-code: UserAPI: userId → user changed

You: OK, continue implementation with new API
```

---

## Available MCP Tools

### Session Tools

| Tool | Args | Description |
|------|------|-------------|
| `harness_session_list` | none | List active sessions |
| `harness_session_broadcast` | `message: string` | Send message |
| `harness_session_inbox` | `since?: string` | Check received |
| `harness_session_register` | `client, sessionId` | Register session |

### Workflow Tools

| Tool | Args | Description |
|------|------|-------------|
| `harness_workflow_plan` | `task, mode?` | Create plan |
| `harness_workflow_work` | `parallel?, full?, taskId?` | Execute tasks |
| `harness_workflow_review` | `files?, focus?, ci?` | Review |

---

## Troubleshooting

### MCP server won't start

**Cause**: Node.js version too old

**Solution**: Install Node.js 18+
```bash
node --version  # v18.0.0 or higher required
```

### Tools not found

**Cause**: MCP server not built

**Solution**:
```bash
cd /path/to/claude-code-harness/mcp-server
npm run build
```

### Messages not delivered between sessions

**Cause**: Not running in same project directory

**Solution**: Start both clients in the same project root
