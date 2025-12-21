---
description: "[オプション] LSP設定（言語サーバーの導入と設定）"
description-en: "[Optional] LSP setup (Language Server installation and configuration)"
---

# /lsp-setup - LSP 設定

既存プロジェクトに LSP（Language Server Protocol）機能を導入・設定します。

## バイブコーダー向け（こう言えばOK）

- 「**LSPを使えるようにして**」→ このコマンド
- 「**コードジャンプできるようにして**」→ Go-to-definition を有効化
- 「**型エラーを事前に検出したい**」→ LSP Diagnostics を設定

## できること（成果物）

1. プロジェクトの言語を自動検出
2. 必要な言語サーバーのインストール確認・実行
3. **公式 LSP プラグインのインストール**
4. 動作確認テスト

---

## 公式 LSP プラグイン（推奨）

Claude Code マーケットプレイスで提供されている公式 LSP プラグイン:

| プラグイン | 言語 | 必要な言語サーバー |
|-----------|------|-------------------|
| `typescript-lsp` | TypeScript/JavaScript | typescript-language-server |
| `pyright-lsp` | Python | pyright |
| `rust-analyzer-lsp` | Rust | rust-analyzer |

> **重要**: プラグインは言語サーバーのバイナリを**含みません**。
> 別途インストールが必要です。

---

## セットアップフロー

### Phase 1: 言語検出

```
🔍 プロジェクト言語の検出

検出ファイル:
├── tsconfig.json → TypeScript ✅
├── package.json → JavaScript/TypeScript ✅
├── requirements.txt → Python ✅
├── pyproject.toml → Python ✅
├── Cargo.toml → Rust
└── go.mod → Go

検出結果:
├── TypeScript ✅
└── Python ✅
```

### Phase 2: 言語サーバーの確認とインストール

```
🔧 言語サーバーの状態

| 言語 | Language Server | 状態 |
|------|-----------------|------|
| TypeScript | typescript-language-server | ❌ 未インストール |
| Python | pyright | ❌ 未インストール |

❌ 未インストールの言語サーバーがあります。
```

> **インストールしますか？**
>
> - **yes** - 自動インストール（推奨）
> - **手動** - コマンドを表示のみ
> - **スキップ** - LSP なしで続行

**回答を待つ**

#### 「yes」を選択した場合: 自動インストール

```bash
echo "📦 言語サーバーをインストール中..."

# TypeScript
npm install -g typescript typescript-language-server
echo "✅ typescript-language-server インストール完了"

# Python
pip install pyright
# または npm install -g pyright
echo "✅ pyright インストール完了"

# インストール確認
which typescript-language-server && echo "✅ TypeScript LSP: OK"
which pyright && echo "✅ Python LSP: OK"
```

#### 「手動」を選択した場合: コマンド表示

```
📋 以下のコマンドを実行してください:

# TypeScript/JavaScript
npm install -g typescript typescript-language-server

# Python
pip install pyright
# または
npm install -g pyright

# Rust
# rust-analyzer 公式インストール手順: https://rust-analyzer.github.io/manual.html#installation

インストール完了後、もう一度 /lsp-setup を実行してください。
```

### Phase 3: 公式プラグインのインストール

```
📦 公式 LSP プラグインをインストール中...
```

```bash
# 検出した言語に対応するプラグインをインストール
claude plugin install typescript-lsp
claude plugin install pyright-lsp

echo "✅ LSP プラグインのインストール完了"
```

```
✅ インストール済みプラグイン:

| プラグイン | 状態 |
|-----------|------|
| typescript-lsp | ✅ インストール済み |
| pyright-lsp | ✅ インストール済み |
```

### Phase 4: 動作確認

```
✅ LSP 動作確認

テスト: Go-to-definition
  → src/index.ts:15 の 'handleSubmit' → src/handlers.ts:42 ✅

テスト: Find-references
  → 'userId' の参照: 8件検出 ✅

テスト: Diagnostics
  → エラー: 0件 / 警告: 2件 ✅

🎉 LSP セットアップ完了！
```

---

## 言語サーバーとプラグインの対応表

| 言語 | 言語サーバー | インストールコマンド | 公式プラグイン |
|------|------------|-------------------|---------------|
| **TypeScript/JS** | typescript-language-server | `npm install -g typescript typescript-language-server` | `typescript-lsp` |
| **Python** | pyright | `pip install pyright` または `npm install -g pyright` | `pyright-lsp` |
| **Rust** | rust-analyzer | [公式手順](https://rust-analyzer.github.io/manual.html#installation) | `rust-analyzer-lsp` |
| **Go** | gopls | `go install golang.org/x/tools/gopls@latest` | `gopls-lsp` |
| **C/C++** | clangd | macOS: `brew install llvm` / Ubuntu: `apt install clangd` | `clangd-lsp` |
| **Java** | jdtls | [公式手順](https://github.com/eclipse/eclipse.jdt.ls) | `jdtls-lsp` |
| **Swift** | sourcekit-lsp | Xcode 付属 | `swift-lsp` |
| **Lua** | lua-language-server | [公式手順](https://github.com/LuaLS/lua-language-server) | `lua-lsp` |
| **PHP** | intelephense | `npm install -g intelephense` | `php-lsp` |
| **C#** | omnisharp | [公式手順](https://github.com/OmniSharp/omnisharp-roslyn) | `csharp-lsp` |

---

## ゼロからのセットアップ手順（まとめ）

完全に未設定の状態から LSP を使えるようにする手順:

```bash
# Step 1: 言語サーバーをインストール
npm install -g typescript typescript-language-server  # TypeScript
pip install pyright                                    # Python

# Step 2: 公式プラグインをインストール
claude plugin install typescript-lsp
claude plugin install pyright-lsp

# Step 3: Claude Code を起動（LSP 自動有効化）
claude
```

これで Go-to-definition、Find-references、Diagnostics が使えるようになります。

---

## カスタム LSP プラグインの作成

公式プラグインがマーケットプレイスに存在しない言語や、独自のLSPサーバー設定が必要な場合、カスタムプラグイン（`.lsp.json`）を作成できます。

> **注**: TypeScript/JS, Python, Rust, Go, C/C++, Java, Swift, Lua, PHP, C# は公式プラグインが提供されています。まず `/plugin` で "lsp" を検索してください。

### `.lsp.json` フォーマット

**例**: カスタム設定でGoのLSPサーバーを起動する場合

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

### 必須フィールド

| フィールド | 説明 |
|-----------|------|
| `command` | LSP サーバーのバイナリ名（PATH 内に存在する必要がある） |
| `extensionToLanguage` | ファイル拡張子 → 言語識別子のマッピング |

### オプションフィールド

| フィールド | 説明 |
|-----------|------|
| `args` | コマンドライン引数 |
| `env` | 環境変数 |
| `initializationOptions` | 初期化オプション |
| `startupTimeout` | 起動タイムアウト（ミリ秒） |
| `restartOnCrash` | クラッシュ時の自動再起動 |

### カスタムプラグインの作成例

```bash
# ディレクトリ作成
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

# インストール
claude plugin install ./my-go-lsp
```

---

## トラブルシューティング

### 「Executable not found in $PATH」エラー

言語サーバーがインストールされていないか、PATH に含まれていません。

```bash
# パスを確認
echo $PATH

# npm グローバルパスを確認・追加
export PATH="$PATH:$(npm config get prefix)/bin"
```

### プラグインのエラーを確認

```
/plugin コマンドで "Errors" タブを確認
```

### LSP が応答しない場合

1. Claude Code を再起動
2. 言語サーバーが正しくインストールされているか確認
3. `/plugin` でプラグインのステータスを確認

---

## 関連ドキュメント

- [docs/LSP_INTEGRATION.md](../../docs/LSP_INTEGRATION.md) - LSP 活用ガイド
- [Claude Code Plugins Reference](https://code.claude.com/docs/en/plugins-reference) - 公式プラグインリファレンス
