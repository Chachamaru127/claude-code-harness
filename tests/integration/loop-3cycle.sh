#!/bin/bash
# loop-3cycle.sh
# harness-loop の 3 サイクル連続 wake-up で文脈が途切れないことを確認する

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
| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 41.4.2 | loop smoke test | 3 cycle wake-up が途切れない | - | cc:TODO |
EOF

run_cycle() {
  local cycle_no="$1"
  local command_name="$2"
  local context_file="${TMP_DIR}/.claude/state/memory-resume-context.md"
  local output=""

  cat > "${context_file}" <<EOF
# Continuity Briefing

## Current Focus
- cycle-${cycle_no}: harness-loop の wake-up が継続することを確認する
EOF
  : > "${TMP_DIR}/.claude/state/.memory-resume-pending"

  output="$(cd "${TMP_DIR}" && bash "./scripts/${command_name}" 2>/dev/null)"

  grep -q "cycle-${cycle_no}" <<<"${output}" || {
    echo "cycle-${cycle_no} の文脈が出力に見つかりません"
    exit 1
  }

  [ ! -f "${context_file}" ] || {
    echo "cycle-${cycle_no} の文脈ファイルが消費されていません"
    exit 1
  }

  [ ! -f "${TMP_DIR}/.claude/state/.memory-resume-pending" ] || {
    echo "cycle-${cycle_no} の pending フラグが残っています"
    exit 1
  }
}

run_cycle 1 session-init.sh
run_cycle 2 session-resume.sh
run_cycle 3 session-init.sh

echo "OK"
