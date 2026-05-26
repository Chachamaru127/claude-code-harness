#!/usr/bin/env bash
#
# progress-snapshot.sh
# Shared function that generates a summary of the latest snapshot from .claude/state/snapshots/progress-*.json
#

if [[ -n "${_PROGRESS_SNAPSHOT_LIB_LOADED:-}" ]]; then
  return 0
fi
_PROGRESS_SNAPSHOT_LIB_LOADED=1

progress_snapshot_summary() {
  local state_dir="$1"
  local snapshot_dir="${state_dir}/snapshots"

  [ -d "${snapshot_dir}" ] || return 0
  command -v python3 >/dev/null 2>&1 || return 0

  python3 - "${snapshot_dir}" <<'PY'
import json
import sys
from pathlib import Path

snapshot_dir = Path(sys.argv[1])
files = sorted(snapshot_dir.glob("progress-*.json"))
if not files:
    sys.exit(0)

latest = json.loads(files[-1].read_text())
previous = json.loads(files[-2].read_text()) if len(files) > 1 else None

phase = latest.get("phase", "unknown")
ts = latest.get("timestamp", "unknown")
progress = latest.get("progress", {})
done = int(progress.get("done", 0) or 0)
wip = int(progress.get("wip", 0) or 0)
todo = int(progress.get("todo", 0) or 0)
rate = latest.get("progress_rate", 0)

lines = [
    f"💾 Latest snapshot: {ts} ({phase})",
    f"   Progress {rate}% / Done {done} / WIP {wip} / TODO {todo}",
]

if previous:
    prev_progress = previous.get("progress", {})
    prev_done = int(prev_progress.get("done", 0) or 0)
    prev_wip = int(prev_progress.get("wip", 0) or 0)
    prev_todo = int(prev_progress.get("todo", 0) or 0)
    prev_rate = int(previous.get("progress_rate", 0) or 0)
    lines.append(
        "   vs previous: "
        f"progress {rate - prev_rate:+d}%pt / done {done - prev_done:+d} / "
        f"WIP {wip - prev_wip:+d} / TODO {todo - prev_todo:+d}"
    )

print("\n".join(lines))
PY
}
