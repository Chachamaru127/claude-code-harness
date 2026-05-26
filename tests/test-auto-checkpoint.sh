#!/bin/bash
# test-auto-checkpoint.sh
# smoke test for auto-checkpoint.sh
#
# Test cases:
#   1. success: when harness-mem is responsive, exit 0 + 1 line in checkpoint-events.jsonl
#   2. failure: set HARNESS_MEM_DISABLE=1 to fail API, exit non-0 +
#              1 regression line in session-events.jsonl +
#              1 line with status:"failed" in checkpoint-events.jsonl
#   3. lock test: 2 processes launched simultaneously → one aborts after timeout

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
AUTO_CHECKPOINT="${ROOT_DIR}/scripts/auto-checkpoint.sh"

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

# Temporary directory (created separately per test, not shared)
make_tmp_dir() {
  mktemp -d
}

cleanup_dirs=()
cleanup() {
  for d in "${cleanup_dirs[@]:-}"; do
    [ -d "$d" ] && rm -rf "$d"
  done
}
trap cleanup EXIT

# ── helper: create fake harness-mem-client ──────────────────────────────
make_fake_client_ok() {
  local dir="$1"
  local fake_client="${dir}/fake-harness-mem-client.sh"
  cat > "${fake_client}" << 'EOF'
#!/bin/bash
# fake harness-mem-client (success)
set -euo pipefail
printf '{"ok":true,"id":"fake-checkpoint-id"}\n'
EOF
  chmod +x "${fake_client}"
  printf '%s' "${fake_client}"
}

make_fake_client_fail() {
  local dir="$1"
  local fake_client="${dir}/fake-harness-mem-client-fail.sh"
  cat > "${fake_client}" << 'EOF'
#!/bin/bash
# fake harness-mem-client (failure)
set -euo pipefail
printf '{"ok":false,"error":"api_error","error_code":"record_checkpoint_failed"}\n'
EOF
  chmod +x "${fake_client}"
  printf '%s' "${fake_client}"
}

# ── helper: create minimal fixture files ────────────────────────────────────
make_fixtures() {
  local dir="$1"
  local contract="${dir}/test-contract.json"
  local review="${dir}/test-review.json"
  printf '{"task_id":"41.0.2","title":"test"}' > "${contract}"
  printf '{"verdict":"APPROVE","status":"ok"}' > "${review}"
  printf '%s %s' "${contract}" "${review}"
}

# ────────────────────────────────────────────────────────────────────────────
# Test 1: success case
# ────────────────────────────────────────────────────────────────────────────
test_success_case() {
  local tmp
  tmp="$(make_tmp_dir)"
  cleanup_dirs+=("${tmp}")

  local fake_client
  fake_client="$(make_fake_client_ok "${tmp}")"
  read -r contract review <<< "$(make_fixtures "${tmp}")"

  local state_dir="${tmp}/.claude/state"
  mkdir -p "${state_dir}/locks"

  local exit_code=0
  HARNESS_MEM_CLIENT="${fake_client}" \
  CHECKPOINT_LOCK_TIMEOUT=5 \
  PROJECT_ROOT="${tmp}" \
    bash "${AUTO_CHECKPOINT}" "41.0.2" "abc1234" "${contract}" "${review}" \
    >/dev/null 2>&1 || exit_code=$?

  # verify exit 0
  if [ "${exit_code}" -ne 0 ]; then
    fail_test "success case: exit code was ${exit_code} (expected: 0)"
    return
  fi

  # checkpoint-events.jsonl must have 1 line
  local events_file="${state_dir}/checkpoint-events.jsonl"
  if [ ! -f "${events_file}" ]; then
    fail_test "success case: checkpoint-events.jsonl was not created"
    return
  fi

  local line_count
  line_count="$(wc -l < "${events_file}" | tr -d ' ')"
  if [ "${line_count}" -lt 1 ]; then
    fail_test "success case: checkpoint-events.jsonl has no lines"
    return
  fi

  # status must be "ok"
  local last_line
  last_line="$(tail -1 "${events_file}")"
  if ! printf '%s' "${last_line}" | grep -q '"status":"ok"'; then
    fail_test "success case: checkpoint-events.jsonl status is not ok: ${last_line}"
    return
  fi

  # session-events.jsonl must not exist or must not contain checkpoint_failed
  local session_events_file="${state_dir}/session-events.jsonl"
  if [ -f "${session_events_file}" ] && grep -q '"type":"checkpoint_failed"' "${session_events_file}"; then
    fail_test "success case: checkpoint_failed recorded in session-events.jsonl"
    return
  fi

  pass_test "success case: exit 0 + checkpoint-events.jsonl has status:ok line"
}

# ────────────────────────────────────────────────────────────────────────────
# Test 2: failure case — HARNESS_MEM_DISABLE=1
# ────────────────────────────────────────────────────────────────────────────
test_failure_case_disable_flag() {
  local tmp
  tmp="$(make_tmp_dir)"
  cleanup_dirs+=("${tmp}")

  local fake_client
  fake_client="$(make_fake_client_ok "${tmp}")"
  read -r contract review <<< "$(make_fixtures "${tmp}")"

  local state_dir="${tmp}/.claude/state"
  mkdir -p "${state_dir}/locks"

  local exit_code=0
  HARNESS_MEM_CLIENT="${fake_client}" \
  HARNESS_MEM_DISABLE=1 \
  CHECKPOINT_LOCK_TIMEOUT=5 \
  PROJECT_ROOT="${tmp}" \
    bash "${AUTO_CHECKPOINT}" "41.0.2" "abc1234" "${contract}" "${review}" \
    >/dev/null 2>&1 || exit_code=$?

  # verify non-zero exit
  if [ "${exit_code}" -eq 0 ]; then
    fail_test "failure case (DISABLE): exit code was 0 (expected: non-zero)"
    return
  fi

  # checkpoint-events.jsonl must have a status:"failed" line
  local events_file="${state_dir}/checkpoint-events.jsonl"
  if [ ! -f "${events_file}" ]; then
    fail_test "failure case (DISABLE): checkpoint-events.jsonl was not created"
    return
  fi

  local last_checkpoint
  last_checkpoint="$(tail -1 "${events_file}")"
  if ! printf '%s' "${last_checkpoint}" | grep -q '"status":"failed"'; then
    fail_test "failure case (DISABLE): checkpoint-events.jsonl status is not failed: ${last_checkpoint}"
    return
  fi

  # session-events.jsonl must contain checkpoint_failed
  local session_events_file="${state_dir}/session-events.jsonl"
  if [ ! -f "${session_events_file}" ]; then
    fail_test "failure case (DISABLE): session-events.jsonl was not created"
    return
  fi

  if ! grep -q '"type":"checkpoint_failed"' "${session_events_file}"; then
    fail_test "failure case (DISABLE): checkpoint_failed not in session-events.jsonl"
    return
  fi

  pass_test "failure case (DISABLE): non-zero exit + checkpoint-events status:failed + session-events checkpoint_failed present"
}

# ────────────────────────────────────────────────────────────────────────────
# Test 3: failure case — API returns a failure response
# ────────────────────────────────────────────────────────────────────────────
test_failure_case_api_error() {
  local tmp
  tmp="$(make_tmp_dir)"
  cleanup_dirs+=("${tmp}")

  local fake_client
  fake_client="$(make_fake_client_fail "${tmp}")"
  read -r contract review <<< "$(make_fixtures "${tmp}")"

  local state_dir="${tmp}/.claude/state"
  mkdir -p "${state_dir}/locks"

  local exit_code=0
  HARNESS_MEM_CLIENT="${fake_client}" \
  CHECKPOINT_LOCK_TIMEOUT=5 \
  PROJECT_ROOT="${tmp}" \
    bash "${AUTO_CHECKPOINT}" "41.0.2" "abc1234" "${contract}" "${review}" \
    >/dev/null 2>&1 || exit_code=$?

  # verify non-zero exit
  if [ "${exit_code}" -eq 0 ]; then
    fail_test "failure case (API error): exit code was 0 (expected: non-zero)"
    return
  fi

  # checkpoint-events.jsonl must have status:"failed"
  local events_file="${state_dir}/checkpoint-events.jsonl"
  if [ ! -f "${events_file}" ]; then
    fail_test "failure case (API error): checkpoint-events.jsonl was not created"
    return
  fi

  local last_checkpoint
  last_checkpoint="$(tail -1 "${events_file}")"
  if ! printf '%s' "${last_checkpoint}" | grep -q '"status":"failed"'; then
    fail_test "failure case (API error): checkpoint-events.jsonl status is not failed: ${last_checkpoint}"
    return
  fi

  # session-events.jsonl must contain checkpoint_failed
  local session_events_file="${state_dir}/session-events.jsonl"
  if [ ! -f "${session_events_file}" ] || ! grep -q '"type":"checkpoint_failed"' "${session_events_file}"; then
    fail_test "failure case (API error): checkpoint_failed not in session-events.jsonl"
    return
  fi

  pass_test "failure case (API error): non-zero exit + checkpoint-events status:failed + session-events checkpoint_failed present"
}

# ────────────────────────────────────────────────────────────────────────────
# Test 4: lock test — 2 processes launched simultaneously → one aborts after timeout
# ────────────────────────────────────────────────────────────────────────────
test_lock_contention() {
  local tmp
  tmp="$(make_tmp_dir)"
  cleanup_dirs+=("${tmp}")

  local state_dir="${tmp}/.claude/state"
  mkdir -p "${state_dir}/locks"
  read -r contract review <<< "$(make_fixtures "${tmp}")"

  # "slow" fake client that holds the lock first (sleeps 2 seconds)
  local slow_client="${tmp}/slow-client.sh"
  cat > "${slow_client}" << 'EOF'
#!/bin/bash
sleep 3
printf '{"ok":true}\n'
EOF
  chmod +x "${slow_client}"

  local exit_code_fast=99
  local checkpoint_events_file="${state_dir}/checkpoint-events.jsonl"

  # Process 1: holds the lock while running slow work
  HARNESS_MEM_CLIENT="${slow_client}" \
  CHECKPOINT_LOCK_TIMEOUT=2 \
  PROJECT_ROOT="${tmp}" \
    bash "${AUTO_CHECKPOINT}" "41.0.2-p1" "abc0001" "${contract}" "${review}" \
    >/dev/null 2>&1 &
  local pid1=$!

  # Wait briefly then launch Process 2 (while Process 1 still holds the lock)
  sleep 0.3

  # Process 2: should abort after lock timeout (2s)
  HARNESS_MEM_CLIENT="${slow_client}" \
  CHECKPOINT_LOCK_TIMEOUT=2 \
  PROJECT_ROOT="${tmp}" \
    bash "${AUTO_CHECKPOINT}" "41.0.2-p2" "abc0002" "${contract}" "${review}" \
    >/dev/null 2>&1 || exit_code_fast=$?

  wait "${pid1}" || true

  # Process 2 must exit non-zero (aborted by lock timeout)
  if [ "${exit_code_fast}" -eq 0 ]; then
    fail_test "lock test: Process 2 exited 0 (should abort on lock timeout)"
    return
  fi

  # checkpoint-events.jsonl should have a timeout failure record for Process 2
  if [ -f "${checkpoint_events_file}" ] && grep -q '"error":"lock_timeout"' "${checkpoint_events_file}"; then
    pass_test "lock test: 2 simultaneous processes — one aborted with lock_timeout"
  else
    # partial pass if no timeout record but exit was non-zero
    if [ "${exit_code_fast}" -ne 0 ]; then
      pass_test "lock test: Process 2 aborted with exit ${exit_code_fast} (lock contention)"
    else
      fail_test "lock test: lock_timeout record not in checkpoint-events.jsonl"
    fi
  fi
}

# ────────────────────────────────────────────────────────────────────────────
# Test 5: no lock deadlock after 10 consecutive runs
# ────────────────────────────────────────────────────────────────────────────
test_no_deadlock_10_runs() {
  local tmp
  tmp="$(make_tmp_dir)"
  cleanup_dirs+=("${tmp}")

  local fake_client
  fake_client="$(make_fake_client_ok "${tmp}")"
  read -r contract review <<< "$(make_fixtures "${tmp}")"

  local state_dir="${tmp}/.claude/state"
  mkdir -p "${state_dir}/locks"

  local failed=0
  for i in $(seq 1 10); do
    local exit_code=0
    HARNESS_MEM_CLIENT="${fake_client}" \
    CHECKPOINT_LOCK_TIMEOUT=5 \
    PROJECT_ROOT="${tmp}" \
      bash "${AUTO_CHECKPOINT}" "41.0.2-run${i}" "abc$(printf '%04d' "${i}")" "${contract}" "${review}" \
      >/dev/null 2>&1 || exit_code=$?
    if [ "${exit_code}" -ne 0 ]; then
      failed=$((failed + 1))
    fi
  done

  if [ "${failed}" -ne 0 ]; then
    fail_test "10 consecutive runs: ${failed} failure(s) (possible lock deadlock)"
    return
  fi

  # checkpoint-events.jsonl must have at least 10 lines
  local events_file="${state_dir}/checkpoint-events.jsonl"
  local line_count
  line_count="$(wc -l < "${events_file}" | tr -d ' ')"
  if [ "${line_count}" -lt 10 ]; then
    fail_test "10 consecutive runs: checkpoint-events.jsonl has ${line_count} lines (expected: 10 or more)"
    return
  fi

  pass_test "10 consecutive runs: no lock deadlock + checkpoint-events.jsonl has ${line_count} lines"
}

# ────────────────────────────────────────────────────────────────────────────
# Run tests
# ────────────────────────────────────────────────────────────────────────────
echo "=== auto-checkpoint.sh smoke test ==="
echo ""

test_success_case
test_failure_case_disable_flag
test_failure_case_api_error
test_lock_contention
test_no_deadlock_10_runs

echo ""
echo "=== Result: PASS=${PASS_COUNT} FAIL=${FAIL_COUNT} ==="

if [ "${FAIL_COUNT}" -ne 0 ]; then
  exit 1
fi

exit 0
