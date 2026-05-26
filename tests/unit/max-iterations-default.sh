#!/bin/bash
# max-iterations-default.sh
# Unit test for the default value and manual override behavior of review.max_iterations
#
# Usage: ./tests/unit/max-iterations-default.sh
#
# Design policy (post Finding 4):
#   detectMaxIterations() in generate-sprint-contract.js only accepts HTML comment markers.
#   Syntax: <!-- max_iterations: 15 --> (not rendered by Markdown, so distinguishable from example text)
#   Plain text "max_iterations: 15" is intentionally ignored (prevents self-reference bugs).
#   Range guard: values outside 1-30 fall back to profile default + stderr warning.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PASS=0
FAIL=0

check() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [ "$actual" = "$expected" ]; then
    echo "  PASS: $label (got $actual)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label - expected $expected, got $actual" >&2
    FAIL=$((FAIL + 1))
  fi
}

# Prepare the base Plans.md
cat > "${TMP_DIR}/Plans.md" <<'EOF'
| Task | Description | DoD | Depends | Status |
|------|-------------|-----|---------|--------|
| T-static | static task | implement test | - | cc:TODO |
| T-browser | browser task | verify UI flow in browser | - | cc:TODO |
| T-html-comment | HTML comment task | include <!-- max_iterations: 15 --> in DoD | - | cc:TODO |
| T-out-of-range | out-of-range task | <!-- max_iterations: 100 --> is invalid | - | cc:TODO |
| T-plain-text | plain text task | only says max_iterations: 15 | - | cc:TODO |
EOF

echo "=== Case (i): no contract equivalent (static profile) → max_iterations=3 ==="
OUT_I="${TMP_DIR}/out-i.json"
(cd "${TMP_DIR}" && node "${PROJECT_ROOT}/scripts/generate-sprint-contract.js" "T-static" "${TMP_DIR}/Plans.md" "${OUT_I}" >/dev/null)
ACTUAL_I="$(jq -r '.review.max_iterations' "${OUT_I}")"
check "static profile → 3" "3" "${ACTUAL_I}"

echo "=== Case (ii): browser profile → max_iterations=5 ==="
OUT_II="${TMP_DIR}/out-ii.json"
(cd "${TMP_DIR}" && HARNESS_BROWSER_REVIEW_DISABLE_PLAYWRIGHT=1 \
  node "${PROJECT_ROOT}/scripts/generate-sprint-contract.js" "T-browser" "${TMP_DIR}/Plans.md" "${OUT_II}" >/dev/null)
ACTUAL_II="$(jq -r '.review.max_iterations' "${OUT_II}")"
check "browser profile → 5" "5" "${ACTUAL_II}"

echo "=== Case (iii): HTML comment <!-- max_iterations: 15 --> → 15 (explicit override) ==="
OUT_III="${TMP_DIR}/out-iii.json"
(cd "${TMP_DIR}" && node "${PROJECT_ROOT}/scripts/generate-sprint-contract.js" "T-html-comment" "${TMP_DIR}/Plans.md" "${OUT_III}" >/dev/null)
ACTUAL_III="$(jq -r '.review.max_iterations' "${OUT_III}")"
check "explicit max_iterations=15 via HTML comment marker" "15" "${ACTUAL_III}"

echo "=== Case (iv): HTML comment <!-- max_iterations: 100 --> is out of range → falls back to profile default + stderr warning ==="
OUT_IV="${TMP_DIR}/out-iv.json"
STDERR_IV="${TMP_DIR}/stderr-iv.txt"
(cd "${TMP_DIR}" && node "${PROJECT_ROOT}/scripts/generate-sprint-contract.js" "T-out-of-range" "${TMP_DIR}/Plans.md" "${OUT_IV}" 2>"${STDERR_IV}" >/dev/null)
ACTUAL_IV="$(jq -r '.review.max_iterations' "${OUT_IV}")"
check "out-of-range max_iterations=100 → profile default 3" "3" "${ACTUAL_IV}"
# Check that a warning is emitted to stderr
if grep -q "out of range" "${STDERR_IV}"; then
  echo "  PASS: out-of-range warning emitted to stderr"
  PASS=$((PASS + 1))
else
  echo "  FAIL: out-of-range warning not emitted to stderr (content: $(cat "${STDERR_IV}"))" >&2
  FAIL=$((FAIL + 1))
fi

echo "=== Case (v): plain text \"max_iterations: 15\" (no HTML comment) → stays at profile default ==="
OUT_V="${TMP_DIR}/out-v.json"
(cd "${TMP_DIR}" && node "${PROJECT_ROOT}/scripts/generate-sprint-contract.js" "T-plain-text" "${TMP_DIR}/Plans.md" "${OUT_V}" >/dev/null)
ACTUAL_V="$(jq -r '.review.max_iterations' "${OUT_V}")"
check "plain text max_iterations: 15 is ignored → profile default 3" "3" "${ACTUAL_V}"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [ "${FAIL}" -gt 0 ]; then
  exit 1
fi
exit 0
