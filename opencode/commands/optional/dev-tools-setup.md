---
description: 開発ツール (AST-Grep, LSP) を一括セットアップ
---

# /dev-tools-setup - Development Tools Setup

Setup AST-Grep and LSP to enable advanced code intelligence features.

---

## Why MCP? (設計意図)

AST-Grep や LSP を「ただインストールするだけ」では、Claude は標準ツール（Grep, Read, Bash など）を使い続けてしまいます。

**MCP 化することで**:

| 課題 | MCP による解決 |
|------|---------------|
| Claude が `sg` コマンドを知らない | `harness_ast_search` として明示的に提供 |
| スキルから呼び出せない | MCP ツールとしてスキル内で参照可能 |
| 使い方が不明確 | ツール説明に用途・パターンを記載 |

**結果**: `/review` や review スキルが自動的に `harness_ast_search` を使用し、コードスメル検出の精度が向上します。

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
# Check if ast-grep is installed
which sg || echo "AST-Grep not found"
```

**If not installed, suggest:**

| Platform | Install Command |
|----------|-----------------|
| macOS | `brew install ast-grep` |
| npm (any) | `npm install -g @ast-grep/cli` |
| Cargo (any) | `cargo install ast-grep --locked` |

### Step 3: Check LSP Installation

Based on detected languages:

| Language | Check Command | Install Command |
|----------|---------------|-----------------|
| TypeScript/JS | `which typescript-language-server` | `npm install -g typescript-language-server typescript` |
| Python | `which pylsp` | `pip install python-lsp-server` |
| Rust | `which rust-analyzer` | `rustup component add rust-analyzer` |
| Go | `which gopls` | `go install golang.org/x/tools/gopls@latest` |

### Step 4: Configure MCP Server

MCP ツールを有効にするため、harness MCP サーバーを設定します。

#### 4.1: MCP サーバービルド確認

```bash
# MCP サーバーがビルド済みか確認
ls "${CLAUDE_PLUGIN_ROOT}/mcp-server/dist/index.js" 2>/dev/null || echo "Not built"
```

**ビルドされていない場合:**

```bash
cd "${CLAUDE_PLUGIN_ROOT}/mcp-server"
npm install
npm run build
```

#### 4.2: 設定スコープの選択（ユーザー確認必須）

> 🔴 **AskUserQuestion ツールで確認すること**

ユーザーに以下を確認:

```
MCP サーバーの設定スコープを選択してください:

1. グローバル設定（推奨）
   - ~/.mcp.json に設定
   - すべてのプロジェクトで harness MCP ツールが使用可能
   - 一度設定すれば他のプロジェクトで再設定不要

2. プロジェクト固有設定
   - .mcp.json（プロジェクトルート）に設定
   - このプロジェクトのみで使用可能
   - リポジトリに含めてチームで共有可能
```

#### 4.3: 設定ファイル作成

**グローバル設定の場合:**

`~/.mcp.json` に追加:

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

```bash
# ~/.mcp.json が存在しない場合は作成
if [ ! -f ~/.mcp.json ]; then
  cat > ~/.mcp.json << 'EOF'
{
  "mcpServers": {
    "harness": {
      "command": "node",
      "args": ["${CLAUDE_PLUGIN_ROOT}/mcp-server/dist/index.js"]
    }
  }
}
EOF
  echo "Created ~/.mcp.json (global)"
else
  echo "~/.mcp.json already exists - please add harness MCP server manually"
fi
```

**プロジェクト固有設定の場合:**

`.mcp.json`（プロジェクトルート）に追加:

```bash
# .mcp.json が存在しない場合は作成
if [ ! -f .mcp.json ]; then
  cat > .mcp.json << 'EOF'
{
  "mcpServers": {
    "harness": {
      "command": "node",
      "args": ["${CLAUDE_PLUGIN_ROOT}/mcp-server/dist/index.js"]
    }
  }
}
EOF
  echo "Created .mcp.json (project)"
else
  echo ".mcp.json already exists - please add harness MCP server manually"
fi
```

#### 4.4: 動作確認

```bash
# Claude Code を再起動後、MCP ツールが利用可能か確認
# harness_ast_search, harness_lsp_* などが使用可能になる
```

### Step 5: Report Status

```markdown
## 🔧 Development Tools Status

### AST-Grep
- Status: ✅ Installed / ❌ Not Installed
- Version: x.x.x
- Command: `sg`

### Language Servers

| Language | Status | Server |
|----------|--------|--------|
| TypeScript | ✅/❌ | typescript-language-server |
| Python | ✅/❌ | pylsp |

### MCP Server
- Status: ✅ Configured / ❌ Not Configured
- Config: `.mcp.json`

### Available MCP Tools

After setup complete:
- `harness_ast_search` - Structural code search
- `harness_lsp_references` - Find references
- `harness_lsp_definition` - Go to definition
- `harness_lsp_diagnostics` - Get diagnostics
- `harness_lsp_hover` - Type information

### Next Steps

1. Install missing tools (commands shown above)
2. Restart Claude Code session
3. MCP tools are now available in your workflow
```

---

## Usage Examples

### After Setup: AST-Grep Search

```bash
# Find all console.log calls
harness_ast_search pattern="console.log($$$)" language="typescript"

# Find empty catch blocks (code smell)
harness_ast_search pattern="catch ($ERR) { }" language="typescript"

# Find async functions without await
harness_ast_search pattern="async function $NAME($$$) { $BODY }" language="typescript"
```

### After Setup: LSP Analysis

```bash
# Find references to a function
harness_lsp_references file="src/utils.ts" line=10 column=5

# Get diagnostics for a file
harness_lsp_diagnostics file="src/components/App.tsx"
```

---

## Integration with /review

When AST-Grep is installed, `/review` automatically:

1. Detects code smells:
   - `console.log` remnants
   - Empty catch blocks
   - Unused async/await
   - Magic numbers

2. Reports findings in review output

---

## VibeCoder Hints

| What You Want | How to Say |
|---------------|------------|
| Setup tools | "setup development tools" |
| Check installation | "are AST and LSP installed?" |
| Search patterns | "find all console.log" |
| Find references | "where is this function used?" |

---

## Troubleshooting

### AST-Grep not working

```bash
# Check installation
which sg
sg --version

# Test search
sg --pattern "console.log" --lang typescript .
```

### LSP not working

```bash
# Check TypeScript server
which typescript-language-server
typescript-language-server --version

# Check if tsconfig.json exists
ls tsconfig.json
```

### Still issues?

1. Restart Claude Code session
2. Check PATH environment variable
3. Try manual installation commands

---

## Related Commands

- `/review` - Code review (uses AST-Grep when available)
- `/lsp-setup` - LSP-only setup (legacy)
- `/mcp-setup` - MCP server configuration
