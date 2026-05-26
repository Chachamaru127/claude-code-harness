#!/bin/bash
# scripts/plan-brief-record-decision.sh
# Phase 65.1.4 - Plan Brief decision recording (memory write side)
#
# Usage:
#   plan-brief-record-decision.sh --action <approve|revise|question> \
#       --user-request <text> --project <name> \
#       [--chosen-option <text>] [--rejected-options <csv>] \
#       [--reasoning <text>] [--out -|<path>]
#
# Role:
#   Records user decisions on Plan Briefs (approve / revise / question).
#   Outputs a payload JSON compliant with the `personal-preference.v1` schema.
#   The actual `mcp__harness__harness_mem_ingest` call is performed on the skill (LLM context)
#   side — this script only assembles the payload.
#
# Schema: personal-preference.v1
#   data: {
#     user_request_hash : sha256 hex (hashed request body; raw text is not stored)
#     chosen_option     : string  (option name selected on approve; "" otherwise)
#     rejected_options  : string[]
#     reasoning         : string  (reason for revise / question body for question)
#     timestamp         : ISO8601 (UTC, Z-terminated)
#     project           : string
#     action            : "approve" | "revise" | "question"
#   }
#
# Tags (fixed — DoD b):
#   ["personal-preference", "plan-brief-approval"]
#
# Output: ingest JSON to stdout (or to the file specified by --out)
# Exit code: 0=success, 2=usage error, 3=runtime error

set -euo pipefail

usage() {
  cat <<USAGE >&2
Usage: $0 --action <approve|revise|question> \
          --user-request <text> --project <name> \
          [--chosen-option <text>] [--rejected-options <csv>] \
          [--reasoning <text>] [--out -|<path>]

Required:
  --action <approve|revise|question>  User decision action type
  --user-request <text>               Original request that launched the Plan Brief
  --project <name>                    Project name (basename of toplevel)

Optional:
  --chosen-option <text>              Option name chosen on approve (default: "")
  --rejected-options <csv>            Rejected options separated by comma (default: "")
  --reasoning <text>                  Reason for revise / question body (default: "")
  --out -|<path>                      Output destination (- = stdout, default: stdout)

Output: harness_mem_ingest JSON compliant with personal-preference.v1 schema
USAGE
  exit 2
}

ACTION=""
USER_REQUEST=""
PROJECT=""
CHOSEN_OPTION=""
REJECTED_OPTIONS_CSV=""
REASONING=""
OUT="-"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --action)            ACTION="${2:-}";              shift 2 ;;
    --user-request)      USER_REQUEST="${2:-}";        shift 2 ;;
    --project)           PROJECT="${2:-}";             shift 2 ;;
    --chosen-option)     CHOSEN_OPTION="${2:-}";       shift 2 ;;
    --rejected-options)  REJECTED_OPTIONS_CSV="${2:-}";shift 2 ;;
    --reasoning)         REASONING="${2:-}";           shift 2 ;;
    --out)               OUT="${2:-}";                 shift 2 ;;
    -h|--help)           usage ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage ;;
  esac
done

# ---- required arguments ----

if [[ -z "$ACTION" || -z "$USER_REQUEST" || -z "$PROJECT" ]]; then
  echo "ERROR: --action, --user-request, --project are required" >&2
  usage
fi

case "$ACTION" in
  approve|revise|question) ;;
  *)
    echo "ERROR: --action must be one of: approve|revise|question (got: $ACTION)" >&2
    exit 2
    ;;
esac

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required but not found" >&2
  exit 3
fi

# ---- sha256 hex ----
# Hash the request via stdin. Supports both `shasum -a 256` (macOS) and `sha256sum` (Linux).

sha256_of_text() {
  local text="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$text" | sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    printf '%s' "$text" | shasum -a 256 | awk '{print $1}'
  else
    echo "ERROR: neither sha256sum nor shasum found" >&2
    exit 3
  fi
}

USER_REQUEST_HASH="$(sha256_of_text "$USER_REQUEST")"

# ---- convert rejected_options to array ----
# csv is split naively (no quoting). If an element needs to contain a comma, URL-encode it on the SKILL.md side before passing.

if [[ -z "$REJECTED_OPTIONS_CSV" ]]; then
  REJECTED_OPTIONS_JSON='[]'
else
  REJECTED_OPTIONS_JSON="$(printf '%s' "$REJECTED_OPTIONS_CSV" | awk -F',' '{
    printf "[";
    for (i = 1; i <= NF; i++) {
      gsub(/^[ \t]+|[ \t]+$/, "", $i);
      if (i > 1) printf ",";
      gsub(/"/, "\\\"", $i);
      printf "\"%s\"", $i;
    }
    printf "]";
  }')"
fi

# ---- timestamp ----


TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ---- assemble payload ----

PAYLOAD="$(jq -n \
  --arg hash "$USER_REQUEST_HASH" \
  --arg chosen "$CHOSEN_OPTION" \
  --argjson rejected "$REJECTED_OPTIONS_JSON" \
  --arg reasoning "$REASONING" \
  --arg ts "$TIMESTAMP" \
  --arg proj "$PROJECT" \
  --arg action "$ACTION" \
  '{
    schema: "personal-preference.v1",
    observation_type: "decision",
    tags: ["personal-preference", "plan-brief-approval"],
    project: $proj,
    data: {
      user_request_hash: $hash,
      chosen_option: $chosen,
      rejected_options: $rejected,
      reasoning: $reasoning,
      timestamp: $ts,
      project: $proj,
      action: $action
    }
  }')"

if [[ "$OUT" == "-" || -z "$OUT" ]]; then
  printf '%s\n' "$PAYLOAD"
else
  printf '%s\n' "$PAYLOAD" > "$OUT"
fi
