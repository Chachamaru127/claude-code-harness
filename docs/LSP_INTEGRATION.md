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

## ゼロからのセットアップ（推奨）

LSP を使うには **2つのもの** が必要です:

1. **言語サーバー** - 実際にコード解析を行うプログラム
2. **LSP プラグイン** - Claude Code と言語サーバーを接続

### Step 1: 言語サーバーをインストール

| 言語 | Language Server | インストールコマンド |
|------|-----------------|---------------------|
| **TypeScript/JS** | typescript-language-server | `npm install -g typescript typescript-language-server` |
| **Python** | pyright | `pip install pyright` または `npm install -g pyright` |
| **Rust** | rust-analyzer | [公式手順](https://rust-analyzer.github.io/manual.html#installation) |
| **Go** | gopls | `go install golang.org/x/tools/gopls@latest` |
| **C/C++** | clangd | macOS: `brew install llvm` / Ubuntu: `apt install clangd` |

### Step 2: 公式 LSP プラグインをインストール

**プロジェクトで使用する言語に必要なプラグインのみ**インストールしてください。

```bash
# 例: TypeScript/JavaScript プロジェクトの場合
claude plugin install typescript-lsp

# 例: Python プロジェクトの場合
claude plugin install pyright-lsp

# 例: Go プロジェクトの場合
claude plugin install gopls-lsp
```

**どのプラグインが必要か分からない場合**:
- `/plugin` コマンドで "lsp" を検索して、プロジェクトの言語に該当するものを選択
- または `/lsp-setup` コマンドで自動検出・提案を受ける

**利用可能な公式プラグイン**: typescript-lsp, pyright-lsp, rust-analyzer-lsp, gopls-lsp, clangd-lsp, jdtls-lsp, swift-lsp, lua-lsp, php-lsp, csharp-lsp（詳細は下記「公式LSPプラグイン一覧」参照）

### Step 3: Claude Code を起動

```bash
claude
```

**これで完了！** Go-to-definition、Find-references、Diagnostics が使えるようになります。

---

## 公式 LSP プラグイン一覧

以下の言語向けに公式LSPプラグインが提供されています。**プロジェクトで使用する言語に必要なものだけ**インストールしてください。

| プラグイン | 言語 | 必要な言語サーバー |
|-----------|------|-------------------|
| `typescript-lsp` | TypeScript/JS | typescript-language-server |
| `pyright-lsp` | Python | pyright |
| `rust-analyzer-lsp` | Rust | rust-analyzer |
| `gopls-lsp` | Go | gopls |
| `clangd-lsp` | C/C++ | clangd |
| `jdtls-lsp` | Java | jdtls |
| `swift-lsp` | Swift | sourcekit-lsp |
| `lua-lsp` | Lua | lua-language-server |
| `php-lsp` | PHP | intelephense |
| `csharp-lsp` | C# | omnisharp |

**インストール方法**:
```bash
# 例: TypeScript/JavaScript プロジェクトの場合
claude plugin install typescript-lsp

# 例: Python プロジェクトの場合
claude plugin install pyright-lsp
```

または `/plugin` コマンドで "lsp" を検索して、該当言語のプラグインをインストール。

> **重要**: プラグインは言語サーバーのバイナリを**含みません**。Step 1 で言語サーバーを別途インストールしてください。

> **迷ったら**: `/lsp-setup` コマンドが、プロジェクトの言語を自動検出して必要なプラグインを提案します。

---

## 既存プロジェクトへの導入

既存プロジェクトに LSP を追加するには `/lsp-setup` コマンドを使用:

```
/lsp-setup
```

このコマンドは:
1. プロジェクトの言語を自動検出
2. 必要な言語サーバーのインストール確認・実行
3. 公式プラグインのインストール
4. 動作確認


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

## Phase0: LSP tool_name の確認（開発者向け）

公式LSPプラグインの実際の `tool_name` を確認するには、Phase0ログを使用します。

### Phase0ログの有効化

Phase0ログはデフォルトで**無効**になっています。tool_name を確認する際のみ、環境変数で有効化してください。

```bash
# Phase0ログを有効化してClaude Codeを起動
CC_HARNESS_PHASE0_LOG=1 claude

# または、現在のセッションで有効化
export CC_HARNESS_PHASE0_LOG=1
claude
```

**重要**: tool_name確定後は、必ずPhase0ログを無効化してください（ログ肥大化防止）。

```bash
# Phase0ログを無効化（デフォルト状態に戻す）
unset CC_HARNESS_PHASE0_LOG
```

### 手順

1. **Phase0ログを有効化してセッション開始後、LSPツールを1回実行**:
   - 例: TypeScriptファイルで definition, references, diagnostics 等を実行

2. **tool-events.jsonl を確認**:
   ```bash
   cat .claude/state/tool-events.jsonl | grep -i lsp
   ```

3. **tool_name の検出条件を確認・調整**:
   - **現在の実装**: `scripts/posttooluse-log-toolname.sh` が `grep -iq "lsp"` で tool_name に "lsp" が含まれるかチェック
   - **tool_name が想定と異なる場合** (例: "lsp" を含まない名前の場合):
     - `scripts/posttooluse-log-toolname.sh` の LSP 検出条件（line 164付近）を更新:
       ```bash
       # 例: tool_name が "TypeScriptLSP" の場合
       if echo "$TOOL_NAME" | grep -iq "lsp\|TypeScriptLSP"; then
       ```
   - **matcher依存を回避**: PostToolUse は `matcher: "*"` で全ツールを観測するため、matcher設定は不要

4. **Phase0ログを無効化**:
   ```bash
   unset CC_HARNESS_PHASE0_LOG
   ```

### 想定される tool_name パターン

- `"LSP"` - 基本的なLSPツール
- `"typescript-lsp"` - 言語別プラグイン名
- `"LSP:definition"` - 操作別ツール名

いずれも "lsp" を含むため、デフォルトの検出条件（`grep -iq "lsp"`）で対応可能です。

**注意**: Phase0ログは最小フィールドのみ記録（tool_name, ts, session_id, prompt_seq）し、tool_input/tool_response は保存しません（漏洩リスク回避）。

---

## トラブルシューティング

### LSP が動作しない場合

1. 公式LSPプラグインがインストールされているか確認
2. 言語サーバーがインストールされているか確認（例: `which typescript-language-server`, `which pyright`）
3. `/lsp-setup` コマンドで設定を確認

### 診断結果が表示されない場合

1. 対応言語かどうかを確認
2. プロジェクトの設定ファイル（tsconfig.json 等）が正しいか確認
3. `restart_lsp_server` で言語サーバーを再起動

---

## 関連ドキュメント

- [ARCHITECTURE.md](./ARCHITECTURE.md) - プロジェクト全体の設計
- [OPTIONAL_PLUGINS.md](./OPTIONAL_PLUGINS.md) - オプションプラグインについて
