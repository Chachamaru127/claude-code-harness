#!/bin/bash
# OpenClaw daemon status script

PID_FILE="/tmp/openclaw-daemon.pid"
LOG_FILE=".claude/logs/openclaw-daemon.log"

echo "=== OpenClaw Daemon Status ==="

# Check daemon process
if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  PID="$(cat "$PID_FILE")"
  echo "Status:  RUNNING"
  echo "PID:     $PID"

  # Show uptime if available
  if command -v ps &>/dev/null; then
    UPTIME=$(ps -p "$PID" -o etime= 2>/dev/null | xargs)
    [ -n "$UPTIME" ] && echo "Uptime:  $UPTIME"
  fi
else
  echo "Status:  STOPPED"
fi

# Show recent logs
echo ""
echo "=== Recent Logs ==="
if [ -f "$LOG_FILE" ]; then
  tail -5 "$LOG_FILE" 2>/dev/null || echo "(no recent logs)"
else
  echo "(no log file found)"
fi
