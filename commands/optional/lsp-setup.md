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
2. 必要な言語サーバーのインストール確認
3. `.claude/settings.json` に LSP 設定を追加
4. 動作確認テスト

---

## セットアップフロー

### Phase 1: 言語検出

```
🔍 プロジェクト言語の検出

検出結果:
├── TypeScript ✅ (tsconfig.json)
├── Python ⚠️ (requirements.txt)
└── Rust ❌ (なし)
```

### Phase 2: 言語サーバー確認とインストール

```
🔧 言語サーバーの状態

| 言語 | Language Server | 状態 |
|------|-----------------|------|
| TypeScript | typescript-language-server | ✅ インストール済み |
| Python | pylsp | ❌ 未インストール |

❌ 未インストールの言語サーバーがあります:

1. Python (pylsp)
   → pip install python-lsp-server

インストールしますか？
- yes - 自動インストール
- 手動 - コマンドを表示のみ（自分でインストール）
- スキップ - LSP なしで続行
```

**回答を待つ**

#### 「yes」を選択した場合: 自動インストール

```bash
# 検出した未インストールの言語サーバーをインストール
echo "📦 言語サーバーをインストール中..."

# Python の場合
pip install python-lsp-server
echo "✅ pylsp インストール完了"

# インストール確認
which pylsp && echo "✅ パスに追加済み"
```

#### 「手動」を選択した場合: コマンド表示

```
📋 以下のコマンドを実行してください:

pip install python-lsp-server

インストール完了後、もう一度 /lsp-setup を実行してください。
```

### Phase 3: 設定ファイル生成

```
📝 設定ファイルの更新

.claude/settings.json:
  ✅ mcpServers.cclsp を追加
  ✅ permissions.allow に mcp__cclsp__* を追加
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
```

---

## 言語サーバーのインストールコマンド

| 言語 | Language Server | インストールコマンド |
|------|-----------------|---------------------|
| **TypeScript/JS** | typescript-language-server | `npm install -g typescript typescript-language-server` |
| **Python** | pylsp | `pip install python-lsp-server` |
| **Python** | pyright (より高速) | `pip install pyright` または `npm install -g pyright` |
| **Rust** | rust-analyzer | `rustup component add rust-analyzer` |
| **Go** | gopls | `go install golang.org/x/tools/gopls@latest` |
| **C/C++** | clangd | macOS: `brew install llvm` / Ubuntu: `apt install clangd` |
| **Ruby** | solargraph | `gem install solargraph` |
| **PHP** | intelephense | `npm install -g intelephense` |

---

## 実行手順

### Step 1: 言語検出

以下のファイルからプロジェクトの言語を検出:

| 検出ファイル | 言語 |
|-------------|------|
| `tsconfig.json`, `package.json` | TypeScript/JavaScript |
| `requirements.txt`, `pyproject.toml`, `setup.py` | Python |
| `Cargo.toml` | Rust |
| `go.mod` | Go |
| `Makefile`, `CMakeLists.txt` | C/C++ |
| `Gemfile` | Ruby |
| `composer.json` | PHP |

### Step 2: 言語サーバー確認

検出した言語に対応する Language Server がインストールされているか確認:

```bash
# TypeScript
which typescript-language-server

# Python
which pylsp || which pyright

# Rust
which rust-analyzer

# Go
which gopls
```

### Step 3: 設定ファイル更新

`.claude/settings.json` に以下を追加:

```json
{
  "mcpServers": {
    "cclsp": {
      "command": "npx",
      "args": ["@ktnyt/cclsp"],
      "description": "LSP integration for code intelligence"
    }
  },
  "permissions": {
    "allow": [
      "mcp__cclsp__*"
    ]
  }
}
```

### Step 4: 動作確認

LSP の基本機能が動作することを確認:

1. **Go-to-definition**: 任意のシンボルで定義ジャンプ
2. **Find-references**: 任意のシンボルで参照検索
3. **Diagnostics**: ファイルの診断結果を取得

---

## トラブルシューティング

### 言語サーバーが見つからない場合

```bash
# パスを確認
echo $PATH

# npm グローバルパスを確認
npm config get prefix

# 必要に応じてパスを追加
export PATH="$PATH:$(npm config get prefix)/bin"
```

### LSP が応答しない場合

1. Claude Code を再起動
2. 環境変数を確認: `echo $ENABLE_LSP_TOOL`
3. MCP サーバー経由での利用を試す

---

## 関連ドキュメント

- [docs/LSP_INTEGRATION.md](../../docs/LSP_INTEGRATION.md) - LSP 活用ガイド
