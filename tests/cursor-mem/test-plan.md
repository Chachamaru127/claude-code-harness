# Cursor × Claude-mem 自動記録機能テスト計画

このドキュメントは、Cursor × Claude-mem 統合の品質を保証するための厳格なテストケースを定義します。

## テスト環境

### 前提条件

- ✅ Claude-mem プラグイン v8.2.0 以降
- ✅ Claude-code-harness プラグイン v2.6.13 以降
- ✅ Cursor IDE 最新版
- ✅ Node.js 18 以降
- ✅ Worker サービスが起動可能

### テスト用データベース

**重要**: 本番データベースを保護するため、テスト前にバックアップを作成してください。

```bash
# バックアップ作成
cp ~/.claude-mem/claude-mem.db ~/.claude-mem/claude-mem.db.backup

# テスト後のリストア
cp ~/.claude-mem/claude-mem.db.backup ~/.claude-mem/claude-mem.db
```

---

## TC1: プロジェクト検出テスト

### 目的
異なるプロジェクトで記録した際に、正しくプロジェクト名が識別されること

### 手順

1. **プロジェクト A（例: claude-code-harness）で Cursor を開く**
   ```bash
   cd ~/path/to/claude-code-harness
   cursor .
   ```

2. **プロンプトを送信**
   - Cursor Composer で: "テストメッセージA"

3. **プロジェクト B（例: JARVIS）で Cursor を開く**
   ```bash
   cd ~/path/to/JARVIS
   cursor .
   ```

4. **プロンプトを送信**
   - Cursor Composer で: "テストメッセージB"

### 検証

```bash
# データベースで project フィールドを確認
sqlite3 ~/.claude-mem/claude-mem.db \
  "SELECT project, title FROM observations
   WHERE title LIKE '%テストメッセージ%'
   ORDER BY created_at DESC LIMIT 2"
```

### 期待結果

```
claude-code-harness|テストメッセージA
JARVIS|テストメッセージB
```

### 成功基準

- ✅ 各記録が正しいプロジェクト名で保存されている
- ✅ プロジェクト名が混在していない

---

## TC2: beforeSubmitPrompt フックテスト

### 目的
ユーザープロンプトが正しく記録されること

### 手順

1. **Cursor で新しいプロンプトを送信**
   - "フック記録テスト: プロンプト送信"

2. **添付ファイルを含むプロンプトを送信**
   - README.md を添付
   - "このファイルをレビューして"

### 検証

```bash
sqlite3 ~/.claude-mem/claude-mem.db \
  "SELECT tool_name, tool_input FROM observations
   WHERE title LIKE '%フック記録テスト%'
   ORDER BY created_at DESC LIMIT 1"
```

### 期待結果

```
UserPrompt|{"prompt":"フック記録テスト: プロンプト送信","attachments":[]}
```

添付ファイルありの場合:
```
UserPrompt|{"prompt":"このファイルをレビューして","attachments":[...]}
```

### 成功基準

- ✅ tool_name = "UserPrompt"
- ✅ tool_input に prompt テキストが含まれる
- ✅ 添付ファイルがある場合、attachments に記録される

---

## TC3: afterFileEdit フックテスト

### 目的
ファイル編集が正しく記録されること

### 手順

1. **テストファイルを作成**
   ```bash
   echo "Before edit" > test-file-edit.txt
   ```

2. **Cursor でファイルを編集**
   - test-file-edit.txt を開く
   - "Before edit" → "After edit" に変更

3. **複数行編集をテスト**
   - 新しい行を追加
   - 既存の行を削除

### 検証

```bash
sqlite3 ~/.claude-mem/claude-mem.db \
  "SELECT tool_name, tool_input, tool_response FROM observations
   WHERE tool_name = 'Edit'
   ORDER BY created_at DESC LIMIT 1"
```

### 期待結果

```
Edit|{"file_path":"test-file-edit.txt","edits":[{"old_string":"Before edit","new_string":"After edit"}]}|Success
```

### 成功基準

- ✅ tool_name = "Edit"
- ✅ tool_input に file_path が含まれる
- ✅ tool_input に edits 配列が含まれる
- ✅ tool_response = "Success"

---

## TC4: stop フックテスト

### 目的
セッション完了時に正しく記録されること

### 手順

1. **Cursor で作業セッションを開始**
   - いくつかのプロンプトを送信
   - ファイルを編集

2. **セッションを完了**
   - Cursor の "Stop" ボタンをクリック
   - または Cursor を終了

### 検証

```bash
sqlite3 ~/.claude-mem/claude-mem.db \
  "SELECT tool_name, tool_input FROM observations
   WHERE tool_name = 'SessionStop'
   ORDER BY created_at DESC LIMIT 1"
```

### 期待結果

```
SessionStop|{"status":"completed","loop_count":5}
```

### 成功基準

- ✅ tool_name = "SessionStop"
- ✅ tool_input に status が含まれる
- ✅ tool_input に loop_count が含まれる

---

## TC5: Claude Code → Cursor 読み取りテスト

### 目的
Claude Code で記録した内容を Cursor から検索できること

### 手順

1. **Claude Code で作業を実行**
   ```bash
   claude
   ```
   - README.md を編集
   - "Claude Code で編集しました" を追記

2. **Cursor を開く**

3. **MCP ツールで検索**
   - Cursor Composer で: "README 編集 に関する記録を検索して"

### 検証

Cursor が claude-mem MCP ツールを使用して検索を実行し、Claude Code で記録した内容が表示されること

### 期待結果

- MCP search ツールが実行される
- "README 編集" に関連する観測が返される
- Claude Code で記録した内容が含まれる

### 成功基準

- ✅ Cursor が MCP ツールを認識している
- ✅ 検索結果に Claude Code の記録が含まれる
- ✅ プロジェクト名でフィルタリングされている

---

## TC6: Cursor → Claude Code 読み取りテスト

### 目的
Cursor で記録した内容を Claude Code から読み取れること

### 手順

1. **Cursor で作業を実行**
   - プロンプトを送信: "Cursor でテスト作業"
   - ファイルを編集

2. **Claude Code を起動**
   ```bash
   claude
   ```

3. **SessionStart で過去記録が注入されること確認**
   - Claude Code が起動時に claude-mem から最近の記録を読み込む
   - Cursor での作業内容が表示される

### 検証

Claude Code のセッション開始時のコンテキストに Cursor の記録が含まれること

### 期待結果

- SessionStart フックが claude-mem から記録を取得
- Cursor で記録した "Cursor でテスト作業" が含まれる

### 成功基準

- ✅ Claude Code が起動時にコンテキストを読み込む
- ✅ Cursor の記録が含まれる
- ✅ プロジェクト名でフィルタリングされている

---

## TC7: Worker 未起動時の動作テスト

### 目的
Worker が起動していない状態でもフックがエラーで止まらないこと

### 手順

1. **Worker を停止**
   ```bash
   # Worker PID を確認
   cat ~/.claude-mem/worker.pid

   # Worker を停止
   kill -9 $(cat ~/.claude-mem/worker.pid)

   # PID ファイルを削除
   rm ~/.claude-mem/worker.pid
   ```

2. **Cursor でプロンプトを送信**
   - "Worker 停止中のテスト"

3. **Cursor の動作を確認**

### 検証

- Cursor がエラーで停止しないこと
- 開発者ツールの Console に警告が表示されること

### 期待結果

- Cursor の操作は正常に続行される
- Console に "Failed to record observation" 警告が表示される
- Worker API への接続エラーが記録される

### 成功基準

- ✅ Cursor がハングしない
- ✅ エラーメッセージが stderr に出力される
- ✅ ユーザーの操作に影響しない

### クリーンアップ

```bash
# Worker を再起動
claude-mem restart
```

---

## TC8: ネットワークエラーテスト

### 目的
Worker のポートがミスマッチした場合でもタイムアウト後にエラーが出ること

### 手順

1. **Worker を別ポートで起動**
   ```bash
   echo '{"CLAUDE_MEM_WORKER_PORT":"37778"}' > ~/.claude-mem/settings.json
   claude-mem restart
   ```

2. **Cursor でプロンプトを送信**
   - フックスクリプトはデフォルトポート 37777 に接続を試みる

3. **タイムアウトを確認**

### 検証

- 10秒後にタイムアウトエラーが発生すること
- Cursor の動作が継続すること

### 期待結果

- タイムアウトエラー: "Failed to record observation"
- 10秒以内にエラーが返る
- Cursor は正常動作

### 成功基準

- ✅ タイムアウトが正しく動作する（10秒）
- ✅ エラーメッセージが出力される
- ✅ Cursor の操作に影響しない

### クリーンアップ

```bash
# Worker をデフォルトポートに戻す
rm ~/.claude-mem/settings.json
claude-mem restart
```

---

## TC9: パフォーマンステスト

### 目的
フック実行時間が1秒未満であること

### 手順

1. **フックスクリプトに時間計測を追加**
   ```bash
   # scripts/cursor-hooks/record-prompt.js の先頭に追加
   const startTime = Date.now();

   # main() の最後に追加
   const endTime = Date.now();
   console.error(`[Perf] Hook execution time: ${endTime - startTime}ms`);
   ```

2. **10回連続でプロンプトを送信**
   - "パフォーマンステスト 1"
   - "パフォーマンステスト 2"
   - ...
   - "パフォーマンステスト 10"

3. **実行時間を記録**

### 検証

```bash
# Cursor の開発者ツールの Console で "[Perf]" を検索
# または stderr ログを確認
```

### 期待結果

各フックの実行時間:
```
[Perf] Hook execution time: 250ms
[Perf] Hook execution time: 180ms
[Perf] Hook execution time: 200ms
...
```

### 成功基準

- ✅ 平均実行時間 < 500ms
- ✅ 最大実行時間 < 1000ms
- ✅ Cursor の応答性に影響なし

---

## TC10: 並行書き込みテスト

### 目的
Claude Code と Cursor が同時にデータベースへ書き込んでも競合しないこと

### 手順

1. **Claude Code でファイルを編集（バックグラウンド）**
   ```bash
   # ターミナル1
   claude
   # README.md を編集
   ```

2. **同時に Cursor でも別のファイルを編集**
   ```
   # ターミナル2（Cursor を開く）
   # test.txt を編集
   ```

3. **両方の記録がデータベースに保存されるか確認**

### 検証

```bash
sqlite3 ~/.claude-mem/claude-mem.db \
  "SELECT tool_name, tool_input FROM observations
   WHERE tool_name = 'Edit'
   ORDER BY created_at DESC LIMIT 2"
```

### 期待結果

```
Edit|{"file_path":"test.txt",...}
Edit|{"file_path":"README.md",...}
```

### 成功基準

- ✅ データベース競合エラーが発生しない
- ✅ 両方の記録が正しく保存される
- ✅ WAL モードで並行書き込みが処理される

### 確認

```bash
# WAL モードが有効か確認
sqlite3 ~/.claude-mem/claude-mem.db "PRAGMA journal_mode;"
# 期待される出力: wal
```

---

## テスト実行手順

### 事前準備

1. **バックアップ作成**
   ```bash
   cp ~/.claude-mem/claude-mem.db ~/.claude-mem/claude-mem.db.backup
   ```

2. **Worker 起動確認**
   ```bash
   curl http://127.0.0.1:37777/health
   ```

3. **フック設定確認**
   ```bash
   cat .cursor/hooks.json
   ```

### テスト実行

各テストケースを順番に実行し、結果を記録：

```bash
# テスト結果を記録
cat > test-results.md << 'EOF'
# テスト実行結果

| TC | テスト名 | 結果 | 備考 |
|----|---------|------|------|
| TC1 | プロジェクト検出 | ✅ PASS | |
| TC2 | beforeSubmitPrompt | ✅ PASS | |
...
EOF
```

### テスト後のクリーンアップ

```bash
# データベースをリストア
cp ~/.claude-mem/claude-mem.db.backup ~/.claude-mem/claude-mem.db

# テストファイルを削除
rm -f test-file-edit.txt
```

---

## 検証スクリプト

自動検証には `tests/cursor-mem/verify-records.sh` を使用してください。

```bash
# 使用例
./tests/cursor-mem/verify-records.sh "テストメッセージ"
```

詳細は [verify-records.sh](./verify-records.sh) を参照してください。

---

## 成功基準サマリー

全テストケースが以下の基準を満たすこと：

### 機能要件
- ✅ TC1-TC4: 全フックが正しく記録される
- ✅ TC5-TC6: 双方向のデータ共有が機能する
- ✅ TC7-TC8: エラーハンドリングが正常に動作する

### 非機能要件
- ✅ TC9: パフォーマンス基準を満たす（< 1秒）
- ✅ TC10: 並行書き込みが安全に処理される

### ユーザー体験
- ✅ 全ケース: Cursor の動作に影響を与えない
- ✅ 全ケース: エラー発生時も継続動作する

---

## テスト報告

テスト完了後、以下のフォーマットで報告してください：

```markdown
## テスト実行報告

**実施日**: 2025-12-XX
**実施者**: @username
**環境**:
- Cursor バージョン: X.Y.Z
- Claude-mem バージョン: X.Y.Z
- OS: macOS/Windows/Linux

**結果**:
- 合格: X/10
- 不合格: Y/10

**詳細**: [test-results.md](./test-results.md) を参照
```
