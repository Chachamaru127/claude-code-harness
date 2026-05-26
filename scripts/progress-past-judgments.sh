#!/usr/bin/env bash
# scripts/progress-past-judgments.sh
# Phase 65.4.4 - Progress Tracker "past judgment patterns" read side
#
# Purpose:
#   Aggregate past judgment history by alert kind and current project name,
#   and output JSON such as "out of N past cases, M rejected the same suggestion".
#
# Usage:
#   progress-past-judgments.sh \
#     --alert-kind <kind> \
#     --project <name> \
#     --records-file <jsonl-path>      # for mocking / MCP search results via skill
#     [--cross-project-group <name>]   # default OFF (same flag mechanism as Phase 65.3.5)
#
# Input record format (JSONL of alert-judgment.v1):
#   {"data": {
#      "alert_kind": "scope-creep"|"time-overrun"|...,
#      "decision":   "follow_suggestion"|"reject_suggestion"|"ignore",
#      "timestamp":  ISO8601,
#      "reasoning":  string,
#      "project":    string
#   }}
#
# Output schema:
#   {
#     alert_kind:         <string>,
#     project:            <string>,
#     cross_project_used: <bool>,
#     total_count:        <int>,
#     rejected_count:     <int>,    # decision == "reject_suggestion"
#     rejection_rate_pct: <int>,    # 0-100
#     top_3_judgments:    [{decision, reasoning, timestamp}, ...]
#   }
#
# Default behavior (cross-project default OFF):
#   --cross-project-group absent → filter records-file records by project before aggregation
#   --cross-project-group present → disable project filter (aggregate all records)
#
# Exit code: 0=success / 1=runtime error / 2=usage error

set -euo pipefail

usage() {
  cat <<'USAGE' >&2
Usage: progress-past-judgments.sh \
  --alert-kind <kind> \
  --project <name> \
  --records-file <jsonl-path> \
  [--cross-project-group <name>]

Required:
  --alert-kind <kind>        scope-creep|time-overrun|repeated-failure|cost-warning|high-risk-file
  --project <name>           Current project name
  --records-file <path>      Mock input (JSONL of alert-judgment.v1)
                              Normally passed as MCP search results via skill

Optional:
  --cross-project-group <name>  default OFF (current project only)
                                 When specified, disables project filter and aggregates all records

Exit: 0=success / 1=runtime error / 2=usage error
USAGE
  exit 2
}

ALERT_KIND=""
PROJECT=""
RECORDS_FILE=""
CROSS_GROUP=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --alert-kind)            ALERT_KIND="${2:-}"; shift 2 ;;
    --project)               PROJECT="${2:-}"; shift 2 ;;
    --records-file)          RECORDS_FILE="${2:-}"; shift 2 ;;
    --cross-project-group)   CROSS_GROUP="${2:-}"; shift 2 ;;
    -h|--help)               usage ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage ;;
  esac
done

if [[ -z "$ALERT_KIND" || -z "$PROJECT" || -z "$RECORDS_FILE" ]]; then
  echo "ERROR: --alert-kind, --project, --records-file are required" >&2
  usage
fi

# Validate alert-kind enumeration value
case "$ALERT_KIND" in
  scope-creep|time-overrun|repeated-failure|cost-warning|high-risk-file) ;;
  *)
    echo "ERROR: --alert-kind must be one of: scope-creep|time-overrun|repeated-failure|cost-warning|high-risk-file (got: $ALERT_KIND)" >&2
    exit 2
    ;;
esac

if [[ ! -f "$RECORDS_FILE" ]]; then
  echo "ERROR: records-file not found: $RECORDS_FILE" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required" >&2
  exit 1
fi

CROSS_USED="false"
if [[ -n "$CROSS_GROUP" ]]; then
  CROSS_USED="true"
fi

# Filter JSONL line by line with jq
# - alert_kind matches
# - if cross-project OFF, project also matches
# - decision is one of: follow_suggestion / reject_suggestion / ignore

if [[ "$CROSS_USED" == "true" ]]; then
  # cross-project ON: disable project filter
  FILTERED="$(jq -c --arg ak "$ALERT_KIND" '
    select(.data.alert_kind == $ak)
  ' "$RECORDS_FILE" 2>/dev/null || true)"
else
  # default: match project only
  FILTERED="$(jq -c --arg ak "$ALERT_KIND" --arg proj "$PROJECT" '
    select(.data.alert_kind == $ak and .data.project == $proj)
  ' "$RECORDS_FILE" 2>/dev/null || true)"
fi

# Aggregate
TOTAL=0
REJECTED=0
TOP_3="[]"

if [[ -n "$FILTERED" ]]; then
  # Count records (grep -c exits 1 when there are 0 matches and outputs "0".
  # Adding `|| echo 0` would produce "0\n0", so use `|| true` to suppress the exit code)
  TOTAL=$(printf '%s\n' "$FILTERED" | grep -c '^{' || true)
  REJECTED=$(printf '%s\n' "$FILTERED" | jq -c 'select(.data.decision == "reject_suggestion")' 2>/dev/null | grep -c '^{' || true)
  # Guard against non-numeric values
  [[ "$TOTAL" =~ ^[0-9]+$ ]] || TOTAL=0
  [[ "$REJECTED" =~ ^[0-9]+$ ]] || REJECTED=0

  # top 3 (descending by timestamp = newest first)
  TOP_3=$(printf '%s\n' "$FILTERED" | jq -s -c '
    sort_by(.data.timestamp) | reverse | .[0:3] | map({
      decision:  .data.decision,
      reasoning: (.data.reasoning // ""),
      timestamp: .data.timestamp
    })
  ' 2>/dev/null || echo '[]')
fi

# Rejection rate %
RATE=0
if [[ "$TOTAL" -gt 0 ]]; then
  RATE=$(( REJECTED * 100 / TOTAL ))
fi

jq -n \
  --arg ak "$ALERT_KIND" \
  --arg proj "$PROJECT" \
  --argjson cross "$CROSS_USED" \
  --argjson total "$TOTAL" \
  --argjson rejected "$REJECTED" \
  --argjson rate "$RATE" \
  --argjson top3 "$TOP_3" \
  '{
    alert_kind:         $ak,
    project:            $proj,
    cross_project_used: $cross,
    total_count:        $total,
    rejected_count:     $rejected,
    rejection_rate_pct: $rate,
    top_3_judgments:    $top3
  }'

exit 0
