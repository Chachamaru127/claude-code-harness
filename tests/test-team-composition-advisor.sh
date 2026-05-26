#!/bin/bash
# test-team-composition-advisor.sh
# Consistency test for role-assignment documents including the Advisor

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

ADVISOR_FILE="${PROJECT_ROOT}/agents/advisor.md"
TEAM_FILE="${PROJECT_ROOT}/docs/team-composition.md"
WORKER_FILE="${PROJECT_ROOT}/agents/worker.md"
REVIEWER_FILE="${PROJECT_ROOT}/agents/reviewer.md"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

for file in "${ADVISOR_FILE}" "${TEAM_FILE}" "${WORKER_FILE}" "${REVIEWER_FILE}"; do
  [ -f "${file}" ] || fail "missing file: ${file}"
done

grep -q 'advisor-response.v1' "${ADVISOR_FILE}" \
  || fail "advisor.md is missing advisor-response.v1"

grep -q 'PLAN / CORRECTION / STOP' "${ADVISOR_FILE}" \
  || fail "advisor.md is missing the 3 decision types"

grep -q 'コードを書かない' "${ADVISOR_FILE}" \
  || fail "advisor.md is missing the no-implementation rule"

grep -q 'Harness の標準チーム構成は 5 ロール' "${TEAM_FILE}" \
  || fail "team-composition.md is missing the 5-role composition description"

grep -q 'permissionMode' "${TEAM_FILE}" \
  || fail "team-composition.md is missing the permissionMode boundary description"

grep -q '親セッションと plugin settings から継承' "${TEAM_FILE}" \
  || fail "team-composition.md is missing the permission inheritance description"

grep -q 'advisor-request.v1' "${WORKER_FILE}" \
  || fail "worker.md is missing advisor-request.v1"

grep -q 'Advisor は別ロールであり、Reviewer の代替ではない' "${REVIEWER_FILE}" \
  || fail "reviewer.md is missing the explicit statement that Advisor is not a replacement for Reviewer"

echo "test-team-composition-advisor: ok"
