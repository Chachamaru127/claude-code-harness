---
description: "[Optional] Unified session management command (list, inbox, broadcast)"
description-en: "[Optional] Unified session management command (list, inbox, broadcast)"
---

# /session - Unified Session Management

Consolidates all session-related commands into one unified interface.

## Quick Reference

- "**Show sessions**" → `/session list`
- "**Check messages**" → `/session inbox`
- "**Send to all**" → `/session broadcast "message"`

## Usage

```bash
/session              # Show available options
/session list         # Show active sessions
/session inbox        # Check incoming messages
/session broadcast "message"  # Send message to all sessions
```

---

## Subcommands

### `/session list` - List Active Sessions

Shows all active Claude Code sessions in the current project.

**Output**:
```
📋 Active Sessions

| Session ID | Status | Last Activity |
|------------|--------|---------------|
| abc123     | active | 2 min ago     |
| def456     | idle   | 15 min ago    |
```

---

### `/session inbox` - Check Inbox

Checks for incoming messages from other sessions.

**Output**:
```
📬 Session Inbox

| From | Time | Message |
|------|------|---------|
| abc123 | 5m ago | "Ready for review" |
| def456 | 10m ago | "API implementation done" |
```

---

### `/session broadcast "message"` - Broadcast Message

Sends a message to all active sessions.

**Usage**:
```bash
/session broadcast "Review complete, ready for merge"
/session broadcast "Stopping for today"
```

**Output**:
```
📢 Broadcast sent to 3 sessions
```

---

## Migration Note

This command consolidates the following individual commands:
- `/session-list` → `/session list`
- `/session-inbox` → `/session inbox`
- `/session-broadcast` → `/session broadcast "message"`

The individual commands have been removed. Use the unified `/session` command with subcommands.

---

## Related

- Session memory is managed by the `session` skill
- For session initialization, use `/harness-init`
