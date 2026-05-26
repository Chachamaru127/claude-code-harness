#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cat > "${TMP_DIR}/Plans.md" <<'EOF'
| Task | Content | DoD | Depends | Status |
|------|---------|-----|---------|--------|
| 32.1.1 | create contract | add runtime validation to contract | 32.0.1 | cc:TODO |
EOF

CONTRACT_PATH="${TMP_DIR}/contract.json"
node "${PROJECT_ROOT}/scripts/generate-sprint-contract.js" "32.1.1" "${TMP_DIR}/Plans.md" "$CONTRACT_PATH" >/dev/null

if "${PROJECT_ROOT}/scripts/ensure-sprint-contract-ready.sh" "$CONTRACT_PATH" >/dev/null 2>&1; then
  echo "contract should fail before approval"
  exit 1
fi

"${PROJECT_ROOT}/scripts/enrich-sprint-contract.sh" "$CONTRACT_PATH" \
  --check "Re-confirm DoD from reviewer perspective" \
  --non-goal "UI polish is out of scope for this round" \
  --risk "needs-spike" \
  --note "reviewer checked runtime path" \
  --approve >/dev/null

"${PROJECT_ROOT}/scripts/ensure-sprint-contract-ready.sh" "$CONTRACT_PATH" >/dev/null

jq -e '
  .review.status == "approved" and
  (.contract.non_goals | length) == 1 and
  (.contract.risk_flags | index("needs-spike")) != null
' "$CONTRACT_PATH" >/dev/null

echo "test-sprint-contract-approval: ok"
