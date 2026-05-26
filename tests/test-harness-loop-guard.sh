#!/bin/bash
# test-harness-loop-guard.sh
# Test for harness-loop idempotency guard (a) multiple-launch prevention lock
#
# Usage: bash tests/test-harness-loop-guard.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "${SCRIPT_DIR}")"
LOCK_FILE="${PLUGIN_ROOT}/.claude/state/locks/loop-session.lock"

# Color output
GREEN='\033[0;32m'
RED='\033[0;31m'
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

echo "=========================================="
echo "harness-loop idempotency guard (a) test"
echo "=========================================="
echo ""

# Cleanup: remove lock file before starting test
cleanup() {
    rm -f "${LOCK_FILE}" 2>/dev/null || true
}
trap cleanup EXIT
cleanup

# Mock harness-loop launch script (reproduces Step 0 of flow.md)
MOCK_LOOP_SCRIPT="$(mktemp /tmp/test-harness-loop-XXXXXX.sh)"
cat > "${MOCK_LOOP_SCRIPT}" << 'SCRIPT'
#!/bin/bash
# Reproduce multiple-launch prevention lock from flow.md Step 0
LOCK_FILE="$1"
mkdir -p "$(dirname "${LOCK_FILE}")"

if [ -f "${LOCK_FILE}" ]; then
    echo "harness-loop: already running" >&2
    exit 1
fi

SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"
printf '{"pid":%d,"session_id":"%s","started_at":"%s","args":"%s"}\n' \
    "$$" "${SESSION_ID}" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "test" \
    > "${LOCK_FILE}"

cleanup_loop_lock() {
    rm -f "${LOCK_FILE}" 2>/dev/null || true
}
trap cleanup_loop_lock EXIT INT TERM

# Hold lock during operation (test: sleep 0.5s)
sleep 0.5
exit 0
SCRIPT
chmod +x "${MOCK_LOOP_SCRIPT}"

# Test 1: first launch should succeed
echo "--- Test 1: first launch ---"
bash "${MOCK_LOOP_SCRIPT}" "${LOCK_FILE}" &
FIRST_PID=$!
sleep 0.1  # Wait briefly for lock file to be created

if [ -f "${LOCK_FILE}" ]; then
    pass_test "First launch: lock file created"
else
    fail_test "First launch: lock file not created"
fi

# Test 2: second launch should return already running error
echo "--- Test 2: multiple-launch prevention ---"
SECOND_OUTPUT="$(bash "${MOCK_LOOP_SCRIPT}" "${LOCK_FILE}" 2>&1 || true)"
if echo "${SECOND_OUTPUT}" | grep -q "already running"; then
    pass_test "Second launch: 'already running' error returned"
else
    fail_test "Second launch: 'already running' error not returned (output: ${SECOND_OUTPUT})"
fi

# Test 3: second launch should exit with code 1
echo "--- Test 3: exit code on multiple launch ---"
bash "${MOCK_LOOP_SCRIPT}" "${LOCK_FILE}" 2>/dev/null
EXIT_CODE=$?
if [ "${EXIT_CODE}" -eq 1 ]; then
    pass_test "Second launch: exited with code 1"
else
    fail_test "Second launch: exit code was ${EXIT_CODE} (expected: 1)"
fi

# Wait for first launch to finish
wait "${FIRST_PID}" 2>/dev/null || true

# Test 4: lock file should be removed after normal exit
echo "--- Test 4: lock removal after normal exit ---"
if [ ! -f "${LOCK_FILE}" ]; then
    pass_test "After normal exit: lock file removed"
else
    fail_test "After normal exit: lock file still exists"
fi

# Test 5: should be able to relaunch after lock is removed
echo "--- Test 5: relaunch after lock removal ---"
bash "${MOCK_LOOP_SCRIPT}" "${LOCK_FILE}" &
THIRD_PID=$!
sleep 0.1

if [ -f "${LOCK_FILE}" ]; then
    pass_test "Relaunch: lock file created (reusable)"
else
    fail_test "Relaunch: lock file not created"
fi
wait "${THIRD_PID}" 2>/dev/null || true

# Test 6: lock file content should be valid JSON
echo "--- Test 6: lock file JSON format ---"
bash "${MOCK_LOOP_SCRIPT}" "${LOCK_FILE}" &
FOURTH_PID=$!
sleep 0.1

if [ -f "${LOCK_FILE}" ]; then
    if command -v python3 >/dev/null 2>&1; then
        if python3 -c "import json; json.load(open('${LOCK_FILE}'))" 2>/dev/null; then
            pass_test "lock file content is valid JSON"
            # Verify pid, session_id, started_at, args fields
            for field in pid session_id started_at args; do
                if python3 -c "import json; d=json.load(open('${LOCK_FILE}')); assert '${field}' in d" 2>/dev/null; then
                    pass_test "lock file has '${field}' field"
                else
                    fail_test "lock file missing '${field}' field"
                fi
            done
        else
            fail_test "lock file content is not valid JSON"
        fi
    else
        pass_test "python3 not available, skipping JSON validation"
    fi
fi
wait "${FOURTH_PID}" 2>/dev/null || true

# Cleanup
rm -f "${MOCK_LOOP_SCRIPT}" 2>/dev/null || true

echo ""
echo "=========================================="
echo "Test Result Summary"
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
