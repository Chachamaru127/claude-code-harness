#!/bin/bash
# TaskCompleted 完了時 finalize の安全条件を検証

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TASK_COMPLETED_SCRIPT="${ROOT_DIR}/scripts/hook-handlers/task-completed.sh"

TMP_DIR="$(mktemp -d)"
SERVER_PID=""
REQUEST_LOG="${TMP_DIR}/requests.jsonl"
PORT_FILE="${TMP_DIR}/server.port"

cleanup() {
  if [ -n "${SERVER_PID}" ] && kill -0 "${SERVER_PID}" 2>/dev/null; then
    kill "${SERVER_PID}" 2>/dev/null || true
    wait "${SERVER_PID}" 2>/dev/null || true
  fi
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

: > "${REQUEST_LOG}"

start_server() {
  python3 - "${REQUEST_LOG}" "${PORT_FILE}" <<'PY' &
import http.server
import sys
from pathlib import Path

request_log = Path(sys.argv[1])
port_file = Path(sys.argv[2])

class Handler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length).decode("utf-8")
        with request_log.open("a", encoding="utf-8") as fh:
            fh.write(body + "\n")
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"ok")

    def log_message(self, fmt, *args):
        return

server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
port_file.write_text(str(server.server_address[1]), encoding="utf-8")
server.serve_forever()
PY
  SERVER_PID=$!

  for _ in $(seq 1 50); do
    if [ -s "${PORT_FILE}" ]; then
      return 0
    fi
    sleep 0.1
  done

  echo "capture server did not start"
  exit 1
}

request_count() {
  wc -l < "${REQUEST_LOG}" | tr -d ' '
}

write_breezing_active() {
  local project_dir="$1"
  local session_id="${2:-}"
  cat > "${project_dir}/.claude/state/breezing-active.json" <<EOF
{
  "session_id": "${session_id}",
  "batching": {
    "batches": [
      {
        "status": "in_progress",
        "task_ids": ["26.0.1", "26.0.2"]
      }
    ]
  },
  "plans_md_mapping": {
    "26.0.1": {},
    "26.0.2": {}
  }
}
EOF
}

seed_first_task() {
  local project_dir="$1"
  printf '%s\n' '{"event":"task_completed","task_id":"26.0.1"}' > "${project_dir}/.claude/state/breezing-timeline.jsonl"
}

run_task_completed() {
  local project_dir="$1"
  local payload="$2"
  PROJECT_ROOT="${project_dir}" \
    HARNESS_MEM_BASE_URL="http://127.0.0.1:${SERVER_PORT}" \
    bash "${TASK_COMPLETED_SCRIPT}" <<< "${payload}"
}

start_server
SERVER_PORT="$(cat "${PORT_FILE}")"

# Case 1: 途中タスクでは finalize しない
CASE1_DIR="${TMP_DIR}/case1"
mkdir -p "${CASE1_DIR}/.claude/state"
write_breezing_active "${CASE1_DIR}" "session-case1"

case1_output="$(run_task_completed "${CASE1_DIR}" '{"teammate_name":"impl-1","task_id":"26.0.1","task_subject":"最初のタスク"}')"
grep -q '"decision":"approve"' <<<"${case1_output}" || {
  echo "non-final task should approve"
  exit 1
}
[ "$(request_count)" = "0" ] || {
  echo "non-final task should not call finalize"
  exit 1
}

# Case 2: 最後のタスクで session.json fallback を使って finalize
CASE2_DIR="${TMP_DIR}/case2"
mkdir -p "${CASE2_DIR}/.claude/state"
write_breezing_active "${CASE2_DIR}" ""
seed_first_task "${CASE2_DIR}"
cat > "${CASE2_DIR}/.claude/state/session.json" <<'EOF'
{
  "session_id": "session-case2",
  "project_name": "demo-project"
}
EOF

case2_output="$(run_task_completed "${CASE2_DIR}" '{"teammate_name":"impl-1","task_id":"26.0.2","task_subject":"最後のタスク"}')"
grep -q '"stopReason":"all_tasks_completed"' <<<"${case2_output}" || {
  echo "final task should stop after completion"
  exit 1
}
[ "$(request_count)" = "1" ] || {
  echo "final task should call finalize exactly once"
  exit 1
}

tail -n 1 "${REQUEST_LOG}" | jq -e '.session_id == "session-case2" and .project == "demo-project" and .summary_mode == "work_completed"' >/dev/null || {
  echo "finalize payload should include fallback session and project"
  exit 1
}

[ -f "${CASE2_DIR}/.claude/state/harness-mem-finalize-work-completed.json" ] || {
  echo "finalize marker should be written after success"
  exit 1
}

# Case 3: 同一セッションの再実行では finalize を重複送信しない
case3_output="$(run_task_completed "${CASE2_DIR}" '{"teammate_name":"impl-1","task_id":"26.0.2","task_subject":"最後のタスク"}')"
grep -q '"stopReason":"all_tasks_completed"' <<<"${case3_output}" || {
  echo "duplicate final task should still stop cleanly"
  exit 1
}
[ "$(request_count)" = "1" ] || {
  echo "duplicate final task should not call finalize twice"
  exit 1
}

# Case 4: session_id が解決できない時は静かに skip
CASE4_DIR="${TMP_DIR}/case4"
mkdir -p "${CASE4_DIR}/.claude/state"
write_breezing_active "${CASE4_DIR}" ""
seed_first_task "${CASE4_DIR}"

case4_output="$(run_task_completed "${CASE4_DIR}" '{"teammate_name":"impl-1","task_id":"26.0.2","task_subject":"最後のタスク"}')"
grep -q '"stopReason":"all_tasks_completed"' <<<"${case4_output}" || {
  echo "missing session id case should still stop cleanly"
  exit 1
}
[ "$(request_count)" = "1" ] || {
  echo "missing session id should skip finalize"
  exit 1
}
[ ! -f "${CASE4_DIR}/.claude/state/harness-mem-finalize-work-completed.json" ] || {
  echo "missing session id should not write finalize marker"
  exit 1
}

echo "OK"
