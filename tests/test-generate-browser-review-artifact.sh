#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cat > "${TMP_DIR}/Plans.md" <<'EOF'
| Task | Description | DoD | Depends | Status |
|------|-------------|-----|---------|--------|
| 32.2.2 | add browser evaluator | verify UI flow in browser | 32.2.1 | cc:TODO |
| 32.2.5 | handle browser_mode: exploratory | prefer AgentBrowser in exploratory mode | 32.2.2 | cc:TODO |
EOF

CONTRACT_PATH="${TMP_DIR}/browser-contract.json"
(cd "${TMP_DIR}" && node "${PROJECT_ROOT}/scripts/generate-sprint-contract.js" "32.2.2" "${TMP_DIR}/Plans.md" "$CONTRACT_PATH" >/dev/null)
EXPLORATORY_CONTRACT_PATH="${TMP_DIR}/browser-exploratory-contract.json"
(cd "${TMP_DIR}" && node "${PROJECT_ROOT}/scripts/generate-sprint-contract.js" "32.2.5" "${TMP_DIR}/Plans.md" "$EXPLORATORY_CONTRACT_PATH" >/dev/null)

ARTIFACT_PATH="${TMP_DIR}/browser-review.json"

mkdir -p "${TMP_DIR}/playwright"
cat > "${TMP_DIR}/playwright/package.json" <<'EOF'
{
  "devDependencies": {
    "@playwright/test": "^1.51.0"
  }
}
EOF

cp "$CONTRACT_PATH" "${TMP_DIR}/playwright/browser-contract.json"
jq '.review.route = "playwright"' "${TMP_DIR}/playwright/browser-contract.json" > "${TMP_DIR}/playwright/browser-contract.next.json"
mv "${TMP_DIR}/playwright/browser-contract.next.json" "${TMP_DIR}/playwright/browser-contract.json"
(cd "${TMP_DIR}/playwright" && "${PROJECT_ROOT}/scripts/generate-browser-review-artifact.sh" "${TMP_DIR}/playwright/browser-contract.json" "${TMP_DIR}/playwright/browser-review.json" >/dev/null)

jq -e '
  .route == "playwright" and
  .browser_mode == "scripted" and
  (.required_artifacts | index("trace")) != null and
  (.tool_matcher | contains("mcp__playwright__"))
' "${TMP_DIR}/playwright/browser-review.json" >/dev/null

# Add agent-browser stub to PATH (so tests work even without agent-browser in CI/dev environments)
STUB_BIN="${TMP_DIR}/stub-bin"
mkdir -p "$STUB_BIN"
printf '#!/bin/sh\nexit 0\n' > "${STUB_BIN}/agent-browser"
chmod +x "${STUB_BIN}/agent-browser"

mkdir -p "${TMP_DIR}/agent-browser"
cp "$EXPLORATORY_CONTRACT_PATH" "${TMP_DIR}/agent-browser/browser-contract.json"
jq '.review.route = "agent-browser"' "${TMP_DIR}/agent-browser/browser-contract.json" > "${TMP_DIR}/agent-browser/browser-contract.next.json"
mv "${TMP_DIR}/agent-browser/browser-contract.next.json" "${TMP_DIR}/agent-browser/browser-contract.json"
(cd "${TMP_DIR}/agent-browser" && PATH="${STUB_BIN}:${PATH}" "${PROJECT_ROOT}/scripts/generate-browser-review-artifact.sh" "${TMP_DIR}/agent-browser/browser-contract.json" "${TMP_DIR}/agent-browser/browser-review.json" >/dev/null)

jq -e '
  .route == "agent-browser" and
  .browser_mode == "exploratory" and
  (.required_artifacts | index("snapshot")) != null and
  (.tool_matcher | contains("agent-browser"))
' "${TMP_DIR}/agent-browser/browser-review.json" >/dev/null

mkdir -p "${TMP_DIR}/fallback"
cp "$CONTRACT_PATH" "${TMP_DIR}/fallback/browser-contract.json"
jq '.review.route = "chrome-devtools"' "${TMP_DIR}/fallback/browser-contract.json" > "${TMP_DIR}/fallback/browser-contract.next.json"
mv "${TMP_DIR}/fallback/browser-contract.next.json" "${TMP_DIR}/fallback/browser-contract.json"
(cd "${TMP_DIR}/fallback" && HARNESS_BROWSER_REVIEW_DISABLE_PLAYWRIGHT=1 HARNESS_BROWSER_REVIEW_DISABLE_AGENT_BROWSER=1 "${PROJECT_ROOT}/scripts/generate-browser-review-artifact.sh" "${TMP_DIR}/fallback/browser-contract.json" "${TMP_DIR}/fallback/browser-review.json" >/dev/null)

jq -e '
  .route == "chrome-devtools" and
  .browser_mode == "scripted" and
  (.required_artifacts | index("screenshot")) != null
' "${TMP_DIR}/fallback/browser-review.json" >/dev/null

cp "$CONTRACT_PATH" "${TMP_DIR}/override-contract.json"
jq '.review.route = "chrome-devtools"' "${TMP_DIR}/override-contract.json" > "${TMP_DIR}/override-contract.next.json"
mv "${TMP_DIR}/override-contract.next.json" "${TMP_DIR}/override-contract.json"
(cd "${TMP_DIR}" && PATH="${STUB_BIN}:${PATH}" "${PROJECT_ROOT}/scripts/generate-browser-review-artifact.sh" "${TMP_DIR}/override-contract.json" "${TMP_DIR}/override-browser-review.json" >/dev/null)

jq -e '
  .route == "chrome-devtools" and
  .browser_mode == "scripted" and
  (.tool_matcher | contains("chrome-devtools"))
' "${TMP_DIR}/override-browser-review.json" >/dev/null

echo "test-generate-browser-review-artifact: ok"
