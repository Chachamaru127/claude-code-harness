---
name: codex-review
description: "Integrates OpenAI Codex CLI as an MCP server to provide second-opinion reviews. Use when user mentions 'Codex レビュー', 'セカンドオピニオン', 'Codex の意見', 'Codex でレビュー', or 'Codex セットアップ'. Do NOT load for: 'Codex に実装させて', 'Codex Worker', 'Codex に作らせて', '実装を依頼'."
allowed-tools: ["Bash", "Read", "Write", "Edit"]
argument-hint: "[code|plan|scope]"
---

# Codex Review Integration Skill

OpenAI Codex CLI を MCP サーバーとして Claude Code に統合し、コードレビュー時にセカンドオピニオンを提供するスキル。

## Do NOT Load For (誤発動防止)

以下のキーワードは `codex-worker` スキルが担当します（description と完全一致）:

| トリガーワード | 正しいスキル | 理由 |
|---------------|-------------|------|
| "**Codex に実装させて**" | `codex-worker` | 実装 ≠ レビュー |
| "**Codex Worker**" | `codex-worker` | Worker = 実装役 |
| "**Codex に作らせて**" | `codex-worker` | 作成 = 実装 |
| "**実装を依頼**" | `codex-worker` | 実装目的 |

## 🎯 使用場面

### セットアップ
- **初回設定**: Codex CLI のインストール確認と MCP 登録
- **認証設定**: Codex への OAuth / API キー認証

### レビュー
- **セカンドオピニオン**: Claude のレビュー結果に Codex の視点を追加
- **コード品質チェック**: 複数 AI モデルの得意分野を活用
- **設計レビュー**: アーキテクチャや実装パターンの多角的検証

## 機能詳細

| 機能 | 詳細 |
|------|------|
| **MCP セットアップ** | See [references/codex-mcp-setup.md](references/codex-mcp-setup.md) |
| **レビュー統合** | See [references/codex-review-integration.md](references/codex-review-integration.md) |
| **4並列レビュー** | See [references/codex-parallel-review.md](references/codex-parallel-review.md) |
| **モード切替** | See [references/codex-mode.md](references/codex-mode.md) |

## 実行手順

1. ユーザーのリクエストを分類
2. 上記の「機能詳細」から適切な参照ファイルを読む
3. その内容に従って設定またはレビューを実行

### ⚠️ 並列レビュー時の必須ルール

**Codex モード（`review.mode: codex`）でのレビュー実行時**:

1. **呼び出すエキスパートを判定**（全部ではなく必要なもののみ）:
   - 設定で `enabled: false` → 除外
   - CLI/バックエンド → Accessibility, SEO 除外
   - ドキュメントのみ変更 → Quality, Architect, Plan Reviewer, Scope Analyst を優先（Security, Performance は除外可）
2. 有効なエキスパートの `references/experts/*.md` から **プロンプトを個別に読み込む**
3. 有効なエキスパートのみ **MCP 呼び出しを1つのレスポンス内で並列実行**
4. 絶対に1回の呼び出しで複数観点をまとめない

```
✅ 正しい（Code Reviewの場合、4エキスパート）:
   mcp__codex__codex({prompt: security-expert.md})
   mcp__codex__codex({prompt: performance-expert.md})
   mcp__codex__codex({prompt: quality-expert.md})
   mcp__codex__codex({prompt: accessibility-expert.md})

❌ 間違い:
   mcp__codex__codex({prompt: "セキュリティとパフォーマンスと品質をレビューして"})
```

**詳細**: [references/codex-parallel-review.md](references/codex-parallel-review.md)

---

## 📋 利用可能な MCP ツール

Codex MCP サーバーが登録されると、以下のツールが利用可能になります：

| ツール | 用途 |
|-------|------|
| `mcp__codex__codex` | Codex にプロンプトを送信してレビューを依頼 |

> **注**: このツール名は `codex mcp-server` の実装に依存します。

---

## 🔧 クイックスタート

### 前提条件

1. **Codex CLI がインストール済み**
   ```bash
   which codex  # パスが表示されること
   ```

2. **Codex にログイン済み**
   ```bash
   codex login status  # 認証済みであること
   ```

### セットアップコマンド

```bash
# Codex を MCP サーバーとして Claude Code に登録
claude mcp add --scope user codex -- codex mcp-server
```

### 動作確認

```bash
# MCP サーバー一覧を確認
claude mcp list
```

---

## 🔄 レビューワークフロー

### Solo モード

```
/harness-review 実行
    │
    ├── Claude レビュー（従来通り）
    │
    └── Codex MCP 呼び出し（有効時）
            │
            └── 結果統合
```

### 2-Agent モード

```
PM（Cursor / Codex）
    │
    └── タスク依頼
            │
            ├── Claude Code 実装
            │
            └── /harness-review
                    │
                    ├── Claude レビュー
                    └── Codex セカンドオピニオン
```

---

## ⚙️ 設定

`.claude-code-harness.config.yaml` で Codex 統合を設定：

```yaml
review:
  codex:
    enabled: true           # Codex セカンドオピニオン有効化
    auto: false             # true: 自動実行 / false: 毎回確認
    prompt: "Review the code and output issues and improvement suggestions"
    # execution_mode: mcp   # Legacy: MCP (no progress display)
```

| 設定項目 | デフォルト | 説明 |
|---------|-----------|------|
| `enabled` | `false` | Codex 統合の有効/無効 |
| `auto` | `false` | 自動レビュー実行 |
| `prompt` | (上記) | Codex へのレビュープロンプト |
| `execution_mode` | `exec` | 実行モード（`exec`: CLI直接 / `mcp`: レガシー）|

> **Note**: 単発 `/codex-review` は `exec` (進捗表示あり)、並列エキスパートは常に `mcp` (Claude 組み込み並列機能)

---

## 💡 活用例

### 例1: セットアップ

```
ユーザー: 「Codex でもレビューできるようにして」

Claude Code:
→ codex-mcp-setup.md を読み込み
→ Codex インストール確認
→ MCP 登録実行
→ 設定ファイル更新
```

### 例2: レビュー時

```
ユーザー: 「セカンドオピニオンもらって」

Claude Code:
→ codex.enabled = true を確認
→ MCP 経由で Codex にレビュー依頼
→ 結果を統合して表示
```

---

## ⚠️ 注意事項

### パフォーマンス

- Codex MCP 呼び出しには数秒〜数十秒かかる場合があります
- 大規模ファイルの場合はチャンク分割が推奨

### コスト

- Codex API 利用には OpenAI のクレジットが必要です
- レビュー頻度に応じたコスト見積もりを推奨

### トラブルシューティング

**問題**: Codex MCP が認識されない
**解決策**:
1. `claude mcp list` で登録確認
2. `codex login status` で認証確認
3. Claude Code を再起動

**問題**: レビュー結果が返らない
**解決策**:
1. `codex mcp-server` が起動しているか確認
2. ネットワーク接続を確認
3. API クレジット残高を確認

---

## 📚 参考資料

- [Codex CLI Reference](https://developers.openai.com/codex/cli/reference/)
- [Claude Code MCP 設定](https://docs.anthropic.com/claude-code/mcp)
- [Codex MCP 統合記事 (Qiita)](https://qiita.com/YasuhiroKawano/items/76d255b1fd97548dedc5)
