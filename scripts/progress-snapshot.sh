#!/usr/bin/env bash
# scripts/progress-snapshot.sh
# Phase 65.4.1 - Plans.md → progress-snapshot.v1 JSON
#
# Purpose:
#   Extract the cc:todo / cc:wip / cc:done counts and lists from the Plans.md
#   task table and generate a snapshot JSON for the harness-progress skill.
#
# Usage:
#   progress-snapshot.sh --plans <path> --project <name> [--state-file <path>]
#
# Schema: progress-snapshot.v1 (skills/harness-progress/schemas/)
#
# Expected Plans.md format:
#   | <number> | <title> | <DoD> | <Depends> | <Status> |
#   Status is cc:todo / cc:wip / cc:done [hash] (legacy cc:TODO / cc:WIP / cc:完了 also readable)
#   pm:* markers are out of scope for this snapshot
#
# Optional: --state-file
#   Reads elapsed_minutes / cost_so_far_usd etc. from .claude/state/session-cost.json
#   (defaults to 0 for all fields if absent)

set -euo pipefail

usage() {
  cat <<'USAGE' >&2
Usage: progress-snapshot.sh --plans <path> --project <name> [--state-file <path>]

Required:
  --plans <path>       Plans.md file path
  --project <name>     Project name (basename of repo)

Optional:
  --state-file <path>  Session state JSON
                       Expected fields: elapsed_minutes / estimated_total_minutes /
                                        cost_so_far_usd / cost_estimate_usd
                       Falls back to 0 for all fields if absent

Exit: 0=success / 1=runtime error / 2=usage error
USAGE
  exit 2
}

PLANS_PATH=""
PROJECT=""
STATE_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --plans)      PLANS_PATH="${2:-}"; shift 2 ;;
    --project)    PROJECT="${2:-}"; shift 2 ;;
    --state-file) STATE_FILE="${2:-}"; shift 2 ;;
    -h|--help)    usage ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage ;;
  esac
done

if [[ -z "$PLANS_PATH" || -z "$PROJECT" ]]; then
  echo "ERROR: --plans and --project are required" >&2
  usage
fi

if [[ ! -f "$PLANS_PATH" ]]; then
  echo "ERROR: Plans.md not found: $PLANS_PATH" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required" >&2
  exit 1
fi

# state defaults
ELAPSED_MIN=0
ESTIMATE_MIN=0
COST_SO_FAR=0
COST_ESTIMATE=0

if [[ -n "$STATE_FILE" && -f "$STATE_FILE" ]]; then
  ELAPSED_MIN="$(jq -r '.elapsed_minutes // 0' "$STATE_FILE" 2>/dev/null || echo 0)"
  ESTIMATE_MIN="$(jq -r '.estimated_total_minutes // 0' "$STATE_FILE" 2>/dev/null || echo 0)"
  COST_SO_FAR="$(jq -r '.cost_so_far_usd // 0' "$STATE_FILE" 2>/dev/null || echo 0)"
  COST_ESTIMATE="$(jq -r '.cost_estimate_usd // 0' "$STATE_FILE" 2>/dev/null || echo 0)"
fi

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

export PLANS_PATH_PY="$PLANS_PATH"
export PROJECT_PY="$PROJECT"
export TIMESTAMP_PY="$TIMESTAMP"
export ELAPSED_MIN_PY="$ELAPSED_MIN"
export ESTIMATE_MIN_PY="$ESTIMATE_MIN"
export COST_SO_FAR_PY="$COST_SO_FAR"
export COST_ESTIMATE_PY="$COST_ESTIMATE"

exec python3 - <<'PYEOF'
import os
import re
import json
import sys

PLANS_PATH = os.environ["PLANS_PATH_PY"]
PROJECT = os.environ["PROJECT_PY"]
TIMESTAMP = os.environ["TIMESTAMP_PY"]
ELAPSED_MIN = int(os.environ["ELAPSED_MIN_PY"] or 0)
ESTIMATE_MIN = int(os.environ["ESTIMATE_MIN_PY"] or 0)

def to_float(s):
    try:
        return float(s)
    except (TypeError, ValueError):
        return 0.0

COST_SO_FAR = to_float(os.environ["COST_SO_FAR_PY"])
COST_ESTIMATE = to_float(os.environ["COST_ESTIMATE_PY"])

# Parse task rows from Plans.md:
#   "| 65.4.1 | <title> | <DoD> | <Depends> | cc:todo |"
#   "| 65.4.1 | <title> | <DoD> | <Depends> | cc:done [a1b2c3d] |"
# Use everything up to the first `。` as a one-line summary for title

ROW_RE = re.compile(
    r"^\|\s*(\d+(?:\.\d+)*)\s*\|\s*(.+?)\s*\|\s*.+?\s*\|\s*.+?\s*\|\s*(cc:\S+(?:\s*\[[a-f0-9]+\])?)\s*\|\s*$"
)

todo = []
wip = []
done = []

with open(PLANS_PATH, "r", encoding="utf-8") as f:
    for line in f:
        m = ROW_RE.match(line)
        if not m:
            continue
        number, title, status = m.group(1), m.group(2), m.group(3)
        # Shorten title: cut at the first "。", otherwise limit to 80 characters
        short_title = title.split("。")[0]
        if len(short_title) > 80:
            short_title = short_title[:77] + "..."

        if status in ("cc:todo", "cc:TODO"):
            todo.append({"number": number, "title": short_title})
        elif status in ("cc:wip", "cc:WIP"):
            wip.append({"number": number, "title": short_title})
        elif status.startswith("cc:done") or status.startswith("cc:完了"):
            commit_match = re.search(r"\[([a-f0-9]+)\]", status)
            commit = commit_match.group(1)[:7] if commit_match else ""
            done.append({"number": number, "title": short_title, "commit": commit})

total = len(todo) + len(wip) + len(done)
if total == 0:
    progress_pct = 0
else:
    progress_pct = round(len(done) * 100 / total)

current_task = wip[0]["title"] if wip else ""

# Derived helpers (for render-html.sh section expansion)
done_recent = done[-5:][::-1]  # Latest 5 items, newest first

snapshot = {
    "schema": "progress-snapshot.v1",
    "project": PROJECT,
    "current_task": current_task,
    "progress_pct": progress_pct,
    "todo_tasks": todo,
    "wip_tasks": wip,
    "done_tasks": done,
    "elapsed_minutes": ELAPSED_MIN,
    "estimated_total_minutes": ESTIMATE_MIN,
    "cost_so_far_usd": COST_SO_FAR,
    "cost_estimate_usd": COST_ESTIMATE,
    "alerts": [],
    "generated_at": TIMESTAMP,
    "_done_recent_items": done_recent,
    "_todo_count": len(todo),
    "_wip_count": len(wip),
    "_done_count": len(done),
}

print(json.dumps(snapshot, ensure_ascii=False, indent=2))
PYEOF
