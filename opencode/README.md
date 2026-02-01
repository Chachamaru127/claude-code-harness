# Harness for OpenCode

Claude Code Harness の opencode.ai 互換版です。

## セットアップ方法

### 方法 1: ワンコマンドセットアップ（推奨）

Claude Code を持っていなくても、以下のコマンドでセットアップできます：

```bash
cd your-project
curl -fsSL https://raw.githubusercontent.com/Chachamaru127/claude-code-harness/main/scripts/setup-opencode.sh | bash
```

### 方法 2: Claude Code からセットアップ

Claude Code を使っている場合は、コマンド一つでセットアップ：

```bash
# Claude Code 内で実行
/opencode-setup
```

### 方法 3: 手動セットアップ

```bash
# Harness をクローン
git clone https://github.com/Chachamaru127/claude-code-harness.git

# opencode 用コマンドをコピー
cp -r claude-code-harness/opencode/commands/ your-project/.opencode/commands/
cp claude-code-harness/opencode/AGENTS.md your-project/AGENTS.md
```

---

## MCP サーバーセットアップ（オプション）

MCP サーバーを使うと、opencode から Harness のワークフローツールを直接呼び出せます。

```bash
# MCP サーバーをビルド
cd claude-code-harness/mcp-server
npm install
npm run build

# opencode.json をプロジェクトにコピーしてパスを調整
cp claude-code-harness/opencode/opencode.json your-project/
# opencode.json 内のパスを実際のパスに変更
```

---

## 利用可能なコマンド

| コマンド | 説明 |
|----------|------|
| `/harness-init` | プロジェクトセットアップ |
| `/plan-with-agent` | 開発プラン作成 |
| `/work` | タスク実行 |
| `/harness-review` | コードレビュー |
| `/sync-status` | 進捗確認 |
| `/handoff-to-opencode` | OpenCode PM への完了報告生成 |

---

## PM モード (OpenCode で計画管理)

OpenCode を PM (Project Manager) として使用する場合のコマンド:

| コマンド | 説明 |
|----------|------|
| `/start-session` | セッション開始（状況把握→計画） |
| `/plan-with-cc` | 計画作成（Evals含む） |
| `/project-overview` | プロジェクト概要把握 |
| `/handoff-to-claude` | Claude Code への依頼生成 |
| `/review-cc-work` | 作業レビュー・承認 |

### ワークフロー（PM モード）

```
OpenCode (PM)                    Claude Code (Impl)
    |                                   |
    | /start-session                    |
    | /plan-with-cc                     |
    | /handoff-to-claude ─────────────> |
    |                                   | /work
    |                                   | /handoff-to-opencode
    | <─────────────────────────────────|
    | /review-cc-work                   |
    |    ├── approve → 次タスク ────────>|
    |    └── request_changes ──────────>|
```

---

## MCP ツール

MCP サーバー経由で以下のツールが利用可能です：

| ツール | 説明 |
|--------|------|
| `harness_workflow_plan` | プラン作成 |
| `harness_workflow_work` | タスク実行 |
| `harness_workflow_review` | コードレビュー |
| `harness_session_broadcast` | セッション間通知 |
| `harness_status` | 状態確認 |

---

## Claude-mem Integration (Cross-Session Memory)

OpenCode で Claude-mem を使用してセッション間メモリを有効にできます。

### ⚠️ 制限事項

**MCP ツール呼び出しはプラグインフックをトリガーしません。**
ネイティブの OpenCode ツール（Edit, Write, Bash など）のみがプラグインで記録されます。
明示的なメモリ操作には claude-mem MCP サーバーツール（`mem-search`）を使用してください。

### セットアップ

```bash
# OpenCode 内で実行
/opencode-mem
```

または手動セットアップ：

```bash
# 1. Claude-mem をインストール
npm install -g claude-mem-mcp

# 2. プラグインをコピー
mkdir -p .opencode/plugin
cp claude-code-harness/opencode/plugin/claude-mem-plugin.ts .opencode/plugin/

# 3. opencode.json に追加
# "claude-mem" MCP サーバー設定を追加
```

### 利用可能な機能

| 機能 | 説明 |
|------|------|
| コンテキスト注入 | 前回セッションの作業内容を自動挿入 |
| 観察記録 | ツール実行結果を自動記録 |
| セッションサマリー | セッション終了時に要約を保存 |
| `mem-search` | 過去の作業履歴を検索 |

### 共有メモリ

Claude Code、Cursor、OpenCode で同じ Claude-mem データベースを共有できます：

- 全ツールが同じワーカー（port 37777）を使用
- 同じ SQLite データベースに保存
- ツール間でメモリを共有

---

## 使い方

```bash
# opencode を起動
cd your-project
opencode

# コマンドを実行
/plan-with-agent  # プラン作成
/work             # タスク実行
/harness-review   # コードレビュー
```

---

## 制限事項

- Harness プラグインシステム（`.claude-plugin/`）は opencode では使用できません
- フックは opencode 側で別途設定が必要です
- `description-en` フィールドは自動削除されます

---

## 関連リンク

- [Claude Code Harness](https://github.com/Chachamaru127/claude-code-harness)
- [OpenCode Documentation](https://opencode.ai/docs/)
- [OpenCode Commands](https://opencode.ai/docs/commands/)
