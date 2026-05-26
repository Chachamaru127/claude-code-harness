#!/usr/bin/env bash
# test-hook-handler-session-id.sh
# Phase 62.2.4: session ID acquisition policy test for hook handler / Bash subprocess paths
#
# Verification points:
#   (1) hook handlers treat stdin JSON `.session_id` as SSOT
#   (2) no direct dependency on `CLAUDE_CODE_SESSION_ID` env var in hook handlers
#   (3) `docs/session-id-env-policy.md` describes 4 paths and 3 states
#   (4) naming convention compliance for 3 states (Healthy / NotConfigured / Corrupted)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POLICY_DOC="${ROOT_DIR}/docs/session-id-env-policy.md"

# (1) policy doc exists
[ -f "${POLICY_DOC}" ] || {
  echo "FAIL (1): ${POLICY_DOC} not found"
  exit 1
}

# (2) policy doc describes 4 paths
for path in 'stdin JSON' 'CLAUDE_CODE_SESSION_ID' 'session.json' 'CLAUDE_TRANSCRIPT_PATH'; do
  if ! grep -q "${path}" "${POLICY_DOC}"; then
    echo "FAIL (2): ${POLICY_DOC} missing '${path}'"
    exit 1
  fi
done

# (3) policy doc describes 3 states
for state in 'Healthy' 'NotConfigured' 'Corrupted'; do
  if ! grep -q "TestSessionIdEnv_${state}" "${POLICY_DOC}"; then
    echo "FAIL (3): ${POLICY_DOC} missing TestSessionIdEnv_${state}"
    exit 1
  fi
done

# (4) hook handlers that deal with session ID must use stdin JSON
HOOK_HANDLER_DIR="${ROOT_DIR}/scripts/hook-handlers"
HANDLERS_WITH_SESSION_ID="$(grep -l 'session_id' "${HOOK_HANDLER_DIR}"/*.sh 2>/dev/null | sort -u)"
if [ -z "${HANDLERS_WITH_SESSION_ID}" ]; then
  echo "WARN (4): no hook handler references session_id; skipping handler check"
else
  for handler in ${HANDLERS_WITH_SESSION_ID}; do
    # Each handler must obtain session_id via stdin JSON:
    # - uses jq or python json.loads
    # - references .session_id
    # (jq invocation may be multi-line (`jq -r '[ (.session_id // ""), ... ]'`),
    #  so both greps passing simultaneously confirms stdin JSON path)
    if ! grep -q 'jq\|json\.loads' "${handler}"; then
      echo "FAIL (4a): ${handler} references session_id but does not use jq or json.loads"
      exit 1
    fi
    if ! grep -q '\.session_id' "${handler}"; then
      echo "FAIL (4b): ${handler} references session_id but does not use .session_id selector"
      exit 1
    fi
  done
fi

# (5) hook handlers must not directly depend on CLAUDE_CODE_SESSION_ID env (stdin JSON is preferred)
# Exception: future helpers/wrappers may read the env. Current hook handlers fix
# stdin JSON as SSOT posture.
HANDLERS_USING_ENV="$(grep -l 'CLAUDE_CODE_SESSION_ID' "${HOOK_HANDLER_DIR}"/*.sh 2>/dev/null | sort -u || true)"
if [ -n "${HANDLERS_USING_ENV}" ]; then
  echo "FAIL (5): hook handlers should use stdin JSON, not CLAUDE_CODE_SESSION_ID env:"
  echo "${HANDLERS_USING_ENV}"
  echo "see ${POLICY_DOC} for the policy."
  exit 1
fi

# (6) Healthy / NotConfigured / Corrupted descriptions are present
grep -q 'env var present' "${POLICY_DOC}" || {
  echo "FAIL (6): policy doc missing Healthy state description"
  exit 1
}
grep -q 'env absent.*fall back to state file' "${POLICY_DOC}" || {
  echo "FAIL (6b): policy doc missing NotConfigured state description"
  exit 1
}
grep -q 'both env and state absent' "${POLICY_DOC}" || {
  echo "FAIL (6c): policy doc missing Corrupted state description"
  exit 1
}

echo "PASS: test-hook-handler-session-id.sh (Phase 62.2.4) — all 6 checks passed"
