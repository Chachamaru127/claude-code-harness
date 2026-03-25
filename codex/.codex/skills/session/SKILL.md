---
name: session
description: "セッション管理の総合窓口。初期化・記憶・状態を一手に引き受けます。Use when managing Claude Code sessions, /session command. Do NOT load for: app user sessions, login state, authentication features."
description-en: "Unified session management window. Handles initialization, memory, state all-in-one. Use when managing Claude Code sessions, /session command. Do NOT load for: app user sessions, login state, authentication features."
description-ja: "セッション管理の総合窓口。初期化・記憶・状態を一手に引き受けます。Use when managing Claude Code sessions, /session command. Do NOT load for: app user sessions, login state, authentication features."
allowed-tools: ["Read", "Bash", "Write", "Edit", "Glob"]
argument-hint: "[list|inbox|broadcast \"message\"]"
---

# Session Skill (Unified)

Consolidates all session-related functionality into one skill.

## Usage

```bash
/session              # Show available options
/session list         # Show active sessions
/session inbox        # Check incoming messages
/session broadcast "message"  # Send message to all sessions
```

## Subcommands

### `/session list` - List Active Sessions

Shows all active Claude Code sessions in the current project.

```
📋 Active Sessions

| Session ID | Status | Last Activity |
|------------|--------|---------------|
| abc123     | active | 2 min ago     |
| def456     | idle   | 15 min ago    |
```

### `/session inbox` - Check Inbox

Checks for incoming messages from other sessions.

```
📬 Session Inbox

| From | Time | Message |
|------|------|---------|
| abc123 | 5m ago | "Ready for review" |
| def456 | 10m ago | "API implementation done" |
```

### `/session broadcast "message"` - Broadcast Message

Sends a message to all active sessions.

```bash
/session broadcast "Review complete, ready for merge"
```

---

## Capabilities

| Feature | Description | Reference |
|---------|-------------|-----------|
| **Initialization** | Start new session, load context | See [../session-init/SKILL.md](../session-init/SKILL.md) |
| **Memory** | Persist learnings across sessions | See [../session-memory/SKILL.md](../session-memory/SKILL.md) |
| **State Control** | Resume/fork session based on flags | See [references/session-control.md](${CLAUDE_SKILL_DIR}/references/session-control.md) |
| **Communication** | Cross-session messaging | See [../session-state/SKILL.md](../session-state/SKILL.md) |

---

## メモリ最適化（CC 2.1.49+）

Claude Code 2.1.49 以降、セッション再開時のメモリ使用量が **68% 削減** されました。

### 長時間セッション管理のベストプラクティス

| ワークロード | 推奨戦略 |
|------------|---------|
| **通常実装** | 1-2時間ごとに `--resume` で再開 |
| **大規模リファクタ** | 機能単位でセッション分割 → 各セッションで `--resume` |
| **並列タスク** | `/work all` で並列実行、長時間なら途中で `--resume` |
| **メモリ警告時** | 即座に `--resume` で再開（以前より高速） |

### セッション名の自動生成（CC 2.1.41+）

`/rename` を引数なしで実行すると、会話コンテキストからセッション名を自動生成します。
長時間セッションや `--resume` を多用するワークフローでセッションの識別が容易になります。

### 効率的なワークフロー例

```bash
# 実装フェーズ1
claude "認証機能を実装"
# → 1時間後

# セッション再開（メモリ効率的）
claude --resume "パスワードリセット機能を追加"
# → 1時間後

# さらに再開
claude --resume "テストを追加"
```

### メモリ管理の推奨事項

| 推奨事項 | 理由 |
|---------|------|
| **積極的なセッション再開** | 68% メモリ削減で再開コストが低い |
| **定期的な再開** | コンテキストを整理し、集中力を維持 |
| **機能単位の分割** | 大規模タスクを小さく分けて再開 |
| **Plans.md を活用** | 再開時の引き継ぎがスムーズ |

> 💡 メモリ効率が大幅に改善されたため、セッション再開を積極的に活用してください。

---

## When to Use

- Session initialization (`/harness-init`)
- Session resume/fork (`/work --resume`, `/work --fork`)
- Memory persistence (automatic)
- Cross-session communication (`/session broadcast`)

## Execution Flow

### 1. Session Initialization

```
/harness-init
    ↓
├── Load project context
├── Initialize session.json
├── Load previous session memory (if exists)
└── Display session status
```

### 2. Session Control (from /work)

```
/work --resume
    ↓
├── Check session.json exists
├── Load session state
└── Continue from last checkpoint

/work --fork
    ↓
├── Create new session branch
├── Copy relevant context
└── Start fresh with context
```

### 3. Memory Persistence

```
Session end
    ↓
├── Extract learnings (gotchas, patterns)
├── Update .claude/memory/*.md
└── Prepare handoff summary
```

### 4. Cross-Session Communication

```
/session broadcast "message"
    ↓
├── Find active sessions
├── Write to session.events.jsonl
└── Notify all sessions
```

## Files Managed

| File | Purpose |
|------|---------|
| `.claude/state/session.json` | Current session state |
| `.claude/state/session.events.jsonl` | Event log for cross-session communication |
| `.claude/memory/*.md` | Persistent memory files |

## Migration Note

This skill consolidates:
- `session-init` → Session initialization
- `session-memory` → Memory persistence
- `session-control` → Resume/fork control
- `session-state` → State management & communication

The individual skills are deprecated but still work for backward compatibility.
