#!/bin/bash
# loop-compaction-resume.sh
# Verify that structured handoff is restored on resume after compaction

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
| 41.4.2 | compaction resume | context is restored after compaction | - | cc:TODO |
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

printf '%s' "${init_output}" | grep -q 'Structured Handoff' || {
  echo "session-init did not restore structured handoff"
  exit 1
}

printf '%s' "${resume_output}" | grep -q 'Structured Handoff' || {
  echo "session-resume did not restore structured handoff"
  exit 1
}

printf '%s' "${resume_output}" | grep -q 'resume after compaction' || {
  echo "next action not found after resume"
  exit 1
}

printf '%s' "${resume_output}" | grep -q 'plugin-first workflow remains readable' || {
  echo "continuity not found after resume"
  exit 1
}

grep -Eq '"recommended"[[:space:]]*:[[:space:]]*true' "${TMP_DIR}/.claude/state/session.json" || {
  echo "context_reset information missing from session.json"
  exit 1
}

echo "OK"
