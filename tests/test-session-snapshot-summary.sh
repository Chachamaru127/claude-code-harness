#!/bin/bash
# session-init / session-resume が snapshot 要約を additionalContext に含めることを確認

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

mkdir -p "${TMP_DIR}/.claude/state/snapshots"
mkdir -p "${TMP_DIR}/scripts/lib"

git -C "${TMP_DIR}" init -q

cp "${ROOT_DIR}/VERSION" "${TMP_DIR}/VERSION"
cp "${ROOT_DIR}/scripts/session-init.sh" "${TMP_DIR}/scripts/session-init.sh"
cp "${ROOT_DIR}/scripts/session-resume.sh" "${TMP_DIR}/scripts/session-resume.sh"
cp "${ROOT_DIR}/scripts/lib/progress-snapshot.sh" "${TMP_DIR}/scripts/lib/progress-snapshot.sh"

cat > "${TMP_DIR}/Plans.md" <<'EOF'
| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 1.0 | sample | done | - | cc:WIP |
| 1.1 | sample | done | 1.0 | cc:TODO |
EOF

cat > "${TMP_DIR}/.claude/state/snapshots/progress-20260309T150000Z.json" <<'EOF'
{"timestamp":"2026-03-09T15:00:00Z","phase":"Phase 26","progress":{"done":8,"wip":2,"todo":6},"progress_rate":50}
EOF

cat > "${TMP_DIR}/.claude/state/snapshots/progress-20260309T160000Z.json" <<'EOF'
{"timestamp":"2026-03-09T16:00:00Z","phase":"Phase 27","progress":{"done":10,"wip":1,"todo":5},"progress_rate":62}
EOF

init_output="$(cd "${TMP_DIR}" && bash "${TMP_DIR}/scripts/session-init.sh" < /dev/null)"
resume_output="$(cd "${TMP_DIR}" && bash "${TMP_DIR}/scripts/session-resume.sh" < /dev/null)"
init_context="$(printf '%s' "${init_output}" | jq -r '.hookSpecificOutput.additionalContext')"
resume_context="$(printf '%s' "${resume_output}" | jq -r '.hookSpecificOutput.additionalContext')"

if grep -q '\[record-usage\]' <<<"${init_output}"; then
  echo "session-init stdout should not include record-usage noise"
  exit 1
fi

if grep -qx '0' <<<"${init_context}"; then
  echo "session-init additionalContext should not contain standalone zero lines"
  exit 1
fi

if grep -qx '0' <<<"${resume_context}"; then
  echo "session-resume additionalContext should not contain standalone zero lines"
  exit 1
fi

grep -q '最新 snapshot' <<<"${init_output}" || {
  echo "session-init output missing latest snapshot summary"
  exit 1
}

grep -q '前回比' <<<"${resume_output}" || {
  echo "session-resume output missing delta summary"
  exit 1
}

rm -f "${TMP_DIR}/.claude/state/snapshots/"progress-*.json
quiet_output="$(cd "${TMP_DIR}" && bash "${TMP_DIR}/scripts/session-init.sh" < /dev/null)"
quiet_context="$(printf '%s' "${quiet_output}" | jq -r '.hookSpecificOutput.additionalContext')"
if grep -q '\[record-usage\]' <<<"${quiet_output}"; then
  echo "session-init quiet output should not include record-usage noise"
  exit 1
fi
if grep -qx '0' <<<"${quiet_context}"; then
  echo "session-init quiet additionalContext should not contain standalone zero lines"
  exit 1
fi
if grep -q '最新 snapshot' <<<"${quiet_output}"; then
  echo "session-init should skip snapshot summary when no snapshot exists"
  exit 1
fi

echo "OK"
