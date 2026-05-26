#!/bin/bash
# loop-plans-concurrent.sh
# Verify that no updates are lost when harness-loop and plans updates run concurrently

set -euo pipefail

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

WORK_DIR="${TMP_DIR}/work"
mkdir -p "${WORK_DIR}/.claude/state/locks"

LOCK_FILE="${WORK_DIR}/.claude/state/locks/plans.flock"
LOCK_DIR="${LOCK_FILE}.dir"
STATE_FILE="${WORK_DIR}/.claude/state/plans-state.json"

printf '0\n' > "${STATE_FILE}"

WORKER_SCRIPT="${TMP_DIR}/plans-worker.sh"
cat > "${WORKER_SCRIPT}" <<'EOF'
#!/bin/bash
set -euo pipefail

LOCK_FILE="$1"
STATE_FILE="$2"
WORKER_ID="$3"
LOCK_DIR="${LOCK_FILE}.dir"
LOCK_TIMEOUT=3
_LOCK_ACQUIRED=0

acquire_lock() {
  mkdir -p "$(dirname "${LOCK_FILE}")" 2>/dev/null || true

  if command -v flock >/dev/null 2>&1; then
    exec 8>"${LOCK_FILE}"
    if flock -w "${LOCK_TIMEOUT}" 8 2>/dev/null; then
      _LOCK_ACQUIRED=1
      return 0
    fi
    exec 8>&- 2>/dev/null || true
  fi

  if command -v lockf >/dev/null 2>&1; then
    exec 8>"${LOCK_FILE}"
    if lockf -s -t "${LOCK_TIMEOUT}" 8 2>/dev/null; then
      _LOCK_ACQUIRED=2
      return 0
    fi
    exec 8>&- 2>/dev/null || true
  fi

  local waited=0
  while ! mkdir "${LOCK_DIR}" 2>/dev/null; do
    sleep 0.02
    waited=$((waited + 1))
    if [ "${waited}" -ge $((LOCK_TIMEOUT * 50)) ]; then
      return 1
    fi
  done
  _LOCK_ACQUIRED=3
  return 0
}

release_lock() {
  case "${_LOCK_ACQUIRED}" in
    1) flock -u 8 2>/dev/null || true; exec 8>&- 2>/dev/null || true ;;
    2) exec 8>&- 2>/dev/null || true ;;
    3) rmdir "${LOCK_DIR}" 2>/dev/null || true ;;
  esac
}

trap release_lock EXIT

acquire_lock || exit 1

current_count="$(cat "${STATE_FILE}" 2>/dev/null || echo 0)"
next_count=$((current_count + 1))
sleep 0.02
printf '%s\n' "${next_count}" > "${STATE_FILE}"
printf 'worker-%s\n' "${WORKER_ID}" >> "${STATE_FILE}.log"
EOF
chmod +x "${WORKER_SCRIPT}"

WORKER_COUNT=6
PIDS=()
for worker_id in $(seq 1 "${WORKER_COUNT}"); do
  bash "${WORKER_SCRIPT}" "${LOCK_FILE}" "${STATE_FILE}" "${worker_id}" &
  PIDS+=("$!")
done

FAILED=0
for pid in "${PIDS[@]}"; do
  if ! wait "${pid}" 2>/dev/null; then
    FAILED=$((FAILED + 1))
  fi
done

if [ "${FAILED}" -ne 0 ]; then
  echo "${FAILED} worker(s) failed"
  exit 1
fi

FINAL_COUNT="$(cat "${STATE_FILE}" 2>/dev/null || echo 0)"
if [ "${FINAL_COUNT}" -ne "${WORKER_COUNT}" ]; then
  echo "final count mismatch: ${FINAL_COUNT} / ${WORKER_COUNT}"
  exit 1
fi

LOG_COUNT="$(wc -l < "${STATE_FILE}.log" | tr -d ' ')"
if [ "${LOG_COUNT}" -ne "${WORKER_COUNT}" ]; then
  echo "log entry count mismatch: ${LOG_COUNT} / ${WORKER_COUNT}"
  exit 1
fi

[ ! -d "${LOCK_DIR}" ] || {
  echo "lock directory still exists"
  exit 1
}

echo "OK"
