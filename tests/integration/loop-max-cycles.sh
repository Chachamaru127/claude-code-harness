#!/bin/bash
# loop-max-cycles.sh
# Verify that harness-loop stops without exceeding the maximum cycle count

set -euo pipefail

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

mkdir -p "${TMP_DIR}/.claude/state/locks"

QUEUE_FILE="${TMP_DIR}/queue.txt"
LOG_FILE="${TMP_DIR}/cycles.log"
LOCK_DIR="${TMP_DIR}/.claude/state/locks/loop-session.lock.d"

cat > "${QUEUE_FILE}" <<'EOF'
task-1
task-2
task-3
task-4
EOF

MOCK_LOOP_SCRIPT="${TMP_DIR}/mock-loop.sh"
cat > "${MOCK_LOOP_SCRIPT}" <<'EOF'
#!/bin/bash
set -euo pipefail

QUEUE_FILE="$1"
LOG_FILE="$2"
LOCK_DIR="$3"
MAX_CYCLES="${HARNESS_LOOP_MAX_CYCLES:-${MAX_CYCLES:-3}}"

case "${MAX_CYCLES}" in
  ''|*[!0-9]*) MAX_CYCLES=3 ;;
esac
if [ "${MAX_CYCLES}" -lt 1 ]; then
  MAX_CYCLES=1
fi

mkdir -p "$(dirname "${LOCK_DIR}")"
if ! mkdir "${LOCK_DIR}" 2>/dev/null; then
  echo "harness-loop: already running" >&2
  exit 10
fi

printf '{"pid":%d,"started_at":"%s"}\n' "$$" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "${LOCK_DIR}/meta.json"
trap 'rm -rf "${LOCK_DIR}" 2>/dev/null || true' EXIT INT TERM

cycle=0
while [ "${cycle}" -lt "${MAX_CYCLES}" ]; do
  task="$(sed -n "$((cycle + 1))p" "${QUEUE_FILE}" 2>/dev/null || true)"
  [ -n "${task}" ] || break

  cycle=$((cycle + 1))
  printf 'cycle=%s task=%s\n' "${cycle}" "${task}" >> "${LOG_FILE}"
done

if [ "${cycle}" -ge "${MAX_CYCLES}" ]; then
  printf 'max cycles reached (%s)\n' "${MAX_CYCLES}" >> "${LOG_FILE}"
fi
EOF
chmod +x "${MOCK_LOOP_SCRIPT}"

if ! HARNESS_LOOP_MAX_CYCLES=3 bash "${MOCK_LOOP_SCRIPT}" "${QUEUE_FILE}" "${LOG_FILE}" "${LOCK_DIR}" >/dev/null 2>&1; then
  echo "mock loop script failed"
  exit 1
fi

cycle_count="$(grep -c '^cycle=' "${LOG_FILE}" 2>/dev/null || echo 0)"
if [ "${cycle_count}" -ne 3 ]; then
  echo "cycle count is not 3: ${cycle_count}"
  exit 1
fi

grep -q 'max cycles reached (3)' "${LOG_FILE}" || {
  echo "max cycles reached notification not found"
  exit 1
}

grep -q 'task-4' "${LOG_FILE}" && {
  echo "4th task was processed"
  exit 1
}

[ ! -d "${LOCK_DIR}" ] || {
  echo "lock directory still exists"
  exit 1
}

echo "OK"
