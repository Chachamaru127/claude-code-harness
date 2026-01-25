---
description: Inter-session communication (list, inbox, broadcast)
description-en: Inter-session communication (list, inbox, broadcast)
---

# /session - Inter-Session Communication

Manage communication between multiple Claude Code sessions working on the same project.

## Quick Reference

| What You Want | Command |
|---------------|---------|
| See who's working | `/session list` |
| Check messages | `/session inbox` |
| Send message to all | `/session broadcast "message"` |
| Mark as read | `/session inbox --mark` |

---

## Usage

```bash
/session              # Show options
/session list         # Show active sessions
/session inbox        # Check incoming messages
/session inbox --mark # Mark all as read
/session broadcast "API changed: userId → user"
```

---

## Subcommands

### `/session list` - Active Sessions

Show currently active sessions on this project.

**Output**:
```
📋 Active Sessions

| Session | Last Active | Status |
|---------|-------------|--------|
| abc123 (you) | now | active |
| def456 | 5m ago | idle |
| ghi789 | 15m ago | idle |

3 sessions active
```

---

### `/session inbox` - Check Messages

View broadcast messages from other sessions.

**Options**:
- `--mark` - Mark all messages as read
- `--count` - Show unread count only

**Output**:
```
📬 Inbox (2 unread)

[12:34] from session-def456:
  "UserAPI: renamed userId → user"

[12:30] from session-ghi789:
  "Added new endpoint: /api/health"

Mark as read? (y/n)
```

---

### `/session broadcast` - Send Message

Send a message to all other sessions.

**Use when**:
- API signature changed
- Important decision made
- Breaking change introduced

**Example**:
```bash
/session broadcast "Database schema updated - run migrations"
```

---

## When to Use

| Situation | Command |
|-----------|---------|
| "Is anyone else working?" | `/session list` |
| "Any notifications?" | `/session inbox` |
| "Need to tell others about this change" | `/session broadcast "..."` |

---

## How It Works

1. Sessions auto-register on startup via `session-init.sh`
2. Messages stored in `.claude/sessions/broadcast.md`
3. Sessions check inbox before major actions
4. Messages older than 24h auto-cleaned

---

## Notes

- Messages are project-local (not global)
- Sessions inactive >24h are auto-removed from list
- Broadcast is fire-and-forget (no delivery confirmation)
