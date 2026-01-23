---
description: Harness MCP サーバーをセットアップ（クロスクライアント連携）
description-en: Setup Harness MCP server for cross-client communication
---

# /mcp-setup - MCP サーバーセットアップ

Harness MCP サーバーをセットアップして、**Claude Code、Codex、Cursor 間のセッション通信**を有効にします。

## VibeCoder Quick Reference

- "**Codex と連携したい**" → このコマンド
- "**別のAIツールと一緒に使いたい**" → MCP セットアップ
- "**セッション共有したい**" → クロスクライアント通信を有効化

## Deliverables

- MCP サーバーの設定ファイル
- クライアント別の設定手順
- 動作確認ガイド

---

## Usage

```bash
/mcp-setup
```

---

## Execution Flow

### Step 1: クライアント選択

> 🔧 **どのクライアントで MCP を使用しますか？**
>
> 1. Claude Code のみ
> 2. Claude Code + Codex
> 3. Claude Code + Cursor
> 4. すべて（Claude Code + Codex + Cursor）
>
> 番号で回答（デフォルト: 1）

**ユーザーの回答を待つ**

### Step 2: 設定ファイル生成

選択に応じて設定ファイルを生成：

#### Claude Code 設定

`.claude/settings.json` に追記：

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

#### Codex 設定（選択時）

`~/.codex/mcp.json` を生成：

```json
{
  "servers": {
    "harness": {
      "command": "node",
      "args": ["/path/to/claude-code-harness/mcp-server/dist/index.js"]
    }
  }
}
```

#### Cursor 設定（選択時）

`.cursor/mcp.json` を生成：

```json
{
  "harness": {
    "command": "node",
    "args": ["/path/to/claude-code-harness/mcp-server/dist/index.js"]
  }
}
```

### Step 3: MCP サーバービルド

```bash
cd "${CLAUDE_PLUGIN_ROOT}/mcp-server"
npm install
npm run build
```

### Step 4: 動作確認

> ✅ **MCP セットアップ完了**
>
> 📄 **設定ファイル**:
> - `.claude/settings.json` - Claude Code 用
> - `~/.codex/mcp.json` - Codex 用（選択時）
> - `.cursor/mcp.json` - Cursor 用（選択時）
>
> **利用可能なツール**:
>
> | ツール | 説明 |
> |--------|------|
> | `harness_session_list` | アクティブセッション一覧 |
> | `harness_session_broadcast` | 全セッションに通知 |
> | `harness_session_inbox` | 受信メッセージ確認 |
> | `harness_workflow_plan` | プラン作成 |
> | `harness_workflow_work` | タスク実行 |
> | `harness_workflow_review` | コードレビュー |
> | `harness_status` | プロジェクト状態 |
>
> **動作確認**:
> 1. Claude Code を再起動
> 2. "harness_session_list を実行して" と入力
> 3. セッション一覧が表示されれば成功

---

## Cross-Client Workflow Example

### シナリオ: Claude Code と Codex で同じプロジェクトを作業

```
[Claude Code]
You: harness_session_register を実行して、client: "claude-code"

Claude: ✅ Session registered: session-abc123 (claude-code)

You: API を変更したので broadcast して

Claude: 📤 Broadcast sent: "UserAPI: userId → user に変更"

---

[Codex]
You: harness_session_inbox を確認して

Codex: 📨 1 message(s):
       [10:30] claude-code: UserAPI: userId → user に変更

You: OK、新しい API を使って実装を続けて
```

---

## Available MCP Tools

### Session Tools

| ツール | 引数 | 説明 |
|--------|------|------|
| `harness_session_list` | なし | アクティブセッション一覧 |
| `harness_session_broadcast` | `message: string` | メッセージ送信 |
| `harness_session_inbox` | `since?: string` | 受信確認 |
| `harness_session_register` | `client, sessionId` | セッション登録 |

### Workflow Tools

| ツール | 引数 | 説明 |
|--------|------|------|
| `harness_workflow_plan` | `task, mode?` | プラン作成 |
| `harness_workflow_work` | `parallel?, full?, taskId?` | タスク実行 |
| `harness_workflow_review` | `files?, focus?, ci?` | レビュー |

### Status Tools

| ツール | 引数 | 説明 |
|--------|------|------|
| `harness_status` | `verbose?` | 状態確認 |

---

## Troubleshooting

### MCP サーバーが起動しない

**原因**: Node.js のバージョンが古い

**解決**: Node.js 18 以上をインストール

```bash
node --version  # v18.0.0 以上が必要
```

### ツールが見つからない

**原因**: MCP サーバーがビルドされていない

**解決**:

```bash
cd /path/to/claude-code-harness/mcp-server
npm run build
```

### セッション間でメッセージが届かない

**原因**: 同じプロジェクトディレクトリで実行していない

**解決**: 両方のクライアントを同じプロジェクトルートで起動

---

## Related Commands

- `/session-broadcast` - プラグイン版メッセージ送信
- `/session-inbox` - プラグイン版受信確認
- `/session-list` - プラグイン版セッション一覧

---

## Notes

- MCP サーバーはプラグイン機能の拡張版です
- プラグイン版（`/session-*`）と MCP 版は同じデータを共有します
- MCP 非対応のクライアントでもプラグイン版は使用可能
- セッションデータは `.claude/sessions/` に保存されます
