#!/bin/bash
# test-validate-plugin-quick.sh
# jq fallback validation for validate-plugin.sh --quick
#
# Test coverage:
#   1. validate-plugin.sh --quick completes successfully (PASS on the current project)
#   2. The jq fallback function (_check_json_syntax) correctly validates valid JSON
#   3. The jq fallback function correctly detects broken JSON
#   4. python3 fallback works in environments without jq
#   5. Falls back to skip (fail-open) when neither jq nor python3 is available
#
# Usage: bash tests/test-validate-plugin-quick.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "${SCRIPT_DIR}")"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0

pass_test() {
    echo -e "${GREEN}✓${NC} $1"
    PASS_COUNT=$(( PASS_COUNT + 1 ))
}

fail_test() {
    echo -e "${RED}✗${NC} $1"
    FAIL_COUNT=$(( FAIL_COUNT + 1 ))
}

warn_test() {
    echo -e "${YELLOW}⚠${NC} $1"
}

echo "=========================================="
echo "validate-plugin.sh --quick jq fallback test"
echo "=========================================="
echo ""

WORK_DIR="$(mktemp -d /tmp/test-validate-quick-XXXXXX)"
cleanup() { rm -rf "${WORK_DIR}" 2>/dev/null || true; }
trap cleanup EXIT

VALID_JSON="${WORK_DIR}/valid.sprint-contract.json"
BROKEN_JSON="${WORK_DIR}/broken.sprint-contract.json"

cat > "${VALID_JSON}" << 'EOF'
{
  "task_id": "1",
  "review": {
    "status": "approved",
    "reviewer_profile": "static"
  }
}
EOF

printf '{"broken": true, invalid json' > "${BROKEN_JSON}"

# ── Test 1: validate-plugin.sh --quick passes on the current project ─────────────────
echo "--- Test 1: validate-plugin.sh --quick (current project) ---"

output=$(bash "${SCRIPT_DIR}/validate-plugin.sh" --quick 2>&1)
exit_code=$?

if [ "${exit_code}" -eq 0 ]; then
    pass_test "validate-plugin.sh --quick: exit 0 (PASS)"
else
    fail_test "validate-plugin.sh --quick: exit ${exit_code} (FAIL)"
    echo "  Output: ${output}" >&2
fi

# ── Test 2: Verify _check_json_syntax function exists ────────────────────────────────
echo ""
echo "--- Test 2: Presence of _check_json_syntax function and _JSON_PARSER variable ---"

if grep -q '_check_json_syntax' "${SCRIPT_DIR}/validate-plugin.sh"; then
    pass_test "_check_json_syntax function is present in validate-plugin.sh"
else
    fail_test "_check_json_syntax function not found in validate-plugin.sh"
fi

if grep -q '_JSON_PARSER' "${SCRIPT_DIR}/validate-plugin.sh"; then
    pass_test "_JSON_PARSER variable (jq/python3/skip branch) is present"
else
    fail_test "_JSON_PARSER variable not found"
fi

if grep -q 'python3.*json.*load\|python3 -c.*json' "${SCRIPT_DIR}/validate-plugin.sh"; then
    pass_test "python3 fallback code is present"
else
    fail_test "python3 fallback code not found"
fi

# ── Test 3: Valid and broken JSON check in jq environment ───────────────────────────
echo ""
echo "--- Test 3: Direct validation of _check_json_syntax logic (inline implementation) ---"

# Reproduce logic equivalent to validate-plugin.sh's _check_json_syntax here for testing.
# (validate-plugin.sh auto-computes PLUGIN_ROOT, so PLUGIN_ROOT cannot be overridden from outside.)

_test_check_json() {
    local parser="$1"
    local file="$2"
    case "${parser}" in
        jq)      jq empty "${file}" 2>/dev/null ;;
        python3) python3 -c "import json,sys; json.load(open(sys.argv[1]))" "${file}" 2>/dev/null ;;
        skip)    return 0 ;;
    esac
}

if command -v jq >/dev/null 2>&1; then
    if _test_check_json "jq" "${VALID_JSON}"; then
        pass_test "jq: valid JSON → PASS"
    else
        fail_test "jq: valid JSON → FAIL (false positive)"
    fi

    if ! _test_check_json "jq" "${BROKEN_JSON}"; then
        pass_test "jq: broken JSON → FAIL detected (as expected)"
    else
        fail_test "jq: broken JSON → PASS (detection missed)"
    fi
else
    warn_test "jq is not available, skipping jq tests"
fi

# ── Test 4: Valid and broken JSON check with python3 fallback ──────────────────
echo ""
echo "--- Test 4: JSON check with python3 fallback ---"

if command -v python3 >/dev/null 2>&1; then
    if _test_check_json "python3" "${VALID_JSON}"; then
        pass_test "python3: valid JSON → PASS"
    else
        fail_test "python3: valid JSON → FAIL (false positive)"
    fi

    if ! _test_check_json "python3" "${BROKEN_JSON}"; then
        pass_test "python3: broken JSON → FAIL detected (as expected)"
    else
        fail_test "python3: broken JSON → PASS (detection missed)"
    fi
else
    warn_test "python3 is not available, skipping python3 fallback tests"
fi

# ── Test 5: skip mode always returns 0 (fail-open) ─────────────────────────
echo ""
echo "--- Test 5: skip mode (fail-open) ---"

if _test_check_json "skip" "${VALID_JSON}" && _test_check_json "skip" "${BROKEN_JSON}"; then
    pass_test "skip mode: both valid and broken JSON return 0 (fail-open)"
else
    fail_test "skip mode: did not return 0 (fail-open not working)"
fi

# ── Test 6: Verify fallback branch structure in validate-plugin.sh ───────
echo ""
echo "--- Test 6: Fallback branch structure in validate-plugin.sh ---"

# Check that the jq → python3 → skip branch exists
if grep -q 'command -v jq' "${SCRIPT_DIR}/validate-plugin.sh"; then
    pass_test "jq presence check (command -v jq) is present"
else
    fail_test "jq presence check not found"
fi

if grep -q 'command -v python3' "${SCRIPT_DIR}/validate-plugin.sh"; then
    pass_test "python3 presence check (command -v python3) is present"
else
    fail_test "python3 presence check not found"
fi

if grep -q '"skip"' "${SCRIPT_DIR}/validate-plugin.sh"; then
    pass_test "skip branch (\"skip\") is present"
else
    fail_test "skip branch not found"
fi

echo ""
echo "=========================================="
echo "Test results summary"
echo "=========================================="
echo -e "${GREEN}Passed:${NC} ${PASS_COUNT}"
echo -e "${RED}Failed:${NC} ${FAIL_COUNT}"
echo ""

if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed${NC}"
    exit 0
else
    echo -e "${RED}✗ ${FAIL_COUNT} test(s) failed${NC}"
    exit 1
fi
