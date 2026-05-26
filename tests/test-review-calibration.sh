#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cat > "${TMP_DIR}/calibration-input-1.json" <<'EOF'
{
  "verdict": "REQUEST_CHANGES",
  "reviewer_profile": "static",
  "calibration": {
    "label": "false_positive",
    "source": "manual",
    "notes": "Stopped a non-critical diff",
    "prompt_hint": "Keep as minor when there is no evidence",
    "few_shot_ready": true
  },
  "gaps": [
    {
      "severity": "major",
      "issue": "Stopped improvement suggestions excessively",
      "suggestion": "Treat as minor"
    }
  ]
}
EOF

cat > "${TMP_DIR}/calibration-input-2.json" <<'EOF'
{
  "verdict": "REQUEST_CHANGES",
  "reviewer_profile": "browser",
  "browser_mode": "exploratory",
  "route": "agent-browser",
  "execution_instructions": ["Use agent-browser snapshot."],
  "calibration": {
    "label": "missed_bug",
    "source": "retrospective",
    "notes": "Missed a UI layout issue",
    "prompt_hint": "Check screenshot diff first",
    "few_shot_ready": true
  },
  "gaps": [
    {
      "severity": "major",
      "issue": "Missed a screen layout issue",
      "suggestion": "Add browser snapshot"
    }
  ]
}
EOF

(cd "$TMP_DIR" && "${PROJECT_ROOT}/scripts/write-review-result.sh" "${TMP_DIR}/calibration-input-1.json" "" "${TMP_DIR}/result-1.json" >/dev/null)
(cd "$TMP_DIR" && "${PROJECT_ROOT}/scripts/write-review-result.sh" "${TMP_DIR}/calibration-input-2.json" "" "${TMP_DIR}/result-2.json" >/dev/null)

"${PROJECT_ROOT}/scripts/build-review-few-shot-bank.sh" "${TMP_DIR}/.claude/state/review-calibration.jsonl" "${TMP_DIR}/few-shot-bank.json" >/dev/null

jq -e '
  .schema_version == "review-few-shot-bank.v1" and
  (.entries | length) == 2 and
  ([.entries[].calibration_label] | sort) == ["false_positive", "missed_bug"] and
  ([.entries[].reviewer_profile] | sort) == ["browser", "static"] and
  ([.entries[].prompt_hint] | index("Check screenshot diff first")) != null
' "${TMP_DIR}/few-shot-bank.json" >/dev/null

echo "test-review-calibration: ok"
