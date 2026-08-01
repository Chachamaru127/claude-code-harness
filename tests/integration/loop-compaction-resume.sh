#!/bin/bash
# loop-compaction-resume.sh
# まとめ（compaction）後の resume で structured handoff が復元されることを確認する

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
| 41.4.2 | compaction resume | compaction 後の文脈が復元される | - | cc:TODO |
EOF

cat > "${TMP_DIR}/.claude/state/handoff-artifact.json" <<'EOF'
{
  "artifactType": "structured-handoff",
  "version": "2.0.0",
  "previous_state": {
    "summary": "pre-compact snapshot"
  },
  "next_action": {
    "summary": "resume after compaction",
    "taskId": "41.4.2",
    "task": "loop-compaction-resume"
  },
  "open_risks": [
    "resume context may be dropped after compaction"
  ],
  "context_reset": {
    "recommended": true,
    "summary": "dry-run compaction ready"
  },
  "continuity": {
    "summary": "plugin-first workflow remains readable"
  }
}
EOF

cp "${TMP_DIR}/.claude/state/handoff-artifact.json" "${TMP_DIR}/.claude/state/precompact-snapshot.json"

init_output="$(cd "${TMP_DIR}" && bash "./scripts/session-init.sh" 2>/dev/null)"
resume_output="$(cd "${TMP_DIR}" && bash "./scripts/session-resume.sh" 2>/dev/null)"

grep -q 'Structured Handoff' <<<"${init_output}" || {
  echo "session-init が structured handoff を復元していません"
  exit 1
}

grep -q 'Structured Handoff' <<<"${resume_output}" || {
  echo "session-resume が structured handoff を復元していません"
  exit 1
}

grep -q 'resume after compaction' <<<"${resume_output}" || {
  echo "resume 後の next action が見つかりません"
  exit 1
}

grep -q 'plugin-first workflow remains readable' <<<"${resume_output}" || {
  echo "resume 後の continuity が見つかりません"
  exit 1
}

grep -Eq '"recommended"[[:space:]]*:[[:space:]]*true' "${TMP_DIR}/.claude/state/session.json" || {
  echo "session.json に context_reset の情報が残っていません"
  exit 1
}

echo "OK"
