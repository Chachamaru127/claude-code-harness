---
description: Rules for editing hook configuration (hooks.json)
paths: "**/hooks.json"
---

# Hooks Editing Rules

Rules applied when editing `hooks.json` files.

## Important: Dual hooks.json Sync (Required)

**Two hooks.json files exist and must always be in sync:**

```
hooks/hooks.json           ← Source file (for development)
.claude-plugin/hooks.json  ← For plugin distribution (sync required)
```

### Editing Flow

1. Edit `hooks/hooks.json`
2. Apply the same changes to `.claude-plugin/hooks.json`
3. Sync cache with `./scripts/sync-plugin-cache.sh`

```bash
# Always run after changes
./scripts/sync-plugin-cache.sh
```

## Hook Types

4 つのタイプが利用可能です: `command`（汎用）、`http`（外部連携）、`prompt`（LLM 単一判断）、`agent`（LLM エージェント判断）。後者2つは v2.1.63+ で全イベント対応。

> **CC v2.1.69+**: `InstructionsLoaded` イベント、`agent_id` / `agent_type` フィールド、`{"continue": false, "stopReason": "..."}` レスポンスが追加されました。

### command Type (General Purpose)

Available for all events:

```json
{
  "type": "command",
  "command": "node \"${CLAUDE_PLUGIN_ROOT}/scripts/run-script.js\" script-name",
  "timeout": 30
}
```

### prompt Type

**Official Support**: Available for all hook events (v2.1.63+)

```json
{
  "type": "prompt",
  "prompt": "Evaluation instructions...\n\n[IMPORTANT] Always respond in this JSON format:\n{\"ok\": true} or {\"ok\": false, \"reason\": \"reason\"}",
  "timeout": 30
}
```

**Response Schema (Required)**:
```json
{"ok": true}                          // Allow action
{"ok": false, "reason": "explanation"}  // Block action
```

⚠️ **Note**: If you don't explicitly instruct JSON format in the prompt, the LLM may return natural language and cause a `JSON validation failed` error

### agent Type (v2.1.63+)

LLM エージェントにフックの判断を委任する新しいフック形式。Read, Grep, Glob ツールを使ってコードを分析し、許可/拒否を判断できる。

```json
{
  "type": "agent",
  "prompt": "Check if the code change introduces security vulnerabilities. $ARGUMENTS",
  "model": "haiku",
  "timeout": 60
}
```

#### agent hook 専用フィールド

| フィールド | 必須 | 説明 |
|-----------|------|------|
| `prompt` | Yes | エージェントに送るプロンプト。`$ARGUMENTS` でフック入力 JSON を参照 |
| `model` | No | 使用モデル（デフォルト: fast model）。コスト管理のため `haiku` 推奨 |

#### command hook との主な違い

| 項目 | command hook | agent hook |
|------|-------------|-----------|
| 判断方式 | ルールベース（正規表現・条件分岐） | LLM がコンテキストを理解して判断 |
| ツール | シェルコマンド | Read, Grep, Glob（副作用なし） |
| コスト | 低（プロセス起動のみ） | 高（LLM 推論トークン消費） |
| 適用場面 | 確定的なルール | コンテキスト依存の品質判断 |
| 非同期 | `async: true` 対応 | 非対応 |

#### コスト管理ガイドライン

- matcher で対象を最小限に絞る（例: `Write|Edit` のみ）
- `model: "haiku"` でコストを抑制
- 1回あたりの推奨トークン上限: 2,000
- 月間コスト超過時は command 型に rollback を検討

### http Type (v2.1.63+)

JSON を URL に POST する新しいフック形式。外部サービスとの連携に使用。

```json
{
  "type": "http",
  "url": "http://localhost:8080/hooks/pre-tool-use",
  "timeout": 30,
  "headers": {
    "Authorization": "Bearer $MY_TOKEN"
  },
  "allowedEnvVars": ["MY_TOKEN"]
}
```

#### HTTP hook 専用フィールド

| フィールド | 必須 | 説明 |
|-----------|------|------|
| `url` | Yes | POST 先の URL |
| `headers` | No | 追加 HTTP ヘッダー。`$VAR` / `${VAR}` で環境変数展開可 |
| `allowedEnvVars` | No | `headers` で展開を許可する環境変数名リスト。未指定時は展開されない |

#### レスポンス仕様

| レスポンス | 動作 |
|-----------|------|
| `2xx` + 空ボディ | 成功、続行 |
| `2xx` + JSON ボディ | 成功、JSON は command hook と同じスキーマで解析 |
| `非 2xx` / タイムアウト | ノンブロッキングエラー、実行続行 |

#### command hook との主な違い

| 項目 | command hook | http hook |
|------|-------------|-----------|
| 入力 | stdin (JSON) | POST body (JSON) |
| 成功判定 | exit code 0 | 2xx ステータス |
| ブロッキング | exit 2 | 2xx + `permissionDecision: "deny"` の JSON |
| 非同期実行 | `async: true` 対応 | 非対応 |
| `/hooks` メニュー | 追加可能 | 不可（JSON 直接編集のみ） |
| 環境変数 | シェル環境で自動展開 | `allowedEnvVars` に明示リスト必要 |

#### サンプルテンプレート

**Slack 通知**:
```json
{
  "type": "http",
  "url": "https://hooks.slack.com/services/T00/B00/xxx",
  "timeout": 10
}
```

**メトリクス収集**:
```json
{
  "type": "http",
  "url": "http://localhost:9090/metrics/hook",
  "timeout": 5,
  "headers": { "X-Source": "claude-code-harness" }
}
```

**外部ダッシュボード更新**:
```json
{
  "type": "http",
  "url": "https://dashboard.example.com/api/events",
  "timeout": 15,
  "headers": { "Authorization": "Bearer $DASHBOARD_TOKEN" },
  "allowedEnvVars": ["DASHBOARD_TOKEN"]
}
```

### Recommended Pattern

Execute command type via `run-script.js`:

```json
{
  "type": "command",
  "command": "node \"${CLAUDE_PLUGIN_ROOT}/scripts/run-script.js\" {script-name}",
  "timeout": 30
}
```

## Timeout Setting Guidelines

> **Claude Code v2.1.3+**: Maximum timeout for tool hooks extended from 60 seconds → 10 minutes

### Guidelines by Processing Nature

| Hook Type | Recommended Timeout | Notes |
|-----------|-------------------|-------|
| Lightweight check (guard) | 5-10s | File existence checks, etc. |
| Normal processing (cleanup) | 30-60s | File operations, git operations |
| Heavy processing (test) | 60-120s | Test execution, builds |
| External API integration | 60-180s | Codex reviews, etc. |
| agent hook（LLM判断） | 30-60s | モデルとプロンプト量に依存。haiku なら30秒、sonnet なら60秒 |
| http hook（外部連携） | 5-15s | ローカルサーバーは5秒、外部サービスは15秒。タイムアウト時はノンブロッキング |

**Note**: Set timeouts according to processing nature. Don't make them unnecessarily long.

#### agent hook 実測ガイドライン（haiku モデル）

| プロンプト量 | 想定レイテンシ | 推奨 timeout |
|------------|-------------|------------|
| 〜500 tokens | 3-8s | 15s |
| 〜1,000 tokens | 5-15s | 30s |
| 〜2,000 tokens | 10-25s | 45s |
| 2,000 tokens 超 | 非推奨 | — |

コスト目安（haiku）: 100回/日のセッションで〜$0.01-0.05/日。月間$1-2未満が正常範囲。

### Recommended Values by Event Type

| Hook Type | Recommended | Reason |
|-----------|-------------|--------|
| InstructionsLoaded | 5-10s | 初期コンテキストの軽量検証のみ |
| SessionStart | 30s | Initialization may take time |
| SubagentStart/Stop | 10s | Tracking only, lightweight processing |
| TeammateIdle / TaskCompleted | 10-20s | チーム進捗と停止判定（必要なら `continue:false`） |
| PreToolUse | 30s | Guard processing, file validation |
| PostToolUse | 5-30s | Depends on processing content |
| Stop | 20s | Ensure completion of termination processing |
| SessionEnd | 30s | セッション終了処理。`CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS` で制御可能 |
| UserPromptSubmit | 10-30s | Policy injection, tracking |

### Special Considerations for Stop Hooks

Stop hooks execute at session termination, so:
- Too short timeouts may interrupt processing
- 20 seconds or more recommended (D14 decision)

### Special Considerations for SessionEnd Hooks

**CC v2.1.74+**: SessionEnd hooks のタイムアウトは `CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS` 環境変数で制御可能になった。
以前は `hook.timeout` の設定に関わらず固定 1.5 秒で kill されていた。

```bash
# Harness 推奨: session-cleanup（timeout: 30s）に対して 45 秒を設定
export CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS=45000
```

- Harness の `session-cleanup` フック（hooks.json で timeout: 30s 指定）が確実に完了するために、45 秒以上を推奨
- 環境変数を設定しない場合、CC のデフォルト値が適用される（v2.1.74+ では hook.timeout 設定を尊重）

## Hook Structure

### Event Types

```json
{
  "hooks": {
    "PreToolUse": [],      // Before tool execution
    "PostToolUse": [],     // After tool execution
    "InstructionsLoaded": [], // Instruction load completed (v2.1.69+)
    "SessionStart": [],    // At session start
    "Stop": [],            // At session end
    "SubagentStart": [],   // Subagent start
    "SubagentStop": [],    // Subagent end
    "TeammateIdle": [],    // Teammate idle event (team mode)
    "TaskCompleted": [],   // Teammate task completion event (team mode)
    "WorktreeCreate": [],  // Worktree lifecycle start
    "WorktreeRemove": [],  // Worktree lifecycle end
    "UserPromptSubmit": [],// On user input
    "PermissionRequest": [] // On permission request
  }
}
```

### Teammate Event Fields (v2.1.69+)

`TeammateIdle` / `TaskCompleted` / 関連イベントでは、次のフィールドを優先して扱う:

- `agent_id`（推奨キー）
- `agent_type`（worker/reviewer など）
- `session_id`（後方互換キー）

`session_id` のみを前提にせず、`agent_id` を先に参照して fallback する実装を推奨。

### Stop Response Pattern (v2.1.69+)

チームイベントで処理を停止したい場合は、以下の形式を返す:

```json
{"continue": false, "stopReason": "all_tasks_completed"}
```

従来どおり続行する場合は `{"decision":"approve"}` を返してよい。

### matcher Patterns

```json
// Match specific tool
{ "matcher": "Write|Edit|Bash" }

// Match all
{ "matcher": "*" }

// Multiple tools
{ "matcher": "Skill|Task|SlashCommand" }
```

### once Option

Execute only once per session:

```json
{
  "type": "command",
  "command": "...",
  "timeout": 30,
  "once": true  // Recommended for SessionStart
}
```

## Prohibited

- ❌ Editing only one hooks.json
- ❌ Not instructing `{ok, reason}` schema for prompt type
- ❌ Hooks without timeout
- ❌ Absolute paths other than `${CLAUDE_PLUGIN_ROOT}`
- ❌ Commits without running sync-plugin-cache.sh

## Related Decisions

- **D14**: Hook timeout optimization
- **D15**: Stop hook prompt type official spec compliance (`{ok, reason}` schema)

Details: [.claude/memory/decisions.md](../memory/decisions.md)
