# Codex Worker Setup

Codex Worker 機能をセットアップする手順。

## Prerequisites

### 1. Codex CLI インストール

```bash
# npm でインストール
npm install -g @openai/codex

# または Homebrew (macOS)
brew install openai/tap/codex
```

### 2. Codex CLI バージョン確認

```bash
codex --version
# 必須: >= 0.92.0
```

### 3. Codex 認証

```bash
# ChatGPT アカウントでログイン
codex login

# または API キーで認証
export OPENAI_API_KEY="sk-..."
```

### 4. MCP サーバー登録確認

```bash
# Claude Code に Codex MCP が登録されているか確認
claude mcp list | grep codex
```

登録されていない場合:
```bash
claude mcp add --scope user codex -- codex mcp-server
```

## Setup Verification

```bash
# 全ての前提条件を確認するスクリプト
codex --version && \
codex login status && \
claude mcp list | grep -q codex && \
echo "✅ Codex Worker setup complete"
```

## Configuration File

セットアップ完了後、以下の設定ファイルが生成される:

```json
// .claude/state/codex-worker-config.json
{
  "codex_version": "0.92.0",
  "mcp_registered": true,
  "setup_date": "2026-02-02T00:00:00Z",
  "default_approval_policy": "never",
  "default_sandbox": "workspace-write",
  "parallel": {
    "enabled": true,
    "max_workers": 3,
    "worktree_base": "../worktrees"
  },
  "lock": {
    "ttl_minutes": 30,
    "heartbeat_minutes": 10
  }
}
```

## Troubleshooting

### Codex CLI が見つからない

```bash
# PATH を確認
which codex

# npm グローバルパスを確認
npm config get prefix
```

### MCP サーバーが起動しない

```bash
# 手動で MCP サーバーを起動してテスト
codex mcp-server

# ログを確認
tail -f ~/.codex/logs/mcp-server.log
```

### 認証エラー

```bash
# 認証状態を確認
codex login status

# 再認証
codex login
```
