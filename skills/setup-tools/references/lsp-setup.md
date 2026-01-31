# LSP Setup Reference

Introduce and configure LSP (Language Server Protocol) functionality to existing projects.

## Quick Reference

- "**Enable LSP**" → this setup
- "**Enable code jumping**" → Enable Go-to-definition
- "**I want to detect type errors beforehand**" → Configure LSP Diagnostics

## Deliverables

1. Auto-detect project languages
2. Check and install required language servers
3. Install official LSP plugins
4. Run verification tests

---

## Setup Flow

### Phase 1: Language Detection

```
Detection files:
├── tsconfig.json → TypeScript
├── package.json → JavaScript/TypeScript
├── requirements.txt → Python
├── pyproject.toml → Python
├── Cargo.toml → Rust
└── go.mod → Go
```

### Phase 2: Language Server Check and Installation

| Language | Language Server | Install Command |
|----------|-----------------|-----------------|
| **TypeScript/JS** | typescript-language-server | `npm install -g typescript typescript-language-server` |
| **Python** | pyright | `pip install pyright` or `npm install -g pyright` |
| **Rust** | rust-analyzer | [Official guide](https://rust-analyzer.github.io/manual.html#installation) |
| **Go** | gopls | `go install golang.org/x/tools/gopls@latest` |
| **C/C++** | clangd | macOS: `brew install llvm` / Ubuntu: `apt install clangd` |

**If not installed, prompt user**:

> Install them?
> - **yes** - Auto install (Recommended)
> - **manual** - Show commands only
> - **skip** - Continue without LSP

### Phase 3: Official Plugin Installation

```bash
# Install plugins for detected languages
claude plugin install typescript-lsp
claude plugin install pyright-lsp
```

### Phase 4: Verification

```
Test: Go-to-definition
  → src/index.ts:15 'handleSubmit' → src/handlers.ts:42

Test: Find-references
  → 'userId' references: 8 found

Test: Diagnostics
  → Errors: 0 / Warnings: 2
```

---

## Creating Custom LSP Plugins

If official plugins don't exist, create custom plugins (`.lsp.json`).

### `.lsp.json` Format

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

---

## Troubleshooting

### "Executable not found in $PATH" Error

```bash
# Check path
echo $PATH

# Check and add npm global path
export PATH="$PATH:$(npm config get prefix)/bin"
```

### LSP Not Responding

1. Restart Claude Code
2. Verify language server is correctly installed
3. Check plugin status with `/plugin`
