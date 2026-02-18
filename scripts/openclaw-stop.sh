#!/bin/bash
# OpenClaw daemon stop script

set -euo pipefail

PID_FILE="/tmp/openclaw-daemon.pid"

if [ ! -f "$PID_FILE" ]; then
  echo "[openclaw] Daemon not running (no PID file)"
  exit 0
fi

PID="$(cat "$PID_FILE")"

if kill -0 "$PID" 2>/dev/null; then
  echo "[openclaw] Stopping daemon (PID: $PID)..."
  kill "$PID"

  # Wait for graceful shutdown (max 10s)
  for i in $(seq 1 10); do
    if ! kill -0 "$PID" 2>/dev/null; then
      break
    fi
    sleep 1
  done

  # Force kill if still running
  if kill -0 "$PID" 2>/dev/null; then
    echo "[openclaw] Force killing daemon..."
    kill -9 "$PID" 2>/dev/null || true
  fi

  echo "[openclaw] Daemon stopped"
else
  echo "[openclaw] Daemon not running (stale PID file)"
fi

rm -f "$PID_FILE"
