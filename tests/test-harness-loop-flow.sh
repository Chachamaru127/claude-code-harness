#!/bin/bash
# test-harness-loop-flow.sh
# harness-loop flow.md の contract_path / reviewer_profile / advisor 導線の回帰テスト
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

[ -f "${FLOW_FILE}" ] || fail "flow.md が見つかりません"

grep -q 'CONTRACT_PATH=".claude/state/contracts/${task_id}.sprint-contract.json"' "${FLOW_FILE}" \
  || fail "Step 2 に CONTRACT_PATH 初期化がありません"

if grep -q 'task_contract_path' "${FLOW_FILE}"; then
  fail "flow.md に削除済みの task_contract_path 参照が残っています"
fi

grep -q 'REVIEWER_PROFILE=$(jq -r '\''\.review\.reviewer_profile // "static"'\'' "${CONTRACT_PATH}"' "${FLOW_FILE}" \
  || fail "reviewer_profile 読み取りが CONTRACT_PATH を参照していません"

grep -q 'generate-browser-review-artifact.sh" "${CONTRACT_PATH}"' "${FLOW_FILE}" \
  || fail "browser profile 分岐が CONTRACT_PATH を使っていません"

grep -q '### Step 4.5: Advisor consult（必要時のみ）' "${FLOW_FILE}" \
  || fail "advisor consult ステップがありません"

grep -q 'bash "${HARNESS_PLUGIN_ROOT}/scripts/run-advisor-consultation.sh" \\' "${FLOW_FILE}" \
  || fail "advisor consultation wrapper の呼び出しがありません"

if grep -Eq '(^|[[:space:]`"])scripts/(generate-sprint-contract|enrich-sprint-contract|ensure-sprint-contract-ready|detect-review-plateau|run-advisor-consultation)\.(js|sh)' "${FLOW_FILE}"; then
  fail "plugin bundle root を通さない bare scripts/ 呼び出しが残っています"
fi

for surface in "${SCRIPT_PATH_SURFACES[@]}"; do
  [ -f "${surface}" ] || continue
  if grep -Eq 'node scripts/(generate-sprint-contract)\.js|bash scripts/(codex-companion|auto-checkpoint|review-ai-residuals)\.sh|bash\("scripts/|&& scripts/|`scripts/(enrich-sprint-contract|ensure-sprint-contract-ready|run-contract-review-checks|write-review-result|review-ai-residuals)\.sh`' "${surface}"; then
    fail "${surface#${PROJECT_ROOT}/} に plugin bundle root を通さない bare scripts/ 呼び出しが残っています"
  fi
done

grep -q 'PLAN` / `CORRECTION` は次の executor prompt 先頭に advice を入れて再実行' "${FLOW_FILE}" \
  || fail "PLAN / CORRECTION の説明がありません"

grep -q '同じ `trigger_hash` は 1 回だけ相談する' "${FLOW_FILE}" \
  || fail "trigger_hash による重複抑止の説明がありません"

echo "test-harness-loop-flow: ok"
