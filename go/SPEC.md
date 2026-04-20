# Harness v4 Go Rewrite — Specification

> Phase 35 の仕様がぶれないための正本。実装前にここを確認し、実装後にここと照合する。

最終更新: 2026-04-06
CC 確認バージョン: 2.1.92

---

## 1. スコープ定義

### 変えるもの

| 対象 | Before | After |
|------|--------|-------|
| フック実行パス | bash → node → TypeScript | Go バイナリ直接呼び出し |
| 設定ファイル管理 | 5-6 ファイル手動同期 | harness.toml → `harness sync` 自動生成 |
| 状態管理 | TypeScript + better-sqlite3 | Go + pure-Go SQLite |
| スクリプト群 | 127 本 .sh + 7 本 .js | Go サブコマンドに段階的吸収 |

### 変えないもの（CC プラグインプロトコル準拠）

| 対象 | 形式 | 理由 |
|------|------|------|
| `plugin.json` | JSON | CC 必須 |
| `hooks/hooks.json` | JSON | CC 必須 |
| `settings.json` | JSON | CC 必須 |
| `agents/*.md` | YAML frontmatter + Markdown | CC 必須。body が Markdown のため TOML 化不適 |
| `skills/*/SKILL.md` | YAML frontmatter + Markdown | CC 必須 |
| `.mcp.json`, `.lsp.json` | JSON | CC 必須 |
| `output-styles/` | Markdown | CC 必須 |

### 段階的移行の方針

「zero-base rewrite」は設計思想であり「atomic switch」ではない。移行は hook 単位で段階的に行う。

- 各 hook には **正本実装が 1 つだけ** 存在する（Go or shell）
- フォールバックは設けない（Phase 35.0 で Node.js フォールバック削除済み）
- 未移行 hook は shell が正本のまま残る
- `harness doctor --migration` で mixed-mode を検出し警告する

---

## 2. プロトコル Truth Table

CC 公式フック仕様に基づく、フィールドごとの分類。

### HookInput (stdin JSON)

| Field | 分類 | CC バージョン | Go 型 |
|-------|------|-------------|-------|
| `session_id` | documented | - | `string` |
| `transcript_path` | documented | - | `string` |
| `cwd` | documented | - | `string` |
| `permission_mode` | documented | - | `string` |
| `hook_event_name` | documented | - | `string` |
| `tool_name` | documented (required) | - | `string` |
| `tool_input` | documented (required) | - | `map[string]interface{}` |
| `plugin_root` | harness-private | - | `string` |

**未知フィールド方針**: JSON デコード時に無視する（`json.Decoder` のデフォルト動作）。strip しない。hard fail しない。

### PreToolUse hookSpecificOutput

| Field | 分類 | 出力条件 | Go 型 |
|-------|------|---------|-------|
| `hookEventName` | documented | 常に `"PreToolUse"` | `string` |
| `permissionDecision` | documented | 常に | `"allow"\|"deny"\|"ask"\|"defer"` |
| `permissionDecisionReason` | documented | deny/ask 時 | `string` |
| `updatedInput` | documented (v2.1.89+) | 入力変更時 | `json.RawMessage` |
| `additionalContext` | documented | warn 時 | `string` |

**Exit code**: deny → exit 2, それ以外 → exit 0

### PostToolUse hookSpecificOutput

| Field | 分類 | 出力条件 | Go 型 |
|-------|------|---------|-------|
| `hookEventName` | documented | 常に `"PostToolUse"` | `string` |
| `additionalContext` | documented | 警告時 | `string` |
| `updatedMCPToolOutput` | **experimental (未文書化)** | **未実装** | - |

### PermissionRequest hookSpecificOutput

| Field | 分類 | Go 型 |
|-------|------|-------|
| `hookSpecificOutput.hookEventName` | documented | `"PermissionRequest"` |
| `hookSpecificOutput.decision.behavior` | documented | `"allow"\|"deny"` |
| `hookSpecificOutput.decision.updatedInput` | documented (v2.1.89+) | `map[string]interface{}` |
| `hookSpecificOutput.decision.updatedPermissions` | documented | `[]interface{}` |

最終確認日: 2026-04-06 (CC v2.1.92, code.claude.com/docs/en/hooks)

---

## 3. Hook Ownership Matrix

| Hook Event | 正本 | Phase | 備考 |
|-----------|------|-------|------|
| **PreToolUse** (guard) | **Go** | 35.0 ✅ | bin/harness hook pre-tool |
| **PostToolUse** (guard) | **Go** | 35.0 ✅ | bin/harness hook post-tool |
| **PermissionRequest** | **Go** | 35.0 ✅ | bin/harness hook permission |
| SessionStart | shell | 35.3 | session-env-setup + memory-bridge + init |
| SessionEnd | shell | 35.3 | session-cleanup |
| UserPromptSubmit | shell | 35.3 | memory-bridge + policy + tracking |
| PostToolUse (non-guard) | shell | 35.3 | log-toolname, commit-cleanup, track-changes 等 |
| Stop | shell | 35.3 | session-summary + memory-bridge + evaluator |
| SubagentStart/Stop | shell | 35.4 | subagent-tracker |
| TeammateIdle | shell | 35.4 | teammate-idle handler |
| TaskCompleted/Created | shell | 35.4 | task-completed + runtime-reactive |
| PreCompact/PostCompact | shell | 35.3 | pre-compact-save + post-compact |
| Elicitation/Result | shell | 35.3 | elicitation-handler |
| WorktreeCreate/Remove | shell | 35.6 | worktree lifecycle |
| Notification | shell | 35.3 | notification-handler |
| PermissionDenied | shell | 35.3 | permission-denied-handler |
| StopFailure | shell | 35.3 | stop-failure handler |
| InstructionsLoaded | shell | 35.3 | instructions-loaded |
| ConfigChange/CwdChanged/FileChanged | shell | 35.3 | runtime-reactive |

**Canary 順序**: PreToolUse (35.0✅) → PermissionRequest (35.0✅) → PostToolUse (35.0✅) → SessionStart → Stop → UserPromptSubmit → 残り全部

---

## 4. settings.json 実態スキーマ

公式ドキュメントでは「`agent` キーのみ」と記載されているが、実態では以下のキーが CC に認識される（既存 `.claude-plugin/settings.json` で確認済み）:

```jsonc
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  // デフォルトエージェント
  "agent": "string",
  // 環境変数の注入
  "env": {
    "KEY": "value"
  },
  // パーミッション制御
  "permissions": {
    "deny": ["Bash(sudo:*)", "mcp__codex__*", "Read(./.env)"],
    "ask": ["Bash(rm -r:*)", "Bash(git push -f:*)"]
  },
  // サンドボックス設定
  "sandbox": {
    "failIfUnavailable": true,
    "network": {
      "deniedDomains": ["169.254.169.254", "metadata.google.internal"]
    },
    "filesystem": {
      "denyRead": [".env", "secrets/**", "**/*.pem"],
      "allowRead": [".env.example", "docs/**"]
    }
  }
}
```

---

## 5. harness.toml → CC ファイル Mapping Table

| harness.toml セクション | 生成先 | CC キー |
|------------------------|--------|--------|
| `[project]` name, version, description, author | `plugin.json` | name, version, description, author |
| `[hooks]` | `hooks/hooks.json` + `.claude-plugin/hooks.json` | hooks |
| `[safety.permissions]` deny, ask | `settings.json` | permissions.deny, permissions.ask |
| `[safety.sandbox]` | `settings.json` | sandbox |
| `[agent]` default | `settings.json` | agent |
| `[env]` | `settings.json` | env |
| `[telemetry]` | **harness 内部設定** (生成しない) | N/A |
| `[state]` | **harness 内部設定** (生成しない) | N/A |

### Rejected / Unsupported

以下のキーは `harness sync` で **明示的にエラー** を出す:

- `userConfig` — CC に存在しない
- `channels` — CC に存在しない
- `settings.json` の未知キー — CC スキーマに存在しないキーは生成しない

---

## 6. SQLite Driver 選定

| 項目 | `modernc.org/sqlite` | `mattn/go-sqlite3` |
|------|---------------------|-------------------|
| CGO | **不要** (pure Go) | 必要 |
| クロスコンパイル | `GOOS=x go build` で完結 | ターゲット用 C compiler 必要 |
| バイナリサイズ増加 | +3-5MB | +1-2MB |
| WAL mode | ✅ | ✅ |
| ファイルロック | POSIX (flock) | POSIX (flock) |
| パフォーマンス | 10-30% 遅い (pure Go) | ネイティブ速度 |
| 安定性 | 高 (SQLite 公式 C コードの Go 翻訳) | 高 (SQLite 公式 C コード直接) |

**選定: `modernc.org/sqlite`**

理由:
- クロスコンパイルが Phase 35.7 の前提条件
- CGO 不要でビルド・CI が大幅に単純化
- パフォーマンス差は hook の hot path で SQLite を使わない設計で吸収（Phase 35.0 で SQLite なしの 5ms を達成済み）
- `busy_timeout=5000` でロック競合を緩和

---

## 7. CLI コマンド仕様

### `harness hook <event>`

```
stdin:  Hook JSON (CC が送信)
stdout: hookSpecificOutput JSON (CC が解釈)
exit:   0 = allow/warn, 2 = deny/block
```

| サブコマンド | 機能 |
|------------|------|
| `harness hook pre-tool` | PreToolUse ガードレール (R01-R13) |
| `harness hook post-tool` | PostToolUse 改ざん検出 + セキュリティチェック |
| `harness hook permission` | PermissionRequest 自動承認 |

### `harness sync`

```
stdin:  なし
stdout: 生成ログ
exit:   0 = 成功, 1 = harness.toml パースエラー or unsupported key
```

harness.toml を読み取り、以下を生成:
- `hooks/hooks.json`
- `.claude-plugin/hooks.json` (同一内容)
- `.claude-plugin/plugin.json`
- `.claude-plugin/settings.json`

### `harness init`

```
stdin:  なし
stdout: 生成ログ
exit:   0 = 成功
```

カレントディレクトリに `harness.toml` テンプレートを生成。

### `harness validate [skills|agents|all]`

```
stdout: 検証結果
exit:   0 = 全 PASS, 1 = エラーあり
```

### `harness doctor [--migration]`

```
stdout: 診断結果
exit:   0 = 正常, 1 = 問題あり
```

`--migration`: Go/shell の mixed-mode を検出し、移行状況を表示。

### `harness version`

```
stdout: バージョン文字列
exit:   0
```

---

## 8. 状態マシン定義

### 正常系

```
SPAWNING → RUNNING → REVIEWING → APPROVED → COMMITTED
```

### 異常系

```
SPAWNING → FAILED        (起動失敗)
RUNNING  → FAILED        (実行中エラー、3回リトライ超過)
RUNNING  → CANCELLED     (ユーザー中断、Ctrl+C)
REVIEWING → FAILED       (レビュー中エラー)
REVIEWING → CANCELLED    (ユーザー中断)
RUNNING  → STALE         (24h 超過で自動遷移)
REVIEWING → STALE        (24h 超過で自動遷移)
FAILED   → RECOVERING    (リカバリ開始)
RECOVERING → RUNNING     (リカバリ成功)
RECOVERING → ABORTED     (リカバリ失敗、人間介入必要)
```

### 4段階リカバリ

| 段階 | トリガー | アクション |
|------|---------|----------|
| 1. 自己修復 | 最初の失敗 | エラー分析 → 自動修正 → リトライ |
| 2. 仲間修復 | 自己修復失敗 | 別 Worker にタスク委譲 |
| 3. 指揮官介入 | 仲間修復失敗 | Lead セッションに escalation |
| 4. 停止 | 指揮官介入失敗 | ABORTED 状態、ユーザー通知 |

---

## 9. State Storage Contract

### パス優先順位

```
1. ${CLAUDE_PLUGIN_DATA}/state.db    (CC v2.1.78+ で永続)
2. ${PROJECT_ROOT}/.harness/state.db (フォールバック)
3. ${PROJECT_ROOT}/.claude/state/    (shell スクリプト用、読み取りのみ)
```

### 移行戦略

| 操作 | コマンド | 説明 |
|------|---------|------|
| エクスポート | `harness state export` | 現行 state.db を JSON にダンプ |
| インポート | `harness state import` | JSON から新 state.db に復元 |
| ロールバック | `HARNESS_STATE_PATH=old.db` | 環境変数でパスを上書き |

### 保持期間

| テーブル | TTL | クリーンアップ |
|---------|-----|-------------|
| `work_states` | 24h | 自動 (expires_at) |
| `sessions` | 無制限 | 手動 |
| `signals` | 消費済みは 7d | 自動 |
| `task_failures` | 無制限 | 手動 |
| `assumptions` | 無制限 | 手動 |

---

## 10. ガードレールルール仕様

| ID | ツール | 条件 | アクション | バイパス |
|----|--------|------|----------|---------|
| R01 | Bash | `sudo` 検出 | deny | なし |
| R02 | Write/Edit/MultiEdit | 保護パス (.env, .git/, *.pem, *.key, id_rsa 等) | deny | なし |
| R03 | Bash | `> .env`, `tee .git/` 等 | deny | なし |
| R04 | Write/Edit/MultiEdit | プロジェクトルート外への絶対パス | ask | workMode |
| R05 | Bash | `rm -rf` / `rm --recursive` | ask | workMode |
| R06 | Bash | `git push --force` / `-f` | deny | なし |
| R07 | Write/Edit/MultiEdit | codexMode 中の直接書き込み | deny | なし |
| R08 | Write/Edit/MultiEdit/Bash | breezing reviewer の書き込み/変更コマンド | deny | なし |
| R09 | Read | 機密ファイル (.env, id_rsa, *.pem, secrets/) | approve + warn | なし |
| R10 | Bash | `--no-verify` / `--no-gpg-sign` | deny | なし |
| R11 | Bash | protected branch への `git reset --hard` | deny | なし |
| R12 | Bash | main/master への直接 push | approve + warn | なし |
| R13 | Write/Edit/MultiEdit | package.json, Dockerfile, workflow 等 | approve + warn | なし |

テスト ID: `TestR01_*` 〜 `TestR13_*` (go/internal/guard/rules_test.go)

---

## 11. CC バージョン互換性マトリクス

| 機能 | 最小 CC バージョン | 備考 |
|------|-------------------|------|
| `bin/` PATH 自動追加 | v2.1.91 | Bash ツールの PATH に追加 |
| `${CLAUDE_PLUGIN_DATA}` | v2.1.78 | プラグイン更新を跨いで永続 |
| exit code 2 ブロッキング | v2.1.90 | v2.1.89 以前はバグあり |
| `permissionDecision: "defer"` | v2.1.89 | ヘッドレスモード一時停止 |
| `updatedInput` | v2.1.89 | 入力書き換え |
| `additionalContext` | v2.1.89 | Claude への追加コンテキスト |
| PreToolUse `allow` が settings.json `deny` を上書きしない | v2.1.77 | セキュリティ強化 |
| `settings.json` permissions/sandbox | v2.1.77+ | 実態で確認済み |

**最小推奨 CC バージョン: v2.1.91** (bin/ PATH が必要なため)

---

## 12. パッケージ境界

### hook-fastpath (5ms 以内)

```
internal/guard/     — ルール評価、改ざん検出、セキュリティチェック
internal/hook/      — stdin/stdout コーデック
pkg/protocol/       — 型定義
```

**制約**:
- ファイル I/O 禁止（SQLite 参照は BuildContext のみ、optional）
- ネットワーク I/O 禁止
- goroutine 起動禁止
- 外部プロセス起動禁止

### worker-runtime (長寿命)

```
internal/state/       — SQLite ストア
internal/session/     — セッションライフサイクル
internal/breezing/    — 並行オーケストレーション
internal/hookhandler/ — hook handler 群（OTel export, broadcast 含む）
internal/lifecycle/   — セッション状態追跡 + リカバリ
internal/ci/          — CI 統合ユーティリティ
pkg/config/           — 設定パーサー (harness.toml)
```

**制約**:
- goroutine は `context.Context` で管理
- graceful shutdown 必須
- `hook-fastpath` パッケージを import しない（逆方向の依存は可）

### API 境界

```
hook-fastpath ←── protocol (共有)
                       ↓
worker-runtime ←── protocol (共有)
```

`hook-fastpath` と `worker-runtime` は互いを直接 import しない。
共有型は `pkg/protocol/` にのみ置く。

---

## 決定事項: codex-companion.sh

**方針**: Go 統合 **対象外**。shell wrapper を維持する。

理由:
- codex-companion.sh は Codex CLI (外部プロセス) の呼び出しラッパー
- Codex CLI 自体が頻繁にアップデートされ、API が安定していない
- shell wrapper の方が Codex CLI 変更への追従が容易
- DESIGN.md の D2 方針と一致

Go 統合の対象は Harness 内部ロジック（ガードレール、状態管理、設定生成）に限定する。
