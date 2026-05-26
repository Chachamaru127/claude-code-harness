#!/usr/bin/env bash
# scripts/cross-project-audit-log.sh
# Phase 65.3.6 - Cross-project search audit log append
#
# Purpose:
#   Appends 1 line to .claude/state/audit/cross-project-search.jsonl
#   whenever a cross-project search runs (append-only JSON Lines).
#   For privacy, only the sha256 hash of the query string is recorded,
#   not the raw query itself.
#
# Usage:
#   cross-project-audit-log.sh \
#     --group <name> \
#     --members <csv> \
#     --query-hash <sha256-hex> \
#     --dict-count <int> \
#     --ner-count <int> \
#     --passed-final-scan <true|false> \
#     [--out <jsonl-path>]
#
# Schema: cross-project-audit.v1
#   {
#     schema_version: "cross-project-audit.v1",
#     timestamp: <ISO8601 UTC>,
#     group_name: <string>,
#     member_projects: [<string>, ...],
#     query_hash: <sha256 hex 64 chars>,
#     redaction_count: {dict: <int>, ner: <int>},
#     output_passed_final_scan: <bool>
#   }
#
# Default --out: $REPO_ROOT/.claude/state/audit/cross-project-search.jsonl
#   (directory is created automatically if it does not exist)
#
# Exit code: 0=success, 2=usage error, 3=runtime error

set -euo pipefail

usage() {
  cat <<'USAGE' >&2
Usage:
  cross-project-audit-log.sh \
    --group <name> \
    --members <csv> \
    --query-hash <sha256-hex> \
    --dict-count <int> \
    --ner-count <int> \
    --passed-final-scan <true|false> \
    [--out <jsonl-path>]

Required:
  --group <name>             cross-project group name
  --members <csv>            comma-separated list of member project names (e.g. "p1,p2,p3")
  --query-hash <hex>         sha256 hash of the query string (raw query is not recorded)
  --dict-count <int>         number of dict-redaction hits
  --ner-count <int>          number of NER-redaction hits
  --passed-final-scan <bool> Layer 3 final scan: passed=true / failed=false

Optional:
  --out <jsonl-path>         output path (default: .claude/state/audit/cross-project-search.jsonl)

Exit code: 0=success / 2=usage error / 3=runtime error
USAGE
  exit 2
}

GROUP=""
MEMBERS_CSV=""
QUERY_HASH=""
DICT_COUNT=""
NER_COUNT=""
PASSED_FINAL_SCAN=""
OUT_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --group)              GROUP="${2:-}";              shift 2 ;;
    --members)            MEMBERS_CSV="${2:-}";        shift 2 ;;
    --query-hash)         QUERY_HASH="${2:-}";         shift 2 ;;
    --dict-count)         DICT_COUNT="${2:-}";         shift 2 ;;
    --ner-count)          NER_COUNT="${2:-}";          shift 2 ;;
    --passed-final-scan)  PASSED_FINAL_SCAN="${2:-}";  shift 2 ;;
    --out)                OUT_PATH="${2:-}";           shift 2 ;;
    -h|--help)            usage ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage ;;
  esac
done

# Required argument check
for var_name in GROUP MEMBERS_CSV QUERY_HASH DICT_COUNT NER_COUNT PASSED_FINAL_SCAN; do
  if [[ -z "${!var_name}" ]]; then
    echo "ERROR: --${var_name,,} is required (got empty)" >&2
    usage
  fi
done

# Validation
if ! [[ "$DICT_COUNT" =~ ^[0-9]+$ ]]; then
  echo "ERROR: --dict-count must be a non-negative integer (got: $DICT_COUNT)" >&2
  exit 2
fi
if ! [[ "$NER_COUNT" =~ ^[0-9]+$ ]]; then
  echo "ERROR: --ner-count must be a non-negative integer (got: $NER_COUNT)" >&2
  exit 2
fi
case "$PASSED_FINAL_SCAN" in
  true|false) ;;
  *) echo "ERROR: --passed-final-scan must be 'true' or 'false' (got: $PASSED_FINAL_SCAN)" >&2; exit 2 ;;
esac
# query_hash is expected to be 64-char hex
if ! [[ "$QUERY_HASH" =~ ^[0-9a-fA-F]{64}$ ]]; then
  echo "ERROR: --query-hash must be sha256 hex (64 chars, got length=${#QUERY_HASH})" >&2
  exit 2
fi

# default out path
if [[ -z "$OUT_PATH" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
  OUT_PATH="${REPO_ROOT}/.claude/state/audit/cross-project-search.jsonl"
fi

# Create parent directory
OUT_DIR="$(dirname "$OUT_PATH")"
mkdir -p "$OUT_DIR"

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required" >&2
  exit 3
fi

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# CSV → JSON array (empty string becomes [])
if [[ -z "$MEMBERS_CSV" ]]; then
  MEMBERS_JSON='[]'
else
  MEMBERS_JSON="$(printf '%s' "$MEMBERS_CSV" | awk -F',' '{
    printf "[";
    for (i=1; i<=NF; i++) {
      gsub(/^[ \t]+|[ \t]+$/, "", $i);
      if (i>1) printf ",";
      gsub(/"/, "\\\"", $i);
      printf "\"%s\"", $i;
    }
    printf "]";
  }')"
fi

# Build JSON line (compact, no newlines)
LINE="$(jq -n -c \
  --arg ts "$TIMESTAMP" \
  --arg group "$GROUP" \
  --argjson members "$MEMBERS_JSON" \
  --arg hash "$QUERY_HASH" \
  --argjson dict "$DICT_COUNT" \
  --argjson ner "$NER_COUNT" \
  --argjson passed "$PASSED_FINAL_SCAN" \
  '{
    schema_version: "cross-project-audit.v1",
    timestamp: $ts,
    group_name: $group,
    member_projects: $members,
    query_hash: $hash,
    redaction_count: {dict: $dict, ner: $ner},
    output_passed_final_scan: $passed
  }')"

# Append 1 line
printf '%s\n' "$LINE" >> "$OUT_PATH"

# Print audit summary to stderr
echo "audit logged: group=$GROUP, members=$(jq -r 'length' <<< "$MEMBERS_JSON") projects, dict=$DICT_COUNT, ner=$NER_COUNT, passed=$PASSED_FINAL_SCAN -> $OUT_PATH" >&2

exit 0
