#!/bin/bash
# enrich-sprint-contract.sh
# Adds Reviewer perspective annotations to sprint-contract.json and optionally sets it to approved status.

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 2
fi

CONTRACT_FILE="${1:-}"
shift || true

if [ -z "$CONTRACT_FILE" ]; then
  echo "Usage: scripts/enrich-sprint-contract.sh <contract-file> [--check TEXT] [--non-goal TEXT] [--runtime CMD] [--risk FLAG] [--note TEXT] [--profile PROFILE] [--route ROUTE] [--approve]" >&2
  exit 1
fi

if [ ! -f "$CONTRACT_FILE" ]; then
  echo "Contract file not found: $CONTRACT_FILE" >&2
  exit 3
fi

TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT
cp "$CONTRACT_FILE" "$TMP_FILE"

append_json_array() {
  local jq_path="$1"
  local payload="$2"
  local tmp_next
  tmp_next="$(mktemp)"
  jq --argjson payload "$payload" "${jq_path} += [\$payload]" "$TMP_FILE" > "$tmp_next"
  mv "$tmp_next" "$TMP_FILE"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check)
      shift
      append_json_array '.contract.checks' "$(jq -nc --arg desc "${1:-}" '{id:"reviewer-check",source:"reviewer",description:$desc}')"
      ;;
    --non-goal)
      shift
      append_json_array '.contract.non_goals' "$(jq -nc --arg desc "${1:-}" '{description:$desc}')"
      ;;
    --runtime)
      shift
      append_json_array '.contract.runtime_validation' "$(jq -nc --arg cmd "${1:-}" '{label:"reviewer-runtime",command:$cmd}')"
      ;;
    --risk)
      shift
      append_json_array '.contract.risk_flags' "$(jq -nc --arg flag "${1:-}" '$flag')"
      ;;
    --note)
      shift
      append_json_array '.review.reviewer_notes' "$(jq -nc --arg note "${1:-}" '$note')"
      ;;
    --profile)
      shift
      tmp_next="$(mktemp)"
      jq --arg profile "${1:-static}" '.review.reviewer_profile = $profile' "$TMP_FILE" > "$tmp_next"
      mv "$tmp_next" "$TMP_FILE"
      ;;
    --route)
      shift
      tmp_next="$(mktemp)"
      jq --arg route "${1:-}" '.review.route = $route' "$TMP_FILE" > "$tmp_next"
      mv "$tmp_next" "$TMP_FILE"
      ;;
    --approve)
      tmp_next="$(mktemp)"
      jq --arg approved_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.review.status = "approved" | .review.approved_at = $approved_at' "$TMP_FILE" > "$tmp_next"
      mv "$tmp_next" "$TMP_FILE"
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 4
      ;;
  esac
  shift || true
done

mv "$TMP_FILE" "$CONTRACT_FILE"
trap - EXIT
echo "$CONTRACT_FILE"
