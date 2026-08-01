#!/usr/bin/env bash
# test-release-verify-publish.sh — Unit tests for scripts/release-verify-publish.sh
#
# Uses a mock 'gh' binary injected via PATH to avoid real API calls.
# Timeout override: MAX_ATTEMPTS_OVERRIDE and INTERVAL_SEC_OVERRIDE env vars.
#
# Exit code: 0 if all 3 cases PASS, 1 otherwise.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERIFY_SCRIPT="${PROJECT_ROOT}/scripts/release-verify-publish.sh"

PASS_COUNT=0
FAIL_COUNT=0

pass() { echo "PASS: $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { echo "FAIL: $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

run_case() {
  local case_name="$1"
  local mock_script="$2"
  local expected_exit="$3"
  local check_pattern="${4:-}"

  local mock_dir
  mock_dir="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$mock_dir'" RETURN

  # Write mock gh binary
  cat > "$mock_dir/gh" <<MOCK
#!/usr/bin/env bash
${mock_script}
MOCK
  chmod +x "$mock_dir/gh"

  # Short timeout: 3 attempts, 0-second sleep interval
  local actual_output
  local actual_exit=0
  actual_output="$(
    PATH="$mock_dir:$PATH" \
    MAX_ATTEMPTS_OVERRIDE=3 \
    INTERVAL_SEC_OVERRIDE=0 \
    bash "$VERIFY_SCRIPT" "v4.99.0" "Owner/test-repo" 2>&1
  )" || actual_exit=$?

  if [ "$actual_exit" -ne "$expected_exit" ]; then
    fail "${case_name}: expected exit ${expected_exit}, got ${actual_exit} (output: ${actual_output})"
    return
  fi

  if [ -n "$check_pattern" ]; then
    if grep -q "$check_pattern" <<<"$actual_output"; then
      pass "${case_name}: exit=${actual_exit}, pattern '${check_pattern}' found"
    else
      fail "${case_name}: exit=${actual_exit} OK but pattern '${check_pattern}' not in output: ${actual_output}"
    fi
  else
    pass "${case_name}: exit=${actual_exit}"
  fi
}

# --- Case 1: success ---
# mock gh returns draft=false and 4 assets immediately
run_case "Case1_success" \
  'echo '"'"'{"draft":false,"assets":[{"id":1},{"id":2},{"id":3},{"id":4}]}'"'"'' \
  0 \
  "PASS:"

# --- Case 2: draft persists (timeout) ---
# mock gh always returns draft=true, so script should timeout with exit 2
run_case "Case2_draft_persists" \
  'echo '"'"'{"draft":true,"assets":[{"id":1},{"id":2}]}'"'"'' \
  2 \
  "WARN:"

# --- Case 3: 404 not-found (timeout) ---
# mock gh always exits 1 with a 404 message, polling should continue until timeout
run_case "Case3_404_not_found" \
  'echo "Not Found: https://api.github.com/repos/Owner/test-repo/releases/tags/v4.99.0 - 404" >&2; exit 1' \
  2 \
  "WARN:"

# --- Summary ---
echo ""
echo "Results: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0
