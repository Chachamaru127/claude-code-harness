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
