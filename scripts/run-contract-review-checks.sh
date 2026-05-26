#!/bin/bash
# run-contract-review-checks.sh
# Execute the runtime_validation steps defined in sprint-contract.json in order,
# and save the results as a review artifact.

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 2
fi

CONTRACT_FILE="${1:-}"
OUTPUT_FILE="${2:-}"

if [ -z "$CONTRACT_FILE" ]; then
  echo "Usage: scripts/run-contract-review-checks.sh <contract-file> [output-file]" >&2
  exit 1
fi

if [ ! -f "$CONTRACT_FILE" ]; then
  echo "Contract file not found: $CONTRACT_FILE" >&2
  exit 3
fi

PROFILE="$(jq -r '.review.reviewer_profile // "static"' "$CONTRACT_FILE")"
TASK_ID="$(jq -r '.task.id // "unknown"' "$CONTRACT_FILE")"
TASK_TITLE="$(jq -r '.task.title // ""' "$CONTRACT_FILE")"
# Output as absolute path (so the Lead can resolve it even when called from a worktree)
STATE_DIR="$(pwd)/.claude/state/review"
mkdir -p "$STATE_DIR"

if [ -z "$OUTPUT_FILE" ]; then
  OUTPUT_FILE="${STATE_DIR}/${TASK_ID}.runtime-review.json"
fi

if [ "$PROFILE" = "static" ]; then
  jq -n \
    --arg profile "$PROFILE" \
    --arg task_id "$TASK_ID" \
    --arg task_title "$TASK_TITLE" \
    --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
      schema_version: "runtime-review.v1",
      generated_at: $generated_at,
      task: { id: $task_id, title: $task_title },
      reviewer_profile: $profile,
      verdict: "SKIPPED",
      note: "static profile does not execute runtime commands",
      checks: []
    }' > "$OUTPUT_FILE"
  echo "$OUTPUT_FILE"
  exit 0
fi

if [ "$PROFILE" = "browser" ]; then
  BROWSER_ARTIFACT_FILE="${STATE_DIR}/${TASK_ID}.browser-review.json"
  BROWSER_RESULT_FILE="${STATE_DIR}/${TASK_ID}.browser-result.json"
  browser_artifact="$(
    "$(dirname "$0")/generate-browser-review-artifact.sh" "$CONTRACT_FILE" "$BROWSER_ARTIFACT_FILE"
  )"
  browser_result="$(
    "$(dirname "$0")/browser-review-runner.sh" "$browser_artifact" "$BROWSER_RESULT_FILE"
  )"
  browser_verdict="$(jq -r '.browser_verdict // .verdict // "PENDING_BROWSER"' "$browser_result")"
  checks_json="$(jq -c '.checks // []' "$browser_artifact")"

  case "$browser_verdict" in
    APPROVE|REQUEST_CHANGES)
      verdict="$browser_verdict"
      ;;
    *)
      browser_verdict="PENDING_BROWSER"
      verdict="PENDING_BROWSER"
      ;;
  esac

  jq -n \
    --arg profile "$PROFILE" \
    --arg task_id "$TASK_ID" \
    --arg task_title "$TASK_TITLE" \
    --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg verdict "$verdict" \
    --arg browser_verdict "$browser_verdict" \
    --arg browser_artifact "$browser_artifact" \
    --arg browser_result "$browser_result" \
    --argjson checks "$checks_json" \
    '{
      schema_version: "runtime-review.v1",
      generated_at: $generated_at,
      task: { id: $task_id, title: $task_title },
      reviewer_profile: $profile,
      verdict: $verdict,
      browser_verdict: $browser_verdict,
      browser_artifact_path: $browser_artifact,
      browser_result_path: $browser_result,
      note: "browser profile uses the browser review runner; browser_verdict is combined downstream",
      checks: $checks
    }' > "$OUTPUT_FILE"
  echo "$OUTPUT_FILE"
  exit 0
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
CHECKS_FILE="$TMP_DIR/checks.jsonl"
FAILED=0

while IFS= read -r item; do
  label="$(printf '%s' "$item" | jq -r '.label // "unnamed-check"')"
  command="$(printf '%s' "$item" | jq -r '.command // empty')"
  if [ -z "$command" ]; then
    jq -nc --arg label "$label" '{"label":$label,"status":"skipped","reason":"empty command"}' >> "$CHECKS_FILE"
    continue
  fi

  set +e
  output="$(bash -lc "$command" 2>&1)"
  exit_code=$?
  set -e

  if [ $exit_code -ne 0 ]; then
    FAILED=1
    status="failed"
  else
    status="passed"
  fi

  jq -nc \
    --arg label "$label" \
    --arg command "$command" \
    --arg status "$status" \
    --arg output "$output" \
    --argjson exit_code "$exit_code" \
    '{label:$label,command:$command,status:$status,exit_code:$exit_code,output:$output}' >> "$CHECKS_FILE"
done < <(jq -c '.contract.runtime_validation[]? // empty' "$CONTRACT_FILE")

if [ -f "$CHECKS_FILE" ]; then
  checks_json="$(jq -s '.' "$CHECKS_FILE")"
else
  checks_json='[]'
fi

# When runtime_validation is empty, indicate downgrade to the static profile.
# Rather than returning APPROVE/REQUEST_CHANGES with no checks run,
# return DOWNGRADE_TO_STATIC so the caller can switch profiles.
RAN_CHECKS="$(echo "$checks_json" | jq 'length')"
if [ "$RAN_CHECKS" -eq 0 ]; then
  verdict="DOWNGRADE_TO_STATIC"
  checks_json='[{"label":"no-runtime-checks","status":"skipped","reason":"runtime_validation is empty — fallback to static review"}]'
elif [ "$FAILED" -ne 0 ]; then
  verdict="REQUEST_CHANGES"
else
  verdict="APPROVE"
fi

jq -n \
  --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg task_id "$TASK_ID" \
  --arg task_title "$TASK_TITLE" \
  --arg profile "$PROFILE" \
  --arg verdict "$verdict" \
  --argjson checks "$checks_json" \
  '{
    schema_version: "runtime-review.v1",
    generated_at: $generated_at,
    task: { id: $task_id, title: $task_title },
    reviewer_profile: $profile,
    verdict: $verdict,
    checks: $checks
  }' > "$OUTPUT_FILE"

echo "$OUTPUT_FILE"
