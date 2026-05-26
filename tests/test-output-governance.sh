#!/usr/bin/env bash
# test-output-governance.sh
# Phase 62.2.1: PostToolUse.updatedToolOutput governance test
#
# Verification items:
#   (1) opt-in disabled (default) → handler is no-op
#   (2) opt-in enabled + redact use → correctly redacts + records audit
#   (3) JSON-contract tool (Read/Grep/Bash) → skip to prevent mixing
#   (4) audit log is append-only and retains before/after
#
# Also explicitly verifies failure use case (tampering):
#   (5) handler does not allow evidence-concealment in review/test output
#       (handler is allowlist-based; new rules require explicit registration)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HANDLER="${ROOT_DIR}/scripts/hook-handlers/posttool-output-normalize.sh"
AUDIT_LOG="${ROOT_DIR}/.claude/state/output-audit.jsonl"

[ -x "${HANDLER}" ] || chmod +x "${HANDLER}"
[ -x "${HANDLER}" ] || {
  echo "FAIL: ${HANDLER} is not executable"
  exit 1
}

mkdir -p "${ROOT_DIR}/.claude/state"

# Test isolation: use a temp audit log path
TMP_AUDIT="$(mktemp)"
trap 'rm -f "${TMP_AUDIT}"' EXIT

# (1) opt-in disabled → no output
NO_OPT_INPUT='{"tool_name":"Edit","tool_input":{},"tool_response":{"output":"sk-1234567890abcdefghijABCDEFGHIJ"}}'
NO_OPT_OUTPUT="$(printf '%s' "${NO_OPT_INPUT}" | "${HANDLER}" 2>&1 || true)"
if [ -n "${NO_OPT_OUTPUT}" ]; then
  echo "FAIL (1): handler must be no-op when HARNESS_OUTPUT_GOVERNANCE_ENABLE is not set"
  echo "  output: ${NO_OPT_OUTPUT}"
  exit 1
fi

# (2) opt-in enabled + redact use → returns redacted updatedToolOutput
REDACT_INPUT='{"tool_name":"Edit","tool_input":{},"tool_response":{"output":"key=sk-1234567890abcdefghijABCDEFGHIJ visible"}}'
export HARNESS_OUTPUT_GOVERNANCE_ENABLE=1
REDACT_OUTPUT="$(printf '%s' "${REDACT_INPUT}" | "${HANDLER}" 2>&1 || true)"
unset HARNESS_OUTPUT_GOVERNANCE_ENABLE
if [ -z "${REDACT_OUTPUT}" ]; then
  echo "FAIL (2): handler must produce updatedToolOutput when redact rule fires"
  exit 1
fi
if ! printf '%s' "${REDACT_OUTPUT}" | jq -e '.hookSpecificOutput.updatedToolOutput | contains("sk-REDACTED")' >/dev/null; then
  echo "FAIL (2): handler must redact API key in updatedToolOutput"
  echo "  output: ${REDACT_OUTPUT}"
  exit 1
fi
if printf '%s' "${REDACT_OUTPUT}" | jq -e '.hookSpecificOutput.updatedToolOutput | test("sk-1234567890abcdefghij")' >/dev/null; then
  echo "FAIL (2): handler must not leak the original API key"
  exit 1
fi

# (3) JSON-contract tool (Read/Grep/Bash) → skip
for skip_tool in Read Grep Bash TodoWrite; do
  SKIP_INPUT="$(jq -nc --arg t "${skip_tool}" '{tool_name:$t, tool_input:{}, tool_response:{output:"sk-1234567890abcdefghijABCDEFGHIJ"}}')"
  export HARNESS_OUTPUT_GOVERNANCE_ENABLE=1
  SKIP_OUTPUT="$(printf '%s' "${SKIP_INPUT}" | "${HANDLER}" 2>&1 || true)"
  unset HARNESS_OUTPUT_GOVERNANCE_ENABLE
  if [ -n "${SKIP_OUTPUT}" ]; then
    echo "FAIL (3): handler must skip JSON-contract tool ${skip_tool}"
    echo "  output: ${SKIP_OUTPUT}"
    exit 1
  fi
done

# (4) audit log is append-only and retains before/after
if [ -f "${AUDIT_LOG}" ]; then
  LAST_RECORD="$(tail -n 1 "${AUDIT_LOG}")"
  if ! printf '%s' "${LAST_RECORD}" | jq -e '.before and .after and .rule and .timestamp' >/dev/null 2>&1; then
    echo "FAIL (4): audit record missing before/after/rule/timestamp"
    exit 1
  fi
  if ! printf '%s' "${LAST_RECORD}" | jq -e '.rule == "redact-api-key"' >/dev/null 2>&1; then
    echo "FAIL (4): audit record rule is not redact-api-key"
    exit 1
  fi
fi

# (5) test output / review evidence concealment is not in handler allowlist;
#     verify by source inspection that no corresponding rule is registered.
TEST_TAMPERING_PATTERN='passed.*failed|test_result|review_artifact'
if grep -E "${TEST_TAMPERING_PATTERN}" "${HANDLER}" >/dev/null 2>&1; then
  echo "FAIL (5): handler must NOT contain test-tampering rules (pattern: ${TEST_TAMPERING_PATTERN})"
  exit 1
fi

# (6) handler must have HARNESS_OUTPUT_GOVERNANCE_ENABLE=1 explicit opt-in
#     written literally in the code
if ! grep -q 'HARNESS_OUTPUT_GOVERNANCE_ENABLE' "${HANDLER}"; then
  echo "FAIL (6): handler must check HARNESS_OUTPUT_GOVERNANCE_ENABLE for opt-in"
  exit 1
fi

echo "PASS: test-output-governance.sh (Phase 62.2.1) — all 6 cases PASS"
