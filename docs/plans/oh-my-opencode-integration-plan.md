# oh-my-opencode機能の claude-code-harness への導入計画

## 概要

oh-my-opencodeから取り入れるべき機能について評価し、MCPツール化を中心とした実装計画を策定。

---

## 導入機能サマリー

| 機能 | 実現方法 | 工数 | 優先度 |
|------|:--------:|:----:|:------:|
| **1. "ultrawork" マジックキーワード** | parse-work-flags修正 | 低 | 高 |
| **2. AST-Grep + LSP 統合** | MCPツール化 | 中 | 高 |
| **3. 統合セットアップ** | `/dev-tools-setup` | 低 | 高 |
| **4. ワンライナーインストール** | シェルスクリプト | 低 | 中 |

---

## Phase 1: "ultrawork" マジックキーワード

### 工数: 低 (1-2時間)

### 実装方法
`parse-work-flags` スキルを修正してマジックキーワードプリセットを追加:

```javascript
const magicKeywords = {
  "ultrawork": {
    full_mode: true,
    parallel_count: 3,
    isolation_mode: "worktree",
    commit_strategy: "phase",
    max_iterations: 3
  },
  "quickwork": {
    full_mode: true,
    parallel_count: 1,
    commit_strategy: "task"
  }
};
```

### 修正対象ファイル
1. `skills/plans-management/references/parse-work-flags.md`
2. `commands/core/work.md`

---

## Phase 2: AST-Grep + LSP の MCP ツール化

### 工数: 中

### 背景
- スキルベースの指示は Claude が無視する可能性がある
- MCP ツールとして登録すれば Claude が確実に認識・選択できる
- AST-Grep と LSP の両方をセットアップが必要 → 統合コマンドで解決

### 新規 MCP ツール設計

#### 2.1 AST-Grep ツール

```typescript
// mcp-server/src/tools/code-intelligence.ts

{
  name: "ast_search",
  description: "Search code by structural patterns. Use for: finding code smells, pattern matching, structural refactoring. Examples: 'console.log($$$)', 'if ($COND) { return $X }', 'async function $NAME($$$) { $$$ }'",
  inputSchema: {
    type: "object",
    properties: {
      pattern: {
        type: "string",
        description: "AST pattern using ast-grep syntax. Use $ for single node, $$$ for multiple nodes."
      },
      language: {
        type: "string",
        enum: ["typescript", "javascript", "python", "go", "rust", "java", "c", "cpp"],
        description: "Target language"
      },
      path: {
        type: "string",
        description: "Search path (default: current directory)"
      }
    },
    required: ["pattern", "language"]
  }
}
```

#### 2.2 LSP ツール群

```typescript
{
  name: "lsp_references",
  description: "Find all references to a symbol across the codebase. Use for: impact analysis before refactoring, understanding usage patterns.",
  inputSchema: {
    type: "object",
    properties: {
      file: { type: "string", description: "File path containing the symbol" },
      line: { type: "number", description: "Line number (1-indexed)" },
      column: { type: "number", description: "Column number (1-indexed)" }
    },
    required: ["file", "line", "column"]
  }
}

{
  name: "lsp_definition",
  description: "Go to the definition of a symbol. Use for: understanding implementation details, navigating to source.",
  inputSchema: {
    type: "object",
    properties: {
      file: { type: "string", description: "File path" },
      line: { type: "number", description: "Line number" },
      column: { type: "number", description: "Column number" }
    },
    required: ["file", "line", "column"]
  }
}

{
  name: "lsp_diagnostics",
  description: "Get code diagnostics (errors, warnings, hints) for a file. Use for: pre-commit validation, error detection.",
  inputSchema: {
    type: "object",
    properties: {
      file: { type: "string", description: "File path to diagnose" }
    },
    required: ["file"]
  }
}

{
  name: "lsp_hover",
  description: "Get type information and documentation for a symbol. Use for: understanding types, checking signatures.",
  inputSchema: {
    type: "object",
    properties: {
      file: { type: "string", description: "File path" },
      line: { type: "number", description: "Line number" },
      column: { type: "number", description: "Column number" }
    },
    required: ["file", "line", "column"]
  }
}
```

### ツール実装の内部処理

```typescript
// ast_search の実装
async function astSearch(pattern: string, language: string, path: string = ".") {
  // ast-grep がインストールされているか確認
  const installed = await checkCommand("sg");
  if (!installed) {
    return {
      error: "ast-grep not installed. Run /dev-tools-setup to install.",
      suggestion: "Use Grep tool as fallback for basic pattern search."
    };
  }

  // 実行
  const result = await exec(`sg --pattern "${pattern}" --lang ${language} --json ${path}`);
  return JSON.parse(result);
}

// lsp_references の実装
async function lspReferences(file: string, line: number, column: number) {
  // 言語サーバーが起動しているか確認
  const server = await getLspServer(file);
  if (!server) {
    return {
      error: "Language server not running. Run /dev-tools-setup to configure.",
      suggestion: "Use Grep tool to search for the symbol name as text."
    };
  }

  return await server.findReferences({ file, line, column });
}
```

### 修正対象ファイル

| ファイル | 変更内容 |
|----------|----------|
| `mcp-server/src/tools/code-intelligence.ts` | **新規作成** - AST/LSP ツール定義 |
| `mcp-server/src/index.ts` | ツール登録追加 |
| `mcp-server/package.json` | 依存関係追加 (必要に応じて) |

---

## Phase 3: `/dev-tools-setup` 統合セットアップコマンド

### 工数: 低

### 機能
1コマンドで AST-Grep + LSP の両方をセットアップ

```markdown
# commands/optional/dev-tools-setup.md

---
description: 開発ツール (AST-Grep, LSP) を一括セットアップ
description-en: Setup development tools (AST-Grep, LSP) in one command
---

# /dev-tools-setup

開発支援ツールをセットアップし、MCP ツールを有効化します。

## 実行内容

### 1. プロジェクト言語の自動検出
- package.json → TypeScript/JavaScript
- requirements.txt / pyproject.toml → Python
- Cargo.toml → Rust
- go.mod → Go

### 2. AST-Grep インストール確認

インストールされていない場合:
- macOS: `brew install ast-grep`
- その他: `cargo install ast-grep --locked`
- npm: `npm install -g @ast-grep/cli`

### 3. LSP (言語サーバー) セットアップ

検出された言語に応じて:
| 言語 | インストールコマンド |
|------|---------------------|
| TypeScript/JS | `npm install -g typescript-language-server typescript` |
| Python | `pip install python-lsp-server` |
| Rust | `rustup component add rust-analyzer` |
| Go | `go install golang.org/x/tools/gopls@latest` |

### 4. MCP ツール有効化確認

セットアップ完了後、以下のツールが利用可能:
- `ast_search` - 構造パターン検索
- `lsp_references` - シンボル参照検索
- `lsp_definition` - 定義ジャンプ
- `lsp_diagnostics` - コード診断
- `lsp_hover` - 型情報取得
```

### 修正対象ファイル
1. `commands/optional/dev-tools-setup.md` - **新規作成**

---

## Phase 4: `/harness-review` への統合

### 工数: 低

### 実装方法
レビューコマンドで MCP ツールを自動活用

```markdown
# commands/core/review.md に追加

## コードインテリジェンス活用 (オプション)

`/dev-tools-setup` 実行済みの場合、以下を自動実行:

### AST-Grep によるコードスメル検出
- `ast_search("console.log($$$)", "typescript")` - デバッグログ残存
- `ast_search("catch ($ERR) { }", "typescript")` - 空の catch ブロック
- `ast_search("async function $NAME($$$) { $$$_NO_AWAIT }", "typescript")` - 未使用 async

### LSP による影響分析
- `lsp_references` - 変更箇所の参照元を確認
- `lsp_diagnostics` - 型エラー・警告の検出
```

### 修正対象ファイル
1. `commands/core/review.md` - ツール活用セクション追加

---

## Phase 5: ワンライナーインストール

### 工数: 低 (30分)

### 実装方法

```bash
#!/bin/bash
# scripts/quick-install.sh
curl -fsSL https://raw.githubusercontent.com/Chachamaru127/claude-code-harness/main/scripts/quick-install.sh | bash
```

### 修正対象ファイル
1. `scripts/quick-install.sh` - **新規作成**
2. `README.md` - インストール手順更新

---

## 修正対象ファイル一覧

| ファイル | 変更内容 | Phase |
|----------|----------|:-----:|
| `skills/plans-management/references/parse-work-flags.md` | マジックキーワード追加 | 1 |
| `commands/core/work.md` | ドキュメント追加 | 1 |
| `mcp-server/src/tools/code-intelligence.ts` | **新規** AST/LSPツール | 2 |
| `mcp-server/src/index.ts` | ツール登録 | 2 |
| `commands/optional/dev-tools-setup.md` | **新規** セットアップコマンド | 3 |
| `commands/core/review.md` | ツール活用追記 | 4 |
| `scripts/quick-install.sh` | **新規** インストールスクリプト | 5 |
| `README.md` | インストール手順更新 | 5 |

---

## 検証方法

### Phase 1: マジックキーワード
```bash
/work ultrawork
# → full_mode=true, parallel_count=3 で実行確認

/work ultrawork --parallel 5
# → parallel_count=5 に上書き確認
```

### Phase 2-3: MCP ツール
```bash
# セットアップ
/dev-tools-setup

# AST-Grep ツール確認
Claude: "console.log を全部探して"
# → ast_search ツールが呼ばれることを確認

# LSP ツール確認
Claude: "この関数の参照元を探して"
# → lsp_references ツールが呼ばれることを確認
```

### Phase 4: レビュー統合
```bash
/review
# → AST-Grep によるコードスメル検出が実行されることを確認
```

---

## 結論

oh-my-opencode の優れた点を取り入れつつ、Harness のアーキテクチャに適合する形で実装:

1. **"ultrawork" マジックキーワード** - 即座に実装可能
2. **AST-Grep + LSP の MCP ツール化** - Claude が確実に使用
3. **`/dev-tools-setup` 統合コマンド** - セットアップ簡略化
4. **レビューへの自動統合** - 設定済みなら自動活用
