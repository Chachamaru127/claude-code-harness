# Cursor × Claude-mem 統合ガイド

このガイドでは、CursorでClaude-memのMCPサーバーを利用するためのセットアップ手順と使い方を説明します。

## 📋 目次

- [概要](#概要)
- [前提条件](#前提条件)
- [セットアップ手順](#セットアップ手順)
- [使い方](#使い方)
- [トラブルシューティング](#トラブルシューティング)
- [FAQ](#faq)

---

## 概要

### 何ができるか？

- **過去のセッション記録を検索**: Claude Codeで記録された意思決定やパターンをCursorから参照
- **新しい観測を記録**: Cursorでのレビュー結果や気付きをメモリに保存
- **双方向のデータ共有**: Claude CodeとCursorで同じメモリデータベースを共有
- **クロスツール連携**: PMと実装役の役割分担を明確化

### アーキテクチャ

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│ Claude Code │<───>│  claude-mem  │<───>│   Cursor    │
│  (実装役)    │     │  (WALモード)  │     │   (PM役)    │
└─────────────┘     └──────────────┘     └─────────────┘
  自動記録            並行アクセス対応      手動検索・記録
```

---

## 前提条件

### 必須

- ✅ **Claude Code** がインストール済み
- ✅ **Claude-mem** プラグインがインストール済み（バージョン 7.4.0 以降）
- ✅ **Cursor** IDE がインストール済み
- ✅ **Claude-code-harness** プラグインがインストール済み

### 確認方法

```bash
# Claude Code の確認
claude --version

# Claude-mem の確認
ls ~/.claude/plugins/cache/thedotmack/claude-mem/

# Cursor の確認
which cursor
```

---

## セットアップ手順

### Step 1: Claude-memワーカーの起動確認

```bash
# ヘルスチェック
curl http://127.0.0.1:37777/health

# 期待される出力:
# {"status":"ok","timestamp":1234567890123}
```

ワーカーが起動していない場合:

```bash
# 最新バージョンを確認
LATEST=$(ls -1d ~/.claude/plugins/cache/thedotmack/claude-mem/*/ | sort -V | tail -1)

# ワーカーを起動
node "$LATEST/scripts/worker-cli.js" start
```

### Step 2: MCPラッパースクリプトの配置

Claude-code-harnessプラグインをインストール済みの場合、スクリプトは既に配置されています：

```bash
# スクリプトの確認
ls -la ~/.claude/plugins/cache/*/claude-code-harness/*/scripts/claude-mem-mcp

# 実行可能か確認
chmod +x ~/.claude/plugins/cache/*/claude-code-harness/*/scripts/claude-mem-mcp
```

### Step 3: Cursor MCP設定ファイルの作成

プロジェクトルートに `.cursor/mcp.json` を作成：

```bash
# プロジェクトルートで実行
mkdir -p .cursor

# mcp.json を作成
cat > .cursor/mcp.json << 'EOF'
{
  "mcpServers": {
    "claude-mem": {
      "type": "stdio",
      "command": "/absolute/path/to/claude-code-harness/scripts/claude-mem-mcp"
    }
  }
}
EOF
```

**⚠️ 重要**: `command` には絶対パスを指定してください。

#### 絶対パスの取得方法

```bash
# harness プラグインの絶対パスを取得
find ~/.claude/plugins/cache -name "claude-mem-mcp" -type f 2>/dev/null | grep claude-code-harness

# 出力例:
# /Users/yourname/.claude/plugins/cache/.../claude-code-harness/.../scripts/claude-mem-mcp
```

このパスを `.cursor/mcp.json` の `command` に設定します。

### Step 4: Cursor再起動

設定ファイルを作成後、Cursorを再起動してMCPサーバーを認識させます。

### Step 5: 動作確認

Cursor Composer で以下を試してください：

```
「claude-mem で過去の記録を検索して」
```

MCPツールが認識されていれば、`mcp__claude-mem__search` などのツールが利用可能になります。

---

## 使い方

### 基本的な検索

Cursor Composer で：

```
「認証方式の選定理由を教えて」
```

Composerが自動的に `mcp__claude-mem__search` を使用し、過去の記録を検索します。

### 気付きの記録

Cursor Composer で：

```
「このコンポーネント設計のパターンを記録しておいて」
```

Composerが `mcp__claude-mem__add_observations` を使用し、メモリに記録します。

### 詳細な使用例

詳細は [skills/cursor-mem/examples.md](../../skills/cursor-mem/examples.md) を参照してください。

---

## 自動記録の設定（オプション）

Cursor Hooks を使用すると、Cursor での作業内容を自動的に claude-mem に記録できます。

### 自動記録される内容

| Hook | タイミング | 記録内容 |
|------|-----------|---------|
| `beforeSubmitPrompt` | プロンプト送信前 | ユーザープロンプトと添付ファイル |
| `afterFileEdit` | ファイル編集後 | ファイルパスと編集内容（diff） |
| `stop` | セッション完了時 | セッション終了状態とループ回数 |

### セットアップ手順

#### Step 1: hooks.json の作成

プロジェクトルートで `.cursor/hooks.json.example` をコピー：

```bash
# プロジェクトルートで実行
cp .cursor/hooks.json.example .cursor/hooks.json
```

`.cursor/hooks.json` の内容を確認：

```json
{
  "version": 1,
  "hooks": {
    "beforeSubmitPrompt": [
      {
        "command": "node",
        "args": ["${workspaceFolder}/scripts/cursor-hooks/record-prompt.js"]
      }
    ],
    "afterFileEdit": [
      {
        "command": "node",
        "args": ["${workspaceFolder}/scripts/cursor-hooks/record-edit.js"]
      }
    ],
    "stop": [
      {
        "command": "node",
        "args": ["${workspaceFolder}/scripts/cursor-hooks/record-stop.js"]
      }
    ]
  }
}
```

**⚠️ 重要**: `.cursor/hooks.json` はユーザー固有の設定ファイルのため、git には含まれません（`.gitignore` で除外済み）。

#### Step 2: .cursorrules の設定（推奨）

セッション開始時に過去の記録を自動検索するよう指示：

```bash
# プロジェクトルートで実行
cp .cursorrules.example .cursorrules

# 内容をカスタマイズ（オプション）
# vim .cursorrules
```

`.cursorrules` には以下のような指示が含まれます：

```markdown
## Session Start Protocol

At the beginning of each session, search past work using claude-mem MCP tools:

1. Search recent decisions and patterns
2. Review previous session context
3. Continue from where you left off
```

#### Step 3: Worker の起動確認

自動記録には claude-mem ワーカーが起動している必要があります：

```bash
# ヘルスチェック
curl http://127.0.0.1:37777/health

# 期待される出力:
# {"status":"ok"}
```

起動していない場合：

```bash
# ワーカーを起動
claude-mem restart
```

#### Step 4: Cursor 再起動

設定ファイル作成後、Cursor を再起動してフックを有効化します。

#### Step 5: 動作確認

1. Cursor でプロンプトを送信してみる
2. ファイルを編集してみる
3. セッションを完了させる

記録が保存されたか確認：

```bash
# 最新の記録を確認
sqlite3 ~/.claude-mem/claude-mem.db \
  "SELECT id, type, title FROM observations
   WHERE project = '$(basename $(pwd))'
   ORDER BY id DESC LIMIT 5;"
```

以下のような記録が表示されれば成功：

```
10951|change|テストファイルの内容が更新された
10950|discovery|Claude-Memの観測システムが正常に初期化された
10948|change|セッション終了
10947|change|テストファイルの内容編集
10946|discovery|Claude-Mem観測ツールの初期化と目的確認
```

Worker が AI でツールデータを意味のある observation に自動変換します。

### 自動記録の仕組み

Cursor Hooks → Worker API の処理フローを理解することで、トラブルシューティングが容易になります。

#### 1. セッション初期化（beforeSubmitPrompt）

```javascript
// record-prompt.js
beforeSubmitPrompt → /api/sessions/init
  ↓
Worker: セッション作成 + プロンプト保存
  ↓
user_prompts テーブルに登録
```

**重要**: この初期化ステップにより、後続の observation が "private" でスキップされなくなります。

#### 2. Observation 記録（afterFileEdit, stop）

```javascript
// record-edit.js, record-stop.js
afterFileEdit/stop → /api/sessions/observations
  ↓
Worker: AI 処理（Haiku モデル使用）
  ↓
構造化データに変換:
  - tool_name: "Edit" → type: "change", title: "テストファイルの内容編集"
  - tool_input: {...} → narrative: "プロジェクト内のtest.txtファイルに対して..."
  ↓
observations テーブルに保存
```

#### 3. データベーススキーマ

**送信フォーマット（フックスクリプト）**:
```json
{
  "claudeSessionId": "cursor-session-123",
  "tool_name": "Edit",
  "tool_input": "{\"file_path\":\"test.txt\",\"old_string\":\"before\",\"new_string\":\"after\"}",
  "tool_response": "Success",
  "cwd": "/path/to/project"
}
```

**保存フォーマット（データベース）**:
```sql
observations (
  id: 10947,
  type: "change",
  title: "テストファイルの内容編集",
  subtitle: "",
  narrative: "プロジェクト内のtest.txtファイルに対して文字列置換編集が実行された...",
  files_modified: "test.txt",
  ...
)
```

Worker が AI で自動的に変換するため、フックスクリプトは生のツールデータを送信するだけで済みます。

### 制限事項

自動記録には以下の制限があります：

1. **自動コンテキスト注入は不可**: セッション開始時に手動で過去記録を検索する必要があります（Cursor の `beforeSubmitPrompt` フックはレスポンスを尊重しないため）

2. **エージェント応答は記録されない**: Cursor には `afterAgentResponse` フックが存在しないため、エージェントの応答は記録できません

3. **ツール実行結果は部分的**: `beforeShellExecution` や `beforeMCPExecution` フックは実行前の情報のみ記録可能（実行結果は取得できない）

4. **Claude Code より記録が少ない**: フックの制限により、Claude Code での記録と比べて 60-70% 程度のカバレッジとなります

### カバレッジ比較

| 記録内容 | Claude Code | Cursor（自動記録） |
|---------|-------------|-------------------|
| ユーザープロンプト | ✅ 完全 | ✅ 完全 |
| ツール呼び出し | ✅ 完全 | ⚠️ 部分的 |
| ツール結果 | ✅ 完全 | ❌ なし |
| エージェント思考 | ✅ 完全 | ❌ なし |
| ファイル編集 | ✅ 完全 | ✅ 完全 |
| セッション完了 | ✅ 完全 | ✅ 完全 |

### トラブルシューティング（自動記録）

#### 問題: フックが動作しない

**症状**: プロンプトを送信してもデータベースに記録されない

**解決策**:

1. Cursor を完全に再起動
2. `.cursor/hooks.json` のパスが正しいか確認
3. スクリプトが実行可能か確認:
   ```bash
   ls -la scripts/cursor-hooks/*.js
   ```
4. Cursor の開発者ツールでエラーを確認:
   - `View` → `Toggle Developer Tools` → `Console` タブ

#### 問題: Worker が未起動エラー

**症状**: フックスクリプトのエラーログに "Worker API returned..." が表示される

**解決策**:

```bash
# Worker を起動
claude-mem restart

# ステータス確認
curl http://127.0.0.1:37777/health
```

#### 問題: プロジェクト検出が正しくない

**症状**: 記録が別のプロジェクトに保存される

**解決策**:

1. MCP 設定で `cwd` と `env.CLAUDE_MEM_PROJECT_CWD` を確認:
   ```json
   {
     "mcpServers": {
       "claude-mem": {
         "type": "stdio",
         "command": "/path/to/claude-mem-mcp",
         "cwd": "${workspaceFolder}",
         "env": {
           "CLAUDE_MEM_PROJECT_CWD": "${workspaceFolder}"
         }
       }
     }
   }
   ```

2. フックスクリプトが `workspace_roots` を正しく受け取っているか確認:
   ```bash
   # ログを確認
   tail -f ~/.claude-mem/logs/worker-*.log
   ```

#### 問題: Node.js v24 で "Unexpected token" エラー

**症状**: Cursor Hooks ログに以下のエラーが表示される:

```
SyntaxError: Unexpected token ':'
at evalTypeScript (node:internal/process/execution:260:22)
exit code: 1
```

**原因**: Node.js v24.10.0 以降では、stdin を TypeScript コードとして評価しようとするため、Cursor から送信される JSON データが構文エラーになります。

**解決済み**: v2.6.13 以降では wrapper スクリプト (`run-hook.sh`) を使用してこの問題を回避しています。

古いバージョンから更新する場合：

1. `.cursor/hooks.json.example` を参照して hooks.json を更新:
   ```json
   {
     "command": "bash scripts/cursor-hooks/run-hook.sh scripts/cursor-hooks/record-prompt.js"
   }
   ```

2. パスは**プロジェクトルートからの相対パス**であることを確認（`../` は不要）

3. wrapper スクリプトに実行権限を付与:
   ```bash
   chmod +x scripts/cursor-hooks/run-hook.sh
   ```

**検証方法**:

```bash
# Cursor Hooks ログで確認（View → Output → "Cursor Hooks"）
# 成功時:
Command: bash scripts/cursor-hooks/run-hook.sh ... exit code: 0
STDERR: [cursor-hooks] Session XXXXX, prompt #X initialized

# 失敗時:
exit code: 1  # または exit code: 127
STDERR: SyntaxError: Unexpected token ':'
```

---

## トラブルシューティング

### 問題1: MCPツールが認識されない

**症状**: Cursorで `mcp__claude-mem__*` ツールが表示されない

**解決策**:

1. `.cursor/mcp.json` のパスが正しいか確認
2. スクリプトが実行可能か確認:
   ```bash
   chmod +x /path/to/claude-mem-mcp
   ```
3. Cursorを完全に再起動（アプリケーションを終了して起動）
4. Cursorの開発者ツールでエラーを確認:
   - `View` → `Toggle Developer Tools` → `Console` タブ

### 問題2: ワーカーが起動しない

**症状**: `curl http://127.0.0.1:37777/health` が失敗する

**解決策**:

```bash
# ワーカーのステータス確認
ps aux | grep worker-service

# ワーカーを手動起動
LATEST=$(ls -1d ~/.claude/plugins/cache/thedotmack/claude-mem/*/ | sort -V | tail -1)
node "$LATEST/scripts/worker-cli.js" start

# ログを確認
tail -f ~/.claude-mem/logs/worker.log
```

### 問題3: 検索結果が返らない

**症状**: 検索しても結果が空

**考えられる原因**:

1. **データベースが空**: Claude Codeで記録がまだない
2. **クエリが不適切**: より具体的なキーワードを使用
3. **ワーカーが応答していない**: ヘルスチェックを実行

**解決策**:

```bash
# データベースの確認
sqlite3 ~/.claude-mem/claude-mem.db "SELECT COUNT(*) FROM observations;"

# 最近の記録を確認
sqlite3 ~/.claude-mem/claude-mem.db "SELECT id, type, content FROM observations ORDER BY created_at DESC LIMIT 5;"
```

### 問題4: パスの問題（相対パスが動作しない）

**症状**: `.cursor/mcp.json` で相対パスを指定したが動作しない

**解決策**: 必ず絶対パスを使用してください。

```json
{
  "mcpServers": {
    "claude-mem": {
      "type": "stdio",
      "command": "/Users/yourname/.claude/plugins/cache/.../scripts/claude-mem-mcp"
    }
  }
}
```

### デバッグモード

スクリプトのデバッグ出力を有効にする：

```bash
# スクリプトを直接実行してエラーを確認
/path/to/claude-mem-mcp
```

エラーメッセージが stderr に出力されます。

---

## FAQ

### Q1: Claude CodeとCursorで同時に書き込んでも大丈夫？

**A**: はい。Claude-memはWAL（Write-Ahead Logging）モードで動作し、並行書き込みに対応しています。複数のプロセスから同時にアクセスしても安全です。

### Q2: Cursorで記録したデータはClaude Codeから見える？

**A**: はい。両者は同じSQLiteデータベース（`~/.claude-mem/claude-mem.db`）を共有しているため、リアルタイムでデータが同期されます。

### Q3: 機密情報を記録しても安全？

**A**: メモリデータベースはローカル環境（`~/.claude-mem/`）にのみ保存されます。クラウドには送信されません。ただし、機密情報を記録する場合は注意してください。

### Q4: プロジェクト毎に異なる設定ができる？

**A**: はい。`.cursor/mcp.json` はプロジェクト固有の設定です。プロジェクト毎に異なる設定が可能です。

### Q5: グローバル設定はできる？

**A**: はい。`~/.cursor/mcp.json` に設定すると、全てのCursorプロジェクトで利用可能になります。

### Q6: ワーカーサービスの起動は必須？

**A**: はい。MCPサーバーはワーカーサービスと通信します。`claude-mem-mcp` スクリプトは自動起動機能を持っているため、通常は手動起動は不要です。

### Q7: パフォーマンスへの影響は？

**A**: 初回検索時はワーカー起動に2-3秒かかる場合がありますが、2回目以降はワーカーが常駐するため高速です。メモリ使用量は約50-100MB程度です。

### Q8: タグの命名規則は？

**A**: 推奨タグ:
- `source:cursor` - Cursorから記録
- `source:claude-code` - Claude Codeから記録
- `type:decision` - 意思決定
- `type:pattern` - パターン
- `type:bug` - バグ修正
- `type:review` - レビュー結果
- `type:handoff` - 引き継ぎ事項

詳細は [examples.md](../../skills/cursor-mem/examples.md#-ベストプラクティス) を参照。

---

## 関連リソース

- [Cursor MCP 公式ドキュメント](https://cursor.com/docs/context/mcp)
- [Claude-mem GitHub](https://github.com/thedotmack/claude-mem)
- [使用例集](../../skills/cursor-mem/examples.md)
- [スキル詳細](../../skills/cursor-mem/SKILL.md)

---

## サポート

問題が解決しない場合:

1. [Claude Code Issues](https://github.com/anthropics/claude-code/issues)
2. [Claude-mem Issues](https://github.com/thedotmack/claude-mem/issues)
3. [Claude-code-harness Issues](https://github.com/your-repo/claude-code-harness/issues)
