# Harness Go Rewrite — Architecture Design

> Zero-base rewrite. No backward compatibility. All accumulated knowledge applied.

## Why Go

| 要件 | Go | Rust | 現行 (bash+TS) |
|------|-----|------|---------------|
| Cold start | 1-2ms | 0.5-1ms | 40-60ms |
| Cross-compile | `GOOS=x go build` | toolchain 管理 | N/A (interpreter) |
| JSON handling | stdlib `encoding/json` | serde (verbose) | jq + node |
| HTTP client | stdlib `net/http` | reqwest (dep) | curl spawn |
| Development speed | seconds | minutes | immediate but fragile |
| Binary size | 5-10MB | 2-5MB | ~200KB scripts |
| Dependencies | stdlib + 1-2 (uuid) | many crates | node + jq + bash |
| Self-referential dev | compile in 2s | compile in 30s+ | edit & run |

**結論**: Harness は「毎秒数回起動され、JSON を読んで判断を返す」ツール。Go の stdlib 中心 + 高速コンパイルが最適。

### 許容する外部依存

- `github.com/google/uuid` — OTel trace ID 生成。stdlib に UUID v4 がない
- `github.com/mattn/go-isatty` — TTY 検出（省略可: `os.Stdin.Stat()` で代替）
- **それ以外は不可。** MCP プロトコルも OTel フォーマットも stdlib の `encoding/json` + `net/http` で自前実装

## Directory Structure

```
harness-go/
├── cmd/
│   └── harness/
│       └── main.go              # Single entry: stdin → route → stdout
│
├── internal/
│   ├── guardrail/               # Guardrail engine (hot path, PreToolUse/PostToolUse/Permission)
│   │   ├── rules.go             # Declarative rule table (R01-R13+) + evaluation loop
│   │   ├── helpers.go           # Protected path detection, rm -rf, git push --force, etc.
│   │   ├── pre_tool.go          # PreToolUse: context build + deny/allow/defer
│   │   ├── post_tool.go         # PostToolUse: security risk detection + advisory checks
│   │   ├── permission.go        # PermissionRequest: conditional eval
│   │   └── tampering.go         # Test/config tampering detection (T01-T12)
│   │
│   ├── session/                 # Session lifecycle + agent tracking
│   │   ├── start.go             # SessionStart: env + memory bridge + init (parallel)
│   │   ├── stop.go              # Stop: summary, memory save, WIP check
│   │   ├── compact.go           # PreCompact save + PostCompact WIP restore
│   │   ├── agent.go             # SubagentStart/Stop tracking + trace
│   │   └── state.go             # State file + JSONL append with rotation
│   │
│   ├── event/                   # Remaining hook events + dispatcher
│   │   ├── dispatcher.go        # stdin → parse → route → execute → stdout
│   │   ├── prompt.go            # UserPromptSubmit: policy injection, tracking
│   │   ├── task.go              # TaskCreated/Completed + webhook trigger
│   │   ├── denied.go            # PermissionDenied: telemetry + retry
│   │   └── misc.go              # Notification, ConfigChange, Elicitation, StopFailure
│   │
│   ├── plans/                   # Plans.md operations + effort scoring
│   │   ├── parser.go            # Parse Plans.md tables (5-column format)
│   │   ├── marker.go            # Status marker read/update
│   │   └── effort.go            # Task complexity scoring
│   │
│   ├── hook/                    # Hook I/O codec (stdin parse, stdout marshal)
│   │   └── codec.go             # ReadInput / WriteResult helpers
│   │
│   ├── hookhandler/             # Go ports of shell hook handlers (40+ handlers)
│   │   ├── emit_agent_trace.go  # OTel span export (sync HTTP POST, 3s timeout, JSONL fallback)
│   │   ├── session_auto_broadcast.go  # Inter-session file-based broadcast
│   │   ├── memory_bridge.go     # Memory bridge (JSONL logging + harness-mem HTTP POST)
│   │   ├── task_completed.go    # TaskCompleted lifecycle + escalation + timeline
│   │   ├── auto_test_runner.go  # Auto test execution on Write/Edit
│   │   ├── ci_status_checker.go # CI status polling
│   │   └── ...                  # 30+ additional handlers (see go/internal/hookhandler/)
│   │
│   ├── breezing/                # Parallel task orchestration (worktree isolation)
│   │   ├── orchestrator.go      # Semaphore-controlled parallel execution
│   │   ├── worktree.go          # Git worktree create/remove
│   │   └── deps.go              # Task dependency resolution
│   │
│   ├── ci/                      # CI integration utilities
│   │   └── ci.go                # CI provider detection + status check
│   │
│   ├── lifecycle/               # Session lifecycle tracking + recovery
│   │   ├── tracker.go           # Session state machine
│   │   ├── state.go             # Work state persistence
│   │   └── recovery.go          # 4-stage recovery logic
│   │
│   └── state/                   # SQLite state store
│       ├── schema.go            # DB schema definition
│       └── store.go             # HarnessStore CRUD operations
│
├── pkg/
│   ├── hookproto/               # Hook protocol types (public API)
│   │   └── types.go             # HookInput, HookResult, Decision constants, output structs
│   │
│   └── config/                  # Configuration (harness.toml parsing)
│       └── toml.go              # HarnessConfig + TelemetryConfig (webhook_url, otel_endpoint)
│
├── skills/                   # Skills (Markdown, unchanged)
├── agents/                   # Agents (Markdown, unchanged)
├── .claude-plugin/
│   ├── plugin.json
│   ├── hooks.json               # Simplified: all → bin/harness hook <event>
│   └── settings.json
│
├── bin/                         # Build output (gitignored)
│   ├── harness-darwin-arm64
│   ├── harness-darwin-amd64
│   ├── harness-linux-amd64
│   └── harness-windows-amd64.exe
│
├── Makefile
├── go.mod
└── go.sum
```

**internal パッケージ: 9** (guardrail, session, event, hook, hookhandler, breezing, ci, lifecycle, state)。`pkg/` は hookproto + config。
通知機能 (OTel span export, broadcast) は `hookhandler/` に統合。独立 notify パッケージは設けず、各 handler が直接送信する設計に変更。
webhook POST は未実装（config 定義のみ将来対応予定）。
review (security/dual) はスキル側のプロンプト指示で完結するため Go binary から除外。

## Core Design: Single Binary, Subcommand Routing

```
# === Hook events (全 20 event を網羅。現行 hooks.json の全 command hook に対応) ===
bin/harness hook pretool            # PreToolUse
bin/harness hook pretool --browser  # PreToolUse (browser MCP tools)
bin/harness hook posttool           # PostToolUse
bin/harness hook permission         # PermissionRequest
bin/harness hook session-start      # SessionStart (startup + resume)
bin/harness hook session-end        # SessionEnd
bin/harness hook stop               # Stop
bin/harness hook pre-compact        # PreCompact
bin/harness hook post-compact       # PostCompact
bin/harness hook task-completed     # TaskCompleted
bin/harness hook task-created       # TaskCreated (runtime-reactive)
bin/harness hook permission-denied  # PermissionDenied
bin/harness hook teammate-idle      # TeammateIdle
bin/harness hook notification       # Notification
bin/harness hook config-change      # ConfigChange
bin/harness hook elicitation        # Elicitation
bin/harness hook elicitation-result # ElicitationResult
bin/harness hook stop-failure       # StopFailure
bin/harness hook user-prompt        # UserPromptSubmit
bin/harness hook todo-sync          # PostToolUse/TodoWrite → Plans.md sync
bin/harness hook subagent-start     # SubagentStart
bin/harness hook subagent-stop      # SubagentStop
bin/harness hook setup              # Setup (init / init-only / maintenance)
bin/harness hook instructions-loaded # InstructionsLoaded
bin/harness hook worktree-create    # WorktreeCreate
bin/harness hook worktree-remove    # WorktreeRemove
bin/harness hook cwd-changed        # CwdChanged (runtime-reactive)
bin/harness hook file-changed       # FileChanged (runtime-reactive)
bin/harness hook post-tool-failure  # PostToolUseFailure

# === Utilities ===
bin/harness effort <task-desc>      # Effort scoring
bin/harness plans sync              # Plans.md sync
bin/harness plans update <id> <status>  # Marker update
bin/harness version                 # Version info
```

**40+ shell scripts → 1 binary, ~28 subcommands。現行 hooks.json の全 command hook を漏れなくカバー。**
**MCP subcommand は削除（D3: 分離プロセス維持）。**

## hooks.json (Simplified)

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Write|Edit|MultiEdit|Bash|Read",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook pretool",
        "timeout": 10
      }]
    }, {
      "matcher": "Write|Edit",
      "hooks": [{
        "type": "agent",
        "prompt": "Review the following code change for quality issues. Check if the change: (1) introduces hardcoded secrets or credentials, (2) leaves TODO/FIXME stubs without implementation, (3) has obvious security vulnerabilities (SQL injection, XSS, command injection). If any issue is found, return JSON with permissionDecision: 'deny' and permissionDecisionReason explaining the issue. If the change looks acceptable, return nothing (exit 0). Input: $ARGUMENTS",
        "model": "haiku",
        "timeout": 30
      }]
    }, {
      "matcher": "mcp__chrome-devtools__.*|mcp__playwright__.*|mcp__plugin_playwright_playwright__.*",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook pretool --browser",
        "timeout": 5
      }]
    }],
    "PermissionRequest": [{
      "matcher": "Edit|Write|MultiEdit",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook permission",
        "timeout": 10
      }]
    }, {
      "matcher": "Bash",
      "if": "Bash(git status*)|Bash(git diff*)|Bash(git log*)|Bash(git branch*)|Bash(git rev-parse*)|Bash(git show*)|Bash(git ls-files*)|Bash(npm test*)|Bash(npm run test*)|Bash(npm run lint*)|Bash(npm run typecheck*)|Bash(npm run build*)|Bash(npm run validate*)|Bash(npm lint*)|Bash(npm typecheck*)|Bash(npm build*)|Bash(pnpm test*)|Bash(pnpm run test*)|Bash(pnpm run lint*)|Bash(pnpm run typecheck*)|Bash(pnpm run build*)|Bash(pnpm run validate*)|Bash(pnpm lint*)|Bash(pnpm typecheck*)|Bash(pnpm build*)|Bash(yarn test*)|Bash(yarn run test*)|Bash(yarn run lint*)|Bash(yarn run typecheck*)|Bash(yarn run build*)|Bash(yarn run validate*)|Bash(yarn lint*)|Bash(yarn typecheck*)|Bash(yarn build*)|Bash(pytest*)|Bash(python -m pytest*)|Bash(go test*)|Bash(cargo test*)",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook permission",
        "timeout": 10
      }]
    }],
    "PostToolUse": [{
      "matcher": "*",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook posttool",
        "timeout": 10
      }]
    }, {
      "matcher": "Write|Edit",
      "hooks": [{
        "type": "agent",
        "prompt": "Perform a lightweight code review on the file that was just written/edited. Check for: (1) hardcoded secrets or API keys, (2) TODO/FIXME stubs left without implementation, (3) obvious security issues. This is a non-blocking advisory check. If issues found, include them in systemMessage. Input: $ARGUMENTS",
        "model": "haiku",
        "timeout": 30
      }]
    }, {
      "matcher": "Write|Edit|Task",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness worker auto-test",
        "timeout": 120,
        "async": true
      }]
    }, {
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness worker ci-check",
        "timeout": 30,
        "async": true
      }]
    }, {
      "matcher": "TodoWrite",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook todo-sync",
        "timeout": 30
      }]
    }],
    "SessionStart": [{
      "matcher": "startup|resume",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook session-start",
        "timeout": 15,
        "once": true
      }]
    }],
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook stop",
        "timeout": 20
      }, {
        "type": "agent",
        "prompt": "Check if there are incomplete tasks before allowing session to stop. Read the Plans.md file and look for tasks with status 'cc:WIP'. If any WIP tasks exist, return JSON: {\"decision\": \"block\", \"reason\": \"WIP tasks remain: [list task numbers]. Consider completing them or marking as blocked before stopping.\"}. If no WIP tasks, return nothing (allow stop). Input: $ARGUMENTS",
        "model": "haiku",
        "timeout": 30
      }]
    }],
    "PreCompact": [{
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook pre-compact",
        "timeout": 15
      }, {
        "type": "agent",
        "prompt": "Check Plans.md for tasks with status 'cc:WIP' before the context window is compacted. If any WIP tasks exist, include a warning in systemMessage: 'Warning: Compacting context with WIP tasks in progress: [list task IDs and titles]. Key context about these tasks may be lost after compaction. Consider completing or checkpointing them first.' If no WIP tasks, return nothing. Input: $ARGUMENTS",
        "model": "haiku",
        "timeout": 30
      }]
    }],
    "PostCompact": [{
      "matcher": "*",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook post-compact",
        "timeout": 10
      }]
    }],
    "TaskCompleted": [{
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook task-completed",
        "timeout": 10
      }]
    }],
    "TaskCreated": [{
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook task-created",
        "timeout": 5
      }]
    }],
    "PermissionDenied": [{
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook permission-denied",
        "timeout": 5
      }]
    }],
    "SubagentStart": [{
      "matcher": "worker|reviewer|video-scene-generator",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook subagent-start",
        "timeout": 5
      }]
    }],
    "SubagentStop": [{
      "matcher": "worker|reviewer|video-scene-generator",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook subagent-stop",
        "timeout": 5
      }]
    }],
    "TeammateIdle": [{
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook teammate-idle",
        "timeout": 10
      }]
    }],
    "ConfigChange": [{
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook config-change",
        "timeout": 10
      }]
    }],
    "UserPromptSubmit": [{
      "matcher": "*",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook user-prompt",
        "timeout": 10
      }]
    }],
    "Notification": [{
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook notification",
        "timeout": 5
      }]
    }],
    "StopFailure": [{
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook stop-failure",
        "timeout": 5
      }]
    }],
    "SessionEnd": [{
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook session-end",
        "timeout": 15
      }]
    }],
    "Setup": [{
      "matcher": "init|init-only",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook setup --mode init",
        "timeout": 60,
        "once": true
      }]
    }, {
      "matcher": "maintenance",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook setup --mode maintenance",
        "timeout": 60,
        "once": true
      }]
    }],
    "InstructionsLoaded": [{
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook instructions-loaded",
        "timeout": 10
      }]
    }],
    "WorktreeCreate": [{
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook worktree-create",
        "timeout": 10
      }]
    }],
    "WorktreeRemove": [{
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook worktree-remove",
        "timeout": 10
      }]
    }],
    "CwdChanged": [{
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook cwd-changed",
        "timeout": 10
      }]
    }],
    "FileChanged": [{
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook file-changed",
        "timeout": 10
      }]
    }],
    "Elicitation": [{
      "matcher": "*",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook elicitation",
        "timeout": 10
      }]
    }],
    "ElicitationResult": [{
      "matcher": "*",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook elicitation-result",
        "timeout": 5
      }]
    }],
    "PostToolUseFailure": [{
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook post-tool-failure",
        "timeout": 10
      }]
    }]
  }
}
```

**現行 hooks.json の全 command hook event を網羅。** agent hooks (type: "agent") は PreToolUse/PostToolUse/Stop/PreCompact 内にそのまま残る。

### Memory Bridge の内蔵

`hookhandler/memory_bridge.go` が 5 つのイベントターゲットを処理する。
JSONL ログは常に記録し、harness-mem デーモンが起動している場合は HTTP POST で連携する。

**イベントフロー**:

| hook target | harness-mem endpoint | event_type |
|------------|---------------------|------------|
| session-start | POST /v1/events/record | session_start |
| user-prompt | POST /v1/events/record | user_prompt |
| post-tool-use | POST /v1/events/record | tool_use |
| stop | POST /v1/sessions/finalize | (finalize) |
| codex-notify | POST /v1/events/record | checkpoint |

**harness-mem 未導入時の動作**: HTTP POST は `connection refused` で即座に失敗し、
stderr にログを出力して approve を返す。JSONL ログのみが記録される。
レイテンシ追加はコネクション拒否の数ミリ秒のみ。

**設定**:
- `HARNESS_MEM_HOST` (default: 127.0.0.1)
- `HARNESS_MEM_PORT` (default: 37888)
- `HARNESS_MEM_ADMIN_TOKEN` (optional: Bearer ヘッダに付与)

## Guardrail Engine Design

```go
// internal/guardrail/rules.go

type Rule struct {
    ID          string                         // R01, R02, ...
    Name        string                         // Human-readable name
    Events      []string                       // Which hook events this applies to
    Match       func(input *hookproto.Input) bool
    Evaluate    func(input *hookproto.Input) *Decision
    Severity    Severity                       // block, warn, info
}

type Decision struct {
    Action  Action  // allow, deny, defer, warn
    Reason  string
    Details map[string]any
}

var Rules = []Rule{
    {
        ID:       "R01",
        Name:     "no-hardcoded-secrets",
        Events:   []string{"pretool"},
        Severity: Block,
        Match: func(in *hookproto.Input) bool {
            return in.Tool == "Write" || in.Tool == "Edit"
        },
        Evaluate: func(in *hookproto.Input) *Decision {
            if containsSecret(in.Content) {
                return &Decision{Action: Deny, Reason: "Hardcoded secret detected"}
            }
            return nil // pass
        },
    },
    {
        ID:       "R02",
        Name:     "no-test-tampering",
        Events:   []string{"pretool"},
        Severity: Block,
        Match: func(in *hookproto.Input) bool {
            return (in.Tool == "Write" || in.Tool == "Edit") && isTestFile(in.FilePath)
        },
        Evaluate: func(in *hookproto.Input) *Decision {
            if detectsTampering(in.Content) {
                return &Decision{Action: Deny, Reason: "Test tampering detected: skip/only/assertion removal"}
            }
            return nil
        },
    },
    // ... R03-R13+
}
```

**宣言的ルールテーブル。** ルール追加は struct を 1 つ足すだけ。shell の if/else 連鎖と比較して可読性が桁違い。

## State Management

```go
// 設計方針: State directory resolution（各 handler で適用）

func stateDir() string {
    if d := os.Getenv("CLAUDE_PLUGIN_DATA"); d != "" {
        hash := projectHash(projectRoot())
        return filepath.Join(d, "projects", hash)
    }
    return filepath.Join(projectRoot(), ".claude", "state")
}

// 設計方針: Symlink safety（ファイル I/O 前に検証）
func safeAppend(path string, data []byte) error {
    if isSymlink(path) || isSymlink(filepath.Dir(path)) {
        return ErrSymlinkRefused
    }
    // ...
}
```

**セキュリティチェック（symlink 拒否、ディレクトリ検証）は設計方針として全 handler に適用。**
現在は各 handler が個別にパス解決・ファイル I/O を行っている。
共通ユーティリティへの統合は将来のリファクタリング候補。

## Security Design

| 脅威 | 対策 | 実装場所 |
|------|------|---------|
| **Symlink traversal** | ファイル I/O 前に symlink チェック。symlink は即拒否 | 設計方針。各 handler で個別に `os.Lstat` 実施 |
| **Path traversal (../)** | `filepath.Clean` + `filepath.Rel` で state dir 外への書込を拒否 | 設計方針。各 handler で個別に適用 |
| **Secret leak (logs)** | URL、トークン、API キーをログ出力時にマスク | 設計方針（将来 webhook 実装時に統合予定） |
| **Command injection** | guardrail ホットパス（pretool/posttool/permission）は shell・exec.Command を使わず全て内部処理。worker サブコマンド（auto-test, ci-check）は exec.Command でプロジェクトの test/CI コマンドを実行する（現行 shell 版と同等） | guardrail/* は内部処理。hookhandler/auto_test_runner.go, hookhandler/ci_status_checker.go は exec.Command 許可 |
| **TOCTOU** | ファイル存在チェックせず直接操作 → エラーハンドリング | 各 handler で直接操作 → error handling パターンを適用 |
| **Unbounded growth** | JSONL rotation (500行超 → 400行に切詰) | hookhandler/emit_agent_trace.go (MaxFileSize による rotation) |
| **Secret in hook output** | PreToolUse deny 理由にユーザー入力を含める際はサニタイズ | guardrail/pre_tool.go |
| **Memory injection** | harness-mem POST 前に必須フィールド・長さチェック (K-1.2) | hookhandler/memory_bridge.go `validateBridgeInput` |

### SafeResult の fail-open 設計判断

`hook.SafeResult` は stdin パースエラー等のエンジンエラー時に `approve` を返す（fail-open）。
これは S-1.5「安全側をデフォルトにする」と表面上矛盾するが、意図的な設計判断である。

**理由**: CC プロトコルにおいて hook は「ツール使用を補助的に検査する層」であり、
hook 自体の障害でユーザーのセッションが停止することは、ガードレール不在での続行より
被害が大きい。deny の判断は `GuardRule` テーブルの正規表現マッチで確定的に行われ、
SafeResult に到達するのは「ルール評価自体が不可能だった場合」のみ。

**ガードの位置**: deny 判定は exit code 2 で確実にブロックされる。
SafeResult は「ルール評価の前段階でのインフラ障害」であり、
「安全性判定を skip した」のではなく「安全性判定のインプットが得られなかった」ケース。

## Delivery Model: Short-Lived Process での通知

Go binary は都度起動→即終了の短命プロセス。async goroutine はプロセス終了で消える。

**現在の実装状況**:

| 通知チャネル | 状態 | 実装場所 |
|------------|------|---------|
| OTel span export | **実装済み** (sync, 3s timeout) | `hookhandler/emit_agent_trace.go` |
| Inter-session broadcast | **実装済み** (file-based) | `hookhandler/session_auto_broadcast.go` |
| Webhook POST | **未実装** (将来対応予定) | — |

**OTel span export フロー** (emit-agent-trace handler):

```
bin/harness hook PostToolUse (agent trace)
  → trace record を agent-trace.jsonl に追記
  → OTEL_EXPORTER_OTLP_ENDPOINT が設定されている場合:
    → HTTP POST (sync, 3s timeout, Content-Type: application/json)
    → 失敗は stderr ログのみ。リトライしない
  → stdout JSON response
  → exit
```

- OTel 送信は sync with timeout (3s)。プロセス内で完了を待つ
- 送信失敗は stderr ログのみ。リトライしない（次回の hook 起動時に新イベントを送る）
- JSONL は常に書き込まれる（OTel 送信失敗時のフォールバック兼ローカル記録）

**Webhook POST** は config struct (`harness.toml` の `[telemetry]` セクション) に
フィールド定義があるが、送信ロジックは未実装。必要性が確認された時点で
`hookhandler/` 内の該当 handler に sync POST を追加する方針。

**長時間系 hook (PostToolUse) の扱い**:

現行の `auto-test-runner` (120s, async) や `ci-status-checker` (30s, async) は
短命プロセスに収まらない。これらは **分離ワーカー** として扱う:

```json
// hooks.json で Go binary と分離ワーカーを並列配置
"PostToolUse": [{
  "matcher": "Write|Edit|MultiEdit|Bash",
  "hooks": [{
    "type": "command",
    "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook posttool",
    "timeout": 10
  }]
}, {
  "matcher": "Write|Edit|Task",
  "hooks": [{
    "type": "command",
    "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness worker auto-test",
    "timeout": 120,
    "async": true
  }]
}, {
  "matcher": "Bash",
  "hooks": [{
    "type": "command",
    "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness worker ci-check",
    "timeout": 30,
    "async": true
  }]
}]
```

`bin/harness worker <name>` は長時間実行用のサブコマンド。
`bin/harness hook posttool` は高速判定 (10s) のみ担当し、重い処理は worker に分離。

## Agent Hooks (type: "agent") の扱い

**決定: hooks.json に残す。Go binary は関与しない。**

agent hooks は CC が LLM を起動して判断を委任する仕組み。Go binary が置換するのは `type: "command"` のフックのみ。

```json
// hooks.json で agent hooks はそのまま残る
{
  "matcher": "Write|Edit",
  "hooks": [
    {
      "type": "command",
      "command": "${CLAUDE_PLUGIN_ROOT}/bin/harness hook pretool",
      "timeout": 10
    },
    {
      "type": "agent",
      "prompt": "Review the code change for quality issues...",
      "model": "haiku",
      "timeout": 30
    }
  ]
}
```

Go binary (command) が高速にガードレール判定を返し、agent hook (LLM) がその後に非同期で品質チェックを行う。責務分離。

## MCP Server の扱い

**決定: 分離プロセス。Go binary に内蔵しない。HTTP API で連携。**

理由:
- harness-mem は SQLite ベースの永続ストア。Go で CGO なしの SQLite は制約が多い
- MCP server は常駐プロセス。hook handler は短命プロセス。ライフサイクルが異なる
- Go binary は `hookhandler/memory_bridge.go` で harness-mem の HTTP API に直接 POST する

```
bin/harness hook session-start → memory_bridge.go → JSONL log + POST /v1/events/record
bin/harness hook user-prompt   → memory_bridge.go → JSONL log + POST /v1/events/record
bin/harness hook post-tool-use → memory_bridge.go → JSONL log + POST /v1/events/record
bin/harness hook stop          → memory_bridge.go → JSONL log + POST /v1/sessions/finalize
bin/harness hook codex-notify  → memory_bridge.go → JSONL log + POST /v1/events/record
```

harness-mem が未起動の場合は connection refused で即座にフォールバック（JSONL のみ）。
将来 Go 純粋の MCP server が必要になった場合は、`modernc.org/sqlite` (CGO-free) で別バイナリとして実装する。

## Performance Comparison (Estimated)

| Operation | Current (bash+node) | Go rewrite | Speedup |
|-----------|-------------------|------------|---------|
| PreToolUse guardrail | 40-60ms | 2-3ms | **20x** |
| PostToolUse logging | 20-30ms | 1-2ms | **15x** |
| SessionStart init | 500-800ms (4 hooks) | 10-15ms (1 call) | **50x** |
| TaskCompleted + webhook | 100-150ms | 3-5ms | **30x** |
| OTel span export | 100-200ms | 2-3ms (async) | **50x** |
| Plans.md parse | 50-100ms (bash+jq) | 1-2ms | **50x** |
| Total per tool call | 60-90ms overhead | 3-5ms overhead | **20x** |

**Breezing 1000 回のツール呼び出し: 60-90 秒 → 3-5 秒**

### Worst Case Analysis (PreToolUse)

```
stdin JSON read:     0.1ms  (io.ReadAll, unbounded — large Write/Edit payloads safe)
json.Unmarshal:      0.3ms  (encoding/json, typed struct)
Rule matching loop:  0.5ms  (13 rules × Match func, short-circuit on first deny)
State dir access:    0.5ms  (single os.Stat for CLAUDE_PLUGIN_DATA resolution)
JSONL append:        0.3ms  (safefile.Append, includes Lstat check)
json.Marshal output: 0.1ms  (<200B response)
─────────────────────────────
Worst case total:    1.8ms
```

SessionStart (parallel goroutines):
```
env setup:           2ms   ┐
rules load:          1ms   ├── parallel → max(2, 1) = 2ms
memory bridge file:  3ms   │  (sequential after env)
─────────────────────────────
Worst case total:    5ms
```

## What Stays Markdown

| Component | Format | Reason |
|-----------|--------|--------|
| skills/*.md | Markdown | CC がプロンプトとして読む。コンパイル不要 |
| agents/*.md | Markdown | CC がプロンプトとして読む |
| .claude/rules/*.md | Markdown | CC がルールとして読む |
| CLAUDE.md | Markdown | CC が instructions として読む |
| Plans.md | Markdown | Go がパースするが、人間も読む |
| CHANGELOG.md | Markdown | リリースノート |

## What Disappears

| Current | Go Rewrite | Reason |
|---------|------------|--------|
| 40+ shell scripts in scripts/ | 0 | 全て Go binary に統合 |
| core/src/ TypeScript | 0 | Go internal/ に置換 |
| node_modules/ | 0 | Go は stdlib 完結 |
| scripts/run-hook.sh routing | 0 | Go の subcommand routing |
| jq dependency | 0 | Go encoding/json |
| scripts/path-utils.sh | 0 | 各 handler でパス解決を内包 |
| scripts/sync-plugin-cache.sh | Go 版に更新 | hooks.json + bin/* を .claude-plugin/ にコピー。二重管理は維持（テスト互換） |

## Build & Distribution

```makefile
# Makefile

PLATFORMS := darwin/arm64 darwin/amd64 linux/amd64 linux/arm64 windows/amd64

.PHONY: build
build:
	go build -o bin/harness ./cmd/harness

.PHONY: release
release:
	$(foreach platform,$(PLATFORMS),\
		GOOS=$(word 1,$(subst /, ,$(platform))) \
		GOARCH=$(word 2,$(subst /, ,$(platform))) \
		go build -ldflags="-s -w" \
		-o bin/harness-$(subst /,-,$(platform))$(if $(findstring windows,$(platform)),.exe) ./cmd/harness ;)

.PHONY: test
test:
	go test ./...

.PHONY: lint
lint:
	golangci-lint run
```

## Migration Path

This is a **zero-base rewrite**, not a migration. Both versions coexist:

- `main` branch: Current bash+TS version (production)
- `feat/harness-go-rewrite` branch: Go version (development)

Switch is atomic: replace `hooks/hooks.json` + `.claude-plugin/hooks.json` + `.claude-plugin/` metadata + `bin/` in one commit.
`hooks/hooks.json` と `.claude-plugin/hooks.json` の二重管理は維持（test-hooks-sync.sh 互換）。

## Design Decisions (formerly Open Questions)

| # | 質問 | 決定 | 理由 |
|---|------|------|------|
| D1 | agent hooks (type: "agent") | **hooks.json に残す。Go は command hooks のみ** | LLM judgment は CC の責務。Go は高速なルール評価に集中 |
| D2 | Codex companion | **現行 shell wrapper を維持** | companion は codex-plugin-cc の proxy。Go 化の ROI が低い |
| D3 | Memory MCP | **分離プロセス。Go に内蔵しない** | SQLite CGO 問題、ライフサイクル不一致。Node 版を継続利用 |
| D4 | Plugin bin/ auto-selection | **CC の bin/ feature を使う** | CC v2.1.91+ がプラットフォーム別にバイナリを選択。Makefile で命名規則を合わせるだけ |
| D5 | パッケージ構造 | **internal 9 + pkg 2** (guardrail, session, event, hook, hookhandler, breezing, ci, lifecycle, state / hookproto, config) | 通知は hookhandler に統合。機能単位で分割しつつ依存方向を一方向に維持 |
| D6 | review (security/dual) | **Go binary から除外。スキルのプロンプト指示で完結** | review の判断は LLM が行う。Go が持つ必要がない |
| D7 | 外部依存 | **uuid のみ許容。他は stdlib** | MCP/OTel も encoding/json + net/http で自前実装 |

## Binary Size Estimate (Revised)

```
Go stdlib minimal:     1.5MB
+ net/http:           +0.5MB
+ encoding/json:       (included)
+ google/uuid:        +0.1MB
+ ldflags -s -w:      -30%
─────────────────────────────
Expected:              ~2.5MB (darwin/arm64)
```

5 プラットフォーム合計: ~12MB（bin/ ディレクトリ全体）