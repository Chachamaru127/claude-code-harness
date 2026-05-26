#!/bin/bash
# worktree-remove.sh — WorktreeRemove hook handler
# Cleans up worktree-specific resources when a Breezing sub-agent exits
#
# Input (stdin JSON):
#   session_id, cwd, hook_event_name
#
# Design: handles only worktree-specific temporary files;
#         session-wide cleanup is handled by SessionEnd

set -euo pipefail

# === Read JSON payload from stdin ===
INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

# Skip if payload is empty
if [ -z "${INPUT}" ]; then
  echo '{"decision":"approve","reason":"WorktreeRemove: no payload"}'
  exit 0
fi

# === Field extraction ===
SESSION_ID=""
CWD=""

if command -v jq >/dev/null 2>&1; then
  _jq_parsed="$(echo "${INPUT}" | jq -r '[
    (.session_id // ""),
    (.cwd // "")
  ] | @tsv' 2>/dev/null)"
  if [ -n "${_jq_parsed}" ]; then
    IFS=$'\t' read -r SESSION_ID CWD <<< "${_jq_parsed}"
  fi
  unset _jq_parsed
elif command -v python3 >/dev/null 2>&1; then
  _parsed="$(echo "${INPUT}" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('session_id', ''))
    print(d.get('cwd', ''))
except:
    print('')
    print('')
" 2>/dev/null)"
  SESSION_ID="$(echo "${_parsed}" | sed -n '1p')"
  CWD="$(echo "${_parsed}" | sed -n '2p')"
fi

if [ -z "${SESSION_ID}" ]; then
  echo '{"decision":"approve","reason":"WorktreeRemove: no session_id"}'
  exit 0
fi

# === Clean up worktree-specific temporary files ===

# Codex prompt temp files (session-specific ones take priority)
rm -f /tmp/codex-prompt-*.md 2>/dev/null || true

# Harness Codex logs (session-specific)
rm -f /tmp/harness-codex-*.log 2>/dev/null || true

# Clean up worktree-info.json
if [ -n "${CWD}" ] && [ -f "${CWD}/.claude/state/worktree-info.json" ]; then
  rm -f "${CWD}/.claude/state/worktree-info.json" 2>/dev/null || true
fi

# === Response ===
echo '{"decision":"approve","reason":"WorktreeRemove: cleaned up worktree resources"}'
exit 0
