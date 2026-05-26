#!/bin/bash
# test-advisor-config.sh
# Regression test for advisor config reading and state initialization

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_UTILS="${PROJECT_ROOT}/scripts/config-utils.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

pass() {
  echo "[PASS] $1"
}

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  if [ "${expected}" = "${actual}" ]; then
    pass "${label}"
  else
    fail "${label}: expected='${expected}' actual='${actual}'"
  fi
}

mkdir -p "${TMP_DIR}/project"
cat > "${TMP_DIR}/project/Plans.md" <<'EOF'
# Plans
EOF

cat > "${TMP_DIR}/project/AGENTS.md" <<'EOF'
# AGENTS
EOF

(
  cd "${TMP_DIR}/project"
  git init >/dev/null 2>&1
  git config user.email "advisor-config@example.com"
  git config user.name "Advisor Config Test"
)

(
  cd "${TMP_DIR}/project"
  PROJECT_ROOT="${TMP_DIR}/project"
  CONFIG_FILE="${TMP_DIR}/project/missing.yaml"
  # shellcheck disable=SC1090
  source "${CONFIG_UTILS}"

  assert_eq "true" "$(get_advisor_enabled)" "default advisor.enabled"
  assert_eq "on-demand" "$(get_advisor_mode)" "default advisor.mode"
  assert_eq "3" "$(get_advisor_max_consults_per_task)" "default advisor.max_consults_per_task"
  assert_eq "2" "$(get_advisor_retry_threshold)" "default advisor.retry_threshold"
  assert_eq "true" "$(get_advisor_consult_before_user_escalation)" "default advisor.consult_before_user_escalation"
  assert_eq "opus" "$(get_advisor_claude_model)" "default advisor.claude_model"
  assert_eq "gpt-5.4" "$(get_advisor_codex_model)" "default advisor.codex_model"
)

cat > "${TMP_DIR}/project/custom.yaml" <<'EOF'
plansDirectory: "."
advisor:
  enabled: false
  mode: always
  max_consults_per_task: 5
  retry_threshold: 4
  consult_before_user_escalation: false
  claude_model: opus-extended
  codex_model: gpt-5.5
EOF

(
  cd "${TMP_DIR}/project"
  PROJECT_ROOT="${TMP_DIR}/project"
  CONFIG_FILE="${TMP_DIR}/project/custom.yaml"
  # shellcheck disable=SC1090
  source "${CONFIG_UTILS}"

  assert_eq "false" "$(get_advisor_enabled)" "override advisor.enabled"
  assert_eq "always" "$(get_advisor_mode)" "override advisor.mode"
  assert_eq "5" "$(get_advisor_max_consults_per_task)" "override advisor.max_consults_per_task"
  assert_eq "4" "$(get_advisor_retry_threshold)" "override advisor.retry_threshold"
  assert_eq "false" "$(get_advisor_consult_before_user_escalation)" "override advisor.consult_before_user_escalation"
  assert_eq "opus-extended" "$(get_advisor_claude_model)" "override advisor.claude_model"
  assert_eq "gpt-5.5" "$(get_advisor_codex_model)" "override advisor.codex_model"

  ensure_advisor_state_files

  [ -d "${TMP_DIR}/project/.claude/state/advisor" ] || fail "advisor state dir created"
  [ -f "$(get_advisor_history_file)" ] || fail "advisor history file created"
  [ -f "$(get_advisor_last_request_file)" ] || fail "advisor last-request file created"
  [ -f "$(get_advisor_last_response_file)" ] || fail "advisor last-response file created"
  grep -q '^{}$' "$(get_advisor_last_request_file)" || fail "advisor last-request initialized"
  grep -q '^{}$' "$(get_advisor_last_response_file)" || fail "advisor last-response initialized"
  pass "advisor state files initialized"
)

echo "test-advisor-config: ok"
