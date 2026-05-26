#!/bin/bash
# test-harness-loop-flow.sh
# Regression test for contract_path / reviewer_profile / advisor routing in harness-loop flow.md
# Phase 1.5: SCRIPT_PATH_SURFACES restricted to active skills/ (codex/opencode archived)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
FLOW_FILE="${PROJECT_ROOT}/skills/harness-loop/references/flow.md"
SCRIPT_PATH_SURFACES=(
  "${PROJECT_ROOT}/skills/harness-work/SKILL.md"
  "${PROJECT_ROOT}/skills/harness-loop/SKILL.md"
  "${PROJECT_ROOT}/skills/breezing/SKILL.md"
)

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[ -f "${FLOW_FILE}" ] || fail "flow.md not found"

grep -q 'CONTRACT_PATH=".claude/state/contracts/${task_id}.sprint-contract.json"' "${FLOW_FILE}" \
  || fail "Step 2 is missing CONTRACT_PATH initialization"

if grep -q 'task_contract_path' "${FLOW_FILE}"; then
  fail "flow.md still contains removed task_contract_path reference"
fi

grep -q 'REVIEWER_PROFILE=$(jq -r '\''\.review\.reviewer_profile // "static"'\'' "${CONTRACT_PATH}"' "${FLOW_FILE}" \
  || fail "reviewer_profile read does not reference CONTRACT_PATH"

grep -q 'generate-browser-review-artifact.sh" "${CONTRACT_PATH}"' "${FLOW_FILE}" \
  || fail "browser profile branch does not use CONTRACT_PATH"

grep -q '### Step 4.5: Advisor consult (only when needed)' "${FLOW_FILE}" \
  || fail "advisor consult step is missing"

grep -q 'bash "${HARNESS_PLUGIN_ROOT}/scripts/run-advisor-consultation.sh" \\' "${FLOW_FILE}" \
  || fail "advisor consultation wrapper call is missing"

if grep -Eq '(^|[[:space:]`"])scripts/(generate-sprint-contract|enrich-sprint-contract|ensure-sprint-contract-ready|detect-review-plateau|run-advisor-consultation)\.(js|sh)' "${FLOW_FILE}"; then
  fail "bare scripts/ call without going through plugin bundle root remains"
fi

for surface in "${SCRIPT_PATH_SURFACES[@]}"; do
  [ -f "${surface}" ] || continue
  if grep -Eq 'node scripts/(generate-sprint-contract)\.js|bash scripts/(codex-companion|auto-checkpoint|review-ai-residuals)\.sh|bash\("scripts/|&& scripts/|`scripts/(enrich-sprint-contract|ensure-sprint-contract-ready|run-contract-review-checks|write-review-result|review-ai-residuals)\.sh`' "${surface}"; then
    fail "${surface#${PROJECT_ROOT}/} has bare scripts/ call without going through plugin bundle root"
  fi
done

grep -q 'PLAN` / `CORRECTION` prepend advice to the beginning of the next executor prompt and re-run' "${FLOW_FILE}" \
  || fail "PLAN / CORRECTION description is missing"

grep -q 'The same `trigger_hash` is consulted only once' "${FLOW_FILE}" \
  || fail "trigger_hash deduplication description is missing"

echo "test-harness-loop-flow: ok"
