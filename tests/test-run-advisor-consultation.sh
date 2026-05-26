#!/bin/bash
# test-run-advisor-consultation.sh
# Regression tests for the advisor consultation wrapper

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
WRAPPER="${PROJECT_ROOT}/scripts/run-advisor-consultation.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

pass() {
  echo "[PASS] $1"
}

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

cat > "${TMP_DIR}/request.json" <<'EOF'
{
  "schema_version": "advisor-request.v1",
  "task_id": "43.2.2",
  "reason_code": "retry-threshold",
  "trigger_hash": "43.2.2:retry-threshold:abc",
  "question": "The same failure occurred twice in a row. What should be changed next?",
  "attempt": 2,
  "last_error": "schema parse failed",
  "context_summary": ["implementing wrapper", "history append needed"]
}
EOF

cat > "${TMP_DIR}/fake-companion.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
MODE="${FAKE_ADVISOR_MODE:-PLAN}"
if [ "${1:-}" != "task" ]; then
  echo "unexpected subcommand: ${1:-}" >&2
  exit 2
fi
if [ -n "${FAKE_ADVISOR_CAPTURE_PROMPT:-}" ]; then
  cat > "${FAKE_ADVISOR_CAPTURE_PROMPT}"
else
  cat >/dev/null
fi
case "${MODE}" in
  PLAN)
    cat <<'JSON'
{"schema_version":"advisor-response.v1","decision":"PLAN","summary":"Reorder the steps","executor_instructions":["Fix status first"],"confidence":0.81,"stop_reason":null}
JSON
    ;;
  CORRECTION)
    cat <<'JSON'
{"schema_version":"advisor-response.v1","decision":"CORRECTION","summary":"A local fix is sufficient","executor_instructions":["Pass JSON validation first"],"confidence":0.72,"stop_reason":null}
JSON
    ;;
  STOP)
    cat <<'JSON'
{"schema_version":"advisor-response.v1","decision":"STOP","summary":"Stop here","executor_instructions":["Wait for user decision"],"confidence":0.93,"stop_reason":"dangerous-migration"}
JSON
    ;;
  INVALID)
    echo '{"schema_version":"advisor-response.v1","decision":"PLAN"'
    ;;
  TIMEOUT)
    sleep 3
    ;;
  TIMEOUT_WITH_OUTPUT)
    echo "partial stdout before timeout"
    echo "partial stderr before timeout" >&2
    sleep 3
    ;;
  *)
    echo "unknown mode: ${MODE}" >&2
    exit 2
    ;;
esac
EOF
chmod +x "${TMP_DIR}/fake-companion.sh"

run_case() {
  local mode="$1"
  local expected_decision="$2"
  local response_file="${TMP_DIR}/${mode}.response.json"
  local output_file="${TMP_DIR}/${mode}.stdout"
  CODEX_ADVISOR_COMPANION="${TMP_DIR}/fake-companion.sh" \
    FAKE_ADVISOR_MODE="${mode}" \
    bash "${WRAPPER}" \
      --request-file "${TMP_DIR}/request.json" \
      --response-file "${response_file}" \
      --model fake-model > "${output_file}"

  jq -e --arg decision "${expected_decision}" '.decision == $decision' "${response_file}" >/dev/null \
    || fail "${mode}: decision mismatch"
  grep -q "${expected_decision}" "${output_file}" || fail "${mode}: stdout missing response"
  pass "${mode}: decision ${expected_decision}"
}

run_case PLAN PLAN
run_case CORRECTION CORRECTION
run_case STOP STOP

set +e
CODEX_ADVISOR_COMPANION="${TMP_DIR}/fake-companion.sh" \
  FAKE_ADVISOR_MODE="INVALID" \
  bash "${WRAPPER}" \
    --request-file "${TMP_DIR}/request.json" \
    --response-file "${TMP_DIR}/invalid.response.json" >"${TMP_DIR}/invalid.stdout" 2>"${TMP_DIR}/invalid.stderr"
INVALID_EXIT=$?
set -e
[ "${INVALID_EXIT}" -ne 0 ] || fail "INVALID: wrapper should fail"
[ ! -f "${TMP_DIR}/invalid.response.json" ] || fail "INVALID: broken response file should not be written"
pass "INVALID: broken JSON rejected"

set +e
CODEX_ADVISOR_COMPANION="${TMP_DIR}/fake-companion.sh" \
  FAKE_ADVISOR_MODE="TIMEOUT" \
  bash "${WRAPPER}" \
    --request-file "${TMP_DIR}/request.json" \
    --response-file "${TMP_DIR}/timeout.response.json" \
    --timeout-sec 1 >"${TMP_DIR}/timeout.stdout" 2>"${TMP_DIR}/timeout.stderr"
TIMEOUT_EXIT=$?
set -e
[ "${TIMEOUT_EXIT}" -eq 124 ] || fail "TIMEOUT: expected exit 124 got ${TIMEOUT_EXIT}"
[ ! -f "${TMP_DIR}/timeout.response.json" ] || fail "TIMEOUT: timeout response file should not be written"
grep -q "timed out" "${TMP_DIR}/timeout.stderr" || fail "TIMEOUT: stderr should mention timeout"
pass "TIMEOUT: standardized timeout exit"

# Regression: when the subprocess emits output before the timeout fires,
# TimeoutExpired.stdout/stderr arrive as bytes even with text=True, and the
# old handler crashed with "TypeError: can't concat str to bytes".
set +e
CODEX_ADVISOR_COMPANION="${TMP_DIR}/fake-companion.sh" \
  FAKE_ADVISOR_MODE="TIMEOUT_WITH_OUTPUT" \
  bash "${WRAPPER}" \
    --request-file "${TMP_DIR}/request.json" \
    --response-file "${TMP_DIR}/timeout-output.response.json" \
    --timeout-sec 1 >"${TMP_DIR}/timeout-output.stdout" 2>"${TMP_DIR}/timeout-output.stderr"
TIMEOUT_OUTPUT_EXIT=$?
set -e
[ "${TIMEOUT_OUTPUT_EXIT}" -eq 124 ] || fail "TIMEOUT_WITH_OUTPUT: expected exit 124 got ${TIMEOUT_OUTPUT_EXIT}"
[ ! -f "${TMP_DIR}/timeout-output.response.json" ] || fail "TIMEOUT_WITH_OUTPUT: response file should not be written"
grep -q "timed out" "${TMP_DIR}/timeout-output.stderr" || fail "TIMEOUT_WITH_OUTPUT: stderr should mention timeout"
grep -qv "TypeError" "${TMP_DIR}/timeout-output.stderr" || fail "TIMEOUT_WITH_OUTPUT: stderr should not contain TypeError"
pass "TIMEOUT_WITH_OUTPUT: bytes output before timeout handled cleanly"

mkdir -p "${TMP_DIR}/project/.claude/state/elicitation"
cat > "${TMP_DIR}/project/.claude/state/elicitation/events.jsonl" <<'JSONL'
{"schema_version":"elicitation-event.v1","event_kind":"eval_result","run_id":"run-prior","task_id":"43.2.2","rubric_id":"reward-hacking-v1","reward_score":0.2,"verdict":"REQUEST_CHANGES","privacy_tags":["do_not_train"],"evidence_refs":["tests/fixture.log"],"source":"test","timestamp":"2026-05-06T00:00:00Z","message":"reward-hacking pattern: skipped test passed without evidence"}
JSONL

CODEX_ADVISOR_COMPANION="${TMP_DIR}/fake-companion.sh" \
  FAKE_ADVISOR_MODE="PLAN" \
  FAKE_ADVISOR_CAPTURE_PROMPT="${TMP_DIR}/captured-prompt.txt" \
  HARNESS_WEAK_SUPERVISION_PROJECT_ROOT="${TMP_DIR}/project" \
  bash "${WRAPPER}" \
    --request-file "${TMP_DIR}/request.json" \
    --response-file "${TMP_DIR}/cue.response.json" \
    --model fake-model > "${TMP_DIR}/cue.stdout"

grep -q "Weak-supervision cues from local elicitation ledger" "${TMP_DIR}/captured-prompt.txt" \
  || fail "advisor prompt should include weak-supervision cue header"
grep -q "reward-hacking pattern" "${TMP_DIR}/captured-prompt.txt" \
  || fail "advisor prompt should include prior failure cue"
pass "WEAK_SUPERVISION_CUE: injected into advisor prompt"

echo "test-run-advisor-consultation: ok"
