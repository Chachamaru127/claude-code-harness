# Session Management

## Session Resume/Fork

### セッション一覧の確認

```bash
# CLI: アーカイブディレクトリを確認
ls -la .claude/state/sessions/

# UI: harness-ui のWorkページでセッション一覧を確認
# → Session Archives テーブルから resume/fork コマンドをコピー可能
```

### 再開/分岐コマンド

```bash
# Resume latest stopped session
/work --resume latest

# Resume specific session ID
/work --resume session-1700000000

# Fork from current session
/work --fork current --reason "Proceed with trial version separately"

# Fork from specific session
/work --fork session-1700000000 --reason "Try different approach"
```

### Check session state

```bash
# Current session state
cat .claude/state/session.json | jq '.state, .session_id'

# Event history
tail -20 .claude/state/session.events.jsonl
```

## Auto-judgment Logic

Check Plans.md markers and operate in appropriate mode:

| Detected Marker | Operation Mode |
|-----------------|----------------|
| `pm:requested` / `cursor:requested` exists | 2-Agent (prioritize PM's request) |
| `cc:TODO` / `cc:WIP` only | Solo (autonomous) |

**Priority**: `pm:requested` > `cc:WIP` (continue) > `cc:TODO` (new)

## Auto-update Markers on Task Start

`/work` automatically transitions to **`cc:WIP`** on start:

```
pm:requested / cursor:requested / cc:TODO → cc:WIP (auto-update on start)
```

## Pre-task: Pending Commit Check (commit_on_pm_approve)

`/work` 起動時、前回の保留コミットがあるか確認する:

```
/work start:
    ↓
Check: PM approved + commit pending?
  (Handoff message contains "承認" + uncommitted changes exist)
    ↓
YES → Execute pending commit first
    → Then proceed to next task
    ↓
NO  → Proceed normally
```
