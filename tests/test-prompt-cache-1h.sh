#!/usr/bin/env bash
# test-prompt-cache-1h.sh
# Behavior validation tests for enable-1h-cache.sh
#
# Test content:
#   1. Append to new env.local (ENABLE_PROMPT_CACHING_1H=1 is written)
#   2. Idempotency (running twice still yields only 1 line)
#   3. No interference with existing other-key lines (other keys are preserved)
#   4. Warn and exit 1 when same key with different value already exists
#   5. env propagates when env.local contains ENABLE_PROMPT_CACHING_1H=1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET_SCRIPT="${ROOT_DIR}/scripts/enable-1h-cache.sh"

PASS_COUNT=0
FAIL_COUNT=0

pass_test() {
  echo "PASS: $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail_test() {
  echo "FAIL: $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

# Temporary directory for testing (git init required to simulate a git repository)
setup_tmp_repo() {
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  git -C "${tmp_dir}" init -q
  echo "${tmp_dir}"
}

cleanup_tmp() {
  local dir="$1"
  rm -rf "${dir}"
}

# ---------- Test 1: Script exists and is executable ----------
echo "--- Test 1: Script existence and execute permission ---"
if [[ -f "${TARGET_SCRIPT}" ]]; then
  pass_test "enable-1h-cache.sh exists"
else
  fail_test "enable-1h-cache.sh not found (path: ${TARGET_SCRIPT})"
fi

if [[ -x "${TARGET_SCRIPT}" ]]; then
  pass_test "enable-1h-cache.sh is executable"
else
  fail_test "enable-1h-cache.sh has no execute permission"
fi

# ---------- Test 2: Append to new env.local ----------
echo "--- Test 2: Append to new env.local ---"
TMP_REPO="$(setup_tmp_repo)"

# Run with no env.local present
if (cd "${TMP_REPO}" && bash "${TARGET_SCRIPT}" > /dev/null 2>&1); then
  if [[ -f "${TMP_REPO}/env.local" ]]; then
    pass_test "env.local was newly created"
  else
    fail_test "env.local was not created"
  fi

  if grep -qE "^export ENABLE_PROMPT_CACHING_1H=1$" "${TMP_REPO}/env.local"; then
    pass_test "ENABLE_PROMPT_CACHING_1H=1 written to env.local"
  else
    fail_test "ENABLE_PROMPT_CACHING_1H=1 not found in env.local"
  fi
else
  fail_test "Script execution failed (new env.local)"
fi

cleanup_tmp "${TMP_REPO}"

# ---------- Test 3: Idempotency (run twice) ----------
echo "--- Test 3: Idempotency ---"
TMP_REPO="$(setup_tmp_repo)"

(cd "${TMP_REPO}" && bash "${TARGET_SCRIPT}" > /dev/null 2>&1)
(cd "${TMP_REPO}" && bash "${TARGET_SCRIPT}" > /dev/null 2>&1)

COUNT=$(grep -cE "^export ENABLE_PROMPT_CACHING_1H=1$" "${TMP_REPO}/env.local" 2>/dev/null || echo "0")
if [[ "${COUNT}" -eq 1 ]]; then
  pass_test "After 2 runs, ENABLE_PROMPT_CACHING_1H=1 still appears only once (idempotent)"
else
  fail_test "Idempotency violation: ENABLE_PROMPT_CACHING_1H=1 appears ${COUNT} times"
fi

cleanup_tmp "${TMP_REPO}"

# ---------- Test 4: No interference with existing other-key lines ----------
echo "--- Test 4: No interference with existing other-key lines ---"
TMP_REPO="$(setup_tmp_repo)"
echo "SOME_OTHER_KEY=hello" > "${TMP_REPO}/env.local"

(cd "${TMP_REPO}" && bash "${TARGET_SCRIPT}" > /dev/null 2>&1)

if grep -qE "^SOME_OTHER_KEY=hello$" "${TMP_REPO}/env.local"; then
  pass_test "Existing key SOME_OTHER_KEY was preserved"
else
  fail_test "Existing key SOME_OTHER_KEY was removed"
fi

if grep -qE "^export ENABLE_PROMPT_CACHING_1H=1$" "${TMP_REPO}/env.local"; then
  pass_test "ENABLE_PROMPT_CACHING_1H=1 was appended"
else
  fail_test "ENABLE_PROMPT_CACHING_1H=1 was not appended"
fi

cleanup_tmp "${TMP_REPO}"

# ---------- Test 5: Same key with different value → exit 1 ----------
echo "--- Test 5: Same key with different value → exit 1 ---"
TMP_REPO="$(setup_tmp_repo)"
echo "ENABLE_PROMPT_CACHING_1H=0" > "${TMP_REPO}/env.local"

if (cd "${TMP_REPO}" && bash "${TARGET_SCRIPT}" > /dev/null 2>&1); then
  fail_test "Same key with different value returned exit 0 (expected exit 1)"
else
  pass_test "Same key with different value correctly returned exit 1"
fi

cleanup_tmp "${TMP_REPO}"

# ---------- Test 6: env propagation simulation ----------
# ENABLE_PROMPT_CACHING_1H should be set when env.local is sourced
echo "--- Test 6: env propagation when sourcing env.local ---"
TMP_REPO="$(setup_tmp_repo)"
(cd "${TMP_REPO}" && bash "${TARGET_SCRIPT}" > /dev/null 2>&1)

# Verify variable is set when sourcing env.local
SOURCED_VALUE=$(bash -c "source '${TMP_REPO}/env.local' 2>/dev/null; echo \"\${ENABLE_PROMPT_CACHING_1H:-UNSET}\"")
if [[ "${SOURCED_VALUE}" == "1" ]]; then
  pass_test "Sourcing env.local sets ENABLE_PROMPT_CACHING_1H=1 as environment variable"
else
  fail_test "ENABLE_PROMPT_CACHING_1H after sourcing env.local: expected '1', got '${SOURCED_VALUE}'"
fi

# Critical: verify sourced env.local propagates to subprocesses (e.g. claude)
# Without `export KEY=VALUE` form, subprocesses won't inherit it (stays shell-local)
CHILD_VALUE=$(bash -c "source '${TMP_REPO}/env.local' 2>/dev/null; bash -c 'echo \"\${ENABLE_PROMPT_CACHING_1H:-UNSET}\"'")
if [[ "${CHILD_VALUE}" == "1" ]]; then
  pass_test "After sourcing env.local, ENABLE_PROMPT_CACHING_1H=1 propagates to subprocess (child bash) — export confirmed"
else
  fail_test "ENABLE_PROMPT_CACHING_1H in subprocess: expected '1', got '${CHILD_VALUE}' — missing export"
fi

cleanup_tmp "${TMP_REPO}"

# ---------- Result summary ----------
echo ""
echo "========================================"
echo "Results: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"
echo "========================================"

if [[ "${FAIL_COUNT}" -gt 0 ]]; then
  exit 1
fi

exit 0
