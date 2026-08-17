#!/usr/bin/env bash
# writing-rule-list.sh — list writing-rule proposals (Phase 135.4)
#
# Usage:
#   writing-rule-list.sh [--status pending|approved|rejected|all] [--json] [--proposals <path>]
#
# Default lists status=pending proposals in human-readable form, each with the
# copy-paste command to approve it. --json emits the same filtered set as a
# JSON array for machine consumers (e.g. the progress surface, Phase 136.2).
set -euo pipefail

DEFAULT_PROPOSALS="${HOME}/.claude/writing-lint/proposals.jsonl"

status_filter="pending"
json_out=false
proposals_path="${CLAUDE_WRITING_LINT_PROPOSALS:-$DEFAULT_PROPOSALS}"

usage() {
  cat <<'EOF'
Usage:
  writing-rule-list.sh [--status pending|approved|rejected|all] [--json] [--proposals <path>]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --status) status_filter="${2:-}"; shift 2 ;;
    --json) json_out=true; shift ;;
    --proposals) proposals_path="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "writing-rule-list.sh: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ ! -f "$proposals_path" ]]; then
  if [[ "$json_out" == true ]]; then
    echo "[]"
  fi
  exit 0
fi

python3 - "$proposals_path" "$status_filter" "$json_out" <<'PY'
import json
import sys

proposals_path, status_filter, json_out = sys.argv[1], sys.argv[2], sys.argv[3] == "true"

records = []
with open(proposals_path, encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            continue
        if status_filter != "all" and rec.get("status") != status_filter:
            continue
        records.append(rec)

if json_out:
    print(json.dumps(records, ensure_ascii=False))
else:
    if not records:
        print(f"no {status_filter} proposals")
    for rec in records:
        rid = rec.get("id", "?")
        pattern = rec.get("pattern", "")
        good = rec.get("good", "")
        print(f"{rid}  pattern={pattern!r}  good={good!r}")
        print(f"  approve: scripts/writing-rule-approve.sh --id {rid}")
PY
