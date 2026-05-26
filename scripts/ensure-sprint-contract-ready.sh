#!/bin/bash
# ensure-sprint-contract-ready.sh
# Verifies that the sprint-contract is approved before the Worker starts work.

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 2
fi

CONTRACT_FILE="${1:-}"

if [ -z "$CONTRACT_FILE" ]; then
  echo "Usage: scripts/ensure-sprint-contract-ready.sh <contract-file>" >&2
  exit 1
fi

if [ ! -f "$CONTRACT_FILE" ]; then
  echo "Contract file not found: $CONTRACT_FILE" >&2
  exit 3
fi

STATUS="$(jq -r '.review.status // "draft"' "$CONTRACT_FILE")"
PROFILE="$(jq -r '.review.reviewer_profile // "static"' "$CONTRACT_FILE")"

if [ "$STATUS" != "approved" ]; then
  TASK_ID="$(jq -r '.task.id // "unknown"' "$CONTRACT_FILE")"
  echo "Sprint contract is not approved: task=${TASK_ID} status=${STATUS} profile=${PROFILE}" >&2
  exit 4
fi

echo "$CONTRACT_FILE"
