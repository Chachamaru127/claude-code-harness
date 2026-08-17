#!/bin/bash
# enrich-sprint-contract.sh
# sprint-contract.json に Reviewer 観点の追記を加え、必要なら承認状態にする。

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 2
fi

CONTRACT_FILE="${1:-}"
shift || true

if [ -z "$CONTRACT_FILE" ]; then
  echo "Usage: scripts/enrich-sprint-contract.sh <contract-file> [--check TEXT] [--non-goal TEXT] [--runtime CMD] [--risk FLAG] [--note TEXT] [--profile PROFILE] [--profile-override-reason TEXT] [--route ROUTE] [--approve]" >&2
  exit 1
fi

# risk_flags → reviewer_profile 自動昇格テーブル。強さ順は static<runtime<browser<ui-rubric。
# 対象外の flag (例: perf-sensitive) は昇格させない。
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

has_profile_override_reason() {
  jq -e '(.review.reviewer_notes // []) | any(startswith("profile-override-reason: "))' "$TMP_FILE" >/dev/null 2>&1
}

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
      RISK_FLAG="${1:-}"
      append_json_array '.contract.risk_flags' "$(jq -nc --arg flag "$RISK_FLAG" '$flag')"
      REQUIRED_PROFILE="$(required_profile_for_risk "$RISK_FLAG")"
      if [ -n "$REQUIRED_PROFILE" ] && ! has_profile_override_reason; then
        CURRENT_PROFILE="$(jq -r '.review.reviewer_profile // "static"' "$TMP_FILE")"
        if [ "$(profile_rank "$CURRENT_PROFILE")" -lt "$(profile_rank "$REQUIRED_PROFILE")" ]; then
          tmp_next="$(mktemp)"
          jq --arg profile "$REQUIRED_PROFILE" '.review.reviewer_profile = $profile' "$TMP_FILE" > "$tmp_next"
          mv "$tmp_next" "$TMP_FILE"
        fi
      fi
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
    --profile-override-reason)
      shift
      append_json_array '.review.reviewer_notes' "$(jq -nc --arg reason "${1:-}" '"profile-override-reason: " + $reason')"
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
