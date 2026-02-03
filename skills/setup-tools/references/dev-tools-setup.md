# Development Tools Setup Reference

Setup AST-Grep and LSP to enable advanced code intelligence features.

## Why MCP?

Simply installing AST-Grep and LSP doesn't help - Claude will continue using standard tools (Grep, Read, Bash).

**By using MCP**:

| Issue | MCP Solution |
|-------|--------------|
| Claude doesn't know `sg` command | Provide as `harness_ast_search` explicitly |
| Can't call from skills | Reference as MCP tool in skills |
| Usage unclear | Document purpose and patterns in tool description |

**Result**: `/harness-review` and harness-review skill automatically use `harness_ast_search`, improving code smell detection accuracy.

---

## What This Enables

After setup, these MCP tools become available:

| Tool | Purpose |
|------|---------|
| `harness_ast_search` | Structural code pattern search |
| `harness_lsp_references` | Find all symbol references |
| `harness_lsp_definition` | Go to symbol definition |
| `harness_lsp_diagnostics` | Get code diagnostics |
| `harness_lsp_hover` | Get type information |

---

## Execution Flow

### Step 1: Detect Project Languages

```bash
# Auto-detect languages
ls package.json 2>/dev/null && echo "TypeScript/JavaScript detected"
ls requirements.txt pyproject.toml 2>/dev/null && echo "Python detected"
ls Cargo.toml 2>/dev/null && echo "Rust detected"
ls go.mod 2>/dev/null && echo "Go detected"
```

### Step 2: Check AST-Grep Installation

```bash
which sg || echo "AST-Grep not found"
```

**If not installed**:

| Platform | Install Command |
|----------|-----------------|
| macOS | `brew install ast-grep` |
| npm (any) | `npm install -g @ast-grep/cli` |
| Cargo (any) | `cargo install ast-grep --locked` |

### Step 3: Check LSP Installation

| Language | Check Command | Install Command |
|----------|---------------|-----------------|
| TypeScript/JS | `which typescript-language-server` | `npm install -g typescript-language-server typescript` |
| Python | `which pylsp` | `pip install python-lsp-server` |
| Rust | `which rust-analyzer` | `rustup component add rust-analyzer` |
| Go | `which gopls` | `go install golang.org/x/tools/gopls@latest` |

### Step 4: Configure MCP Server

#### 4.1: Check MCP Server Build

```bash
ls "${CLAUDE_PLUGIN_ROOT}/mcp-server/dist/index.js" 2>/dev/null || echo "Not built"
```

**If not built**:
```bash
cd "${CLAUDE_PLUGIN_ROOT}/mcp-server"
npm install
npm run build
```

#### 4.2: Choose Configuration Scope

**Ask user**:

> Choose MCP server configuration scope:
>
> 1. Global (Recommended)
>    - Configure in ~/.mcp.json
>    - Harness MCP tools available in all projects
>    - Configure once, use everywhere
>
> 2. Project-specific
>    - Configure in .mcp.json (project root)
>    - Only for this project
>    - Can be included in repo for team sharing

#### 4.3: Create Configuration File

**For global**:

`~/.mcp.json`:
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

**For project-specific**:

`.mcp.json`:
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

### Step 5: Report Status

```markdown
## Development Tools Status

### AST-Grep
- Status: Installed / Not Installed
- Version: x.x.x
- Command: `sg`

### Language Servers
| Language | Status | Server |
|----------|--------|--------|
| TypeScript | / | typescript-language-server |
| Python | / | pylsp |

### MCP Server
- Status: Configured / Not Configured
- Config: `.mcp.json`

### Available MCP Tools
- `harness_ast_search` - Structural code search
- `harness_lsp_references` - Find references
- `harness_lsp_definition` - Go to definition
- `harness_lsp_diagnostics` - Get diagnostics
- `harness_lsp_hover` - Type information
```

---

## Usage Examples

### AST-Grep Search

```bash
# Find all console.log calls
harness_ast_search pattern="console.log($$$)" language="typescript"

# Find empty catch blocks (code smell)
harness_ast_search pattern="catch ($ERR) { }" language="typescript"

# Find async functions without await
harness_ast_search pattern="async function $NAME($$$) { $BODY }" language="typescript"
```

### LSP Analysis

```bash
# Find references to a function
harness_lsp_references file="src/utils.ts" line=10 column=5

# Get diagnostics for a file
harness_lsp_diagnostics file="src/components/App.tsx"
```

---

## Integration with /harness-review

When AST-Grep is installed, `/harness-review` automatically:

1. Detects code smells:
   - `console.log` remnants
   - Empty catch blocks
   - Unused async/await
   - Magic numbers

2. Reports findings in review output
