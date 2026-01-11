---
description: フック設定 (hooks.json) 編集時のルール
paths: "**/hooks.json"
---

# Hooks Editing Rules

`hooks.json` ファイル編集時に適用されるルール。

## 重要: Dual hooks.json 同期（必須）

**2つの hooks.json が存在し、常に同期が必要:**

```
hooks/hooks.json           ← ソースファイル（開発用）
.claude-plugin/hooks.json  ← プラグイン配布用（同期必須）
```

### 編集フロー

1. `hooks/hooks.json` を編集
2. `.claude-plugin/hooks.json` にも同じ変更を適用
3. `./scripts/sync-plugin-cache.sh` でキャッシュを同期

```bash
# 変更後は必ず実行
./scripts/sync-plugin-cache.sh
```

## フックタイプ

### command タイプ（汎用）

すべてのイベントで使用可能:

```json
{
  "type": "command",
  "command": "node \"${CLAUDE_PLUGIN_ROOT}/scripts/run-script.js\" script-name",
  "timeout": 30
}
```

### prompt タイプ（Stop/SubagentStop 専用）

**公式サポート**: Stop と SubagentStop イベントでのみ使用可能

```json
{
  "type": "prompt",
  "prompt": "評価の指示...\n\n【重要】必ず以下のJSON形式で回答:\n{\"ok\": true} または {\"ok\": false, \"reason\": \"理由\"}",
  "timeout": 30
}
```

**レスポンススキーマ（必須）**:
```json
{"ok": true}                          // アクション許可
{"ok": false, "reason": "説明文"}     // アクション阻止
```

⚠️ **注意**: プロンプトで JSON 形式を明示的に指示しないと、LLM が自然言語を返して `JSON validation failed` エラーになる

### 推奨パターン

command タイプは `run-script.js` 経由で実行:

```json
{
  "type": "command",
  "command": "node \"${CLAUDE_PLUGIN_ROOT}/scripts/run-script.js\" {script-name}",
  "timeout": 30
}
```

## タイムアウト設定ガイドライン

| フックタイプ | 推奨値 | 理由 |
|-------------|--------|------|
| SessionStart | 30s | 初期化処理に時間がかかる場合あり |
| SubagentStart/Stop | 10s | トラッキングのみ、軽量処理 |
| PreToolUse | 30s | ガード処理、ファイル検証 |
| PostToolUse | 5-30s | 処理内容による |
| Stop | 20s | 終了処理は確実に完了させる |
| UserPromptSubmit | 10-30s | ポリシー注入、トラッキング |

### Stop フックの特別な考慮

Stop フックはセッション終了時に実行されるため:
- タイムアウトが短すぎると処理が中断される
- 20秒以上を推奨（D14 決定事項）

## フック構造

### イベントタイプ

```json
{
  "hooks": {
    "PreToolUse": [],      // ツール実行前
    "PostToolUse": [],     // ツール実行後
    "SessionStart": [],    // セッション開始時
    "Stop": [],            // セッション終了時
    "SubagentStart": [],   // サブエージェント開始
    "SubagentStop": [],    // サブエージェント終了
    "UserPromptSubmit": [],// ユーザー入力時
    "PermissionRequest": [] // 権限要求時
  }
}
```

### matcher パターン

```json
// 特定ツールにマッチ
{ "matcher": "Write|Edit|Bash" }

// すべてにマッチ
{ "matcher": "*" }

// 複数ツール
{ "matcher": "Skill|Task|SlashCommand" }
```

### once オプション

セッションで1回だけ実行:

```json
{
  "type": "command",
  "command": "...",
  "timeout": 30,
  "once": true  // SessionStart で推奨
}
```

## 禁止事項

- ❌ 片方の hooks.json だけを編集
- ❌ Stop/SubagentStop 以外での `type: "prompt"` 使用
- ❌ prompt タイプで `{ok, reason}` スキーマを指示しない
- ❌ タイムアウトなしのフック
- ❌ `${CLAUDE_PLUGIN_ROOT}` 以外の絶対パス
- ❌ sync-plugin-cache.sh を実行しないコミット

## 関連決定事項

- **D14**: フックタイムアウト最適化
- **D15**: Stop フック prompt タイプの正式仕様対応（`{ok, reason}` スキーマ）

詳細: [.claude/memory/decisions.md](../memory/decisions.md)
