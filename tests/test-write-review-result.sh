#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cat > "${TMP_DIR}/input.json" <<'EOF'
{
  "verdict": "APPROVE",
  "reviewer_profile": "runtime",
  "task": {
    "id": "32.0.2",
    "title": "Unify review artifacts"
  },
  "critical_issues": [],
  "major_issues": [],
  "recommendations": ["keep watching browser flow"]
}
EOF

(cd "$TMP_DIR" && "${PROJECT_ROOT}/scripts/write-review-result.sh" "${TMP_DIR}/input.json" "abc1234" "${TMP_DIR}/review-result.json" >/dev/null)

jq -e '
  .schema_version == "review-result.v1" and
  .verdict == "APPROVE" and
  .reviewer_profile == "runtime" and
  .task.id == "32.0.2" and
  .commit_hash == "abc1234" and
  (.followups | length) == 1
' "${TMP_DIR}/review-result.json" >/dev/null

jq -e '
  .judgment == "APPROVE" and
  .commit_hash == "abc1234"
' "${TMP_DIR}/.claude/state/review-approved.json" >/dev/null

cat > "${TMP_DIR}/browser-input.json" <<'EOF'
{
  "verdict": "APPROVE",
  "reviewer_profile": "browser",
  "browser_mode": "exploratory",
  "route": "playwright",
  "tool_matcher": "mcp__playwright__*",
  "required_artifacts": ["screenshot", "ui-flow-log"],
  "execution_instructions": [
    "Use Playwright MCP.",
    "Capture screenshot."
  ],
  "checks": [
    {
      "id": "browser-smoke",
      "description": "Verify the main UI flow"
    }
  ]
}
EOF

cat > "${TMP_DIR}/browser-result.json" <<'EOF'
{
  "browser_verdict": "APPROVE",
  "runner_status": "ok",
  "note": "browser review command completed"
}
EOF

(cd "$TMP_DIR" && "${PROJECT_ROOT}/scripts/write-review-result.sh" "${TMP_DIR}/browser-input.json" "" "${TMP_DIR}/browser-review-result.json" --browser-result "${TMP_DIR}/browser-result.json" >/dev/null)

jq -e '
  .verdict == "APPROVE" and
  .browser_verdict == "APPROVE" and
  .reviewer_profile == "browser" and
  .execution.route == "playwright" and
  .execution.mode == "exploratory" and
  .execution.browser_mode == "exploratory" and
  (.execution.required_artifacts | length) == 2 and
  (.execution.instructions | length) == 2 and
  (.checks | length) == 1
' "${TMP_DIR}/browser-review-result.json" >/dev/null

cat > "${TMP_DIR}/browser-request-input.json" <<'EOF'
{
  "verdict": "APPROVE",
  "reviewer_profile": "browser",
  "browser_mode": "exploratory",
  "route": "playwright"
}
EOF

cat > "${TMP_DIR}/browser-request-result.json" <<'EOF'
{
  "browser_verdict": "REQUEST_CHANGES",
  "runner_status": "ok",
  "note": "browser review found an issue"
}
EOF

(cd "$TMP_DIR" && "${PROJECT_ROOT}/scripts/write-review-result.sh" "${TMP_DIR}/browser-request-input.json" "" "${TMP_DIR}/browser-request-review-result.json" --browser-result "${TMP_DIR}/browser-request-result.json" >/dev/null)

jq -e '
  .verdict == "REQUEST_CHANGES" and
  .browser_verdict == "REQUEST_CHANGES" and
  .reviewer_profile == "browser"
' "${TMP_DIR}/browser-request-review-result.json" >/dev/null

cat > "${TMP_DIR}/calibration-input.json" <<'EOF'
{
  "verdict": "REQUEST_CHANGES",
  "reviewer_profile": "static",
  "calibration": {
    "label": "false_negative",
    "source": "post-review",
    "notes": "Caught a missed major issue later",
    "prompt_hint": "Verify the basis for major findings in the diff",
    "few_shot_ready": true
  },
  "gaps": [
    {
      "severity": "major",
      "issue": "Key diff review was missing",
      "suggestion": "Re-check the diff"
    }
  ],
  "followups": ["Revisit reviewer prompt"]
}
EOF

(cd "$TMP_DIR" && "${PROJECT_ROOT}/scripts/write-review-result.sh" "${TMP_DIR}/calibration-input.json" "" "${TMP_DIR}/calibration-review-result.json" >/dev/null)

jq -e '
  .calibration.label == "false_negative" and
  .calibration.source == "post-review" and
  .calibration.few_shot_ready == true
' "${TMP_DIR}/calibration-review-result.json" >/dev/null

CALIBRATION_LINES="$(wc -l < "${TMP_DIR}/.claude/state/review-calibration.jsonl" | tr -d ' ')"
if [ "$CALIBRATION_LINES" -lt 1 ]; then
  echo "expected calibration log to be written"
  exit 1
fi

jq -e '
  .schema_version == "review-few-shot-bank.v1" and
  (.entries | length) >= 1 and
  .entries[0].calibration_label == "false_negative"
' "${TMP_DIR}/.claude/state/review-few-shot-bank.json" >/dev/null

echo "test-write-review-result: ok"
