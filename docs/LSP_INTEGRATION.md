# LSP Integration Guide

Claude Code の LSP（Language Server Protocol）機能を活用するためのガイドです。

---

## LSP 機能の概要

Claude Code v2.0.30+ で利用可能な LSP 機能：

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
