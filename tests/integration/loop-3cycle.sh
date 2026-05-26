#!/bin/bash
# loop-3cycle.sh
# Verify that context is not lost across 3 consecutive wake-ups of harness-loop

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

mkdir -p "${TMP_DIR}/.claude/state" "${TMP_DIR}/scripts/lib"
git -C "${TMP_DIR}" init -q

cp "${ROOT_DIR}/VERSION" "${TMP_DIR}/VERSION"
cp "${ROOT_DIR}/scripts/session-init.sh" "${TMP_DIR}/scripts/session-init.sh"
cp "${ROOT_DIR}/scripts/session-resume.sh" "${TMP_DIR}/scripts/session-resume.sh"
cp "${ROOT_DIR}/scripts/lib/progress-snapshot.sh" "${TMP_DIR}/scripts/lib/progress-snapshot.sh"

cat > "${TMP_DIR}/Plans.md" <<'EOF'
| Task | Description | DoD | Depends | Status |
|------|-------------|-----|---------|--------|
| 41.4.2 | loop smoke test | 3 cycle wake-up continues without interruption | - | cc:TODO |
EOF

run_cycle() {
  local cycle_no="$1"
  local command_name="$2"
  local context_file="${TMP_DIR}/.claude/state/memory-resume-context.md"
  local output=""

  cat > "${context_file}" <<EOF
# Continuity Briefing

## Current Focus
- cycle-${cycle_no}: verifying that harness-loop wake-up continues
EOF
  : > "${TMP_DIR}/.claude/state/.memory-resume-pending"

  output="$(cd "${TMP_DIR}" && bash "./scripts/${command_name}" 2>/dev/null)"

  printf '%s' "${output}" | grep -q "cycle-${cycle_no}" || {
    echo "cycle-${cycle_no} context not found in output"
    exit 1
  }

  [ ! -f "${context_file}" ] || {
    echo "cycle-${cycle_no} context file was not consumed"
    exit 1
  }

  [ ! -f "${TMP_DIR}/.claude/state/.memory-resume-pending" ] || {
    echo "cycle-${cycle_no} pending flag still present"
    exit 1
  }
}

run_cycle 1 session-init.sh
run_cycle 2 session-resume.sh
run_cycle 3 session-init.sh

echo "OK"
