#!/bin/bash
# plans-watcher.sh - Monitors changes to Plans.md and generates notifications to PM (compat: cursor:*)
# Called from PostToolUse hook
#
# Idempotency guard (e): exclusive control via .claude/state/locks/plans.flock
# Prevents lost updates from concurrent wake-up and Worker writes.
# Uses a 3-tier lock: flock(Linux) → lockf(macOS) → mkdir fallback.
# Same pattern as acquire_lock/release_lock in auto-checkpoint.sh.
#
# fail-closed policy (41.1.3):
# Retries lock acquisition 3 times (to absorb transient races);
# if still unable to acquire, exits with code 11 (fail-closed, does not continue).
# This prevents unprotected read-modify-write to plans-state.json.

set +e  # do not stop on error

# ── flock guard (3-tier fallback) ─────────────────────────────────────────────
PLANS_LOCK_FILE="${PLANS_LOCK_FILE:-.claude/state/locks/plans.flock}"
PLANS_LOCK_DIR="${PLANS_LOCK_FILE}.dir"
PLANS_LOCK_TIMEOUT="${PLANS_LOCK_TIMEOUT:-5}"
_PLANS_LOCK_ACQUIRED=0

_plans_acquire_lock() {
    mkdir -p "$(dirname "${PLANS_LOCK_FILE}")" 2>/dev/null || true

    if command -v flock >/dev/null 2>&1; then
        exec 8>"${PLANS_LOCK_FILE}"
        if flock -w "${PLANS_LOCK_TIMEOUT}" 8 2>/dev/null; then
            _PLANS_LOCK_ACQUIRED=1
            return 0
        else
            exec 8>&- 2>/dev/null || true
            return 1
        fi
    fi

    if command -v lockf >/dev/null 2>&1; then
        exec 8>"${PLANS_LOCK_FILE}"
        if lockf -s -t "${PLANS_LOCK_TIMEOUT}" 8 2>/dev/null; then
            _PLANS_LOCK_ACQUIRED=2
            return 0
        else
            exec 8>&- 2>/dev/null || true
            return 1
        fi
    fi

    # Fallback: exclusive control via mkdir
    local waited=0
    local max_wait=$(( PLANS_LOCK_TIMEOUT * 5 ))
    while ! mkdir "${PLANS_LOCK_DIR}" 2>/dev/null; do
        sleep 0.2
        waited=$(( waited + 1 ))
        if [ "${waited}" -ge "${max_wait}" ]; then
            return 1
        fi
    done
    _PLANS_LOCK_ACQUIRED=3
    return 0
}

_plans_release_lock() {
    case "${_PLANS_LOCK_ACQUIRED}" in
        1) flock -u 8 2>/dev/null || true; exec 8>&- 2>/dev/null || true ;;
        2) exec 8>&- 2>/dev/null || true ;;
        3) rmdir "${PLANS_LOCK_DIR}" 2>/dev/null || true ;;
    esac
    _PLANS_LOCK_ACQUIRED=0
}

# Acquire lock (fail-closed: exit 11 if still failing after 3 retries)
# Attempt 3 times to absorb transient race conditions.
# If all attempts fail, abort to avoid unprotected access to plans-state.json.
_PLANS_LOCK_MAX_RETRIES=3
_PLANS_LOCK_GOT=0
for _retry in 1 2 3; do
    if _plans_acquire_lock; then
        _PLANS_LOCK_GOT=1
        break
    fi
    echo "plans-watcher.sh: warning: could not acquire plans.flock (attempt ${_retry}/${_PLANS_LOCK_MAX_RETRIES}, timeout ${PLANS_LOCK_TIMEOUT}s)" >&2
    if [ "${_retry}" -lt "${_PLANS_LOCK_MAX_RETRIES}" ]; then
        sleep 1
    fi
done

if [ "${_PLANS_LOCK_GOT}" -eq 0 ]; then
    echo "plans-watcher.sh: ERROR: Failed to acquire plans.flock after ${_PLANS_LOCK_MAX_RETRIES} attempts, aborting (fail-closed)" >&2
    exit 11
fi

# Always release lock on script exit
_plans_watcher_cleanup() {
    _plans_release_lock
}
trap _plans_watcher_cleanup EXIT

# Get the changed file (stdin JSON preferred / compat: $1,$2)
INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

CHANGED_FILE="${1:-}"
TOOL_NAME="${2:-}"
CWD=""

if [ -n "$INPUT" ]; then
  if command -v jq >/dev/null 2>&1; then
    TOOL_NAME_FROM_STDIN="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"
    FILE_PATH_FROM_STDIN="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_response.filePath // empty' 2>/dev/null)"
    CWD_FROM_STDIN="$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)"
  elif command -v python3 >/dev/null 2>&1; then
    eval "$(printf '%s' "$INPUT" | python3 -c '
import json, shlex, sys
try:
    data = json.load(sys.stdin)
except Exception:
    data = {}
tool_name = data.get("tool_name") or ""
cwd = data.get("cwd") or ""
tool_input = data.get("tool_input") or {}
tool_response = data.get("tool_response") or {}
file_path = tool_input.get("file_path") or tool_response.get("filePath") or ""
print(f"TOOL_NAME_FROM_STDIN={shlex.quote(tool_name)}")
print(f"CWD_FROM_STDIN={shlex.quote(cwd)}")
print(f"FILE_PATH_FROM_STDIN={shlex.quote(file_path)}")
' 2>/dev/null)"
  fi

  [ -z "$CHANGED_FILE" ] && CHANGED_FILE="${FILE_PATH_FROM_STDIN:-}"
  [ -z "$TOOL_NAME" ] && TOOL_NAME="${TOOL_NAME_FROM_STDIN:-}"
  CWD="${CWD_FROM_STDIN:-}"
fi

# Normalize to project-relative path if possible
if [ -n "$CWD" ] && [ -n "$CHANGED_FILE" ] && [[ "$CHANGED_FILE" == "$CWD/"* ]]; then
  CHANGED_FILE="${CHANGED_FILE#$CWD/}"
fi

# Path to Plans.md (respects plansDirectory setting)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/config-utils.sh" ]; then
  source "${SCRIPT_DIR}/config-utils.sh"
  PLANS_FILE=$(get_plans_file_path)
  plans_file_exists || PLANS_FILE=""
else
  # Fallback: legacy search logic
  find_plans_file() {
      for f in Plans.md plans.md PLANS.md PLANS.MD; do
          if [ -f "$f" ]; then
              echo "$f"
              return 0
          fi
      done
      return 1
  }
  PLANS_FILE=$(find_plans_file)
fi

# Skip changes to files other than Plans.md
if [ -z "$PLANS_FILE" ]; then
    exit 0
fi

case "$CHANGED_FILE" in
    "$PLANS_FILE"|*/"$PLANS_FILE") ;;
    *) exit 0 ;;
esac

# State directory
STATE_DIR=".claude/state"
mkdir -p "$STATE_DIR"

# Retrieve previous state
PREV_STATE_FILE="${STATE_DIR}/plans-state.json"

# Count markers
count_markers() {
    local marker=$1
    local count=0
    if [ -f "$PLANS_FILE" ]; then
        count=$(grep -c "$marker" "$PLANS_FILE" 2>/dev/null || true)
        [ -z "$count" ] && count=0
    fi
    echo "$count"
}

# Get current state (English marker family is canonical; Japanese / cursor are read-compatible)
PM_PENDING=$(( $(count_markers "pm:requested") + $(count_markers "pm:依頼中") + $(count_markers "cursor:依頼中") ))
CC_TODO=$(( $(count_markers "cc:todo") + $(count_markers "cc:TODO") ))
CC_WIP=$(( $(count_markers "cc:wip") + $(count_markers "cc:WIP") ))
CC_DONE=$(( $(count_markers "cc:done") + $(count_markers "cc:完了") ))
PM_CONFIRMED=$(( $(count_markers "pm:approved") + $(count_markers "pm:確認済") + $(count_markers "cursor:確認済") ))

# Detect new tasks
NEW_TASKS=""
if [ -f "$PREV_STATE_FILE" ]; then
    PREV_PM_PENDING=$(jq -r '.pm_pending // 0' "$PREV_STATE_FILE" 2>/dev/null || echo "0")
    if [ "$PM_PENDING" -gt "$PREV_PM_PENDING" ] 2>/dev/null; then
        NEW_TASKS="pm:requested"
    fi
fi

# Detect completed tasks
COMPLETED_TASKS=""
if [ -f "$PREV_STATE_FILE" ]; then
    PREV_CC_DONE=$(jq -r '.cc_done // 0' "$PREV_STATE_FILE" 2>/dev/null || echo "0")
    if [ "$CC_DONE" -gt "$PREV_CC_DONE" ] 2>/dev/null; then
        COMPLETED_TASKS="cc:done"
    fi
fi

# Save state
cat > "$PREV_STATE_FILE" << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "pm_pending": $PM_PENDING,
  "cc_todo": $CC_TODO,
  "cc_wip": $CC_WIP,
  "cc_done": $CC_DONE,
  "pm_confirmed": $PM_CONFIRMED
}
EOF

# Generate notification
generate_notification() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Plans.md update detected"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ -n "$NEW_TASKS" ]; then
        echo "🆕 New task: PM requested work"
        echo "   → Check status with /sync-status, then start with /work"
    fi

    if [ -n "$COMPLETED_TASKS" ]; then
        echo "✅ Task done: ready to report to PM"
        echo "   → Report with /handoff-to-pm-claude or /handoff-to-cursor"
    fi

    echo ""
    echo "📊 Current status:"
    echo "   pm:requested   : $PM_PENDING (legacy: pm:依頼中 / cursor:依頼中)"
    echo "   cc:todo        : $CC_TODO (legacy: cc:TODO)"
    echo "   cc:wip         : $CC_WIP (legacy: cc:WIP)"
    echo "   cc:done        : $CC_DONE (legacy: cc:完了)"
    echo "   pm:approved    : $PM_CONFIRMED (legacy: pm:確認済 / cursor:確認済)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# Notify only if there are changes
if [ -n "$NEW_TASKS" ] || [ -n "$COMPLETED_TASKS" ]; then
    generate_notification
fi

# PM notification file for two-role operation
if [ -n "$NEW_TASKS" ] || [ -n "$COMPLETED_TASKS" ]; then
    PM_NOTIFICATION_FILE="${STATE_DIR}/pm-notification.md"
    CURSOR_NOTIFICATION_FILE="${STATE_DIR}/cursor-notification.md" # compat alias
    cat > "$PM_NOTIFICATION_FILE" << EOF
# PM Notification

**Generated at**: $(date +"%Y-%m-%d %H:%M:%S")

## Status Changes

EOF

    if [ -n "$NEW_TASKS" ]; then
        echo "### 🆕 New Task" >> "$PM_NOTIFICATION_FILE"
        echo "" >> "$PM_NOTIFICATION_FILE"
        echo "PM requested new work (${NEW_TASKS}; legacy input remains supported)." >> "$PM_NOTIFICATION_FILE"
        echo "" >> "$PM_NOTIFICATION_FILE"
    fi

    if [ -n "$COMPLETED_TASKS" ]; then
        echo "### ✅ Done Task" >> "$PM_NOTIFICATION_FILE"
        echo "" >> "$PM_NOTIFICATION_FILE"
        echo "Impl Claude completed a task. Please review it (${COMPLETED_TASKS})." >> "$PM_NOTIFICATION_FILE"
        echo "" >> "$PM_NOTIFICATION_FILE"
    fi

    echo "---" >> "$PM_NOTIFICATION_FILE"
    echo "" >> "$PM_NOTIFICATION_FILE"
    echo "**Next action**: Review in PM Claude, then request follow-up if needed (/handoff-to-impl-claude)." >> "$PM_NOTIFICATION_FILE"

    # Compat: also write same content to legacy filename
    cp -f "$PM_NOTIFICATION_FILE" "$CURSOR_NOTIFICATION_FILE" 2>/dev/null || true
fi
