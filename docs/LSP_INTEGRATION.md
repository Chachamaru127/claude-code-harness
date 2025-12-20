# LSP Integration Guide

Claude Code の LSP（Language Server Protocol）機能を活用するためのガイドです。

---

## LSP 機能の概要

Claude Code v2.0.74+ で利用可能な LSP 機能：

| 機能 | 説明 | 活用シーン |
|------|------|-----------|
| **Go-to-definition** | シンボルの定義元へジャンプ | コード理解、影響範囲調査 |
| **Find-references** | シンボルの全使用箇所を検索 | リファクタリング前の影響分析 |
| **Rename** | シンボル名を一括変更 | 安全なリネーム操作 |
| **Diagnostics** | コードの問題を検出 | ビルド前の問題検出、レビュー |
| **Hover** | シンボルの型情報・ドキュメント表示 | コード理解 |
| **Completions** | コード補完候補の提示 | 実装作業 |

### 対応言語

- TypeScript / JavaScript
- Python
- Rust
- Go
- C/C++
- Ruby
- PHP
- C#
- Swift
- Java
- HTML/CSS

---

## 言語サーバーのセットアップ（必須）

> ⚠️ **重要**: LSP を使うには、対象言語の **Language Server** が必要です。Claude Code の LSP 機能はプロトコルであり、実際の解析は言語サーバーが行います。

### 言語別インストールコマンド

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
| **Java** | Eclipse JDT LS | [手動セットアップが必要](https://github.com/eclipse/eclipse.jdt.ls) |

### セットアップ手順

```bash
# 1. 言語サーバーをインストール（例: TypeScript プロジェクト）
npm install -g typescript typescript-language-server

# 2. インストール確認
which typescript-language-server  # パスが表示されればOK

# 3. Claude Code を LSP 有効で起動
export ENABLE_LSP_TOOL=1
claude
```

### 既存プロジェクトへの導入

既存プロジェクトに LSP 設定を追加するには `/lsp-setup` コマンドを使用:

```
/lsp-setup
```

このコマンドは:
1. プロジェクトの言語を検出
2. 必要な言語サーバーのインストール状況を確認
3. `.claude/settings.json` に LSP 設定を追加
4. 動作確認

---

## LSP の有効化

### 方法1: 環境変数（推奨）

```bash
export ENABLE_LSP_TOOL=1
claude
```

### 方法2: MCP サーバー経由（より安定）

`.claude/settings.json`:

```json
{
  "mcpServers": {
    "cclsp": {
      "command": "npx",
      "args": ["@ktnyt/cclsp"]
    }
  },
  "permissions": {
    "allow": [
      "mcp__cclsp__*"
    ]
  }
}
```

---

## VibeCoder 向けの使い方

技術的な詳細を知らなくても、自然な言葉で LSP 機能を活用できます：

| 言いたいこと | 言い方 |
|-------------|--------|
| 定義を見たい | 「この関数の定義はどこ？」「`handleSubmit` の中身を見せて」 |
| 使用箇所を調べたい | 「この変数はどこで使われてる？」「`userId` の参照箇所を探して」 |
| 名前を変えたい | 「`getData` を `fetchUserData` にリネームして」 |
| 問題を検出したい | 「このファイルに問題ある？」「エラーをチェックして」 |
| 型情報を知りたい | 「この変数の型は何？」 |

---

## コマンド・スキルでの LSP 活用

### `/work` - 実装時

```
LSP 活用ポイント:
- 定義ジャンプで既存コードの理解を高速化
- 参照検索で影響範囲を事前把握
- 診断で実装中のエラーを即座に検出
```

### `/harness-review` - レビュー時

```
LSP 活用ポイント:
- Diagnostics で型エラー・未使用変数を自動検出
- Find-references で変更の影響範囲を確認
- 静的解析結果をレビュー観点に追加
```

### `/refactor` - リファクタリング時

```
LSP 活用ポイント:
- Rename でシンボルを安全に一括変更
- Find-references で漏れのない変更を保証
- Diagnostics で変更後の問題を即座に検出
```

### `/troubleshoot` - 問題解決時

```
LSP 活用ポイント:
- Diagnostics でエラー箇所を正確に特定
- Go-to-definition で問題のあるコードの原因を追跡
- 型情報で期待値と実際の不一致を発見
```

### `/validate` - 検証時

```
LSP 活用ポイント:
- プロジェクト全体の Diagnostics を実行
- 型エラー・警告の一覧を生成
- ビルド前に問題を検出
```

---

## LSP 診断の出力形式

```
📊 LSP 診断結果

ファイル: src/components/UserForm.tsx

| 行 | 重要度 | メッセージ |
|----|--------|-----------|
| 15 | Error | 型 'string' を型 'number' に割り当てることはできません |
| 23 | Warning | 'tempData' は宣言されていますが、使用されていません |
| 42 | Info | この条件は常に true です |

合計: エラー 1件 / 警告 1件 / 情報 1件
```

---

## LSP と Grep の使い分け

LSP と Grep はそれぞれ得意分野が異なります。適切に使い分けることで効率が上がります。

### 使い分け早見表

| 目的 | 推奨 | 理由 |
|------|------|------|
| シンボルの定義を探す | **LSP** | スコープを理解し、同名の別変数を区別 |
| シンボルの参照箇所を探す | **LSP** | 意味論的に正確な参照のみ抽出 |
| 変数・関数のリネーム | **LSP** | 漏れなく一括変更、安全 |
| 型エラー・構文エラー検出 | **LSP** | ビルド前に検出可能 |
| 文字列リテラル内を検索 | **Grep** | LSP はコード構造のみ対象 |
| コメント内を検索 | **Grep** | `TODO:` や `FIXME:` など |
| 正規表現パターン検索 | **Grep** | 柔軟なマッチング |
| 設定ファイル・ドキュメント | **Grep** | LSP はコードのみ対象 |
| LSP 非対応言語 | **Grep** | フォールバック |

### 具体例

```
❓「userId 変数はどこで使われてる？」
→ LSP Find-references（別スコープの userId を除外）

❓「"userId" という文字列はどこに書いてある？」
→ Grep（API レスポンス、コメント、ログも含む）

❓「TODO: を全部探して」
→ Grep（コメント内のテキスト）

❓「fetchUser を fetchUserById に変えたい」
→ LSP Rename（確実に全箇所変更）

❓「API エンドポイント /api/users を探して」
→ Grep（文字列リテラル検索）
```

### VibeCoder 向けの判断基準

| こう聞かれたら | 使うツール |
|---------------|-----------|
| 「この関数の定義はどこ？」 | LSP |
| 「この変数はどこで使われてる？」 | LSP |
| 「〇〇 を △△ にリネームして」 | LSP |
| 「"〇〇" という文字列を探して」 | Grep |
| 「TODO を全部リストして」 | Grep |
| 「〇〇 というテキストがどこにあるか」 | Grep |

---

## LSP 活用のベストプラクティス

### 1. 実装前に定義を確認

```
実装前:
1. 関連するシンボルの定義を LSP で確認
2. 既存のパターンを把握
3. 影響範囲を Find-references で調査
```

### 2. 変更後に診断を実行

```
変更後:
1. LSP Diagnostics を実行
2. エラー・警告を確認
3. 問題があれば即座に修正
```

### 3. リファクタリングは LSP Rename を使用

```
リファクタリング:
1. 変更対象を Find-references で確認
2. LSP Rename で一括変更
3. Diagnostics で問題がないことを確認
```

---

## トラブルシューティング

### LSP が動作しない場合

1. 環境変数を確認: `echo $ENABLE_LSP_TOOL`
2. 言語サーバーがインストールされているか確認
3. MCP サーバー経由での利用を試す

### 診断結果が表示されない場合

1. 対応言語かどうかを確認
2. プロジェクトの設定ファイル（tsconfig.json 等）が正しいか確認
3. `restart_lsp_server` で言語サーバーを再起動

---

## 関連ドキュメント

- [ARCHITECTURE.md](./ARCHITECTURE.md) - プロジェクト全体の設計
- [OPTIONAL_PLUGINS.md](./OPTIONAL_PLUGINS.md) - オプションプラグインについて
