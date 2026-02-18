#!/bin/bash
# OpenClaw daemon start script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DAEMON_DIR="$SCRIPT_DIR/../openclaw/daemon"
PID_FILE="/tmp/openclaw-daemon.pid"

# Check if already running
if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "[openclaw] Daemon already running (PID: $(cat "$PID_FILE"))"
  exit 1
fi

# Check bun is available
if ! command -v bun &>/dev/null; then
  echo "[openclaw] Error: bun is not installed. Install from https://bun.sh"
  exit 1
fi

# Check daemon directory exists
if [ ! -f "$DAEMON_DIR/index.ts" ]; then
  echo "[openclaw] Error: Daemon not found at $DAEMON_DIR/index.ts"
  echo "[openclaw] Run '/openclaw setup' first."
  exit 1
fi

# Install dependencies if needed
if [ ! -d "$DAEMON_DIR/node_modules" ]; then
  echo "[openclaw] Installing dependencies..."
  (cd "$DAEMON_DIR" && bun install)
fi

# Start daemon in background
echo "[openclaw] Starting daemon..."
nohup bun run "$DAEMON_DIR/index.ts" >/dev/null 2>&1 &
DAEMON_PID=$!
echo "$DAEMON_PID" > "$PID_FILE"

# Verify it started
sleep 1
if kill -0 "$DAEMON_PID" 2>/dev/null; then
  echo "[openclaw] Daemon started successfully (PID: $DAEMON_PID)"
else
  echo "[openclaw] Error: Daemon failed to start. Check logs at .claude/logs/openclaw-daemon.log"
  rm -f "$PID_FILE"
  exit 1
fi
