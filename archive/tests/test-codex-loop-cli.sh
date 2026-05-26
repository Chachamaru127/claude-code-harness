#!/bin/bash
# test-codex-loop-cli.sh
# Codex-native long-running loop CLI の統合テスト

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOOP_SCRIPT="${REPO_ROOT}/scripts/codex-loop.sh"

PASS_COUNT=0
FAIL_COUNT=0

pass() {
  echo "[PASS] $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo "[FAIL] $1" >&2
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

cleanup_tmp() {
  local path="$1"
  local attempt=0
  while [ "${attempt}" -lt 10 ]; do
    rm -rf "${path}" 2>/dev/null && return 0
    sleep 0.2
    attempt=$((attempt + 1))
  done
  rm -rf "${path}"
}

setup_fake_tools() {
  local workdir="$1"
  local mode="$2"
  mkdir -p "${workdir}/bin"

  cat > "${workdir}/bin/fake-generate-contract.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
task_id="$1"
state_dir="${PROJECT_ROOT}/.claude/state/contracts"
mkdir -p "${state_dir}"
path="${state_dir}/${task_id}.sprint-contract.json"
advisor_json='{"enabled":false,"mode":"on-demand","max_consults":3,"retry_threshold":2,"pre_escalation_consult":true,"triggers":[],"model_policy":{"claude_default":"opus","codex_default":"gpt-5.4"}}'
if [ "${FAKE_ADVISOR_MODE:-off}" = "preflight" ]; then
  advisor_json='{"enabled":true,"mode":"on-demand","max_consults":3,"retry_threshold":2,"pre_escalation_consult":true,"triggers":["security-sensitive"],"model_policy":{"claude_default":"opus","codex_default":"gpt-5.4"}}'
elif [ "${FAKE_ADVISOR_MODE:-off}" = "retry" ]; then
  advisor_json='{"enabled":true,"mode":"on-demand","max_consults":3,"retry_threshold":2,"pre_escalation_consult":true,"triggers":[],"model_policy":{"claude_default":"opus","codex_default":"gpt-5.4"}}'
elif [ "${FAKE_ADVISOR_MODE:-off}" = "plateau" ]; then
  advisor_json='{"enabled":true,"mode":"on-demand","max_consults":3,"retry_threshold":2,"pre_escalation_consult":true,"triggers":[],"model_policy":{"claude_default":"opus","codex_default":"gpt-5.4"}}'
fi
cat > "${path}" <<JSON
{
  "task": { "id": "${task_id}", "title": "Task ${task_id}" },
  "review": { "status": "draft", "reviewer_profile": "static" },
  "advisor": ${advisor_json}
}
JSON
echo "${path}"
EOF

  cat > "${workdir}/bin/fake-enrich-contract.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "$1"
EOF

  cat > "${workdir}/bin/fake-ensure-contract.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
test -f "$1"
echo "$1"
EOF

  cat > "${workdir}/bin/fake-runtime-review.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
contract="$1"
output="$2"
cat > "${output}" <<JSON
{
  "schema_version": "runtime-review.v1",
  "task": { "id": "fake" },
  "reviewer_profile": "static",
  "verdict": "APPROVE",
  "checks": []
}
JSON
echo "${output}"
EOF

  cat > "${workdir}/bin/fake-write-review-result.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
input="$1"
commit_hash="$2"
output="$3"
cp "${input}" "${output}"
echo "${output}"
EOF

  cat > "${workdir}/bin/fake-plateau.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
if [ "${FAKE_PLATEAU_MODE:-normal}" = "pivot" ]; then
  echo "STATUS: PIVOT_REQUIRED"
  echo "ENTRIES: 3"
  echo "JACCARD_AVG: 0.9500"
  echo "REASON: plateau detected"
  exit 2
fi
echo "STATUS: PIVOT_NOT_REQUIRED"
echo "ENTRIES: 3"
echo "JACCARD_AVG: 0.1000"
echo "REASON: progress is fine"
exit 0
EOF

  cat > "${workdir}/bin/fake-checkpoint.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
touch "${PROJECT_ROOT}/.claude/state/checkpoint-called"
EOF

  cat > "${workdir}/bin/fake-validate.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
exit 0
EOF

  cat > "${workdir}/bin/fake-mem.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
echo '{"ok":true,"items":[]}'
EOF

  cat > "${workdir}/bin/codex" <<'EOF'
#!/bin/bash
set -euo pipefail
cmd="${1:-}"
shift || true
if [ "${cmd}" != "exec" ]; then
  echo "unknown fake codex command: ${cmd}" >&2
  exit 2
fi

case "${FAKE_CODEX_MODE:-success}" in
  fail)
    cat >/dev/null
    echo "fake codex failed" >&2
    exit 42
    ;;
  slow)
    if [ -n "${FAKE_CODEX_PID_FILE:-}" ]; then
      printf '%s\n' "$$" > "${FAKE_CODEX_PID_FILE}"
    fi
    trap 'if [ -n "${FAKE_CODEX_TERM_FILE:-}" ]; then echo terminated > "${FAKE_CODEX_TERM_FILE}"; fi; exit 143' TERM INT
    while true; do
      sleep 1
    done
    ;;
  success)
    cat >/dev/null
    echo "RESULT: BLOCKED"
    exit 0
    ;;
  *)
    echo "unknown FAKE_CODEX_MODE: ${FAKE_CODEX_MODE:-}" >&2
    exit 2
    ;;
esac
EOF

  cat > "${workdir}/bin/fake-advisor.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
request_file=""
response_file=""
while [ $# -gt 0 ]; do
  case "$1" in
    --request-file)
      request_file="${2:-}"
      shift 2
      ;;
    --response-file)
      response_file="${2:-}"
      shift 2
      ;;
    --model|--timeout-sec)
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
[ -n "${request_file}" ] || exit 2
[ -n "${response_file}" ] || exit 2
decision="${FAKE_ADVISOR_DECISION:-PLAN}"
stop_reason="null"
if [ "${decision}" = "STOP" ]; then
  stop_reason='"advisor-stop"'
fi
cat > "${response_file}" <<JSON
{
  "schema_version": "advisor-response.v1",
  "decision": "${decision}",
  "summary": "advisor ${decision}",
  "executor_instructions": ["follow advisor ${decision}"],
  "confidence": 0.9,
  "stop_reason": ${stop_reason}
}
JSON
cat "${response_file}"
EOF

  cat > "${workdir}/bin/fake-companion.sh" <<EOF
#!/bin/bash
set -euo pipefail
STATE_DIR="${workdir}/companion-state"
mkdir -p "\${STATE_DIR}"
JOB_FILE="\${STATE_DIR}/job.json"
COUNTER_FILE="\${STATE_DIR}/status-count"
PROMPT_FILE_STATE="\${STATE_DIR}/prompt-file"
MODE="${mode}"

read_json() {
  python3 - "\$1" <<'PY'
import json, os, sys
path = sys.argv[1]
if not os.path.exists(path):
    print("{}")
else:
    with open(path, "r", encoding="utf-8") as fh:
        print(json.dumps(json.load(fh)))
PY
}

write_job() {
  python3 - "\$JOB_FILE" "\$1" <<'PY'
import json, sys
path, status = sys.argv[1:3]
payload = {
  "id": "fake-job-1",
  "status": status,
  "title": "Codex Task",
  "phase": "running" if status == "running" else ("done" if status == "completed" else status)
}
with open(path, "w", encoding="utf-8") as fh:
    json.dump(payload, fh)
PY
}

complete_task() {
  python3 - "\${PROJECT_ROOT}/Plans.md" "\${PROMPT_FILE_STATE}" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
prompt_state = Path(sys.argv[2])
text = path.read_text(encoding="utf-8")
targets = []
if prompt_state.exists():
    prompt_path = Path(prompt_state.read_text(encoding="utf-8").strip())
    if prompt_path.exists():
        for line in prompt_path.read_text(encoding="utf-8").splitlines():
            if line.startswith("Target tasks:"):
                targets = [item.strip() for item in line.split(":", 1)[1].split(",") if item.strip()]
                break
if targets:
    lines = []
    for raw in text.splitlines():
        line = raw
        if line.startswith("|"):
            cells = [cell.strip() for cell in line.strip("|").split("|")]
            if cells and cells[0] in targets and "cc:完了" not in cells[-1]:
                line = raw.rsplit("|", 2)[0] + "| cc:完了 [fake] |"
        lines.append(line)
    text = "\n".join(lines) + ("\n" if text.endswith("\n") else "")
else:
    text = text.replace("cc:TODO", "cc:完了 [fake]", 1)
path.write_text(text, encoding="utf-8")
PY
  git -C "\${PROJECT_ROOT}" add Plans.md >/dev/null 2>&1
  git -C "\${PROJECT_ROOT}" commit -m "codex-loop test completion" >/dev/null 2>&1 || true
}

cmd="\${1:-}"
shift || true
case "\${cmd}" in
  task)
    prompt_file=""
    while [ \$# -gt 0 ]; do
      case "\$1" in
        --prompt-file)
          prompt_file="\${2:-}"
          shift 2
          ;;
        *)
          shift
          ;;
      esac
    done
    if [ -n "\${FAKE_COMPANION_TASK_STDERR:-}" ]; then
      echo "fake guard message on stderr" >&2
    fi
    printf '%s\n' "\${prompt_file}" > "\${PROMPT_FILE_STATE}"
    write_job "queued"
    printf '0' > "\${COUNTER_FILE}"
    printf '{"jobId":"fake-job-1","status":"queued","title":"Codex Task","logFile":"%s"}\n' "\${STATE_DIR}/job.log"
    ;;
  status)
    job_id="\${1:-}"
    shift || true
    count=0
    if [ -f "\${COUNTER_FILE}" ]; then
      count="\$(cat "\${COUNTER_FILE}")"
    fi
    if [ "\${MODE}" = "complete" ] || [ "\${MODE}" = "advisor-preflight" ]; then
      if [ "\${count}" = "0" ]; then
        write_job "running"
        printf '1' > "\${COUNTER_FILE}"
        printf '{"workspaceRoot":"%s","job":{"id":"fake-job-1","status":"running","phase":"running","title":"Codex Task"}}\n' "\${PROJECT_ROOT}"
      else
        complete_task
        write_job "completed"
        printf '2' > "\${COUNTER_FILE}"
        printf '{"workspaceRoot":"%s","job":{"id":"fake-job-1","status":"completed","phase":"done","title":"Codex Task"}}\n' "\${PROJECT_ROOT}"
      fi
    elif [ "\${MODE}" = "retry" ]; then
      write_job "completed"
      printf '{"workspaceRoot":"%s","job":{"id":"fake-job-1","status":"completed","phase":"done","title":"Codex Task"}}\n' "\${PROJECT_ROOT}"
    else
      if [ -f "\${STATE_DIR}/cancelled" ]; then
        write_job "cancelled"
        printf '{"workspaceRoot":"%s","job":{"id":"fake-job-1","status":"cancelled","phase":"cancelled","title":"Codex Task"}}\n' "\${PROJECT_ROOT}"
      else
        write_job "running"
        printf '{"workspaceRoot":"%s","job":{"id":"fake-job-1","status":"running","phase":"running","title":"Codex Task"}}\n' "\${PROJECT_ROOT}"
      fi
    fi
    ;;
  result)
    status="completed"
    if [ -f "\${STATE_DIR}/cancelled" ]; then
      status="cancelled"
    fi
    if [ "\${MODE}" = "retry" ] && [ "\${status}" = "completed" ]; then
      printf '{"job":{"id":"fake-job-1","status":"completed","title":"Codex Task"},"storedJob":{"status":"completed","result":{"rawOutput":"RESULT: BLOCKED\\nsummary"}}}\n'
    else
      printf '{"job":{"id":"fake-job-1","status":"%s","title":"Codex Task"},"storedJob":{"status":"%s","result":{"rawOutput":"RESULT: %s\\nsummary"}}}\n' "\${status}" "\${status}" "\$( [ "\${status}" = "completed" ] && echo APPROVED || echo BLOCKED )"
    fi
    ;;
  cancel)
    touch "\${STATE_DIR}/cancelled"
    write_job "cancelled"
    printf '{"jobId":"fake-job-1","status":"cancelled","title":"Codex Task"}\n'
    ;;
  *)
    echo "unknown fake companion command: \${cmd}" >&2
    exit 1
    ;;
esac
EOF

  chmod +x "${workdir}"/bin/fake-*.sh "${workdir}/bin/codex"
}

setup_repo() {
  local repo="$1"
  mkdir -p "${repo}/.claude/state"
  cat > "${repo}/Plans.md" <<'EOF'
# Plans

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 1 | fake task | done | - | cc:TODO |
EOF
  git -C "${repo}" init >/dev/null 2>&1
  git -C "${repo}" config user.email "loop-test@example.com"
  git -C "${repo}" config user.name "Loop Test"
  git -C "${repo}" add Plans.md
  git -C "${repo}" commit -m "initial" >/dev/null 2>&1
}

setup_local_worker_job() {
  local repo="$1"
  local job_id="$2"
  local prompt_file="${repo}/.claude/state/codex-loop/prompts/${job_id}.md"
  local job_file="${repo}/.claude/state/codex-loop/jobs/${job_id}.json"
  local log_file="${repo}/.claude/state/codex-loop/jobs/${job_id}.log"
  local output_file="${repo}/.claude/state/codex-loop/jobs/${job_id}.out"

  mkdir -p "${repo}/.claude/state/codex-loop/prompts" "${repo}/.claude/state/codex-loop/jobs"
  printf 'fake prompt\n' > "${prompt_file}"
  : > "${log_file}"
  : > "${output_file}"
  cat > "${job_file}" <<EOF
{
  "id": "${job_id}",
  "status": "queued",
  "phase": "queued",
  "title": "Codex Task",
  "summary": "fake prompt",
  "workspaceRoot": "${repo}",
  "jobClass": "task",
  "write": true,
  "logFile": "${log_file}",
  "request": {
    "cwd": "${repo}",
    "promptFile": "${prompt_file}"
  }
}
EOF
}

setup_named_repo() {
  local repo="$1"
  mkdir -p "${repo}/.claude/state"
  cat > "${repo}/Plans.md" <<'EOF'
# Plans

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| JLB3R-01 | done task | done | - | cc:完了 [seed] |
| JLB3R-02 | fake task 02 | done | - | cc:TODO |
| JLB3R-03 | fake task 03 | done | - | cc:TODO |
| JLB3R-08 | fake task 08 | done | - | cc:TODO |
EOF
  git -C "${repo}" init >/dev/null 2>&1
  git -C "${repo}" config user.email "loop-test@example.com"
  git -C "${repo}" config user.name "Loop Test"
  git -C "${repo}" add Plans.md
  git -C "${repo}" commit -m "initial" >/dev/null 2>&1
}

setup_heading_repo() {
  local repo="$1"
  mkdir -p "${repo}/.claude/state"
  cat > "${repo}/Plans.md" <<'EOF'
# Plans

#### 6G-6: Mount Mode 音声ルーティング UI / 構成チェック `cc:TODO`

- [ ] 自分にも音を聞かせるための出力先を UI で選べるようにする
- [ ] 起動前チェックで AI が聞ける / 自分が聞ける / LINE に返せるを判定する
Depends: 6G-1, 6G-2
EOF
  git -C "${repo}" init >/dev/null 2>&1
  git -C "${repo}" config user.email "loop-test@example.com"
  git -C "${repo}" config user.name "Loop Test"
  git -C "${repo}" add Plans.md
  git -C "${repo}" commit -m "initial" >/dev/null 2>&1
}

setup_batch_repo() {
  local repo="$1"
  mkdir -p "${repo}/.claude/state"
  cat > "${repo}/Plans.md" <<'EOF'
# Plans

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 1 | ready task 1 | done | - | cc:TODO |
| 2 | ready task 2 | done | - | cc:TODO |
| 3 | dependent task 3 | done | 1 | cc:TODO |
EOF
  git -C "${repo}" init >/dev/null 2>&1
  git -C "${repo}" config user.email "loop-test@example.com"
  git -C "${repo}" config user.name "Loop Test"
  git -C "${repo}" add Plans.md
  git -C "${repo}" commit -m "initial" >/dev/null 2>&1
}

setup_cross_repo_cli() {
  local install_root="$1"
  mkdir -p "${install_root}/bin"
  cp -R "${REPO_ROOT}/scripts" "${install_root}/scripts"
  cp "${REPO_ROOT}/bin/harness" "${install_root}/bin/harness"
  (
    cd "${REPO_ROOT}/go" && \
    go build -o "${install_root}/bin/harness-$(go env GOOS)-$(go env GOARCH)" ./cmd/harness
  )
}

poll_for_status() {
  local run_json="$1"
  local expected="$2"
  local tries=0
  local max_tries="${CODEX_LOOP_TEST_POLL_TRIES:-160}"
  while [ "${tries}" -lt "${max_tries}" ]; do
    if [ -f "${run_json}" ]; then
      local status
      status="$(python3 - "${run_json}" <<'PY'
import json, sys
with open(sys.argv[1], "r", encoding="utf-8") as fh:
    print(json.load(fh).get("status", ""))
PY
)"
      if [ "${status}" = "${expected}" ]; then
        return 0
      fi
    fi
    sleep 0.2
    tries=$((tries + 1))
  done
  return 1
}

run_local_worker_failure_case() {
  local tmp
  tmp="$(mktemp -d)"
  local repo="${tmp}/repo"
  local job_id="local-fail-job"
  mkdir -p "${repo}"
  setup_fake_tools "${tmp}" "complete"
  setup_local_worker_job "${repo}" "${job_id}"

  local status=0
  set +e
  PROJECT_ROOT="${repo}" \
  PATH="${tmp}/bin:${PATH}" \
  FAKE_CODEX_MODE=fail \
  bash "${LOOP_SCRIPT}" local-task-worker --job-id "${job_id}" >/dev/null 2>&1
  status=$?
  set -e

  if [ "${status}" -eq 42 ]; then
    pass "local worker failure: codex exec exit status propagated"
  else
    fail "local worker failure: codex exec exit status was not propagated"
  fi

  jq -e '.status == "failed" and .phase == "failed" and .pid == null and .childPid == null and .result.status == 42' \
    "${repo}/.claude/state/codex-loop/jobs/${job_id}.json" >/dev/null \
    && pass "local worker failure: job recorded failed state" \
    || fail "local worker failure: job did not record failed state"

  cleanup_tmp "${tmp}"
}

run_local_worker_cancel_case() {
  local tmp
  tmp="$(mktemp -d)"
  local repo="${tmp}/repo"
  local job_id="local-cancel-job"
  local worker_pid=""
  local codex_pid_file="${tmp}/codex.pid"
  local codex_term_file="${tmp}/codex-terminated"
  mkdir -p "${repo}"
  setup_fake_tools "${tmp}" "complete"
  setup_local_worker_job "${repo}" "${job_id}"
  cat > "${repo}/.claude/state/codex-loop/run.json" <<EOF
{
  "schema_version": "codex-loop-run.v1",
  "run_id": "local-cancel-run",
  "status": "running",
  "current_job_id": "${job_id}"
}
EOF

  PROJECT_ROOT="${repo}" \
  PATH="${tmp}/bin:${PATH}" \
  FAKE_CODEX_MODE=slow \
  FAKE_CODEX_PID_FILE="${codex_pid_file}" \
  FAKE_CODEX_TERM_FILE="${codex_term_file}" \
  bash "${LOOP_SCRIPT}" local-task-worker --job-id "${job_id}" >/dev/null 2>&1 &
  worker_pid=$!

  local tries=0
  while [ "${tries}" -lt 40 ]; do
    if jq -e '.childPid != null' "${repo}/.claude/state/codex-loop/jobs/${job_id}.json" >/dev/null 2>&1; then
      break
    fi
    sleep 0.1
    tries=$((tries + 1))
  done

  PROJECT_ROOT="${repo}" \
  PATH="${tmp}/bin:${PATH}" \
  bash "${LOOP_SCRIPT}" stop >/dev/null

  wait "${worker_pid}" 2>/dev/null || true

  if [ -f "${codex_term_file}" ]; then
    pass "local worker cancel: child codex process received termination"
  else
    fail "local worker cancel: child codex process was not terminated"
  fi

  if [ -f "${codex_pid_file}" ] && ! kill -0 "$(cat "${codex_pid_file}")" 2>/dev/null; then
    pass "local worker cancel: child codex process exited"
  else
    fail "local worker cancel: child codex process is still alive"
  fi

  jq -e '.status == "cancelled" and .phase == "cancelled" and .pid == null and .childPid == null' \
    "${repo}/.claude/state/codex-loop/jobs/${job_id}.json" >/dev/null \
    && pass "local worker cancel: job preserved cancelled state" \
    || fail "local worker cancel: job did not preserve cancelled state"

  cleanup_tmp "${tmp}"
}

run_completion_case() {
  local tmp
  tmp="$(mktemp -d)"
  local repo="${tmp}/repo"
  mkdir -p "${repo}"
  setup_repo "${repo}"
  setup_fake_tools "${tmp}" "complete"

  PROJECT_ROOT="${repo}" \
  CODEX_LOOP_TASK_DRIVER=companion \
  CODEX_LOOP_COMPANION="${tmp}/bin/fake-companion.sh" \
  CODEX_LOOP_VALIDATE_SCRIPT="${tmp}/bin/fake-validate.sh" \
  CODEX_LOOP_ENRICH_CONTRACT_SCRIPT="${tmp}/bin/fake-enrich-contract.sh" \
  CODEX_LOOP_ENSURE_CONTRACT_SCRIPT="${tmp}/bin/fake-ensure-contract.sh" \
  CODEX_LOOP_RUNTIME_REVIEW_SCRIPT="${tmp}/bin/fake-runtime-review.sh" \
  CODEX_LOOP_WRITE_REVIEW_RESULT_SCRIPT="${tmp}/bin/fake-write-review-result.sh" \
  CODEX_LOOP_PLATEAU_SCRIPT="${tmp}/bin/fake-plateau.sh" \
  CODEX_LOOP_CHECKPOINT_SCRIPT="${tmp}/bin/fake-checkpoint.sh" \
  CODEX_LOOP_MEM_CLIENT="${tmp}/bin/fake-mem.sh" \
  CODEX_LOOP_GENERATE_CONTRACT_SCRIPT="${tmp}/bin/fake-generate-contract.sh" \
  CODEX_LOOP_POLL_INTERVAL_SEC=1 \
  bash "${LOOP_SCRIPT}" start all --max-cycles 1 --pacing worker >/dev/null

  if poll_for_status "${repo}/.claude/state/codex-loop/run.json" "completed"; then
    pass "completion case: run finished"
  else
    fail "completion case: run did not finish"
  fi

  if grep -q 'cc:完了' "${repo}/Plans.md"; then
    pass "completion case: Plans.md updated"
  else
    fail "completion case: Plans.md was not updated"
  fi

  if [ -f "${repo}/.claude/state/checkpoint-called" ]; then
    pass "completion case: checkpoint executed"
  else
    fail "completion case: checkpoint was not executed"
  fi

  cleanup_tmp "${tmp}"
}

run_stop_case() {
  local tmp
  tmp="$(mktemp -d)"
  local repo="${tmp}/repo"
  mkdir -p "${repo}"
  setup_repo "${repo}"
  setup_fake_tools "${tmp}" "stall"

  PROJECT_ROOT="${repo}" \
  CODEX_LOOP_TASK_DRIVER=companion \
  CODEX_LOOP_COMPANION="${tmp}/bin/fake-companion.sh" \
  CODEX_LOOP_VALIDATE_SCRIPT="${tmp}/bin/fake-validate.sh" \
  CODEX_LOOP_ENRICH_CONTRACT_SCRIPT="${tmp}/bin/fake-enrich-contract.sh" \
  CODEX_LOOP_ENSURE_CONTRACT_SCRIPT="${tmp}/bin/fake-ensure-contract.sh" \
  CODEX_LOOP_RUNTIME_REVIEW_SCRIPT="${tmp}/bin/fake-runtime-review.sh" \
  CODEX_LOOP_WRITE_REVIEW_RESULT_SCRIPT="${tmp}/bin/fake-write-review-result.sh" \
  CODEX_LOOP_PLATEAU_SCRIPT="${tmp}/bin/fake-plateau.sh" \
  CODEX_LOOP_CHECKPOINT_SCRIPT="${tmp}/bin/fake-checkpoint.sh" \
  CODEX_LOOP_MEM_CLIENT="${tmp}/bin/fake-mem.sh" \
  CODEX_LOOP_GENERATE_CONTRACT_SCRIPT="${tmp}/bin/fake-generate-contract.sh" \
  CODEX_LOOP_POLL_INTERVAL_SEC=1 \
  bash "${LOOP_SCRIPT}" start all --max-cycles 2 --pacing worker >/dev/null

  sleep 1
  PROJECT_ROOT="${repo}" \
  CODEX_LOOP_TASK_DRIVER=companion \
  CODEX_LOOP_COMPANION="${tmp}/bin/fake-companion.sh" \
  bash "${LOOP_SCRIPT}" stop >/dev/null

  if poll_for_status "${repo}/.claude/state/codex-loop/run.json" "stopped"; then
    pass "stop case: run stopped"
  else
    fail "stop case: run did not stop"
  fi

  if [ -f "${tmp}/companion-state/cancelled" ]; then
    pass "stop case: active job was cancelled"
  else
    fail "stop case: cancel was not sent to companion"
  fi

  cleanup_tmp "${tmp}"
}

run_cross_repo_case() {
  local tmp
  tmp="$(mktemp -d)"
  local repo="${tmp}/repo"
  local install_root="${tmp}/install"
  mkdir -p "${repo}"
  setup_repo "${repo}"
  setup_fake_tools "${tmp}" "complete"
  setup_cross_repo_cli "${install_root}"

  (
    cd "${repo}" && \
    CODEX_LOOP_TASK_DRIVER=companion \
    CODEX_LOOP_COMPANION="${tmp}/bin/fake-companion.sh" \
    CODEX_LOOP_CHECKPOINT_SCRIPT="${tmp}/bin/fake-checkpoint.sh" \
    CODEX_LOOP_POLL_INTERVAL_SEC=1 \
    "${install_root}/bin/harness" codex-loop start all --max-cycles 1 --pacing worker --executor task >/dev/null
  )

  if poll_for_status "${repo}/.claude/state/codex-loop/run.json" "completed"; then
    pass "cross-repo case: harness codex-loop completed from sibling repo"
  else
    fail "cross-repo case: harness codex-loop did not complete from sibling repo"
  fi

  if grep -q 'cc:完了' "${repo}/Plans.md"; then
    pass "cross-repo case: target repo Plans.md updated"
  else
    fail "cross-repo case: target repo Plans.md was not updated"
  fi

  cleanup_tmp "${tmp}"
}

run_state_corrupt_case() {
  local tmp
  tmp="$(mktemp -d)"
  local repo="${tmp}/repo"
  mkdir -p "${repo}/.claude/state/codex-loop"
  cat > "${repo}/.claude/state/codex-loop/run.json" <<'EOF'
{ invalid json
EOF

  local output
  output="$(PROJECT_ROOT="${repo}" bash "${LOOP_SCRIPT}" status --json)"

  if echo "${output}" | jq -e '.status == "state_corrupt" and .run == null and .current_job == null' >/dev/null; then
    pass "state corrupt case: status --json reports state_corrupt"
  else
    fail "state corrupt case: status --json did not report state_corrupt"
  fi

  cleanup_tmp "${tmp}"
}

run_startup_failure_case() {
  local tmp
  tmp="$(mktemp -d)"
  local repo="${tmp}/repo"
  mkdir -p "${repo}"
  setup_repo "${repo}"
  setup_fake_tools "${tmp}" "complete"

  local output=""
  local status=0
  set +e
  output="$(
    PROJECT_ROOT="${repo}" \
    CODEX_LOOP_TASK_DRIVER=companion \
    CODEX_LOOP_COMPANION="${tmp}/bin/fake-companion.sh" \
    CODEX_LOOP_VALIDATE_SCRIPT="${tmp}/bin/fake-validate.sh" \
    CODEX_LOOP_ENRICH_CONTRACT_SCRIPT="${tmp}/bin/fake-enrich-contract.sh" \
    CODEX_LOOP_ENSURE_CONTRACT_SCRIPT="${tmp}/bin/fake-ensure-contract.sh" \
    CODEX_LOOP_RUNTIME_REVIEW_SCRIPT="${tmp}/bin/fake-runtime-review.sh" \
    CODEX_LOOP_WRITE_REVIEW_RESULT_SCRIPT="${tmp}/bin/fake-write-review-result.sh" \
    CODEX_LOOP_PLATEAU_SCRIPT="${tmp}/bin/fake-plateau.sh" \
    CODEX_LOOP_CHECKPOINT_SCRIPT="${tmp}/bin/fake-checkpoint.sh" \
    CODEX_LOOP_MEM_CLIENT="${tmp}/bin/fake-mem.sh" \
    CODEX_LOOP_GENERATE_CONTRACT_SCRIPT="/bin/false" \
    CODEX_LOOP_STARTUP_CHECKS=120 \
    CODEX_LOOP_STARTUP_INTERVAL_SEC=0.05 \
    bash "${LOOP_SCRIPT}" start all --max-cycles 1 --pacing worker --executor task 2>&1
  )"
  status=$?
  set -e

  if [ "${status}" -ne 0 ] && \
     printf '%s' "${output}" | grep -q 'Failed to start codex-loop' && \
     ! printf '%s' "${output}" | grep -q 'Started codex-loop'; then
    pass "startup failure case: start fails instead of printing success"
  else
    fail "startup failure case: start did not fail fast"
  fi

  if jq -e '.status == "startup_failed" and (.error_message | contains("runner log tail"))' \
    "${repo}/.claude/state/codex-loop/run.json" >/dev/null; then
    pass "startup failure case: run state records startup_failed with log tail"
  else
    fail "startup failure case: run state did not preserve startup failure"
  fi

  if [ ! -d "${repo}/.claude/state/locks/codex-loop.lock.d" ]; then
    pass "startup failure case: stale startup lock was released"
  else
    fail "startup failure case: lock remained after startup failure"
  fi

  cleanup_tmp "${tmp}"
}

run_state_stale_log_tail_case() {
  local tmp
  tmp="$(mktemp -d)"
  local repo="${tmp}/repo"
  mkdir -p "${repo}/.claude/state/codex-loop"
  cat > "${repo}/.claude/state/codex-loop/run.json" <<'EOF'
{
  "schema_version": "codex-loop-run.v1",
  "run_id": "codex-loop-stale-fixture",
  "selection": "all",
  "max_cycles": 1,
  "status": "running",
  "pid": 99999999
}
EOF
  cat > "${repo}/.claude/state/codex-loop/runner.log" <<'EOF'
[fixture] starting runner
[fixture] early startup boom
EOF

  local output
  output="$(PROJECT_ROOT="${repo}" bash "${LOOP_SCRIPT}" status --json)"

  if printf '%s' "${output}" \
    | jq -e '.run.status == "state_stale" and (.run.error_message | contains("early startup boom"))' >/dev/null; then
    pass "state stale case: status includes runner log tail"
  else
    fail "state stale case: status did not include runner log tail"
  fi

  cleanup_tmp "${tmp}"
}

run_runner_lost_active_job_status_and_stop_case() {
  local tmp
  tmp="$(mktemp -d)"
  local repo="${tmp}/repo"
  mkdir -p "${repo}/.claude/state/codex-loop"
  setup_fake_tools "${tmp}" "stall"
  cat > "${repo}/.claude/state/codex-loop/run.json" <<EOF
{
  "schema_version": "codex-loop-run.v1",
  "run_id": "codex-loop-lost-job-fixture",
  "selection": "all",
  "max_cycles": 1,
  "task_driver": "companion",
  "companion_path": "${tmp}/bin/fake-companion.sh",
  "status": "running",
  "pid": 99999999,
  "current_task_id": "1",
  "current_cycle": 1,
  "current_job_id": "fake-job-1",
  "current_job_status": "running",
  "current_job_phase": "running"
}
EOF
  cat > "${repo}/.claude/state/codex-loop/current-job.json" <<'EOF'
{
  "run_id": "codex-loop-lost-job-fixture",
  "cycle": 1,
  "task_id": "1",
  "job_id": "fake-job-1"
}
EOF
  cat > "${repo}/.claude/state/codex-loop/runner.log" <<'EOF'
[fixture] launched fake-job-1
[fixture] runner disappeared before polling finished
EOF

  local output
  output="$(
    PROJECT_ROOT="${repo}" \
    CODEX_LOOP_TASK_DRIVER=companion \
    CODEX_LOOP_COMPANION="${tmp}/bin/fake-companion.sh" \
    bash "${LOOP_SCRIPT}" status --json
  )"

  if printf '%s' "${output}" | jq -e '.run.status == "runner_lost_job_running" and .run.current_job_id == "fake-job-1" and (.run.error_message | contains("active job fake-job-1"))' >/dev/null; then
    pass "runner lost active job: status reports dedicated state"
  else
    fail "runner lost active job: status did not report dedicated state"
  fi

  PROJECT_ROOT="${repo}" bash "${LOOP_SCRIPT}" stop >/dev/null

  if [ -f "${tmp}/companion-state/cancelled" ]; then
    pass "runner lost active job: stop cancels active companion job"
  else
    fail "runner lost active job: stop did not cancel active companion job"
  fi

  if jq -e '.status == "stopped" and .exit_reason == "user_stop" and .last_cancelled_job_id == "fake-job-1"' \
    "${repo}/.claude/state/codex-loop/run.json" >/dev/null; then
    pass "runner lost active job: stop reconciles stale run state"
  else
    fail "runner lost active job: stop did not reconcile stale run state"
  fi

  cleanup_tmp "${tmp}"
}

run_runner_lost_cancel_failure_case() {
  local tmp
  tmp="$(mktemp -d)"
  local repo="${tmp}/repo"
  mkdir -p "${repo}/.claude/state/codex-loop"
  cat > "${repo}/.claude/state/codex-loop/run.json" <<EOF
{
  "schema_version": "codex-loop-run.v1",
  "run_id": "codex-loop-cancel-fail-fixture",
  "selection": "all",
  "max_cycles": 1,
  "task_driver": "companion",
  "companion_path": "/bin/false",
  "status": "running",
  "pid": 99999999,
  "current_task_id": "1",
  "current_cycle": 1,
  "current_job_id": "fake-job-1",
  "current_job_status": "running",
  "current_job_phase": "running"
}
EOF
  cat > "${repo}/.claude/state/codex-loop/current-job.json" <<'EOF'
{
  "run_id": "codex-loop-cancel-fail-fixture",
  "cycle": 1,
  "task_id": "1",
  "job_id": "fake-job-1",
  "task_driver": "companion",
  "companion_path": "/bin/false"
}
EOF

  local status=0
  set +e
  PROJECT_ROOT="${repo}" bash "${LOOP_SCRIPT}" stop >/dev/null 2>&1
  status=$?
  set -e

  if [ "${status}" -ne 0 ]; then
    pass "runner lost cancel failure: stop returns failure when cancel fails"
  else
    fail "runner lost cancel failure: stop falsely succeeded"
  fi

  if jq -e '.status == "runner_lost_job_running" and .exit_reason == "stop_cancel_failed" and .current_job_status == "cancel_failed" and .last_cancel_exit_status != 0 and .current_job_id == "fake-job-1"' \
    "${repo}/.claude/state/codex-loop/run.json" >/dev/null; then
    pass "runner lost cancel failure: active job remains unreconciled"
  else
    fail "runner lost cancel failure: state falsely reconciled failed cancellation"
  fi

  cleanup_tmp "${tmp}"
}

run_runner_failure_cancels_active_job_case() {
  local tmp
  tmp="$(mktemp -d)"
  local repo="${tmp}/repo"
  mkdir -p "${repo}"
  setup_repo "${repo}"
  setup_fake_tools "${tmp}" "stall"

  set +e
  PROJECT_ROOT="${repo}" \
  CODEX_LOOP_TASK_DRIVER=companion \
  CODEX_LOOP_COMPANION="${tmp}/bin/fake-companion.sh" \
  CODEX_LOOP_VALIDATE_SCRIPT="${tmp}/bin/fake-validate.sh" \
  CODEX_LOOP_ENRICH_CONTRACT_SCRIPT="${tmp}/bin/fake-enrich-contract.sh" \
  CODEX_LOOP_ENSURE_CONTRACT_SCRIPT="${tmp}/bin/fake-ensure-contract.sh" \
  CODEX_LOOP_RUNTIME_REVIEW_SCRIPT="${tmp}/bin/fake-runtime-review.sh" \
  CODEX_LOOP_WRITE_REVIEW_RESULT_SCRIPT="${tmp}/bin/fake-write-review-result.sh" \
  CODEX_LOOP_PLATEAU_SCRIPT="${tmp}/bin/fake-plateau.sh" \
  CODEX_LOOP_CHECKPOINT_SCRIPT="${tmp}/bin/fake-checkpoint.sh" \
  CODEX_LOOP_MEM_CLIENT="${tmp}/bin/fake-mem.sh" \
  CODEX_LOOP_GENERATE_CONTRACT_SCRIPT="${tmp}/bin/fake-generate-contract.sh" \
  CODEX_LOOP_POLL_INTERVAL_SEC=not-a-number \
  CODEX_LOOP_STARTUP_CHECKS=40 \
  CODEX_LOOP_STARTUP_INTERVAL_SEC=0.05 \
  bash "${LOOP_SCRIPT}" start all --max-cycles 1 --pacing worker --executor task >/dev/null 2>&1
  set -e

  poll_for_status "${repo}/.claude/state/codex-loop/run.json" "failed" || fail "runner failure cancel: run should fail"

  if [ -f "${tmp}/companion-state/cancelled" ]; then
    pass "runner failure cancel: active companion job was cancelled"
  else
    fail "runner failure cancel: active companion job was orphaned"
  fi

  jq -e '.status == "failed" and .exit_reason == "runner_exit" and (.error_message | contains("exit=1")) and .last_cancelled_job_id == "fake-job-1"' \
    "${repo}/.claude/state/codex-loop/run.json" >/dev/null \
    && pass "runner failure cancel: run records explicit failure" \
    || fail "runner failure cancel: run did not record explicit failure"

  cleanup_tmp "${tmp}"
}

run_companion_stderr_json_case() {
  local tmp
  tmp="$(mktemp -d)"
  local repo="${tmp}/repo"
  mkdir -p "${repo}"
  setup_repo "${repo}"
  setup_fake_tools "${tmp}" "complete"

  PROJECT_ROOT="${repo}" \
  CODEX_LOOP_TASK_DRIVER=companion \
  CODEX_LOOP_COMPANION="${tmp}/bin/fake-companion.sh" \
  CODEX_LOOP_VALIDATE_SCRIPT="${tmp}/bin/fake-validate.sh" \
  CODEX_LOOP_ENRICH_CONTRACT_SCRIPT="${tmp}/bin/fake-enrich-contract.sh" \
  CODEX_LOOP_ENSURE_CONTRACT_SCRIPT="${tmp}/bin/fake-ensure-contract.sh" \
  CODEX_LOOP_RUNTIME_REVIEW_SCRIPT="${tmp}/bin/fake-runtime-review.sh" \
  CODEX_LOOP_WRITE_REVIEW_RESULT_SCRIPT="${tmp}/bin/fake-write-review-result.sh" \
  CODEX_LOOP_PLATEAU_SCRIPT="${tmp}/bin/fake-plateau.sh" \
  CODEX_LOOP_CHECKPOINT_SCRIPT="${tmp}/bin/fake-checkpoint.sh" \
  CODEX_LOOP_MEM_CLIENT="${tmp}/bin/fake-mem.sh" \
  CODEX_LOOP_GENERATE_CONTRACT_SCRIPT="${tmp}/bin/fake-generate-contract.sh" \
  CODEX_LOOP_POLL_INTERVAL_SEC=1 \
  FAKE_COMPANION_TASK_STDERR=1 \
  bash "${LOOP_SCRIPT}" start all --max-cycles 1 --pacing worker --executor task >/dev/null

  poll_for_status "${repo}/.claude/state/codex-loop/run.json" "completed" \
    && pass "companion stderr case: launch JSON parsed from stdout only" \
    || fail "companion stderr case: stderr guard output broke launch JSON parsing"

  cleanup_tmp "${tmp}"
}

run_plain_status_case() {
  local tmp
  tmp="$(mktemp -d)"
  local repo="${tmp}/repo"
  mkdir -p "${repo}"
  setup_repo "${repo}"
  setup_fake_tools "${tmp}" "complete"

  PROJECT_ROOT="${repo}" \
  CODEX_LOOP_TASK_DRIVER=companion \
  CODEX_LOOP_COMPANION="${tmp}/bin/fake-companion.sh" \
  CODEX_LOOP_VALIDATE_SCRIPT="${tmp}/bin/fake-validate.sh" \
  CODEX_LOOP_ENRICH_CONTRACT_SCRIPT="${tmp}/bin/fake-enrich-contract.sh" \
  CODEX_LOOP_ENSURE_CONTRACT_SCRIPT="${tmp}/bin/fake-ensure-contract.sh" \
  CODEX_LOOP_RUNTIME_REVIEW_SCRIPT="${tmp}/bin/fake-runtime-review.sh" \
  CODEX_LOOP_WRITE_REVIEW_RESULT_SCRIPT="${tmp}/bin/fake-write-review-result.sh" \
  CODEX_LOOP_PLATEAU_SCRIPT="${tmp}/bin/fake-plateau.sh" \
  CODEX_LOOP_CHECKPOINT_SCRIPT="${tmp}/bin/fake-checkpoint.sh" \
  CODEX_LOOP_MEM_CLIENT="${tmp}/bin/fake-mem.sh" \
  CODEX_LOOP_GENERATE_CONTRACT_SCRIPT="${tmp}/bin/fake-generate-contract.sh" \
  CODEX_LOOP_POLL_INTERVAL_SEC=1 \
  bash "${LOOP_SCRIPT}" start all --max-cycles 1 --pacing worker >/dev/null

  poll_for_status "${repo}/.claude/state/codex-loop/run.json" "completed" || fail "plain status case: run did not finish"

  local output
  output="$(
    PROJECT_ROOT="${repo}" \
    bash "${LOOP_SCRIPT}" status
  )"

  if printf '%s' "${output}" | grep -q 'codex-loop: completed' && \
     printf '%s' "${output}" | grep -q 'selection: all' && \
     printf '%s' "${output}" | grep -q 'exit reason:'; then
    pass "plain status case: human-readable status output rendered"
  else
    fail "plain status case: human-readable status output missing expected fields"
  fi

  cleanup_tmp "${tmp}"
}

run_named_selection_case() {
  local tmp
  tmp="$(mktemp -d)"
  local repo="${tmp}/repo"
  mkdir -p "${repo}"
  setup_named_repo "${repo}"
  setup_fake_tools "${tmp}" "complete"

  PROJECT_ROOT="${repo}" \
  CODEX_LOOP_TASK_DRIVER=companion \
  CODEX_LOOP_COMPANION="${tmp}/bin/fake-companion.sh" \
  CODEX_LOOP_VALIDATE_SCRIPT="${tmp}/bin/fake-validate.sh" \
  CODEX_LOOP_ENRICH_CONTRACT_SCRIPT="${tmp}/bin/fake-enrich-contract.sh" \
  CODEX_LOOP_ENSURE_CONTRACT_SCRIPT="${tmp}/bin/fake-ensure-contract.sh" \
  CODEX_LOOP_RUNTIME_REVIEW_SCRIPT="${tmp}/bin/fake-runtime-review.sh" \
  CODEX_LOOP_WRITE_REVIEW_RESULT_SCRIPT="${tmp}/bin/fake-write-review-result.sh" \
  CODEX_LOOP_PLATEAU_SCRIPT="${tmp}/bin/fake-plateau.sh" \
  CODEX_LOOP_CHECKPOINT_SCRIPT="${tmp}/bin/fake-checkpoint.sh" \
  CODEX_LOOP_MEM_CLIENT="${tmp}/bin/fake-mem.sh" \
  CODEX_LOOP_GENERATE_CONTRACT_SCRIPT="${tmp}/bin/fake-generate-contract.sh" \
  CODEX_LOOP_POLL_INTERVAL_SEC=1 \
  bash "${LOOP_SCRIPT}" start JLB3R-02..JLB3R-08 --max-cycles 1 --pacing worker --executor task >/dev/null

  poll_for_status "${repo}/.claude/state/codex-loop/run.json" "completed" || fail "named selection case: run did not finish"

  local selection task_02 task_03
  selection="$(python3 - "${repo}/.claude/state/codex-loop/run.json" <<'PY'
import json, sys
with open(sys.argv[1], "r", encoding="utf-8") as fh:
    print(json.load(fh).get("selection", ""))
PY
)"
  task_02="$(grep '^| JLB3R-02 ' "${repo}/Plans.md" || true)"
  task_03="$(grep '^| JLB3R-03 ' "${repo}/Plans.md" || true)"

  if [ "${selection}" = "JLB3R-02..JLB3R-08" ] && \
     printf '%s' "${task_02}" | grep -q 'cc:完了' && \
     printf '%s' "${task_03}" | grep -q 'cc:TODO'; then
    pass "named selection case: Plans.md-aware range selection works"
  else
    fail "named selection case: range selection did not target expected tasks"
  fi

  cleanup_tmp "${tmp}"
}

run_heading_selection_case() {
  local tmp
  tmp="$(mktemp -d)"
  local repo="${tmp}/repo"
  mkdir -p "${repo}"
  setup_heading_repo "${repo}"
  setup_fake_tools "${tmp}" "complete"

  PROJECT_ROOT="${repo}" \
  CODEX_LOOP_TASK_DRIVER=companion \
  CODEX_LOOP_COMPANION="${tmp}/bin/fake-companion.sh" \
  CODEX_LOOP_VALIDATE_SCRIPT="${tmp}/bin/fake-validate.sh" \
  CODEX_LOOP_ENRICH_CONTRACT_SCRIPT="${tmp}/bin/fake-enrich-contract.sh" \
  CODEX_LOOP_ENSURE_CONTRACT_SCRIPT="${tmp}/bin/fake-ensure-contract.sh" \
  CODEX_LOOP_RUNTIME_REVIEW_SCRIPT="${tmp}/bin/fake-runtime-review.sh" \
  CODEX_LOOP_WRITE_REVIEW_RESULT_SCRIPT="${tmp}/bin/fake-write-review-result.sh" \
  CODEX_LOOP_PLATEAU_SCRIPT="${tmp}/bin/fake-plateau.sh" \
  CODEX_LOOP_CHECKPOINT_SCRIPT="${tmp}/bin/fake-checkpoint.sh" \
  CODEX_LOOP_MEM_CLIENT="${tmp}/bin/fake-mem.sh" \
  CODEX_LOOP_GENERATE_CONTRACT_SCRIPT="${tmp}/bin/fake-generate-contract.sh" \
  CODEX_LOOP_POLL_INTERVAL_SEC=1 \
  bash "${LOOP_SCRIPT}" start 6G-6 --max-cycles 1 --pacing worker --executor task >/dev/null

  poll_for_status "${repo}/.claude/state/codex-loop/run.json" "completed" || fail "heading selection case: run did not finish"

  local selection heading_line
  selection="$(jq -r '.selection' "${repo}/.claude/state/codex-loop/run.json")"
  heading_line="$(grep '^#### 6G-6:' "${repo}/Plans.md" || true)"
  if [ "${selection}" = "6G-6" ] && [[ "${heading_line}" == *"cc:完了"* ]]; then
    pass "heading selection case: hyphenated heading task id is accepted as exact task"
  else
    fail "heading selection case: heading task selection failed"
  fi

  cleanup_tmp "${tmp}"
}

run_line_ref_selection_case() {
  local tmp
  tmp="$(mktemp -d)"
  local repo="${tmp}/repo"
  mkdir -p "${repo}"
  setup_heading_repo "${repo}"
  setup_fake_tools "${tmp}" "complete"

  PROJECT_ROOT="${repo}" \
  CODEX_LOOP_TASK_DRIVER=companion \
  CODEX_LOOP_COMPANION="${tmp}/bin/fake-companion.sh" \
  CODEX_LOOP_VALIDATE_SCRIPT="${tmp}/bin/fake-validate.sh" \
  CODEX_LOOP_ENRICH_CONTRACT_SCRIPT="${tmp}/bin/fake-enrich-contract.sh" \
  CODEX_LOOP_ENSURE_CONTRACT_SCRIPT="${tmp}/bin/fake-ensure-contract.sh" \
  CODEX_LOOP_RUNTIME_REVIEW_SCRIPT="${tmp}/bin/fake-runtime-review.sh" \
  CODEX_LOOP_WRITE_REVIEW_RESULT_SCRIPT="${tmp}/bin/fake-write-review-result.sh" \
  CODEX_LOOP_PLATEAU_SCRIPT="${tmp}/bin/fake-plateau.sh" \
  CODEX_LOOP_CHECKPOINT_SCRIPT="${tmp}/bin/fake-checkpoint.sh" \
  CODEX_LOOP_MEM_CLIENT="${tmp}/bin/fake-mem.sh" \
  CODEX_LOOP_GENERATE_CONTRACT_SCRIPT="${tmp}/bin/fake-generate-contract.sh" \
  CODEX_LOOP_POLL_INTERVAL_SEC=1 \
  bash "${LOOP_SCRIPT}" start Plans.md:2 --max-cycles 1 --pacing worker --executor task >/dev/null

  poll_for_status "${repo}/.claude/state/codex-loop/run.json" "completed" || fail "line ref selection case: run did not finish"

  local selection heading_line
  selection="$(jq -r '.selection' "${repo}/.claude/state/codex-loop/run.json")"
  heading_line="$(grep '^#### 6G-6:' "${repo}/Plans.md" || true)"
  if [ "${selection}" = "6G-6" ] && [[ "${heading_line}" == *"cc:完了"* ]]; then
    pass "line ref selection case: Plans.md:line resolves nearby heading task"
  else
    fail "line ref selection case: Plans.md:line did not resolve heading task"
  fi

  cleanup_tmp "${tmp}"
}

run_breezing_batch_case() {
  local tmp
  tmp="$(mktemp -d)"
  local repo="${tmp}/repo"
  mkdir -p "${repo}"
  setup_batch_repo "${repo}"
  setup_fake_tools "${tmp}" "complete"

  PROJECT_ROOT="${repo}" \
  CODEX_LOOP_TASK_DRIVER=companion \
  CODEX_LOOP_COMPANION="${tmp}/bin/fake-companion.sh" \
  CODEX_LOOP_VALIDATE_SCRIPT="${tmp}/bin/fake-validate.sh" \
  CODEX_LOOP_ENRICH_CONTRACT_SCRIPT="${tmp}/bin/fake-enrich-contract.sh" \
  CODEX_LOOP_ENSURE_CONTRACT_SCRIPT="${tmp}/bin/fake-ensure-contract.sh" \
  CODEX_LOOP_RUNTIME_REVIEW_SCRIPT="${tmp}/bin/fake-runtime-review.sh" \
  CODEX_LOOP_WRITE_REVIEW_RESULT_SCRIPT="${tmp}/bin/fake-write-review-result.sh" \
  CODEX_LOOP_PLATEAU_SCRIPT="${tmp}/bin/fake-plateau.sh" \
  CODEX_LOOP_CHECKPOINT_SCRIPT="${tmp}/bin/fake-checkpoint.sh" \
  CODEX_LOOP_MEM_CLIENT="${tmp}/bin/fake-mem.sh" \
  CODEX_LOOP_GENERATE_CONTRACT_SCRIPT="${tmp}/bin/fake-generate-contract.sh" \
  CODEX_LOOP_POLL_INTERVAL_SEC=1 \
  bash "${LOOP_SCRIPT}" start all --max-cycles 1 --pacing worker --max-workers 2 >/dev/null

  poll_for_status "${repo}/.claude/state/codex-loop/run.json" "completed" || fail "breezing batch case: run did not finish"

  jq -e '.executor == "breezing" and .max_workers == "2" and .last_batch_ids == "1,2"' \
    "${repo}/.claude/state/codex-loop/run.json" >/dev/null \
    && pass "breezing batch case: run state records executor and capped batch" \
    || fail "breezing batch case: run state did not record expected executor/batch"

  if grep '^| 1 ' "${repo}/Plans.md" | grep -q 'cc:完了' && \
     grep '^| 2 ' "${repo}/Plans.md" | grep -q 'cc:完了' && \
     grep '^| 3 ' "${repo}/Plans.md" | grep -q 'cc:TODO'; then
    pass "breezing batch case: ready batch completed without dependency leak"
  else
    fail "breezing batch case: Plans.md statuses were not expected"
  fi

  if grep -q '"executor":"breezing"' "${repo}/.claude/state/codex-loop/cycles.jsonl" && \
     grep -q '"task_ids":"1,2"' "${repo}/.claude/state/codex-loop/cycles.jsonl"; then
    pass "breezing batch case: cycle log records breezing batch"
  else
    fail "breezing batch case: cycle log missing breezing batch"
  fi

  cleanup_tmp "${tmp}"
}

run_breezing_blocked_case() {
  local tmp
  tmp="$(mktemp -d)"
  local repo="${tmp}/repo"
  mkdir -p "${repo}"
  setup_batch_repo "${repo}"
  setup_fake_tools "${tmp}" "retry"

  set +e
  PROJECT_ROOT="${repo}" \
  CODEX_LOOP_TASK_DRIVER=companion \
  CODEX_LOOP_COMPANION="${tmp}/bin/fake-companion.sh" \
  CODEX_LOOP_VALIDATE_SCRIPT="${tmp}/bin/fake-validate.sh" \
  CODEX_LOOP_ENRICH_CONTRACT_SCRIPT="${tmp}/bin/fake-enrich-contract.sh" \
  CODEX_LOOP_ENSURE_CONTRACT_SCRIPT="${tmp}/bin/fake-ensure-contract.sh" \
  CODEX_LOOP_RUNTIME_REVIEW_SCRIPT="${tmp}/bin/fake-runtime-review.sh" \
  CODEX_LOOP_WRITE_REVIEW_RESULT_SCRIPT="${tmp}/bin/fake-write-review-result.sh" \
  CODEX_LOOP_PLATEAU_SCRIPT="${tmp}/bin/fake-plateau.sh" \
  CODEX_LOOP_CHECKPOINT_SCRIPT="${tmp}/bin/fake-checkpoint.sh" \
  CODEX_LOOP_MEM_CLIENT="${tmp}/bin/fake-mem.sh" \
  CODEX_LOOP_GENERATE_CONTRACT_SCRIPT="${tmp}/bin/fake-generate-contract.sh" \
  CODEX_LOOP_POLL_INTERVAL_SEC=1 \
  bash "${LOOP_SCRIPT}" start all --max-cycles 2 --pacing worker --max-workers 2 >/dev/null
  set -e

  poll_for_status "${repo}/.claude/state/codex-loop/run.json" "failed" || fail "breezing blocked case: run should fail"

  jq -e '.exit_reason == "task_blocked" and .last_batch_ids == "1,2" and .cycle_count == 1' \
    "${repo}/.claude/state/codex-loop/run.json" >/dev/null \
    && pass "breezing blocked case: blocked batch stops loop" \
    || fail "breezing blocked case: loop did not stop on blocked batch"

  if grep '^| 3 ' "${repo}/Plans.md" | grep -q 'cc:TODO'; then
    pass "breezing blocked case: dependent follow-up was not advanced"
  else
    fail "breezing blocked case: dependent follow-up advanced unexpectedly"
  fi

  cleanup_tmp "${tmp}"
}

run_start_reset_case() {
  local tmp
  tmp="$(mktemp -d)"
  local repo="${tmp}/repo"
  mkdir -p "${repo}"
  setup_repo "${repo}"
  setup_fake_tools "${tmp}" "stall"
  mkdir -p "${repo}/.claude/state/codex-loop"
  cat > "${repo}/.claude/state/codex-loop/current-job.json" <<'EOF'
{"id":"stale-job","status":"running"}
EOF

  PROJECT_ROOT="${repo}" \
  CODEX_LOOP_TASK_DRIVER=companion \
  CODEX_LOOP_COMPANION="${tmp}/bin/fake-companion.sh" \
  CODEX_LOOP_VALIDATE_SCRIPT="${tmp}/bin/fake-validate.sh" \
  CODEX_LOOP_ENRICH_CONTRACT_SCRIPT="${tmp}/bin/fake-enrich-contract.sh" \
  CODEX_LOOP_ENSURE_CONTRACT_SCRIPT="${tmp}/bin/fake-ensure-contract.sh" \
  CODEX_LOOP_RUNTIME_REVIEW_SCRIPT="${tmp}/bin/fake-runtime-review.sh" \
  CODEX_LOOP_WRITE_REVIEW_RESULT_SCRIPT="${tmp}/bin/fake-write-review-result.sh" \
  CODEX_LOOP_PLATEAU_SCRIPT="${tmp}/bin/fake-plateau.sh" \
  CODEX_LOOP_CHECKPOINT_SCRIPT="${tmp}/bin/fake-checkpoint.sh" \
  CODEX_LOOP_MEM_CLIENT="${tmp}/bin/fake-mem.sh" \
  CODEX_LOOP_GENERATE_CONTRACT_SCRIPT="${tmp}/bin/fake-generate-contract.sh" \
  CODEX_LOOP_POLL_INTERVAL_SEC=1 \
  bash "${LOOP_SCRIPT}" start all --max-cycles 1 --pacing worker >/dev/null

  sleep 1
  if [ ! -f "${repo}/.claude/state/codex-loop/current-job.json" ] || ! grep -q 'stale-job' "${repo}/.claude/state/codex-loop/current-job.json"; then
    pass "start reset case: stale current-job.json cleared on start"
  else
    fail "start reset case: stale current-job.json was not cleared on start"
  fi

  PROJECT_ROOT="${repo}" \
  CODEX_LOOP_TASK_DRIVER=companion \
  CODEX_LOOP_COMPANION="${tmp}/bin/fake-companion.sh" \
  bash "${LOOP_SCRIPT}" stop >/dev/null
  poll_for_status "${repo}/.claude/state/codex-loop/run.json" "stopped" || true

  cleanup_tmp "${tmp}"
}

run_advisor_preflight_case() {
  local tmp
  tmp="$(mktemp -d)"
  local repo="${tmp}/repo"
  mkdir -p "${repo}"
  setup_repo "${repo}"
  setup_fake_tools "${tmp}" "advisor-preflight"

  PROJECT_ROOT="${repo}" \
  CODEX_LOOP_TASK_DRIVER=companion \
  CODEX_LOOP_ADVISOR_SCRIPT="${tmp}/bin/fake-advisor.sh" \
  CODEX_LOOP_COMPANION="${tmp}/bin/fake-companion.sh" \
  CODEX_LOOP_VALIDATE_SCRIPT="${tmp}/bin/fake-validate.sh" \
  CODEX_LOOP_ENRICH_CONTRACT_SCRIPT="${tmp}/bin/fake-enrich-contract.sh" \
  CODEX_LOOP_ENSURE_CONTRACT_SCRIPT="${tmp}/bin/fake-ensure-contract.sh" \
  CODEX_LOOP_RUNTIME_REVIEW_SCRIPT="${tmp}/bin/fake-runtime-review.sh" \
  CODEX_LOOP_WRITE_REVIEW_RESULT_SCRIPT="${tmp}/bin/fake-write-review-result.sh" \
  CODEX_LOOP_PLATEAU_SCRIPT="${tmp}/bin/fake-plateau.sh" \
  CODEX_LOOP_CHECKPOINT_SCRIPT="${tmp}/bin/fake-checkpoint.sh" \
  CODEX_LOOP_MEM_CLIENT="${tmp}/bin/fake-mem.sh" \
  CODEX_LOOP_GENERATE_CONTRACT_SCRIPT="${tmp}/bin/fake-generate-contract.sh" \
  CODEX_LOOP_POLL_INTERVAL_SEC=1 \
  FAKE_ADVISOR_MODE=preflight \
  FAKE_ADVISOR_DECISION=PLAN \
  bash "${LOOP_SCRIPT}" start all --max-cycles 1 --pacing worker >/dev/null

  poll_for_status "${repo}/.claude/state/codex-loop/run.json" "completed" || fail "advisor preflight: run did not finish"
  jq -e '.consultations == 1 and .last_decision == "PLAN" and (.last_trigger | contains("high-risk-preflight")) and .last_model == "gpt-5.4"' \
    "${repo}/.claude/state/codex-loop/run.json" >/dev/null \
    && pass "advisor preflight: status JSON records consultation" \
    || fail "advisor preflight: status JSON missing advisor fields"

  cleanup_tmp "${tmp}"
}

run_advisor_duplicate_case() {
  local tmp
  tmp="$(mktemp -d)"
  local repo="${tmp}/repo"
  mkdir -p "${repo}"
  setup_repo "${repo}"
  setup_fake_tools "${tmp}" "retry"

  set +e
  PROJECT_ROOT="${repo}" \
  CODEX_LOOP_TASK_DRIVER=companion \
  CODEX_LOOP_ADVISOR_SCRIPT="${tmp}/bin/fake-advisor.sh" \
  CODEX_LOOP_COMPANION="${tmp}/bin/fake-companion.sh" \
  CODEX_LOOP_VALIDATE_SCRIPT="${tmp}/bin/fake-validate.sh" \
  CODEX_LOOP_ENRICH_CONTRACT_SCRIPT="${tmp}/bin/fake-enrich-contract.sh" \
  CODEX_LOOP_ENSURE_CONTRACT_SCRIPT="${tmp}/bin/fake-ensure-contract.sh" \
  CODEX_LOOP_RUNTIME_REVIEW_SCRIPT="${tmp}/bin/fake-runtime-review.sh" \
  CODEX_LOOP_WRITE_REVIEW_RESULT_SCRIPT="${tmp}/bin/fake-write-review-result.sh" \
  CODEX_LOOP_PLATEAU_SCRIPT="${tmp}/bin/fake-plateau.sh" \
  CODEX_LOOP_CHECKPOINT_SCRIPT="${tmp}/bin/fake-checkpoint.sh" \
  CODEX_LOOP_MEM_CLIENT="${tmp}/bin/fake-mem.sh" \
  CODEX_LOOP_GENERATE_CONTRACT_SCRIPT="${tmp}/bin/fake-generate-contract.sh" \
  CODEX_LOOP_POLL_INTERVAL_SEC=1 \
  FAKE_ADVISOR_MODE=retry \
  FAKE_ADVISOR_DECISION=PLAN \
  bash "${LOOP_SCRIPT}" start all --max-cycles 1 --pacing worker >/dev/null
  set -e

  poll_for_status "${repo}/.claude/state/codex-loop/run.json" "failed" || fail "advisor duplicate: run should fail after retries"
  jq -e '.consultations == 1 and (.last_trigger | contains("retry-threshold"))' \
    "${repo}/.claude/state/codex-loop/run.json" >/dev/null \
    && pass "advisor duplicate: duplicate trigger suppressed" \
    || fail "advisor duplicate: duplicate suppression failed"

  cleanup_tmp "${tmp}"
}

run_advisor_stop_case() {
  local tmp
  tmp="$(mktemp -d)"
  local repo="${tmp}/repo"
  mkdir -p "${repo}"
  setup_repo "${repo}"
  setup_fake_tools "${tmp}" "complete"

  set +e
  PROJECT_ROOT="${repo}" \
  CODEX_LOOP_TASK_DRIVER=companion \
  CODEX_LOOP_ADVISOR_SCRIPT="${tmp}/bin/fake-advisor.sh" \
  CODEX_LOOP_COMPANION="${tmp}/bin/fake-companion.sh" \
  CODEX_LOOP_VALIDATE_SCRIPT="${tmp}/bin/fake-validate.sh" \
  CODEX_LOOP_ENRICH_CONTRACT_SCRIPT="${tmp}/bin/fake-enrich-contract.sh" \
  CODEX_LOOP_ENSURE_CONTRACT_SCRIPT="${tmp}/bin/fake-ensure-contract.sh" \
  CODEX_LOOP_RUNTIME_REVIEW_SCRIPT="${tmp}/bin/fake-runtime-review.sh" \
  CODEX_LOOP_WRITE_REVIEW_RESULT_SCRIPT="${tmp}/bin/fake-write-review-result.sh" \
  CODEX_LOOP_PLATEAU_SCRIPT="${tmp}/bin/fake-plateau.sh" \
  CODEX_LOOP_CHECKPOINT_SCRIPT="${tmp}/bin/fake-checkpoint.sh" \
  CODEX_LOOP_MEM_CLIENT="${tmp}/bin/fake-mem.sh" \
  CODEX_LOOP_GENERATE_CONTRACT_SCRIPT="${tmp}/bin/fake-generate-contract.sh" \
  CODEX_LOOP_POLL_INTERVAL_SEC=1 \
  FAKE_ADVISOR_MODE=preflight \
  FAKE_ADVISOR_DECISION=STOP \
  bash "${LOOP_SCRIPT}" start all --max-cycles 1 --pacing worker >/dev/null
  set -e

  poll_for_status "${repo}/.claude/state/codex-loop/run.json" "failed" || fail "advisor stop: run should fail"
  jq -e '.consultations == 1 and .last_decision == "STOP" and (.last_trigger | contains("high-risk-preflight"))' \
    "${repo}/.claude/state/codex-loop/run.json" >/dev/null \
    && pass "advisor stop: STOP decision recorded" \
    || fail "advisor stop: STOP decision missing"

  cleanup_tmp "${tmp}"
}

run_plateau_advisor_case() {
  local tmp
  tmp="$(mktemp -d)"
  local repo="${tmp}/repo"
  mkdir -p "${repo}"
  setup_repo "${repo}"
  setup_fake_tools "${tmp}" "complete"

  PROJECT_ROOT="${repo}" \
  CODEX_LOOP_TASK_DRIVER=companion \
  CODEX_LOOP_ADVISOR_SCRIPT="${tmp}/bin/fake-advisor.sh" \
  CODEX_LOOP_COMPANION="${tmp}/bin/fake-companion.sh" \
  CODEX_LOOP_VALIDATE_SCRIPT="${tmp}/bin/fake-validate.sh" \
  CODEX_LOOP_ENRICH_CONTRACT_SCRIPT="${tmp}/bin/fake-enrich-contract.sh" \
  CODEX_LOOP_ENSURE_CONTRACT_SCRIPT="${tmp}/bin/fake-ensure-contract.sh" \
  CODEX_LOOP_RUNTIME_REVIEW_SCRIPT="${tmp}/bin/fake-runtime-review.sh" \
  CODEX_LOOP_WRITE_REVIEW_RESULT_SCRIPT="${tmp}/bin/fake-write-review-result.sh" \
  CODEX_LOOP_PLATEAU_SCRIPT="${tmp}/bin/fake-plateau.sh" \
  CODEX_LOOP_CHECKPOINT_SCRIPT="${tmp}/bin/fake-checkpoint.sh" \
  CODEX_LOOP_MEM_CLIENT="${tmp}/bin/fake-mem.sh" \
  CODEX_LOOP_GENERATE_CONTRACT_SCRIPT="${tmp}/bin/fake-generate-contract.sh" \
  CODEX_LOOP_POLL_INTERVAL_SEC=1 \
  FAKE_ADVISOR_MODE=plateau \
  FAKE_ADVISOR_DECISION=PLAN \
  FAKE_PLATEAU_MODE=pivot \
  bash "${LOOP_SCRIPT}" start all --max-cycles 1 --pacing worker >/dev/null

  poll_for_status "${repo}/.claude/state/codex-loop/run.json" "completed" || fail "plateau advisor: run should complete"
  jq -e '.consultations == 1 and .last_decision == "PLAN" and (.last_trigger | contains("plateau-pre-escalation"))' \
    "${repo}/.claude/state/codex-loop/run.json" >/dev/null \
    && pass "plateau advisor: plateau consult recorded" \
    || fail "plateau advisor: plateau consult missing"

  cleanup_tmp "${tmp}"
}

run_resume_clears_terminal_fields_case() {
  local tmp
  tmp="$(mktemp -d)"
  local repo="${tmp}/repo"
  mkdir -p "${repo}"
  setup_repo "${repo}"
  setup_fake_tools "${tmp}" "stall"
  mkdir -p "${repo}/.claude/state/codex-loop"

  cat > "${repo}/.claude/state/codex-loop/run.json" <<EOF
{
  "schema_version": "codex-loop-run.v1",
  "run_id": "resume-run-1",
  "selection": "all",
  "max_cycles": 2,
  "pacing": "worker",
  "delay_seconds": 270,
  "cycle_count": 0,
  "status": "failed",
  "started_at": "2026-04-17T00:00:00Z",
  "updated_at": "2026-04-17T00:00:00Z",
  "finished_at": "2026-04-17T00:01:00Z",
  "exit_reason": "cycle_error",
  "error_message": "old failure",
  "stop_requested_at": "2026-04-17T00:00:30Z",
  "project_root": "${repo}",
  "plans_file": "${repo}/Plans.md"
}
EOF

  PROJECT_ROOT="${repo}" \
  CODEX_LOOP_TASK_DRIVER=companion \
  CODEX_LOOP_COMPANION="${tmp}/bin/fake-companion.sh" \
  CODEX_LOOP_VALIDATE_SCRIPT="${tmp}/bin/fake-validate.sh" \
  CODEX_LOOP_ENRICH_CONTRACT_SCRIPT="${tmp}/bin/fake-enrich-contract.sh" \
  CODEX_LOOP_ENSURE_CONTRACT_SCRIPT="${tmp}/bin/fake-ensure-contract.sh" \
  CODEX_LOOP_RUNTIME_REVIEW_SCRIPT="${tmp}/bin/fake-runtime-review.sh" \
  CODEX_LOOP_WRITE_REVIEW_RESULT_SCRIPT="${tmp}/bin/fake-write-review-result.sh" \
  CODEX_LOOP_PLATEAU_SCRIPT="${tmp}/bin/fake-plateau.sh" \
  CODEX_LOOP_CHECKPOINT_SCRIPT="${tmp}/bin/fake-checkpoint.sh" \
  CODEX_LOOP_MEM_CLIENT="${tmp}/bin/fake-mem.sh" \
  CODEX_LOOP_GENERATE_CONTRACT_SCRIPT="${tmp}/bin/fake-generate-contract.sh" \
  CODEX_LOOP_POLL_INTERVAL_SEC=1 \
  bash "${LOOP_SCRIPT}" run --run-id resume-run-1 >/dev/null 2>&1 &

  if poll_for_status "${repo}/.claude/state/codex-loop/run.json" "running"; then
    pass "resume clear case: resumed run entered running state"
  else
    fail "resume clear case: resumed run did not enter running state"
  fi

  jq -e '.exit_reason == null and .finished_at == null and .error_message == null and .stop_requested_at == null' \
    "${repo}/.claude/state/codex-loop/run.json" >/dev/null \
    && pass "resume clear case: stale terminal fields cleared" \
    || fail "resume clear case: stale terminal fields still present"

  PROJECT_ROOT="${repo}" \
  CODEX_LOOP_TASK_DRIVER=companion \
  CODEX_LOOP_COMPANION="${tmp}/bin/fake-companion.sh" \
  bash "${LOOP_SCRIPT}" stop >/dev/null
  poll_for_status "${repo}/.claude/state/codex-loop/run.json" "stopped" || true

  cleanup_tmp "${tmp}"
}

run_reentry_guard_case() {
  local tmp
  tmp="$(mktemp -d)"
  local repo="${tmp}/repo"
  mkdir -p "${repo}"
  setup_repo "${repo}"
  setup_fake_tools "${tmp}" "stall"

  PROJECT_ROOT="${repo}" \
  CODEX_LOOP_TASK_DRIVER=companion \
  CODEX_LOOP_COMPANION="${tmp}/bin/fake-companion.sh" \
  CODEX_LOOP_VALIDATE_SCRIPT="${tmp}/bin/fake-validate.sh" \
  CODEX_LOOP_ENRICH_CONTRACT_SCRIPT="${tmp}/bin/fake-enrich-contract.sh" \
  CODEX_LOOP_ENSURE_CONTRACT_SCRIPT="${tmp}/bin/fake-ensure-contract.sh" \
  CODEX_LOOP_RUNTIME_REVIEW_SCRIPT="${tmp}/bin/fake-runtime-review.sh" \
  CODEX_LOOP_WRITE_REVIEW_RESULT_SCRIPT="${tmp}/bin/fake-write-review-result.sh" \
  CODEX_LOOP_PLATEAU_SCRIPT="${tmp}/bin/fake-plateau.sh" \
  CODEX_LOOP_CHECKPOINT_SCRIPT="${tmp}/bin/fake-checkpoint.sh" \
  CODEX_LOOP_MEM_CLIENT="${tmp}/bin/fake-mem.sh" \
  CODEX_LOOP_GENERATE_CONTRACT_SCRIPT="${tmp}/bin/fake-generate-contract.sh" \
  CODEX_LOOP_POLL_INTERVAL_SEC=1 \
  bash "${LOOP_SCRIPT}" start all --max-cycles 2 --pacing worker >/dev/null

  poll_for_status "${repo}/.claude/state/codex-loop/run.json" "running" || true
  local run_id
  run_id="$(jq -r '.run_id' "${repo}/.claude/state/codex-loop/run.json")"

  local output=""
  local status=0
  set +e
  output="$(
    PROJECT_ROOT="${repo}" \
    CODEX_LOOP_TASK_DRIVER=companion \
    CODEX_LOOP_COMPANION="${tmp}/bin/fake-companion.sh" \
    CODEX_LOOP_VALIDATE_SCRIPT="${tmp}/bin/fake-validate.sh" \
    CODEX_LOOP_ENRICH_CONTRACT_SCRIPT="${tmp}/bin/fake-enrich-contract.sh" \
    CODEX_LOOP_ENSURE_CONTRACT_SCRIPT="${tmp}/bin/fake-ensure-contract.sh" \
    CODEX_LOOP_RUNTIME_REVIEW_SCRIPT="${tmp}/bin/fake-runtime-review.sh" \
    CODEX_LOOP_WRITE_REVIEW_RESULT_SCRIPT="${tmp}/bin/fake-write-review-result.sh" \
    CODEX_LOOP_PLATEAU_SCRIPT="${tmp}/bin/fake-plateau.sh" \
    CODEX_LOOP_CHECKPOINT_SCRIPT="${tmp}/bin/fake-checkpoint.sh" \
    CODEX_LOOP_MEM_CLIENT="${tmp}/bin/fake-mem.sh" \
    CODEX_LOOP_GENERATE_CONTRACT_SCRIPT="${tmp}/bin/fake-generate-contract.sh" \
    CODEX_LOOP_POLL_INTERVAL_SEC=1 \
    bash "${LOOP_SCRIPT}" run --run-id "${run_id}" 2>&1
  )"
  status=$?
  set -e

  if [ "${status}" -ne 0 ] && printf '%s' "${output}" | grep -q 'already running'; then
    pass "reentry guard case: second run invocation refused"
  else
    fail "reentry guard case: second run invocation was not refused"
  fi

  PROJECT_ROOT="${repo}" \
  CODEX_LOOP_TASK_DRIVER=companion \
  CODEX_LOOP_COMPANION="${tmp}/bin/fake-companion.sh" \
  bash "${LOOP_SCRIPT}" stop >/dev/null
  poll_for_status "${repo}/.claude/state/codex-loop/run.json" "stopped" || true

  cleanup_tmp "${tmp}"
}

run_local_worker_failure_case
run_local_worker_cancel_case
run_completion_case
run_stop_case
run_cross_repo_case
run_state_corrupt_case
run_startup_failure_case
run_state_stale_log_tail_case
run_runner_lost_active_job_status_and_stop_case
run_runner_lost_cancel_failure_case
run_runner_failure_cancels_active_job_case
run_companion_stderr_json_case
run_plain_status_case
run_named_selection_case
run_heading_selection_case
run_line_ref_selection_case
run_breezing_batch_case
run_breezing_blocked_case
run_start_reset_case
run_advisor_preflight_case
run_advisor_duplicate_case
run_advisor_stop_case
run_plateau_advisor_case
run_resume_clears_terminal_fields_case
run_reentry_guard_case

echo "passed=${PASS_COUNT} failed=${FAIL_COUNT}"
[ "${FAIL_COUNT}" -eq 0 ]
