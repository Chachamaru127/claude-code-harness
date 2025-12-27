# Cursor 統合テスト手順

このディレクトリでCursor × Claude-mem 統合をテストできます。

## 📋 前提条件

- ✅ Cursor IDE がインストール済み
- ✅ Claude-mem ワーカーが起動中（`curl http://127.0.0.1:37777/health` で確認）

## 🧪 テスト手順

### Step 1: Cursorでこのディレクトリを開く

```bash
# ターミナルで実行
cd /Users/tachibanashuuta/Desktop/Code/CC-harness/claude-code-harness-cursor-mem-integration
cursor .
```

または、Cursorアプリから直接このディレクトリを開きます。

### Step 2: Cursorを再起動

`.cursor/mcp.json` が認識されるように、Cursorを完全に再起動します：
1. Cursorを終了
2. Cursorを再度起動
3. このディレクトリを開く

### Step 3: MCP サーバーの起動確認

Cursorの開発者ツールでMCPサーバーのログを確認：
1. `View` → `Toggle Developer Tools`
2. `Console` タブを開く
3. 以下のようなログが表示されるか確認：

```
[MCP] Starting server: claude-mem
[MCP] Server claude-mem started successfully
```

### Step 4: Composer でテスト

#### テスト 4-1: MCPツールの認識確認

Cursor Composer（`Cmd+I` または `Ctrl+I`）を開いて以下を入力：

```
claude-mem で利用可能なツールを確認して
```

**期待される動作:**
- Composerが `mcp__claude-mem__*` ツールを認識
- 利用可能なツールのリストを表示

#### テスト 4-2: 検索機能のテスト

```
claude-mem で「harness」に関する記録を検索して
```

**期待される動作:**
- `mcp__claude-mem__search` ツールを使用
- 検索結果を返す（記録がある場合）

#### テスト 4-3: 書き込み機能のテスト

```
「Cursor統合テスト実施」という観測を claude-mem に記録して。
タグは「test, cursor-integration」で。
```

**期待される動作:**
- `mcp__claude-mem__add_observations` ツールを使用
- 観測が記録される
- 確認メッセージが表示される

#### テスト 4-4: 記録確認

```
今記録した「Cursor統合テスト実施」を検索して
```

**期待される動作:**
- 先ほど記録した観測が検索結果に表示される

## ✅ 成功基準

以下が全て動作すれば統合は成功です：

- [ ] Cursor起動時にMCPサーバーがエラーなく起動
- [ ] Composerでclaude-memツールが認識される
- [ ] 検索機能が動作する
- [ ] 書き込み機能が動作する
- [ ] 書き込んだデータを即座に検索できる

## ❌ トラブルシューティング

### 問題1: MCPサーバーが起動しない

**確認:**
```bash
# ワーカーの起動確認
curl http://127.0.0.1:37777/health

# スクリプトが実行可能か確認
ls -la scripts/claude-mem-mcp

# スクリプトを手動実行してエラーを確認
./scripts/claude-mem-mcp
```

### 問題2: Composerでツールが認識されない

**確認:**
1. `.cursor/mcp.json` の内容が正しいか
2. Cursorを完全に再起動したか
3. 開発者ツールのConsoleにエラーが出ていないか

**修正:**
```bash
# .cursor/mcp.json を確認
cat .cursor/mcp.json

# パスが正しいか確認
ls -la /Users/tachibanashuuta/Desktop/Code/CC-harness/claude-code-harness-cursor-mem-integration/scripts/claude-mem-mcp
```

### 問題3: 検索結果が空

**原因:** データベースにまだ記録がない

**対処:** テスト 4-3 で書き込みを実施してから、テスト 4-4 で検索

## 📊 テスト結果の記録

テスト結果をこちらに記録してください：

```markdown
## テスト実施日: YYYY-MM-DD

### 環境
- OS:
- Cursor バージョン:
- Claude-mem バージョン:

### テスト結果
- [ ] Step 1: ディレクトリを開いた
- [ ] Step 2: Cursorを再起動した
- [ ] Step 3: MCPサーバー起動確認
- [ ] Step 4-1: ツール認識確認
- [ ] Step 4-2: 検索機能
- [ ] Step 4-3: 書き込み機能
- [ ] Step 4-4: 記録確認

### 問題点（あれば）


### 備考

```

## 🔗 参考資料

- [統合ガイド](docs/guides/cursor-mem-integration.md)
- [スキル詳細](skills/cursor-mem/SKILL.md)
- [使用例](skills/cursor-mem/examples.md)
