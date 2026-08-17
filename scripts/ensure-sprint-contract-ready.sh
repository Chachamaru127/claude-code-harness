#!/bin/bash
# ensure-sprint-contract-ready.sh
# Worker 着手前に sprint-contract が approved か確認する。

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

# risk_flags → reviewer_profile 最低要求の再計算 (enrich-sprint-contract.sh --risk と同一テーブル)。
# 強さ順は static<runtime<browser<ui-rubric。対象外の flag は最低要求に影響しない。
required_profile_for_risk() {
  case "$1" in
    security-sensitive) echo "runtime" ;;
    data-migration) echo "runtime" ;;
    ux-regression) echo "browser" ;;
    *) echo "" ;;
  esac
}

profile_rank() {
  case "$1" in
    static) echo 0 ;;
    runtime) echo 1 ;;
    browser) echo 2 ;;
    ui-rubric) echo 3 ;;
    *) echo 0 ;;
  esac
}

if ! jq -e '(.review.reviewer_notes // []) | any(startswith("profile-override-reason: "))' "$CONTRACT_FILE" >/dev/null 2>&1; then
  MIN_PROFILE="static"
  MIN_RANK=0
  while IFS= read -r flag; do
    [ -z "$flag" ] && continue
    required="$(required_profile_for_risk "$flag")"
    [ -z "$required" ] && continue
    required_rank="$(profile_rank "$required")"
    if [ "$required_rank" -gt "$MIN_RANK" ]; then
      MIN_RANK="$required_rank"
      MIN_PROFILE="$required"
    fi
  done < <(jq -r '.contract.risk_flags[]? // empty' "$CONTRACT_FILE")

  if [ "$(profile_rank "$PROFILE")" -lt "$MIN_RANK" ]; then
    TASK_ID="$(jq -r '.task.id // "unknown"' "$CONTRACT_FILE")"
    echo "Sprint contract profile below risk-flag minimum: task=${TASK_ID} profile=${PROFILE} required=${MIN_PROFILE}" >&2
    exit 5
  fi
fi

echo "$CONTRACT_FILE"
