---
description: "[Optional] LSP setup (Language Server installation and configuration)"
description-en: "[Optional] LSP setup (Language Server installation and configuration)"
---

# /lsp-setup - LSP Setup

Introduce and configure LSP (Language Server Protocol) functionality to existing projects.

## VibeCoder Phrases

- "**Enable LSP**" → this command
- "**Enable code jumping**" → Enable Go-to-definition
- "**I want to detect type errors beforehand**" → Configure LSP Diagnostics

## Deliverables

1. Auto-detect project languages
2. Check and install required language servers
3. **Install official LSP plugins**
4. Run verification tests

---

## Official LSP Plugins (Recommended)

Official LSP plugins available in Claude Code marketplace:

| Plugin | Language | Required Language Server |
|--------|----------|-------------------------|
| `typescript-lsp` | TypeScript/JavaScript | typescript-language-server |
| `pyright-lsp` | Python | pyright |
| `rust-analyzer-lsp` | Rust | rust-analyzer |

> **Important**: Plugins do **not include** language server binaries.
> Separate installation is required.

---

## Setup Flow

### Phase 1: Language Detection

```
🔍 Detecting Project Languages

Detection files:
├── tsconfig.json → TypeScript ✅
├── package.json → JavaScript/TypeScript ✅
├── requirements.txt → Python ✅
├── pyproject.toml → Python ✅
├── Cargo.toml → Rust
└── go.mod → Go

Detection results:
├── TypeScript ✅
└── Python ✅
```

### Phase 2: Language Server Check and Installation

```
🔧 Language Server Status

| Language | Language Server | Status |
|----------|-----------------|--------|
| TypeScript | typescript-language-server | ❌ Not installed |
| Python | pyright | ❌ Not installed |

❌ Some language servers are not installed.
```

> **Install them?**
>
> - **yes** - Auto install (Recommended)
> - **manual** - Show commands only
> - **skip** - Continue without LSP

**Wait for response**

#### If "yes" selected: Auto Installation

```bash
echo "📦 Installing language servers..."

# TypeScript
npm install -g typescript typescript-language-server
echo "✅ typescript-language-server installation complete"

# Python
pip install pyright
# or npm install -g pyright
echo "✅ pyright installation complete"

# Verify installation
which typescript-language-server && echo "✅ TypeScript LSP: OK"
which pyright && echo "✅ Python LSP: OK"
```

#### If "manual" selected: Display Commands

```
📋 Please run the following commands:

# TypeScript/JavaScript
npm install -g typescript typescript-language-server

# Python
pip install pyright
# or
npm install -g pyright

# Rust
# rust-analyzer official installation: https://rust-analyzer.github.io/manual.html#installation

After installation, run /lsp-setup again.
```

### Phase 3: Official Plugin Installation

```
📦 Installing official LSP plugins...
```

```bash
# Install plugins for detected languages
claude plugin install typescript-lsp
claude plugin install pyright-lsp

echo "✅ LSP plugin installation complete"
```

```
✅ Installed plugins:

| Plugin | Status |
|--------|--------|
| typescript-lsp | ✅ Installed |
| pyright-lsp | ✅ Installed |
```

### Phase 4: Verification

```
✅ LSP Verification

Test: Go-to-definition
  → src/index.ts:15 'handleSubmit' → src/handlers.ts:42 ✅

Test: Find-references
  → 'userId' references: 8 found ✅

Test: Diagnostics
  → Errors: 0 / Warnings: 2 ✅

🎉 LSP Setup Complete!
```

---

## Language Server and Plugin Reference Table

| Language | Language Server | Install Command | Official Plugin |
|----------|-----------------|-----------------|-----------------|
| **TypeScript/JS** | typescript-language-server | `npm install -g typescript typescript-language-server` | `typescript-lsp` |
| **Python** | pyright | `pip install pyright` or `npm install -g pyright` | `pyright-lsp` |
| **Rust** | rust-analyzer | [Official guide](https://rust-analyzer.github.io/manual.html#installation) | `rust-analyzer-lsp` |
| **Go** | gopls | `go install golang.org/x/tools/gopls@latest` | `gopls-lsp` |
| **C/C++** | clangd | macOS: `brew install llvm` / Ubuntu: `apt install clangd` | `clangd-lsp` |
| **Java** | jdtls | [Official guide](https://github.com/eclipse/eclipse.jdt.ls) | `jdtls-lsp` |
| **Swift** | sourcekit-lsp | Included with Xcode | `swift-lsp` |
| **Lua** | lua-language-server | [Official guide](https://github.com/LuaLS/lua-language-server) | `lua-lsp` |
| **PHP** | intelephense | `npm install -g intelephense` | `php-lsp` |
| **C#** | omnisharp | [Official guide](https://github.com/OmniSharp/omnisharp-roslyn) | `csharp-lsp` |

---

## Zero to Setup Guide (Summary)

Steps to enable LSP from a completely unconfigured state:

```bash
# Step 1: Install language servers
npm install -g typescript typescript-language-server  # TypeScript
pip install pyright                                    # Python

# Step 2: Install official plugins
claude plugin install typescript-lsp
claude plugin install pyright-lsp

# Step 3: Start Claude Code (LSP auto-enabled)
claude
```

Now Go-to-definition, Find-references, and Diagnostics are available.

---

## Creating Custom LSP Plugins

If official plugins don't exist in the marketplace for your language, or if you need custom LSP server configuration, you can create custom plugins (`.lsp.json`).

> **Note**: TypeScript/JS, Python, Rust, Go, C/C++, Java, Swift, Lua, PHP, C# have official plugins. First search "lsp" with `/plugin`.

### `.lsp.json` Format

**Example**: Starting Go LSP server with custom settings

```json
{
  "go": {
    "command": "gopls",
    "args": ["serve"],
    "extensionToLanguage": {
      ".go": "go"
    }
  }
}
```

### Required Fields

| Field | Description |
|-------|-------------|
| `command` | LSP server binary name (must exist in PATH) |
| `extensionToLanguage` | File extension → language identifier mapping |

### Optional Fields

| Field | Description |
|-------|-------------|
| `args` | Command line arguments |
| `env` | Environment variables |
| `initializationOptions` | Initialization options |
| `startupTimeout` | Startup timeout (milliseconds) |
| `restartOnCrash` | Auto-restart on crash |

### Custom Plugin Creation Example

```bash
# Create directory
mkdir my-go-lsp
mkdir my-go-lsp/.claude-plugin

# plugin.json
cat > my-go-lsp/.claude-plugin/plugin.json << 'EOF'
{
  "name": "my-go-lsp",
  "description": "Go LSP support",
  "version": "1.0.0",
  "author": { "name": "Your Name" },
  "lspServers": "./.lsp.json"
}
EOF

# .lsp.json
cat > my-go-lsp/.lsp.json << 'EOF'
{
  "go": {
    "command": "gopls",
    "args": ["serve"],
    "extensionToLanguage": {
      ".go": "go"
    }
  }
}
EOF

# Install
claude plugin install ./my-go-lsp
```

---

## Troubleshooting

### "Executable not found in $PATH" Error

Language server is not installed or not in PATH.

```bash
# Check path
echo $PATH

# Check and add npm global path
export PATH="$PATH:$(npm config get prefix)/bin"
```

### Check Plugin Errors

```
Check "Errors" tab with /plugin command
```

### LSP Not Responding

1. Restart Claude Code
2. Verify language server is correctly installed
3. Check plugin status with `/plugin`

---

## Related Documentation

- [docs/LSP_INTEGRATION.md](../../docs/LSP_INTEGRATION.md) - LSP Usage Guide
- [Claude Code Plugins Reference](https://code.claude.com/docs/en/plugins-reference) - Official Plugin Reference
