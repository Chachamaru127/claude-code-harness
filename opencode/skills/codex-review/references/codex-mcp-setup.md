---
name: codex-mcp-setup
description: "Codex CLI の検出・MCP 登録・認証確認を行うセットアップ手順"
allowed-tools: ["Bash", "Read", "Write", "Edit"]
---

# Codex MCP セットアップ

OpenAI Codex CLI を Claude Code の MCP サーバーとして登録するセットアップ手順。

---

## 🎯 このスキルでやること

1. Codex CLI のインストール確認
2. Codex 認証状態の確認
3. MCP サーバーとしての登録
4. 設定ファイルの更新
5. 動作確認

---

## 実行フロー

### Step 1: Codex CLI の確認

```bash
# Codex CLI が存在するか確認
which codex
```

**結果判定**:

| 結果 | 次のアクション |
|------|---------------|
| パスが表示される | Step 2 へ |
| `not found` | インストール案内を表示 |

**インストール案内（未インストール時）**:

```markdown
⚠️ Codex CLI がインストールされていません

インストール方法:

1. **Homebrew（macOS）**:
   ```bash
   brew install openai-codex
   ```

2. **npm（クロスプラットフォーム）**:
   ```bash
   npm install -g @openai/codex-cli
   ```

3. **公式ドキュメント**:
   https://developers.openai.com/codex/cli/installation

インストール後、再度このコマンドを実行してください。
```

---

### Step 2: 認証状態の確認

```bash
# ログイン状態を確認
codex login status
```

**結果判定**:

| 終了コード | 意味 | 次のアクション |
|-----------|------|---------------|
| 0 | ログイン済み | Step 3 へ |
| 非0 | 未ログイン | 認証案内を表示 |

**認証案内（未ログイン時）**:

```markdown
🔐 Codex にログインが必要です

ログイン方法:

1. **OAuth（推奨）**:
   ```bash
   codex login
   ```
   ブラウザが開き、OpenAI アカウントで認証します。

2. **API キー**:
   ```bash
   echo $OPENAI_API_KEY | codex login --with-api-key
   ```
   環境変数に設定済みの API キーを使用します。

ログイン後、再度このコマンドを実行してください。
```

---

### Step 3: MCP サーバー登録

```bash
# Codex を MCP サーバーとして登録
claude mcp add --scope user codex -- codex mcp-server
```

**成功時の出力例**:

```
Added MCP server: codex
Scope: user
Command: codex mcp-server
```

**エラー時の対応**:

| エラー | 原因 | 対応 |
|-------|------|------|
| `Already exists` | 既に登録済み | Step 4 へ（スキップ可） |
| `Command not found` | claude CLI がない | Claude Code を最新版に更新 |
| `Permission denied` | 権限不足 | `--scope project` を試す |

---

### Step 4: 設定ファイル更新

`.claude-code-harness.config.yaml` に Codex 設定を追加:

```yaml
# 追加する設定
review:
  codex:
    enabled: true
    auto: false
    prompt: "日本語でコードレビューを行い、問題点と改善提案を出力してください"
```

**設定項目の説明**:

| 項目 | 型 | デフォルト | 説明 |
|-----|-----|-----------|------|
| `enabled` | boolean | `false` | Codex 統合を有効化 |
| `auto` | boolean | `false` | `/review` 時に自動で Codex を呼び出すか |
| `prompt` | string | (上記) | Codex へ送信するレビュープロンプト |

---

### Step 5: 動作確認

```bash
# MCP サーバー一覧を確認
claude mcp list
```

**期待される出力**:

```
codex (user)
  Command: codex mcp-server
  Status: Ready
```

**簡易テスト（オプション）**:

```bash
# Codex MCP が応答するか確認
codex exec --json "Hello, this is a test" 2>/dev/null | head -1
```

---

## 完了メッセージ

セットアップ完了時に表示:

```markdown
✅ Codex MCP セットアップ完了

**設定内容**:
- MCP サーバー: codex (user scope)
- 自動レビュー: 無効（毎回確認）
- プロンプト言語: 日本語

**使い方**:
- `/review` 実行時に「Codex にもレビューさせますか？」と確認
- `codex.auto: true` で自動実行に変更可能

**次のアクション**:
- `codex.enabled: true` を設定ファイルで確認
- `/review` でセカンドオピニオンを試す
```

---

## トラブルシューティング

### 問題: `claude mcp add` が失敗する

**原因**: Claude Code のバージョンが古い

**解決策**:
```bash
# Claude Code を更新
claude update

# 再試行
claude mcp add --scope user codex -- codex mcp-server
```

### 問題: Codex MCP が応答しない

**原因**: Codex CLI の問題

**解決策**:
```bash
# Codex 単体で動作確認
codex exec "Hello" --output-last-message /tmp/test.txt
cat /tmp/test.txt
```

### 問題: API エラーが発生する

**原因**: OpenAI クレジット不足または API 制限

**解決策**:
1. OpenAI ダッシュボードでクレジット確認
2. API 使用量制限を確認
3. レート制限の場合は時間を置いて再試行

---

## 関連ドキュメント

- [Codex CLI Reference](https://developers.openai.com/codex/cli/reference/)
- [Claude Code MCP 公式ドキュメント](https://docs.anthropic.com/claude-code/mcp)
- [codex-review-integration.md](./codex-review-integration.md) - レビュー統合手順
