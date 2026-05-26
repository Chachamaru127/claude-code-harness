#!/bin/bash
# posttool-progress-regen.sh
# Phase 65.4.2 - Auto-regenerate Progress Tracker HTML via PostToolUse hook
#
# Trigger: Edit / Write / Bash fires (via PostToolUse hook)
# Rate limit: skip consecutive fires within 60 seconds
# Background: regeneration runs in the background (the hook itself returns immediately, does not block CC)
#
# Input:  stdin (JSON: PostToolUse hook payload)
# Output: stdout (JSON: {"ok": true} or {"ok": true, "skipped": "rate-limit"})
#
# State file: .claude/state/progress-last-regen.txt
#   (epoch seconds of last successful regen)
#
# Side effect: regenerates out/progress-snapshot.html

set +e  # Hook must not stop CC on errors

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${PARENT_DIR}/.." && pwd)"

# Detect project root (host project is the target when it is not CCH itself)
if declare -F detect_project_root > /dev/null 2>&1; then
  PROJECT_ROOT="${PROJECT_ROOT:-$(detect_project_root 2>/dev/null || pwd)}"
else
  PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
fi

STATE_FILE="${PROJECT_ROOT}/.claude/state/progress-last-regen.txt"
PLANS_FILE="${PROJECT_ROOT}/Plans.md"
OUT_HTML="${PROJECT_ROOT}/out/progress-snapshot.html"
SNAPSHOT_SCRIPT="${REPO_ROOT}/scripts/progress-snapshot.sh"
RENDER_SCRIPT="${REPO_ROOT}/scripts/render-html.sh"

RATE_LIMIT_SEC=60

# Do nothing if Plans.md does not exist
if [[ ! -f "$PLANS_FILE" ]]; then
  echo '{"ok":true,"skipped":"no-plans-md"}'
  exit 0
fi

# Discard stdin (hook payload is not used)
cat >/dev/null 2>&1

# rate limit check
NOW_EPOCH="$(date +%s)"
if [[ -f "$STATE_FILE" ]]; then
  LAST_EPOCH="$(cat "$STATE_FILE" 2>/dev/null || echo 0)"
  if ! [[ "$LAST_EPOCH" =~ ^[0-9]+$ ]]; then
    LAST_EPOCH=0
  fi
  ELAPSED=$((NOW_EPOCH - LAST_EPOCH))
  if [[ $ELAPSED -lt $RATE_LIMIT_SEC ]]; then
    echo "{\"ok\":true,\"skipped\":\"rate-limit\",\"elapsed_sec\":${ELAPSED}}"
    exit 0
  fi
fi

# Project name
PROJECT_NAME="$(basename "$(git -C "$PROJECT_ROOT" rev-parse --show-toplevel 2>/dev/null || echo "$PROJECT_ROOT")")"

# Ensure state directory exists
mkdir -p "${PROJECT_ROOT}/.claude/state" "${PROJECT_ROOT}/out" 2>/dev/null

# background regen (hook returns immediately)
(
  SNAP_TMP="$(mktemp /tmp/progress-snap-XXXX.json 2>/dev/null)"
  if bash "$SNAPSHOT_SCRIPT" --plans "$PLANS_FILE" --project "$PROJECT_NAME" > "$SNAP_TMP" 2>/dev/null; then
    if bash "$RENDER_SCRIPT" --template progress --data "$SNAP_TMP" --out "$OUT_HTML" >/dev/null 2>&1; then
      # Success: update state file
      echo "$NOW_EPOCH" > "$STATE_FILE"
    fi
  fi
  rm -f "$SNAP_TMP"
) &

echo '{"ok":true,"regenerated":true}'
exit 0
