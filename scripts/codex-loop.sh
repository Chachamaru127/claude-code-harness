#!/usr/bin/env bash
#
# codex-loop.sh
#
# Real background runner for `harness codex-loop`.
# Stores state under .claude/state/codex-loop/ and delegates each cycle to the
# Codex companion background task runner.

set -euo pipefail

SOURCE_PATH="${BASH_SOURCE[0]}"
while [ -h "${SOURCE_PATH}" ]; do
  SOURCE_DIR="$(cd -P "$(dirname "${SOURCE_PATH}")" && pwd)"
  SOURCE_TARGET="$(readlink "${SOURCE_PATH}")"
  case "${SOURCE_TARGET}" in
    /*) SOURCE_PATH="${SOURCE_TARGET}" ;;
    *) SOURCE_PATH="${SOURCE_DIR}/${SOURCE_TARGET}" ;;
  esac
done
SCRIPT_DIR="$(cd -P "$(dirname "${SOURCE_PATH}")" && pwd)"
SELF_SCRIPT="${SCRIPT_DIR}/$(basename "${SOURCE_PATH}")"
DEFAULT_INSTALL_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
HARNESS_INSTALL_ROOT="${HARNESS_INSTALL_ROOT:-${DEFAULT_INSTALL_ROOT}}"
DEFAULT_PROJECT_ROOT="${HARNESS_INSTALL_ROOT}"
PROJECT_ROOT="${PROJECT_ROOT:-${DEFAULT_PROJECT_ROOT}}"

STATE_ROOT="${PROJECT_ROOT}/.claude/state"
LOOP_STATE_DIR="${STATE_ROOT}/codex-loop"
LOCKS_DIR="${STATE_ROOT}/locks"
LOCK_DIR="${LOCKS_DIR}/codex-loop.lock.d"
RUN_JSON="${LOOP_STATE_DIR}/run.json"
CYCLES_JSONL="${LOOP_STATE_DIR}/cycles.jsonl"
RUNNER_LOG="${LOOP_STATE_DIR}/runner.log"
CURRENT_JOB_JSON="${LOOP_STATE_DIR}/current-job.json"
PROMPTS_DIR="${LOOP_STATE_DIR}/prompts"
RESULTS_DIR="${LOOP_STATE_DIR}/results"
TASK_JOBS_DIR="${LOOP_STATE_DIR}/jobs"
CONFIG_UTILS="${HARNESS_INSTALL_ROOT}/scripts/config-utils.sh"

COMPANION="${CODEX_LOOP_COMPANION:-${HARNESS_INSTALL_ROOT}/scripts/codex-companion.sh}"
VALIDATE_SCRIPT="${CODEX_LOOP_VALIDATE_SCRIPT:-${PROJECT_ROOT}/tests/validate-plugin.sh}"
ENRICH_CONTRACT_SCRIPT="${CODEX_LOOP_ENRICH_CONTRACT_SCRIPT:-${HARNESS_INSTALL_ROOT}/scripts/enrich-sprint-contract.sh}"
ENSURE_CONTRACT_SCRIPT="${CODEX_LOOP_ENSURE_CONTRACT_SCRIPT:-${HARNESS_INSTALL_ROOT}/scripts/ensure-sprint-contract-ready.sh}"
RUNTIME_REVIEW_SCRIPT="${CODEX_LOOP_RUNTIME_REVIEW_SCRIPT:-${HARNESS_INSTALL_ROOT}/scripts/run-contract-review-checks.sh}"
WRITE_REVIEW_RESULT_SCRIPT="${CODEX_LOOP_WRITE_REVIEW_RESULT_SCRIPT:-${HARNESS_INSTALL_ROOT}/scripts/write-review-result.sh}"
PLATEAU_SCRIPT="${CODEX_LOOP_PLATEAU_SCRIPT:-${HARNESS_INSTALL_ROOT}/scripts/detect-review-plateau.sh}"
CHECKPOINT_SCRIPT="${CODEX_LOOP_CHECKPOINT_SCRIPT:-${HARNESS_INSTALL_ROOT}/scripts/auto-checkpoint.sh}"
MEM_CLIENT="${CODEX_LOOP_MEM_CLIENT:-${HARNESS_INSTALL_ROOT}/scripts/harness-mem-client.sh}"
NODE_BIN="${NODE_BIN:-node}"
GENERATE_CONTRACT_SCRIPT="${CODEX_LOOP_GENERATE_CONTRACT_SCRIPT:-${HARNESS_INSTALL_ROOT}/scripts/generate-sprint-contract.js}"

POLL_INTERVAL_SEC="${CODEX_LOOP_POLL_INTERVAL_SEC:-5}"

if [ -f "${CONFIG_UTILS}" ]; then
  # shellcheck source=scripts/config-utils.sh
  CONFIG_FILE="${PROJECT_ROOT}/.claude-code-harness.config.yaml"
  source "${CONFIG_UTILS}"
fi

usage() {
  cat <<'EOF'
Usage:
  scripts/codex-loop.sh start <all|N|N-M> [--max-cycles N] [--pacing worker|ci|plateau|night]
  scripts/codex-loop.sh status [--json]
  scripts/codex-loop.sh stop
  scripts/codex-loop.sh run --run-id <id>
  scripts/codex-loop.sh run-cycle --run-id <id> --task-id <id> --cycle <n>
  scripts/codex-loop.sh local-task-worker --job-id <id>
EOF
}

timestamp_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

ensure_dirs() {
  mkdir -p "${LOOP_STATE_DIR}" "${LOCKS_DIR}" "${PROMPTS_DIR}" "${RESULTS_DIR}"
  mkdir -p "${TASK_JOBS_DIR}"
  if declare -F ensure_advisor_state_files >/dev/null 2>&1; then
    ensure_advisor_state_files
  fi
}

log_line() {
  ensure_dirs
  printf '[%s] %s\n' "$(timestamp_utc)" "$*" >> "${RUNNER_LOG}"
}

json_escape() {
  python3 - "$1" <<'PY'
import json, sys
print(json.dumps(sys.argv[1]))
PY
}

python_json() {
  python3 - "$@"
}

run_state_patch() {
  local patch_json="$1"
  ensure_dirs
  python_json "${RUN_JSON}" "${patch_json}" <<'PY'
import json
import os
import sys
import tempfile

path = sys.argv[1]
patch = json.loads(sys.argv[2])
data = {}
if os.path.exists(path):
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)

def merge(left, right):
    for key, value in right.items():
        if isinstance(value, dict) and isinstance(left.get(key), dict):
            merge(left[key], value)
        else:
            left[key] = value

merge(data, patch)
parent = os.path.dirname(path) or "."
fd, tmp_path = tempfile.mkstemp(prefix=".run-json-", suffix=".tmp", dir=parent)
with os.fdopen(fd, "w", encoding="utf-8") as fh:
    json.dump(data, fh, ensure_ascii=False, indent=2)
    fh.write("\n")
os.replace(tmp_path, path)
PY
}

set_run_field() {
  local key="$1"
  local value_json="$2"
  run_state_patch "{\"${key}\": ${value_json}}"
}

json_get_file() {
  local file="$1"
  local path_expr="$2"
  local default_value="${3:-}"
  python_json "${file}" "${path_expr}" "${default_value}" <<'PY'
import json
import os
import sys

path = sys.argv[1]
expr = sys.argv[2]
default = sys.argv[3]

if not os.path.exists(path):
    print(default)
    raise SystemExit(0)

with open(path, "r", encoding="utf-8") as fh:
    data = json.load(fh)

value = data
for part in expr.split("."):
    if not part:
        continue
    if isinstance(value, dict) and part in value:
        value = value[part]
    else:
        print(default)
        raise SystemExit(0)

if value is None:
    print(default)
elif isinstance(value, bool):
    print("true" if value else "false")
elif isinstance(value, (dict, list)):
    print(json.dumps(value, ensure_ascii=False))
else:
    print(value)
PY
}

append_jsonl() {
  local file="$1"
  local json_line="$2"
  ensure_dirs
  printf '%s\n' "${json_line}" >> "${file}"
}

plans_file_path() {
  local plans_file=""
  if [ -f "${CONFIG_UTILS}" ]; then
    plans_file="$(
      cd "${PROJECT_ROOT}" && \
      CONFIG_FILE="${PROJECT_ROOT}/.claude-code-harness.config.yaml" \
      source "${CONFIG_UTILS}" && \
      get_plans_file_path 2>/dev/null
    )" || plans_file=""
    if [ -n "${plans_file}" ] && [ ! -f "${plans_file}" ] && [ -f "${PROJECT_ROOT}/${plans_file}" ]; then
      plans_file="${PROJECT_ROOT}/${plans_file}"
    fi
  fi

  if [ -z "${plans_file}" ]; then
    if [ -f "${PROJECT_ROOT}/Plans.md" ]; then
      plans_file="${PROJECT_ROOT}/Plans.md"
    fi
  fi

  if [ -n "${plans_file}" ]; then
    case "${plans_file}" in
      /*) ;;
      *) plans_file="${PROJECT_ROOT}/${plans_file}" ;;
    esac
  fi

  printf '%s\n' "${plans_file}"
}

is_pid_alive() {
  local pid="${1:-}"
  [ -n "${pid}" ] || return 1
  kill -0 "${pid}" 2>/dev/null
}

terminate_process_tree() {
  local root_pid="${1:-}"
  local grace_sec="${CODEX_LOOP_CANCEL_GRACE_SEC:-1}"
  [ -n "${root_pid}" ] || return 1
  # macOS does not provide setsid by default, so cancel direct descendants too.
  python_json "${root_pid}" "${grace_sec}" <<'PY'
import os
import signal
import subprocess
import sys
import time

try:
    root = int(sys.argv[1])
except (TypeError, ValueError):
    raise SystemExit(1)

try:
    grace = float(sys.argv[2])
except (TypeError, ValueError):
    grace = 1.0


def pid_alive(pid):
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def process_tree(root_pid):
    try:
        output = subprocess.check_output(["ps", "-axo", "pid=,ppid="], text=True)
    except Exception:
        return []
    children = {}
    for raw_line in output.splitlines():
        parts = raw_line.split()
        if len(parts) < 2:
            continue
        try:
            pid, ppid = int(parts[0]), int(parts[1])
        except ValueError:
            continue
        children.setdefault(ppid, []).append(pid)

    result = []

    def visit(pid):
        for child in children.get(pid, []):
            visit(child)
            result.append(child)

    visit(root_pid)
    return result


targets = process_tree(root) + [root]
sent = False
for pid in targets:
    try:
        os.kill(pid, signal.SIGTERM)
        sent = True
    except OSError:
        pass

if sent and grace > 0:
    time.sleep(grace)

for pid in targets:
    if not pid_alive(pid):
        continue
    try:
        os.kill(pid, signal.SIGKILL)
    except OSError:
        pass

raise SystemExit(0 if sent else 1)
PY
}

cleanup_stale_lock_if_needed() {
  if [ ! -d "${LOCK_DIR}" ]; then
    return 0
  fi

  local pid_file="${LOCK_DIR}/pid"
  local locked_pid=""
  if [ -f "${pid_file}" ]; then
    locked_pid="$(cat "${pid_file}" 2>/dev/null || true)"
  fi

  if [ -n "${locked_pid}" ] && is_pid_alive "${locked_pid}"; then
    return 1
  fi

  rm -rf "${LOCK_DIR}"
  return 0
}

acquire_lock() {
  ensure_dirs
  if mkdir "${LOCK_DIR}" 2>/dev/null; then
    printf '%s\n' "$$" > "${LOCK_DIR}/pid"
    return 0
  fi
  if cleanup_stale_lock_if_needed; then
    mkdir "${LOCK_DIR}"
    printf '%s\n' "$$" > "${LOCK_DIR}/pid"
    return 0
  fi
  return 1
}

release_lock() {
  rm -rf "${LOCK_DIR}" 2>/dev/null || true
}

delay_for_pacing() {
  local pacing="$1"
  case "${pacing}" in
    worker|ci) printf '270\n' ;;
    plateau) printf '1200\n' ;;
    night) printf '3600\n' ;;
    *) printf '270\n' ;;
  esac
}

normalize_selection() {
  local plans_file="$1"
  local selection="$2"
  python_json "${plans_file}" "${selection}" <<'PY'
import sys

plans_path = sys.argv[1]
selection = sys.argv[2].strip()


def load_task_ids():
    task_ids = []
    with open(plans_path, "r", encoding="utf-8") as fh:
        for raw_line in fh:
            stripped = raw_line.strip()
            if not stripped.startswith("|"):
                continue
            cells = [cell.strip() for cell in stripped.strip("|").split("|")]
            if len(cells) < 2:
                continue
            task_id = cells[0]
            if not task_id or task_id.lower() == "task" or set(task_id) <= {"-"}:
                continue
            task_ids.append(task_id)
    return task_ids


def to_tuple(value):
    parts = []
    for item in value.split("."):
        try:
            parts.append(int(item))
        except ValueError:
            parts.append(item)
    return tuple(parts)


def resolve_token(task_ids, token):
    if token in task_ids:
        return token

    lowered = token.lower()
    matches = [task_id for task_id in task_ids if task_id.lower() == lowered]
    if len(matches) == 1:
        return matches[0]
    raise ValueError(f"selection token not found in Plans.md: {token}")


def resolve_range_endpoint(task_ids, token, side):
    """Resolve a range endpoint, accepting phase prefixes like 41.1 to mean
    'first/last task whose ID starts with 41.1.'. Restores main-branch behavior
    where harness codex-loop start 41.1-41.4 traversed all 41.1.x..41.4.x tasks.
    """
    try:
        return resolve_token(task_ids, token)
    except ValueError:
        pass
    token_tuple = to_tuple(token)
    matching = [tid for tid in task_ids if to_tuple(tid)[: len(token_tuple)] == token_tuple]
    if not matching:
        raise ValueError(f"selection token not found in Plans.md: {token}")
    return matching[0] if side == "start" else matching[-1]


task_ids = load_task_ids()
if not task_ids:
    raise SystemExit("no task ids found in Plans.md")

if selection == "all":
    print("all")
    raise SystemExit(0)

try:
    print(resolve_token(task_ids, selection))
    raise SystemExit(0)
except ValueError:
    pass

range_parts = None
if ".." in selection:
    range_parts = selection.split("..", 1)
elif "-" in selection:
    range_parts = selection.split("-", 1)

if range_parts is None:
    print(resolve_token(task_ids, selection))
    raise SystemExit(0)

start_raw, end_raw = [part.strip() for part in range_parts]
if not start_raw or not end_raw:
    raise SystemExit(f"invalid selection range: {selection}")

start_id = resolve_range_endpoint(task_ids, start_raw, "start")
end_id = resolve_range_endpoint(task_ids, end_raw, "end")
start_index = task_ids.index(start_id)
end_index = task_ids.index(end_id)
if start_index > end_index:
    raise SystemExit(
        f"selection range is reversed in Plans.md order: {start_id}..{end_id}"
    )

print(f"{start_id}..{end_id}")
PY
}

selection_contains() {
  local selection="$1"
  local task_id="$2"
  python_json "${selection}" "${task_id}" <<'PY'
import sys

selection = sys.argv[1]
task = sys.argv[2]

def to_tuple(value):
    parts = []
    for item in value.split("."):
        try:
            parts.append(int(item))
        except ValueError:
            parts.append(item)
    return tuple(parts)

if selection == "all":
    raise SystemExit(0)

if "-" in selection:
    start, end = selection.split("-", 1)
    if to_tuple(start) <= to_tuple(task) <= to_tuple(end):
        raise SystemExit(0)
    raise SystemExit(1)

raise SystemExit(0 if selection == task else 1)
PY
}

next_task_id() {
  local selection="$1"
  local plans_file="$2"
  python_json "${plans_file}" "${selection}" <<'PY'
import sys

plans_path = sys.argv[1]
selection = sys.argv[2]


def parse_task_rows():
    rows = []
    with open(plans_path, "r", encoding="utf-8") as fh:
        for raw_line in fh:
            stripped = raw_line.strip()
            if not stripped.startswith("|"):
                continue
            cells = [cell.strip() for cell in stripped.strip("|").split("|")]
            if len(cells) < 2:
                continue
            task_id = cells[0]
            if not task_id or task_id.lower() == "task" or set(task_id) <= {"-"}:
                continue
            rows.append((task_id, cells[-1]))
    return rows


rows = parse_task_rows()
ordered_ids = [task_id for task_id, _ in rows]

if selection == "all":
    selected_ids = set(ordered_ids)
elif ".." in selection:
    start, end = selection.split("..", 1)
    start = start.strip()
    end = end.strip()
    start_index = ordered_ids.index(start)
    end_index = ordered_ids.index(end)
    selected_ids = set(ordered_ids[start_index : end_index + 1])
elif "-" in selection:
    start, end = selection.split("-", 1)
    start = start.strip()
    end = end.strip()
    start_index = ordered_ids.index(start)
    end_index = ordered_ids.index(end)
    selected_ids = set(ordered_ids[start_index : end_index + 1])
else:
    selected_ids = {selection}

for task_id, status in rows:
    if task_id in selected_ids and ("cc:TODO" in status or "cc:WIP" in status):
        print(task_id)
        raise SystemExit(0)

raise SystemExit(1)
PY
}

task_status_value() {
  local plans_file="$1"
  local task_id="$2"
  python_json "${plans_file}" "${task_id}" <<'PY'
import sys

plans_path = sys.argv[1]
target = sys.argv[2]

with open(plans_path, "r", encoding="utf-8") as fh:
    for raw_line in fh:
        stripped = raw_line.strip()
        if not stripped.startswith("|"):
            continue
        cells = [cell.strip() for cell in stripped.strip("|").split("|")]
        if len(cells) < 2:
            continue
        task_id = cells[0]
        if not task_id or task_id.lower() == "task" or set(task_id) <= {"-"}:
            continue
        if task_id != target:
            continue
        print(cells[-1])
        raise SystemExit(0)

raise SystemExit(1)
PY
}

task_title_from_contract() {
  local contract_file="$1"
  json_get_file "${contract_file}" "task.title" ""
}

stop_requested() {
  [ -f "${RUN_JSON}" ] || return 1
  local stop_at
  stop_at="$(json_get_file "${RUN_JSON}" "stop_requested_at" "")"
  [ -n "${stop_at}" ]
}

companion_status_json() {
  local job_id="$1"
  if [ "${CODEX_LOOP_TASK_DRIVER:-local}" = "companion" ]; then
    bash "${COMPANION}" status "${job_id}" --json
    return 0
  fi
  local_task_status_json "${job_id}"
}

companion_result_json() {
  local job_id="$1"
  if [ "${CODEX_LOOP_TASK_DRIVER:-local}" = "companion" ]; then
    bash "${COMPANION}" result "${job_id}" --json
    return 0
  fi
  local_task_result_json "${job_id}"
}

companion_cancel_json() {
  local job_id="$1"
  if [ "${CODEX_LOOP_TASK_DRIVER:-local}" = "companion" ]; then
    bash "${COMPANION}" cancel "${job_id}" --json
    return 0
  fi
  local_task_cancel_json "${job_id}"
}

start_background_task() {
  local prompt_file="$1"
  if [ "${CODEX_LOOP_TASK_DRIVER:-local}" = "companion" ]; then
    bash "${COMPANION}" task --background --write --json --prompt-file "${prompt_file}"
    return 0
  fi
  local_task_start_json "${prompt_file}"
}

local_task_job_file() {
  printf '%s\n' "${TASK_JOBS_DIR}/$1.json"
}

local_task_log_file() {
  printf '%s\n' "${TASK_JOBS_DIR}/$1.log"
}

local_task_output_file() {
  printf '%s\n' "${TASK_JOBS_DIR}/$1.out"
}

local_task_summary() {
  local prompt_file="$1"
  python_json "${prompt_file}" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
if not path.exists():
    print("Codex loop task")
    raise SystemExit(0)

for raw_line in path.read_text(encoding="utf-8").splitlines():
    line = raw_line.strip()
    if line:
        print(line[:120])
        raise SystemExit(0)

print("Codex loop task")
PY
}

local_task_write_record() {
  local job_file="$1"
  local payload_json="$2"
  printf '%s\n' "${payload_json}" > "${job_file}"
}

local_task_mark_crashed_if_needed() {
  local job_id="$1"
  local job_file
  job_file="$(local_task_job_file "${job_id}")"
  [ -f "${job_file}" ] || return 0

  python_json "${job_file}" <<'PY'
import json
import os
import signal
import sys

job_file = sys.argv[1]
with open(job_file, "r", encoding="utf-8") as fh:
    job = json.load(fh)

if job.get("status") not in {"queued", "running"}:
    raise SystemExit(0)

pid = job.get("pid")
child_pid = job.get("childPid")
if not pid:
    job["status"] = "failed"
    job["phase"] = "failed"
    job["errorMessage"] = "Loop worker terminated before recording a pid."
else:
    try:
        os.kill(int(pid), 0)
        raise SystemExit(0)
    except OSError:
        if child_pid:
            try:
                os.kill(int(child_pid), signal.SIGTERM)
            except OSError:
                pass
        job["status"] = "failed"
        job["phase"] = "failed"
        job["pid"] = None
        job["childPid"] = None
        job["errorMessage"] = "Loop worker process exited unexpectedly."

with open(job_file, "w", encoding="utf-8") as fh:
    json.dump(job, fh, ensure_ascii=False, indent=2)
    fh.write("\n")
PY
}

local_task_start_json() {
  local prompt_file="$1"
  local job_id="task-$(date +%Y%m%d%H%M%S)-$$"
  local job_file log_file output_file summary
  job_file="$(local_task_job_file "${job_id}")"
  log_file="$(local_task_log_file "${job_id}")"
  output_file="$(local_task_output_file "${job_id}")"
  summary="$(local_task_summary "${prompt_file}")"

  : > "${log_file}"
  : > "${output_file}"
  append_jsonl "${log_file}" "[local-task] queued"

  local_task_write_record "${job_file}" "$(cat <<EOF
{
  "id": $(json_escape "${job_id}"),
  "status": "queued",
  "phase": "queued",
  "title": "Codex Task",
  "summary": $(json_escape "${summary}"),
  "workspaceRoot": $(json_escape "${PROJECT_ROOT}"),
  "jobClass": "task",
  "write": true,
  "logFile": $(json_escape "${log_file}"),
  "request": {
    "cwd": $(json_escape "${PROJECT_ROOT}"),
    "promptFile": $(json_escape "${prompt_file}")
  }
}
EOF
)"

  nohup bash "${SELF_SCRIPT}" local-task-worker --job-id "${job_id}" >> "${log_file}" 2>&1 &
  local worker_pid=$!

  python_json "${job_file}" "${worker_pid}" <<'PY'
import json
import sys

job_file = sys.argv[1]
pid = int(sys.argv[2])
with open(job_file, "r", encoding="utf-8") as fh:
    job = json.load(fh)
job["pid"] = pid
job["childPid"] = None
with open(job_file, "w", encoding="utf-8") as fh:
    json.dump(job, fh, ensure_ascii=False, indent=2)
    fh.write("\n")
PY

  python_json "${job_id}" "${log_file}" "${summary}" <<'PY'
import json
import sys

job_id, log_file, summary = sys.argv[1:4]
print(json.dumps({
    "jobId": job_id,
    "status": "queued",
    "title": "Codex Task",
    "summary": summary,
    "logFile": log_file,
}, ensure_ascii=False))
PY
}

local_task_status_json() {
  local job_id="$1"
  local job_file
  job_file="$(local_task_job_file "${job_id}")"
  [ -f "${job_file}" ] || {
    printf '{"job":{"id":%s,"status":"missing","phase":"missing"}}\n' "$(json_escape "${job_id}")"
    return 0
  }

  local_task_mark_crashed_if_needed "${job_id}"
  python_json "${job_file}" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    job = json.load(fh)
print(json.dumps({"job": job}, ensure_ascii=False))
PY
}

local_task_result_json() {
  local job_id="$1"
  local job_file
  job_file="$(local_task_job_file "${job_id}")"
  [ -f "${job_file}" ] || {
    printf '{"storedJob":{"id":%s,"status":"missing","phase":"missing"}}\n' "$(json_escape "${job_id}")"
    return 0
  }

  local_task_mark_crashed_if_needed "${job_id}"
  python_json "${job_file}" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    job = json.load(fh)
print(json.dumps({"storedJob": job}, ensure_ascii=False))
PY
}

local_task_cancel_json() {
  local job_id="$1"
  local job_file
  job_file="$(local_task_job_file "${job_id}")"
  [ -f "${job_file}" ] || {
    printf '{"jobId":%s,"cancelled":false,"reason":"missing"}\n' "$(json_escape "${job_id}")"
    return 0
  }

  local worker_pid child_pid cancelled reason
  worker_pid="$(json_get_file "${job_file}" "pid" "")"
  child_pid="$(json_get_file "${job_file}" "childPid" "")"
  cancelled="false"
  reason="not-running"

  if [ -n "${child_pid}" ] && terminate_process_tree "${child_pid}"; then
    cancelled="true"
    reason="signal_sent"
  fi
  if [ -n "${worker_pid}" ]; then
    if kill -TERM "${worker_pid}" 2>/dev/null; then
      cancelled="true"
      reason="signal_sent"
    elif [ "${cancelled}" != "true" ]; then
      reason="already-exited"
    fi
  fi

  python_json "${job_file}" "${cancelled}" "${reason}" <<'PY'
import json
import sys

job_file = sys.argv[1]
cancelled = sys.argv[2] == "true"
reason = sys.argv[3]
with open(job_file, "r", encoding="utf-8") as fh:
    job = json.load(fh)

job["status"] = "cancelled"
job["phase"] = "cancelled"
job["pid"] = None
job["childPid"] = None
with open(job_file, "w", encoding="utf-8") as fh:
    json.dump(job, fh, ensure_ascii=False, indent=2)
    fh.write("\n")

print(json.dumps({
    "jobId": job.get("id"),
    "cancelled": cancelled,
    "reason": reason,
}, ensure_ascii=False))
PY
}

run_local_task_worker() {
  local job_id=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --job-id)
        job_id="${2:-}"
        shift 2
        ;;
      *)
        echo "Unknown option: $1" >&2
        exit 2
        ;;
    esac
  done
  [ -n "${job_id}" ] || {
    echo "local-task-worker requires --job-id" >&2
    exit 2
  }

  local job_file log_file output_file
  job_file="$(local_task_job_file "${job_id}")"
  [ -f "${job_file}" ] || {
    echo "job file not found: ${job_id}" >&2
    exit 1
  }
  log_file="$(local_task_log_file "${job_id}")"
  output_file="$(local_task_output_file "${job_id}")"

  local prompt_file
  prompt_file="$(json_get_file "${job_file}" "request.promptFile" "")"
  [ -f "${prompt_file}" ] || {
    local_task_write_record "${job_file}" "$(cat <<EOF
{
  "id": $(json_escape "${job_id}"),
  "status": "failed",
  "phase": "failed",
  "title": "Codex Task",
  "summary": "Missing prompt file",
  "workspaceRoot": $(json_escape "${PROJECT_ROOT}"),
  "jobClass": "task",
  "write": true,
  "logFile": $(json_escape "${log_file}"),
  "errorMessage": "Prompt file missing: ${prompt_file}"
}
EOF
)"
    exit 1
  }

  python_json "${job_file}" "$$" <<'PY'
import json
import sys
from datetime import datetime, timezone

job_file = sys.argv[1]
pid = int(sys.argv[2])
with open(job_file, "r", encoding="utf-8") as fh:
    job = json.load(fh)
job["status"] = "running"
job["phase"] = "running"
job["pid"] = pid
job["childPid"] = None
job["startedAt"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
with open(job_file, "w", encoding="utf-8") as fh:
    json.dump(job, fh, ensure_ascii=False, indent=2)
    fh.write("\n")
PY

  printf '[%s] local task worker started: %s\n' "$(timestamp_utc)" "${job_id}" >> "${log_file}"

  local exit_code=0
  local child_pid=""
  local worker_cancelled=0

  terminate_child() {
    worker_cancelled=1
    if [ -n "${child_pid}" ]; then
      printf '[%s] local task worker terminating child: %s\n' "$(timestamp_utc)" "${child_pid}" >> "${log_file}"
      terminate_process_tree "${child_pid}" || true
    fi
  }

  trap 'terminate_child' TERM INT
  codex exec - --dangerously-bypass-approvals-and-sandbox < "${prompt_file}" > "${output_file}" 2>> "${log_file}" &
  child_pid=$!
  python_json "${job_file}" "${child_pid}" <<'PY'
import json
import sys

job_file = sys.argv[1]
child_pid = int(sys.argv[2])
with open(job_file, "r", encoding="utf-8") as fh:
    job = json.load(fh)
job["childPid"] = child_pid
with open(job_file, "w", encoding="utf-8") as fh:
    json.dump(job, fh, ensure_ascii=False, indent=2)
    fh.write("\n")
PY
  set +e
  wait "${child_pid}"
  exit_code=$?
  set -e
  trap - TERM INT
  child_pid=""
  if [ "${worker_cancelled}" -eq 1 ] && [ "${exit_code}" -eq 0 ]; then
    exit_code=143
  fi

  python_json "${job_file}" "${output_file}" "${exit_code}" <<'PY'
import json
import pathlib
import sys
from datetime import datetime, timezone

job_file = pathlib.Path(sys.argv[1])
output_file = pathlib.Path(sys.argv[2])
exit_code = int(sys.argv[3])

with job_file.open("r", encoding="utf-8") as fh:
    job = json.load(fh)

raw_output = output_file.read_text(encoding="utf-8") if output_file.exists() else ""
was_cancelled = job.get("status") == "cancelled"
if was_cancelled:
    job["status"] = "cancelled"
    job["phase"] = "cancelled"
else:
    job["status"] = "completed" if exit_code == 0 else "failed"
    job["phase"] = "done" if exit_code == 0 else "failed"
job["pid"] = None
job["childPid"] = None
job["completedAt"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
job["result"] = {
    "status": exit_code,
    "rawOutput": raw_output,
    "touchedFiles": [],
    "reasoningSummary": [],
}
job["rendered"] = raw_output
if exit_code != 0 and not was_cancelled:
    job["errorMessage"] = f"codex exec exited with status {exit_code}"

with job_file.open("w", encoding="utf-8") as fh:
    json.dump(job, fh, ensure_ascii=False, indent=2)
    fh.write("\n")
PY

  printf '[%s] local task worker finished: %s (exit=%s)\n' "$(timestamp_utc)" "${job_id}" "${exit_code}" >> "${log_file}"
  return "${exit_code}"
}

resume_pack_best_effort() {
  if [ ! -x "${MEM_CLIENT}" ]; then
    log_line "resume-pack skipped: harness-mem client not executable"
    return 0
  fi
  local output
  if output="$("${MEM_CLIENT}" resume-pack --project claude-code-harness --limit 5 2>&1)"; then
    log_line "resume-pack ok"
  else
    log_line "resume-pack warning: ${output}"
  fi
}

builtin_validate_quick() {
  echo "=========================================="
  echo "Claude harness - クイック整合性チェック"
  echo "=========================================="
  echo ""

  local quick_fail=0

  if [ -d "${PROJECT_ROOT}/.claude/state" ]; then
    echo "✓ .claude/state/ ディレクトリが存在します"
  else
    echo "✗ .claude/state/ ディレクトリが見つかりません"
    quick_fail=$((quick_fail + 1))
  fi

  local plans_file=""
  plans_file="$(plans_file_path)"
  if [ -n "${plans_file}" ] && [ -f "${plans_file}" ]; then
    echo "✓ Plans.md が存在します: ${plans_file}"
  else
    echo "✗ Plans.md が見つかりません"
    quick_fail=$((quick_fail + 1))
  fi

  if [ -n "${plans_file}" ] && [ -f "${plans_file}" ]; then
    if grep -q "DoD" "${plans_file}" && grep -q "Depends" "${plans_file}"; then
      echo "✓ Plans.md は v2 フォーマットです（DoD / Depends カラムあり）"
    else
      echo "✗ Plans.md が v2 フォーマットではありません（DoD または Depends カラムがありません）"
      quick_fail=$((quick_fail + 1))
    fi
  fi

  local contract_dir="${PROJECT_ROOT}/.claude/state/contracts"
  if [ -d "${contract_dir}" ]; then
    local contract_error=0
    while IFS= read -r contract_file; do
      [ -f "${contract_file}" ] || continue
      if command -v jq >/dev/null 2>&1; then
        if ! jq empty "${contract_file}" >/dev/null 2>&1; then
          echo "✗ 壊れた JSON: $(basename "${contract_file}")"
          contract_error=$((contract_error + 1))
        fi
      elif command -v python3 >/dev/null 2>&1; then
        if ! python3 -c "import json,sys; json.load(open(sys.argv[1], encoding='utf-8'))" "${contract_file}" >/dev/null 2>&1; then
          echo "✗ 壊れた JSON: $(basename "${contract_file}")"
          contract_error=$((contract_error + 1))
        fi
      fi
    done < <(find "${contract_dir}" -name "*.sprint-contract.json" -type f 2>/dev/null)

    if [ "${contract_error}" -eq 0 ]; then
      echo "✓ sprint-contract の形式チェックは問題ありません"
    else
      quick_fail=$((quick_fail + contract_error))
    fi
  else
    echo "✓ sprint-contract ディレクトリは未作成（初回実行）"
  fi

  echo ""
  if [ "${quick_fail}" -eq 0 ]; then
    echo "✓ クイック整合性チェック: OK"
    return 0
  fi

  echo "✗ クイック整合性チェック: ${quick_fail} 件の問題があります"
  return 1
}

validate_quick() {
  if [ -n "${CODEX_LOOP_VALIDATE_SCRIPT:-}" ]; then
    if [ ! -f "${VALIDATE_SCRIPT}" ]; then
      echo "validate script not found: ${VALIDATE_SCRIPT}" >&2
      return 1
    fi
    (cd "${PROJECT_ROOT}" && bash "${VALIDATE_SCRIPT}" --quick)
    return 0
  fi

  if [ -f "${VALIDATE_SCRIPT}" ]; then
    (cd "${PROJECT_ROOT}" && bash "${VALIDATE_SCRIPT}" --quick)
    return 0
  fi

  builtin_validate_quick
}

generate_contract() {
  if [[ "${GENERATE_CONTRACT_SCRIPT}" == *.js ]]; then
    (cd "${PROJECT_ROOT}" && "${NODE_BIN}" "${GENERATE_CONTRACT_SCRIPT}" "$1")
  else
    (cd "${PROJECT_ROOT}" && "${GENERATE_CONTRACT_SCRIPT}" "$1")
  fi
}

enrich_contract() {
  (cd "${PROJECT_ROOT}" && "${ENRICH_CONTRACT_SCRIPT}" "$1" --check "Codex loop auto-approval for task $2" --approve)
}

ensure_contract_ready() {
  (cd "${PROJECT_ROOT}" && "${ENSURE_CONTRACT_SCRIPT}" "$1")
}

run_runtime_review() {
  (cd "${PROJECT_ROOT}" && "${RUNTIME_REVIEW_SCRIPT}" "$1" "$2")
}

write_review_result() {
  (cd "${PROJECT_ROOT}" && "${WRITE_REVIEW_RESULT_SCRIPT}" "$1" "$2" "$3")
}

run_plateau_check() {
  (cd "${PROJECT_ROOT}" && "${PLATEAU_SCRIPT}" "$1")
}

run_checkpoint() {
  (cd "${PROJECT_ROOT}" && "${CHECKPOINT_SCRIPT}" "$1" "$2" "$3" "$4")
}

advisor_script_path() {
  printf '%s\n' "${CODEX_LOOP_ADVISOR_SCRIPT:-${HARNESS_INSTALL_ROOT}/scripts/run-advisor-consultation.sh}"
}

advisor_enabled_globally() {
  if [ ! -f "${CONFIG_UTILS}" ]; then
    printf 'true\n'
    return 0
  fi
  # shellcheck disable=SC1090
  PROJECT_ROOT="${PROJECT_ROOT}" CONFIG_FILE="${PROJECT_ROOT}/.claude-code-harness.config.yaml" source "${CONFIG_UTILS}"
  get_advisor_enabled
}

advisor_retry_threshold() {
  if [ ! -f "${CONFIG_UTILS}" ]; then
    printf '2\n'
    return 0
  fi
  # shellcheck disable=SC1090
  PROJECT_ROOT="${PROJECT_ROOT}" CONFIG_FILE="${PROJECT_ROOT}/.claude-code-harness.config.yaml" source "${CONFIG_UTILS}"
  get_advisor_retry_threshold
}

advisor_max_consults_per_task() {
  if [ ! -f "${CONFIG_UTILS}" ]; then
    printf '3\n'
    return 0
  fi
  # shellcheck disable=SC1090
  PROJECT_ROOT="${PROJECT_ROOT}" CONFIG_FILE="${PROJECT_ROOT}/.claude-code-harness.config.yaml" source "${CONFIG_UTILS}"
  get_advisor_max_consults_per_task
}

advisor_consult_before_user_escalation() {
  if [ ! -f "${CONFIG_UTILS}" ]; then
    printf 'true\n'
    return 0
  fi
  # shellcheck disable=SC1090
  PROJECT_ROOT="${PROJECT_ROOT}" CONFIG_FILE="${PROJECT_ROOT}/.claude-code-harness.config.yaml" source "${CONFIG_UTILS}"
  get_advisor_consult_before_user_escalation
}

advisor_model_name() {
  if [ ! -f "${CONFIG_UTILS}" ]; then
    printf 'gpt-5.4\n'
    return 0
  fi
  # shellcheck disable=SC1090
  PROJECT_ROOT="${PROJECT_ROOT}" CONFIG_FILE="${PROJECT_ROOT}/.claude-code-harness.config.yaml" source "${CONFIG_UTILS}"
  get_advisor_codex_model
}

contract_advisor_enabled() {
  local contract_path="$1"
  local global_enabled
  global_enabled="$(advisor_enabled_globally)"
  if [ "${global_enabled}" != "true" ]; then
    printf 'false\n'
    return 0
  fi
  json_get_file "${contract_path}" "advisor.enabled" "false"
}

contract_high_risk_summary() {
  local contract_path="$1"
  python_json "${contract_path}" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)

triggers = data.get("advisor", {}).get("triggers", []) or []
high_risk = [value for value in triggers if value in {"needs-spike", "security-sensitive", "state-migration"}]
print(",".join(high_risk))
PY
}

normalize_error_signature() {
  local text="$1"
  python_json "${text}" <<'PY'
import re
import sys

normalized = re.sub(r"[^a-z0-9]+", "-", sys.argv[1].lower()).strip("-")
print(normalized[:80] or "none")
PY
}

advisor_trigger_seen() {
  local trigger_hash="$1"
  python_json "${RUN_JSON}" "${trigger_hash}" <<'PY'
import json
import os
import sys

path = sys.argv[1]
target = sys.argv[2]
if not os.path.exists(path):
    raise SystemExit(1)

with open(path, "r", encoding="utf-8") as fh:
    data = json.load(fh)

hashes = data.get("consulted_trigger_hashes", []) or []
raise SystemExit(0 if target in hashes else 1)
PY
}

advisor_task_consult_count() {
  local task_id="$1"
  python_json "${RUN_JSON}" "${task_id}" <<'PY'
import json
import os
import sys

path = sys.argv[1]
task_id = sys.argv[2]
if not os.path.exists(path):
    print(0)
    raise SystemExit(0)

with open(path, "r", encoding="utf-8") as fh:
    data = json.load(fh)

counts = data.get("task_consultations", {}) or {}
print(counts.get(task_id, 0))
PY
}

record_advisor_consultation() {
  local task_id="$1"
  local trigger_hash="$2"
  local decision="$3"
  local model="$4"
  python_json "${RUN_JSON}" "${task_id}" "${trigger_hash}" "${decision}" "${model}" <<'PY'
import json
import os
import sys
import tempfile

path, task_id, trigger_hash, decision, model = sys.argv[1:6]
data = {}
if os.path.exists(path):
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)

data["consultations"] = int(data.get("consultations", 0)) + 1
data["last_decision"] = decision
data["last_trigger"] = trigger_hash
data["last_model"] = model

hashes = data.setdefault("consulted_trigger_hashes", [])
if trigger_hash not in hashes:
    hashes.append(trigger_hash)

task_counts = data.setdefault("task_consultations", {})
task_counts[task_id] = int(task_counts.get(task_id, 0)) + 1

parent = os.path.dirname(path) or "."
fd, tmp_path = tempfile.mkstemp(prefix=".run-json-", suffix=".tmp", dir=parent)
with os.fdopen(fd, "w", encoding="utf-8") as fh:
    json.dump(data, fh, ensure_ascii=False, indent=2)
    fh.write("\n")
os.replace(tmp_path, path)
PY
}

render_advisor_guidance() {
  local response_file="$1"
  python_json "${response_file}" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    payload = json.load(fh)

lines = []
summary = payload.get("summary")
if summary:
    lines.append(f"Advisor summary: {summary}")
for item in payload.get("executor_instructions", []) or []:
    lines.append(f"- {item}")

print("\n".join(lines))
PY
}

consult_advisor() {
  local task_id="$1"
  local reason_code="$2"
  local trigger_hash="$3"
  local question="$4"
  local attempt="$5"
  local last_error="$6"
  local context_summary="$7"

  local request_file response_file model
  model="$(advisor_model_name)"
  request_file="${RESULTS_DIR}/${task_id}.${reason_code}.advisor-request.json"
  response_file="${RESULTS_DIR}/${task_id}.${reason_code}.advisor-response.json"

  python_json "${request_file}" "${task_id}" "${reason_code}" "${trigger_hash}" "${question}" "${attempt}" "${last_error}" "${context_summary}" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
task_id, reason_code, trigger_hash, question, attempt, last_error, context_summary = sys.argv[2:9]
context_items = [item for item in context_summary.split("||") if item]
payload = {
    "schema_version": "advisor-request.v1",
    "task_id": task_id,
    "reason_code": reason_code,
    "trigger_hash": trigger_hash,
    "question": question,
    "attempt": int(attempt),
    "last_error": last_error,
    "context_summary": context_items,
}
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

  bash "$(advisor_script_path)" \
    --request-file "${request_file}" \
    --response-file "${response_file}" \
    --model "${model}" >> "${RUNNER_LOG}" 2>&1

  local decision
  decision="$(json_get_file "${response_file}" "decision" "")"
  record_advisor_consultation "${task_id}" "${trigger_hash}" "${decision}" "${model}"
  printf '%s\n' "${response_file}"
}

create_cycle_prompt() {
  local task_id="$1"
  local contract_path="$2"
  local result_file="$3"
  local advisor_guidance="${4:-}"
  cat > "${result_file}" <<EOF
You are running one Codex loop cycle inside ${PROJECT_ROOT}.

Target task: ${task_id}
Sprint contract: ${contract_path}

${advisor_guidance:+Advisor guidance for this attempt:
${advisor_guidance}
}

Do exactly one task cycle.
1. Read Plans.md and the sprint contract.
2. Work only on task ${task_id}. Do not start another long-running loop or background runner.
3. Implement the task, run the validation you judge necessary, and keep the repo coherent.
4. If the task is in a good state, update Plans.md for ${task_id} to \`cc:完了 [<commit>]\` and create a commit.
5. If the task is blocked or not ready to approve, do not fake completion. Leave a clear explanation in the final message.
6. In all cases, end with a short summary that starts with either:
   - RESULT: APPROVED
   - RESULT: BLOCKED

Important:
- Be honest about failures.
- Do not revert unrelated user changes.
- Keep all work inside this repository.
EOF
}

build_review_input() {
  local output_file="$1"
  local verdict="$2"
  local reviewer_profile="$3"
  local task_id="$4"
  local task_title="$5"
  local summary="$6"
  python_json "${output_file}" "${verdict}" "${reviewer_profile}" "${task_id}" "${task_title}" "${summary}" <<'PY'
import json
import sys

path, verdict, reviewer_profile, task_id, task_title, summary = sys.argv[1:7]
payload = {
    "schema_version": "codex-loop-review-input.v1",
    "verdict": verdict,
    "reviewer_profile": reviewer_profile,
    "task": {
        "id": task_id,
        "title": task_title,
    },
    "recommendations": [] if verdict == "APPROVE" else [summary or "Task did not reach approval."],
}
with open(path, "w", encoding="utf-8") as fh:
    json.dump(payload, fh, ensure_ascii=False, indent=2)
    fh.write("\n")
PY
}

cleanup_current_job() {
  rm -f "${CURRENT_JOB_JSON}" 2>/dev/null || true
  run_state_patch '{
    "current_task_id": null,
    "current_cycle": null,
    "current_job_id": null,
    "current_job_status": null,
    "current_job_phase": null,
    "current_job_log": null
  }'
}

finalize_run() {
  local status="$1"
  local exit_reason="$2"
  local error_message="${3:-}"
  local runner_pid=""
  runner_pid="$(json_get_file "${RUN_JSON}" "pid" "")"
  run_state_patch "$(cat <<EOF
{
  "status": $(json_escape "${status}"),
  "exit_reason": $(json_escape "${exit_reason}"),
  "finished_at": $(json_escape "$(timestamp_utc)"),
  "updated_at": $(json_escape "$(timestamp_utc)"),
  "pid": null,
  "error_message": $( [ -n "${error_message}" ] && json_escape "${error_message}" || printf 'null' )
}
EOF
)"
  cleanup_current_job
  release_lock
  log_line "run finished: status=${status} reason=${exit_reason}"
  [ -n "${runner_pid}" ] && true
}

write_current_job_state() {
  local json_payload="$1"
  local tmp_file
  tmp_file="$(mktemp "${CURRENT_JOB_JSON}.tmp.XXXXXX")"
  printf '%s\n' "${json_payload}" > "${tmp_file}"
  mv "${tmp_file}" "${CURRENT_JOB_JSON}"
}

perform_cycle() {
  local run_id="$1"
  local task_id="$2"
  local cycle_number="$3"
  local cycle_started_at
  cycle_started_at="$(timestamp_utc)"

  log_line "cycle ${cycle_number} starting for task ${task_id}"
  if ! validate_quick >> "${RUNNER_LOG}" 2>&1; then
    log_line "cycle ${cycle_number} failed validation"
    return 20
  fi

  resume_pack_best_effort

  local contract_path
  contract_path="$(generate_contract "${task_id}")"
  contract_path="$(enrich_contract "${contract_path}" "${task_id}")"
  ensure_contract_ready "${contract_path}" >> "${RUNNER_LOG}" 2>&1

  local task_title reviewer_profile
  task_title="$(task_title_from_contract "${contract_path}")"
  reviewer_profile="$(json_get_file "${contract_path}" "review.reviewer_profile" "static")"

  local prompt_file runtime_review_file review_input_file review_result_file
  prompt_file="${PROMPTS_DIR}/${run_id}-cycle-${cycle_number}.md"
  runtime_review_file="${RESULTS_DIR}/${run_id}-cycle-${cycle_number}.runtime.json"
  review_input_file="${RESULTS_DIR}/${run_id}-cycle-${cycle_number}.review-input.json"
  review_result_file="${RESULTS_DIR}/${run_id}-cycle-${cycle_number}.review-result.json"

  local advisor_active advisor_guidance high_risk_summary
  advisor_active="$(contract_advisor_enabled "${contract_path}")"
  advisor_guidance=""
  high_risk_summary="$(contract_high_risk_summary "${contract_path}")"

  if [ "${advisor_active}" = "true" ] && [ -n "${high_risk_summary}" ]; then
    local preflight_hash preflight_response preflight_decision preflight_count preflight_exit
    preflight_hash="${task_id}:high-risk-preflight:$(normalize_error_signature "${high_risk_summary}")"
    preflight_count="$(advisor_task_consult_count "${task_id}")"
    if ! advisor_trigger_seen "${preflight_hash}" && [ "${preflight_count}" -lt "$(advisor_max_consults_per_task)" ]; then
      preflight_exit=0
      preflight_response="$(consult_advisor "${task_id}" "high-risk-preflight" "${preflight_hash}" "高リスク task の初回実行前。どの観点を先に固めるべきか。" 1 "${high_risk_summary}" "task=${task_id}||risk_triggers=${high_risk_summary}||cycle=${cycle_number}")" || preflight_exit=$?
      if [ "${preflight_exit}" -ne 0 ]; then
        log_line "advisor preflight failed for ${task_id} (exit=${preflight_exit}); continuing without guidance"
        advisor_guidance=""
      else
        preflight_decision="$(json_get_file "${preflight_response}" "decision" "")"
        advisor_guidance="$(render_advisor_guidance "${preflight_response}")"
        if [ "${preflight_decision}" = "STOP" ]; then
          log_line "advisor stop before execution for ${task_id}"
          return 21
        fi
      fi
    fi
  fi

  local retry_threshold max_consults attempt_limit
  retry_threshold="$(advisor_retry_threshold)"
  max_consults="$(advisor_max_consults_per_task)"
  attempt_limit=$((retry_threshold + 1))

  local task_attempt=1 failure_count=0 failure_signature=""
  local job_id="" job_log="" job_status="" job_phase="" summary=""
  local post_head="" static_verdict="REQUEST_CHANGES" runtime_verdict="REQUEST_CHANGES" final_verdict="REQUEST_CHANGES"
  local checkpoint_status="skipped" plateau_exit=1

  while [ "${task_attempt}" -le "${attempt_limit}" ]; do
    create_cycle_prompt "${task_id}" "${contract_path}" "${prompt_file}" "${advisor_guidance}"

    local pre_head=""
    pre_head="$(cd "${PROJECT_ROOT}" && git rev-parse --short HEAD 2>/dev/null || true)"

    local task_launch_json
    task_launch_json="$(start_background_task "${prompt_file}")"
    job_id="$(python_json "${task_launch_json}" <<'PY'
import json, sys
print(json.loads(sys.argv[1]).get("jobId", ""))
PY
)"
    job_log="$(python_json "${task_launch_json}" <<'PY'
import json, sys
print(json.loads(sys.argv[1]).get("logFile", ""))
PY
)"
    [ -n "${job_id}" ] || {
      log_line "cycle ${cycle_number} missing job id"
      return 21
    }

    write_current_job_state "$(cat <<EOF
{
  "run_id": $(json_escape "${run_id}"),
  "cycle": ${cycle_number},
  "attempt": ${task_attempt},
  "task_id": $(json_escape "${task_id}"),
  "job_id": $(json_escape "${job_id}"),
  "log_file": $(json_escape "${job_log}"),
  "contract_path": $(json_escape "${contract_path}"),
  "reviewer_profile": $(json_escape "${reviewer_profile}"),
  "started_at": $(json_escape "${cycle_started_at}")
}
EOF
)"
    run_state_patch "$(cat <<EOF
{
  "status": "running",
  "updated_at": $(json_escape "$(timestamp_utc)"),
  "current_task_id": $(json_escape "${task_id}"),
  "current_cycle": ${cycle_number},
  "current_job_id": $(json_escape "${job_id}"),
  "current_job_status": "queued",
  "current_job_phase": "queued",
  "current_job_log": $(json_escape "${job_log}")
}
EOF
)"

    local stop_cancelled=0
    local status_json
    while true; do
      status_json="$(companion_status_json "${job_id}" 2>/dev/null || true)"
      local status_payload="${status_json}"
      [ -n "${status_payload}" ] || status_payload='{}'
      job_status="$(python_json "${status_payload}" <<'PY'
import json, sys
try:
    payload = json.loads(sys.argv[1]) if sys.argv[1] else {}
except json.JSONDecodeError:
    payload = {}
job = payload.get("job", {})
print(job.get("status", "unknown"))
PY
)"
      job_phase="$(python_json "${status_payload}" <<'PY'
import json, sys
try:
    payload = json.loads(sys.argv[1]) if sys.argv[1] else {}
except json.JSONDecodeError:
    payload = {}
job = payload.get("job", {})
print(job.get("phase", "unknown"))
PY
)"

      run_state_patch "$(cat <<EOF
{
  "updated_at": $(json_escape "$(timestamp_utc)"),
  "current_job_status": $(json_escape "${job_status}"),
  "current_job_phase": $(json_escape "${job_phase}")
}
EOF
)"

      if stop_requested && [ "${stop_cancelled}" -eq 0 ] && { [ "${job_status}" = "queued" ] || [ "${job_status}" = "running" ]; }; then
        log_line "stop requested: cancelling ${job_id}"
        companion_cancel_json "${job_id}" >> "${RUNNER_LOG}" 2>&1 || true
        stop_cancelled=1
      fi

      if [ "${job_status}" != "queued" ] && [ "${job_status}" != "running" ]; then
        break
      fi
      sleep "${POLL_INTERVAL_SEC}"
    done

    local result_json result_payload
    result_json="$(companion_result_json "${job_id}" 2>/dev/null || true)"
    result_payload="${result_json}"
    [ -n "${result_payload}" ] || result_payload='{}'
    summary="$(python_json "${result_payload}" <<'PY'
import json, sys
try:
    payload = json.loads(sys.argv[1]) if sys.argv[1] else {}
except json.JSONDecodeError:
    payload = {}
stored = payload.get("storedJob", {}) or {}
result = stored.get("result", {}) or {}
raw = result.get("rawOutput", "") or stored.get("rendered", "") or ""
for line in str(raw).splitlines():
    if line.strip():
        print(line.strip())
        break
else:
    print("")
PY
)"

    post_head="$(cd "${PROJECT_ROOT}" && git rev-parse --short HEAD 2>/dev/null || true)"
    local task_status
    task_status="$(task_status_value "$(plans_file_path)" "${task_id}" 2>/dev/null || true)"

    static_verdict="REQUEST_CHANGES"
    if [ -n "${post_head}" ] && [ "${post_head}" != "${pre_head}" ] && printf '%s' "${task_status}" | grep -q 'cc:完了'; then
      static_verdict="APPROVE"
    fi

    runtime_verdict="${static_verdict}"
    if run_runtime_review "${contract_path}" "${runtime_review_file}" >> "${RUNNER_LOG}" 2>&1; then
      runtime_verdict="$(json_get_file "${runtime_review_file}" "verdict" "${static_verdict}")"
    fi

    final_verdict="${static_verdict}"
    if [ "${runtime_verdict}" = "REQUEST_CHANGES" ]; then
      final_verdict="REQUEST_CHANGES"
    elif [ "${runtime_verdict}" = "APPROVE" ] && [ "${static_verdict}" = "APPROVE" ]; then
      final_verdict="APPROVE"
    fi

    build_review_input "${review_input_file}" "${final_verdict}" "${reviewer_profile}" "${task_id}" "${task_title}" "${summary}"
    write_review_result "${review_input_file}" "${post_head}" "${review_result_file}" >> "${RUNNER_LOG}" 2>&1 || true

    if [ "${final_verdict}" = "APPROVE" ]; then
      break
    fi

    local current_signature
    current_signature="$(normalize_error_signature "${summary}")"
    if [ "${current_signature}" = "${failure_signature}" ]; then
      failure_count=$((failure_count + 1))
    else
      failure_signature="${current_signature}"
      failure_count=1
    fi

    if [ "${task_attempt}" -lt "${retry_threshold}" ]; then
      task_attempt=$((task_attempt + 1))
      advisor_guidance=""
      continue
    fi

    if [ "${advisor_active}" = "true" ] && [ "${failure_count}" -ge "${retry_threshold}" ]; then
      local retry_hash retry_response retry_decision retry_count retry_exit
      retry_hash="${task_id}:retry-threshold:${failure_signature}"
      retry_count="$(advisor_task_consult_count "${task_id}")"
      if ! advisor_trigger_seen "${retry_hash}" && [ "${retry_count}" -lt "${max_consults}" ]; then
        retry_exit=0
        retry_response="$(consult_advisor "${task_id}" "retry-threshold" "${retry_hash}" "同じ原因の失敗が繰り返された。次は何を変えるべきか。" "${task_attempt}" "${summary}" "task=${task_id}||attempt=${task_attempt}||signature=${failure_signature}")" || retry_exit=$?
        if [ "${retry_exit}" -ne 0 ]; then
          log_line "advisor retry-threshold failed for ${task_id} (exit=${retry_exit}); proceeding without guidance"
          advisor_guidance=""
          if [ "${task_attempt}" -lt "${attempt_limit}" ]; then
            task_attempt=$((task_attempt + 1))
            continue
          fi
        else
          retry_decision="$(json_get_file "${retry_response}" "decision" "")"
          advisor_guidance="$(render_advisor_guidance "${retry_response}")"
          if [ "${retry_decision}" = "STOP" ]; then
            break
          fi
          if [ "${task_attempt}" -lt "${attempt_limit}" ]; then
            task_attempt=$((task_attempt + 1))
            continue
          fi
        fi
      fi
    fi
    break
  done

  if [ -n "${post_head}" ] && [ "${final_verdict}" = "APPROVE" ] && [ -f "${review_result_file}" ]; then
    if run_checkpoint "${task_id}" "${post_head}" "${contract_path}" "${review_result_file}" >> "${RUNNER_LOG}" 2>&1; then
      checkpoint_status="ok"
    else
      checkpoint_status="failed"
    fi
  fi

  if run_plateau_check "${task_id}" >> "${RUNNER_LOG}" 2>&1; then
    plateau_exit=0
  else
    plateau_exit=$?
  fi

  if [ "${plateau_exit}" -eq 2 ] && [ "${advisor_active}" = "true" ] && [ "$(advisor_consult_before_user_escalation)" = "true" ]; then
    local plateau_hash plateau_response plateau_decision plateau_count
    plateau_hash="${task_id}:plateau-pre-escalation:$(normalize_error_signature "${summary}")"
    plateau_count="$(advisor_task_consult_count "${task_id}")"
    if ! advisor_trigger_seen "${plateau_hash}" && [ "${plateau_count}" -lt "${max_consults}" ]; then
      plateau_response="$(consult_advisor "${task_id}" "plateau-pre-escalation" "${plateau_hash}" "plateau により停止候補。もう一度進めるべきか止めるべきか。" "${task_attempt}" "${summary}" "task=${task_id}||phase=plateau||verdict=${final_verdict}")" || return 22
      plateau_decision="$(json_get_file "${plateau_response}" "decision" "")"
      if [ "${plateau_decision}" != "STOP" ]; then
        plateau_exit=0
      fi
    fi
  fi

  append_jsonl "${CYCLES_JSONL}" "$(cat <<EOF
{"run_id":$(json_escape "${run_id}"),"cycle":${cycle_number},"task_id":$(json_escape "${task_id}"),"job_id":$(json_escape "${job_id}"),"job_status":$(json_escape "${job_status}"),"reviewer_profile":$(json_escape "${reviewer_profile}"),"verdict":$(json_escape "${final_verdict}"),"static_verdict":$(json_escape "${static_verdict}"),"runtime_verdict":$(json_escape "${runtime_verdict}"),"commit_hash":$( [ -n "${post_head}" ] && json_escape "${post_head}" || printf 'null' ),"summary":$(json_escape "${summary}"),"checkpoint":$(json_escape "${checkpoint_status}"),"attempts":${task_attempt},"consultations":$(json_get_file "${RUN_JSON}" "consultations" "0"),"started_at":$(json_escape "${cycle_started_at}"),"finished_at":$(json_escape "$(timestamp_utc)")}
EOF
)"

  run_state_patch "$(cat <<EOF
{
  "cycle_count": ${cycle_number},
  "last_task_id": $(json_escape "${task_id}"),
  "last_job_id": $(json_escape "${job_id}"),
  "last_verdict": $(json_escape "${final_verdict}"),
  "updated_at": $(json_escape "$(timestamp_utc)")
}
EOF
)"
  cleanup_current_job

  if stop_requested; then
    return 30
  fi
  if [ "${plateau_exit}" -eq 2 ]; then
    return 22
  fi
  if [ "${final_verdict}" != "APPROVE" ]; then
    return 21
  fi
  return 0
}

cmd_start() {
  local selection="${1:-}"
  shift || true
  [ -n "${selection}" ] || {
    echo "codex-loop start requires a selection (all|TASK|START-END|START..END)" >&2
    exit 2
  }

  local max_cycles="8"
  local pacing="worker"
  while [ $# -gt 0 ]; do
    case "$1" in
      --max-cycles)
        max_cycles="${2:-}"
        shift 2
        ;;
      --pacing)
        pacing="${2:-}"
        shift 2
        ;;
      *)
        echo "Unknown option: $1" >&2
        exit 2
        ;;
    esac
  done

  local plans_file
  plans_file="$(plans_file_path)"
  [ -f "${plans_file}" ] || {
    echo "Plans.md not found under ${PROJECT_ROOT}" >&2
    exit 1
  }

  local normalized_selection=""
  if ! normalized_selection="$(normalize_selection "${plans_file}" "${selection}" 2>&1)"; then
    echo "${normalized_selection}" >&2
    exit 2
  fi
  selection="${normalized_selection}"

  ensure_dirs
  if ! acquire_lock; then
    local existing_pid=""
    existing_pid="$(cat "${LOCK_DIR}/pid" 2>/dev/null || true)"
    echo "codex-loop is already running (pid=${existing_pid:-unknown})" >&2
    exit 1
  fi

  local run_id delay_seconds
  run_id="codex-loop-$(date +%Y%m%d%H%M%S)-$$"
  delay_seconds="$(delay_for_pacing "${pacing}")"

  rm -f "${CURRENT_JOB_JSON}"
  local run_tmp
  run_tmp="$(mktemp "${RUN_JSON}.tmp.XXXXXX")"
  cat > "${run_tmp}" <<EOF
{
  "schema_version": "codex-loop-run.v1",
  "run_id": "$(printf '%s' "${run_id}")",
  "selection": "$(printf '%s' "${selection}")",
  "max_cycles": ${max_cycles},
  "pacing": "$(printf '%s' "${pacing}")",
  "delay_seconds": ${delay_seconds},
  "cycle_count": 0,
  "consultations": 0,
  "last_decision": null,
  "last_trigger": null,
  "last_model": null,
  "consulted_trigger_hashes": [],
  "task_consultations": {},
  "status": "starting",
  "started_at": "$(timestamp_utc)",
  "updated_at": "$(timestamp_utc)",
  "project_root": "$(printf '%s' "${PROJECT_ROOT}")",
  "plans_file": "$(printf '%s' "${plans_file}")"
}
EOF
  mv "${run_tmp}" "${RUN_JSON}"
  : > "${RUNNER_LOG}"

  log_line "starting runner: script=${SELF_SCRIPT} run_id=${run_id}"
  nohup env CODEX_LOOP_BOOTSTRAP_PID="$$" bash "${SELF_SCRIPT}" run --run-id "${run_id}" >> "${RUNNER_LOG}" 2>&1 &
  local runner_pid=$!
  printf '%s\n' "${runner_pid}" > "${LOCK_DIR}/pid"
  run_state_patch "$(cat <<EOF
{
  "pid": ${runner_pid},
  "status": "running",
  "updated_at": $(json_escape "$(timestamp_utc)")
}
EOF
)"
  printf 'Started codex-loop %s in background (pid=%s)\n' "${run_id}" "${runner_pid}"
}

cmd_status() {
  local as_json=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --json) as_json=1 ;;
      *)
        echo "Unknown option: $1" >&2
        exit 2
        ;;
    esac
    shift
  done

  ensure_dirs
  if [ ! -f "${RUN_JSON}" ]; then
    if [ "${as_json}" -eq 1 ]; then
      printf '{"status":"idle","project_root":%s}\n' "$(json_escape "${PROJECT_ROOT}")"
    else
      echo "codex-loop: idle"
    fi
    return 0
  fi

  local payload
  payload="$(python_json "${RUN_JSON}" "${CURRENT_JOB_JSON}" "${PROJECT_ROOT}" <<'PY'
import json
import os
import sys

run_file, current_job_file, project_root = sys.argv[1:4]

def pid_alive(pid):
    if pid in (None, "", 0):
        return False
    try:
        os.kill(int(pid), 0)
    except (OSError, ValueError, TypeError):
        return False
    return True

try:
    with open(run_file, "r", encoding="utf-8") as fh:
        run = json.load(fh)
except Exception as exc:
    print(json.dumps({
        "status": "state_corrupt",
        "project_root": project_root,
        "run": None,
        "current_job": None,
        "error": str(exc),
    }, ensure_ascii=False, indent=2))
    raise SystemExit(0)

payload = {"run": run, "current_job": None}
if os.path.exists(current_job_file):
    try:
        with open(current_job_file, "r", encoding="utf-8") as fh:
            payload["current_job"] = json.load(fh)
    except Exception as exc:
        payload["warning"] = f"current_job_corrupt: {exc}"

active_statuses = {"starting", "running", "waiting", "stopping"}
if run.get("status") in active_statuses and not pid_alive(run.get("pid")):
    run = dict(run)
    run["status"] = "state_stale"
    run["error_message"] = run.get("error_message") or "loop runner pid is not alive"
    payload["run"] = run

print(json.dumps(payload, ensure_ascii=False, indent=2))
PY
)"

  if [ "${as_json}" -eq 1 ]; then
    printf '%s\n' "${payload}"
    return 0
  fi

  python3 - "${payload}" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
status = payload.get("status")
if status == "state_corrupt":
    print("codex-loop: state_corrupt")
    print(f"  error: {payload.get('error', 'unknown error')}")
    raise SystemExit(0)

run = payload.get("run") or {}
print(f"codex-loop: {run.get('status', 'unknown')}")
selection = run.get("selection")
if selection:
    print(f"  selection: {selection}")
cycles = run.get("cycle_count")
max_cycles = run.get("max_cycles")
if cycles is not None and max_cycles is not None:
    print(f"  cycles: {cycles}/{max_cycles}")
task_id = run.get("current_task_id")
if task_id:
    print(f"  current task: {task_id}")
job_state = run.get("current_job_status")
if job_state:
    print(f"  current job: {job_state}")
exit_reason = run.get("exit_reason")
if exit_reason:
    print(f"  exit reason: {exit_reason}")
error_message = run.get("error_message")
if error_message:
    print(f"  error: {error_message}")
warning = payload.get("warning")
if warning:
    print(f"  warning: {warning}")
PY
}

cmd_stop() {
  ensure_dirs
  [ -f "${RUN_JSON}" ] || {
    echo "codex-loop is not running"
    return 0
  }

  run_state_patch "$(cat <<EOF
{
  "status": "stopping",
  "stop_requested_at": $(json_escape "$(timestamp_utc)"),
  "updated_at": $(json_escape "$(timestamp_utc)")
}
EOF
)"

  local job_id
  job_id="$(json_get_file "${RUN_JSON}" "current_job_id" "")"
  if [ -n "${job_id}" ]; then
    companion_cancel_json "${job_id}" >> "${RUNNER_LOG}" 2>&1 || true
  fi

  echo "stop requested"
}

prepare_run_lock() {
  local bootstrap_pid="${CODEX_LOOP_BOOTSTRAP_PID:-}"
  local lock_pid=""

  if [ -d "${LOCK_DIR}" ]; then
    lock_pid="$(cat "${LOCK_DIR}/pid" 2>/dev/null || true)"
    if [ -n "${lock_pid}" ] && is_pid_alive "${lock_pid}"; then
      if [ "${lock_pid}" != "$$" ] && [ -z "${bootstrap_pid}" -o "${lock_pid}" != "${bootstrap_pid}" ]; then
        return 1
      fi
    else
      rm -rf "${LOCK_DIR}" 2>/dev/null || true
    fi
  fi

  if [ ! -d "${LOCK_DIR}" ]; then
    if ! acquire_lock; then
      return 1
    fi
  fi

  printf '%s\n' "$$" > "${LOCK_DIR}/pid"
  return 0
}

cmd_run() {
  local run_id=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --run-id)
        run_id="${2:-}"
        shift 2
        ;;
      *)
        echo "Unknown option: $1" >&2
        exit 2
        ;;
    esac
  done
  [ -n "${run_id}" ] || {
    echo "run requires --run-id" >&2
    exit 2
  }

  ensure_dirs
  [ -f "${RUN_JSON}" ] || {
    echo "codex-loop run state not found for ${run_id}" >&2
    exit 1
  }

  local state_run_id=""
  state_run_id="$(json_get_file "${RUN_JSON}" "run_id" "")"
  if [ -n "${state_run_id}" ] && [ "${state_run_id}" != "${run_id}" ]; then
    echo "codex-loop run id mismatch: state has ${state_run_id}, requested ${run_id}" >&2
    exit 1
  fi

  if ! prepare_run_lock; then
    local existing_pid=""
    existing_pid="$(cat "${LOCK_DIR}/pid" 2>/dev/null || true)"
    log_line "runner refused to start: lock already held by pid=${existing_pid:-unknown}"
    echo "codex-loop is already running (pid=${existing_pid:-unknown})" >&2
    exit 1
  fi
  trap 'release_lock' EXIT

  local selection max_cycles pacing delay_seconds plans_file
  selection="$(json_get_file "${RUN_JSON}" "selection" "all")"
  max_cycles="$(json_get_file "${RUN_JSON}" "max_cycles" "8")"
  pacing="$(json_get_file "${RUN_JSON}" "pacing" "worker")"
  delay_seconds="$(json_get_file "${RUN_JSON}" "delay_seconds" "270")"
  plans_file="$(json_get_file "${RUN_JSON}" "plans_file" "$(plans_file_path)")"
  run_state_patch "$(cat <<EOF
{
  "pid": $$,
  "status": "running",
  "updated_at": $(json_escape "$(timestamp_utc)"),
  "exit_reason": null,
  "finished_at": null,
  "error_message": null,
  "stop_requested_at": null
}
EOF
)"

  while true; do
    if stop_requested; then
      finalize_run "stopped" "user_stop"
      exit 0
    fi

    local cycle_count
    cycle_count="$(json_get_file "${RUN_JSON}" "cycle_count" "0")"
    if [ "${cycle_count}" -ge "${max_cycles}" ]; then
      finalize_run "completed" "max_cycles"
      exit 0
    fi

    local task_id=""
    task_id="$(next_task_id "${selection}" "${plans_file}" 2>/dev/null || true)"
    if [ -z "${task_id}" ]; then
      finalize_run "completed" "no_remaining_tasks"
      exit 0
    fi

    local next_cycle
    next_cycle=$((cycle_count + 1))
    local cycle_status=0
    bash "${SELF_SCRIPT}" run-cycle --run-id "${run_id}" --task-id "${task_id}" --cycle "${next_cycle}" || cycle_status=$?
    if [ "${cycle_status}" -ne 0 ]; then
      case "${cycle_status}" in
        21) finalize_run "failed" "task_blocked" "Task ${task_id} did not reach approval" ;;
        22) finalize_run "failed" "pivot_required" "Plateau detected for task ${task_id}" ;;
        30) finalize_run "stopped" "user_stop" ;;
        *) finalize_run "failed" "cycle_error" "Cycle ${next_cycle} failed for task ${task_id}" ;;
      esac
      exit 1
    fi

    if stop_requested; then
      finalize_run "stopped" "user_stop"
      exit 0
    fi
    if [ "${next_cycle}" -ge "${max_cycles}" ]; then
      finalize_run "completed" "max_cycles"
      exit 0
    fi

    local remaining=""
    remaining="$(next_task_id "${selection}" "${plans_file}" 2>/dev/null || true)"
    if [ -z "${remaining}" ]; then
      finalize_run "completed" "no_remaining_tasks"
      exit 0
    fi

    run_state_patch "$(cat <<EOF
{
  "status": "waiting",
  "updated_at": $(json_escape "$(timestamp_utc)")
}
EOF
)"
    log_line "cycle ${next_cycle} finished; sleeping ${delay_seconds}s before next task"
    local slept=0
    while [ "${slept}" -lt "${delay_seconds}" ]; do
      if stop_requested; then
        finalize_run "stopped" "user_stop"
        exit 0
      fi
      sleep 1
      slept=$((slept + 1))
    done
    set_run_field "status" '"running"'
  done
}

cmd_run_cycle() {
  local run_id="" task_id="" cycle_number=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --run-id)
        run_id="${2:-}"
        shift 2
        ;;
      --task-id)
        task_id="${2:-}"
        shift 2
        ;;
      --cycle)
        cycle_number="${2:-}"
        shift 2
        ;;
      *)
        echo "Unknown option: $1" >&2
        exit 2
        ;;
    esac
  done
  [ -n "${run_id}" ] && [ -n "${task_id}" ] && [ -n "${cycle_number}" ] || {
    echo "run-cycle requires --run-id, --task-id, and --cycle" >&2
    exit 2
  }
  perform_cycle "${run_id}" "${task_id}" "${cycle_number}"
}

subcommand="${1:-}"
case "${subcommand}" in
  start)
    shift
    cmd_start "$@"
    ;;
  status)
    shift
    cmd_status "$@"
    ;;
  stop)
    shift
    cmd_stop "$@"
    ;;
  run)
    shift
    cmd_run "$@"
    ;;
  run-cycle)
    shift
    cmd_run_cycle "$@"
    ;;
  local-task-worker)
    shift
    run_local_task_worker "$@"
    ;;
  ""|-h|--help|help)
    usage
    ;;
  *)
    echo "Unknown subcommand: ${subcommand}" >&2
    usage >&2
    exit 2
    ;;
esac
