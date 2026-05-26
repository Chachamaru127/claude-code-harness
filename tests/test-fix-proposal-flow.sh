#!/bin/bash
# Verify that TaskCompleted 3-strike -> pending fix proposal -> approve fix is reflected in Plans.md

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TASK_COMPLETED_SCRIPT="${ROOT_DIR}/scripts/hook-handlers/task-completed.sh"
FIX_INJECTOR_SCRIPT="${ROOT_DIR}/scripts/hook-handlers/fix-proposal-injector.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

mkdir -p "${TMP_DIR}/.claude/state"
cat > "${TMP_DIR}/Plans.md" <<'EOF'
| Task | Description | DoD | Depends | Status |
|------|-------------|-----|---------|--------|
| 26.0.1 | original task | existing DoD | - | cc:完了 |
EOF

cat > "${TMP_DIR}/.claude/state/test-result.json" <<'EOF'
{
  "status": "failed",
  "command": "npm test",
  "output": "FAIL expected true toBe false"
}
EOF

cat > "${TMP_DIR}/.claude/state/task-quality-gate.json" <<'EOF'
{
  "26.0.1": {
    "failure_count": 2,
    "updated_at": "2026-03-09T15:41:58Z"
  }
}
EOF

payload='{"teammate_name":"impl-1","task_id":"26.0.1","task_subject":"original task"}'
output="$(printf '%s' "${payload}" | PROJECT_ROOT="${TMP_DIR}" bash "${TASK_COMPLETED_SCRIPT}")"

echo "${output}" | grep -q '"decision":"approve"' || {
  echo "task-completed output should approve"
  exit 1
}

echo "${output}" | grep -q 'fix proposal queued' || {
  echo "task-completed output should mention queued proposal"
  exit 1
}

[ -f "${TMP_DIR}/.claude/state/pending-fix-proposals.jsonl" ] || {
  echo "pending proposal file missing"
  exit 1
}

grep -q '"source_task_id": "26.0.1"' "${TMP_DIR}/.claude/state/pending-fix-proposals.jsonl" || {
  echo "proposal file missing source_task_id"
  exit 1
}

approve_output="$(printf '%s' '{"prompt":"approve fix 26.0.1"}' | PROJECT_ROOT="${TMP_DIR}" bash "${FIX_INJECTOR_SCRIPT}")"

echo "${approve_output}" | grep -q 'fix proposal applied' || {
  echo "approve output should mention applied proposal"
  exit 1
}

grep -q '| 26.0.1.fix | fix: original task - assertion_error |' "${TMP_DIR}/Plans.md" || {
  echo "Plans.md missing appended fix row"
  exit 1
}

if [ -s "${TMP_DIR}/.claude/state/pending-fix-proposals.jsonl" ]; then
  echo "pending proposal file should be consumed after approval"
  exit 1
fi

cat > "${TMP_DIR}/.claude/state/pending-fix-proposals.jsonl" <<'EOF'
{"source_task_id":"26.0.2","fix_task_id":"26.0.2.fix","proposal_subject":"fix: A","dod":"done","failure_category":"assertion_error","recommended_action":"check","status":"pending"}
{"source_task_id":"26.0.3","fix_task_id":"26.0.3.fix","proposal_subject":"fix: B","dod":"done","failure_category":"assertion_error","recommended_action":"check","status":"pending"}
EOF

ambiguous_output="$(printf '%s' '{"prompt":"yes"}' | PROJECT_ROOT="${TMP_DIR}" bash "${FIX_INJECTOR_SCRIPT}")"
echo "${ambiguous_output}" | grep -q 'pending fix proposals' || {
  echo "ambiguous approval should require explicit task id"
  exit 1
}

grep -q '"source_task_id":"26.0.2"' "${TMP_DIR}/.claude/state/pending-fix-proposals.jsonl" || {
  echo "ambiguous approval should not consume existing proposals"
  exit 1
}

missing_target_output="$(printf '%s' '{"prompt":"approve fix 99.9.9"}' | PROJECT_ROOT="${TMP_DIR}" bash "${FIX_INJECTOR_SCRIPT}")"
echo "${missing_target_output}" | grep -q 'fix proposal was not found' || {
  echo "missing target approval should be rejected"
  exit 1
}

grep -q '"source_task_id":"26.0.2"' "${TMP_DIR}/.claude/state/pending-fix-proposals.jsonl" || {
  echo "missing target approval should not consume proposals"
  exit 1
}

if grep -q '| 99.9.9.fix |' "${TMP_DIR}/Plans.md" || grep -q '| 26.0.2.fix |' "${TMP_DIR}/Plans.md"; then
  echo "missing target approval should not modify Plans.md"
  exit 1
fi

cat > "${TMP_DIR}/.claude/state/test-result.json" <<'EOF'
{
  "status": "failed",
  "command": "npm test",
  "output": "FAIL expected true toBe false"
}
EOF

cat > "${TMP_DIR}/.claude/state/task-quality-gate.json" <<'EOF'
{
  "26.0.1.fix2": {
    "failure_count": 2,
    "updated_at": "2026-03-09T15:41:58Z"
  }
}
EOF

retry_payload='{"teammate_name":"impl-1","task_id":"26.0.1.fix2","task_subject":"re-fix task"}'
retry_output="$(printf '%s' "${retry_payload}" | PROJECT_ROOT="${TMP_DIR}" bash "${TASK_COMPLETED_SCRIPT}")"

echo "${retry_output}" | grep -q '26.0.1.fix3' || {
  echo "task-completed should increment fix suffix for repeated retries"
  exit 1
}

TMP_SYMLINK_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}" "${TMP_SYMLINK_DIR}"' EXIT
mkdir -p "${TMP_SYMLINK_DIR}/.claude/state"
printf 'SAFE\n' > "${TMP_SYMLINK_DIR}/target.txt"
ln -s "${TMP_SYMLINK_DIR}/target.txt" "${TMP_SYMLINK_DIR}/.claude/state/pending-fix-proposals.jsonl"

cat > "${TMP_SYMLINK_DIR}/.claude/state/test-result.json" <<'EOF'
{
  "status": "failed",
  "command": "npm test",
  "output": "FAIL expected true toBe false"
}
EOF

cat > "${TMP_SYMLINK_DIR}/.claude/state/task-quality-gate.json" <<'EOF'
{
  "26.0.9": {
    "failure_count": 2,
    "updated_at": "2026-03-09T15:41:58Z"
  }
}
EOF

symlink_output="$(printf '%s' '{"teammate_name":"impl-1","task_id":"26.0.9","task_subject":"dangerous case"}' | PROJECT_ROOT="${TMP_SYMLINK_DIR}" bash "${TASK_COMPLETED_SCRIPT}")"

grep -q '^SAFE$' "${TMP_SYMLINK_DIR}/target.txt" || {
  echo "task-completed should not overwrite symlinked pending proposal target"
  exit 1
}

echo "${symlink_output}" | grep -q 'failed to save proposal' || {
  echo "task-completed should warn when proposal state path is unsafe"
  exit 1
}

TMP_PLAN_SYMLINK_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}" "${TMP_SYMLINK_DIR}" "${TMP_PLAN_SYMLINK_DIR}"' EXIT
mkdir -p "${TMP_PLAN_SYMLINK_DIR}/.claude/state"
printf '| Task | Description | DoD | Depends | Status |\n|------|-------------|-----|---------|--------|\n| 26.0.1 | original task | existing DoD | - | cc:完了 |\n' > "${TMP_PLAN_SYMLINK_DIR}/real-target.md"
ln -s "${TMP_PLAN_SYMLINK_DIR}/real-target.md" "${TMP_PLAN_SYMLINK_DIR}/Plans.md"
printf '%s\n' '{"source_task_id":"26.0.1","fix_task_id":"26.0.1.fix","proposal_subject":"fix: A","dod":"done","depends":"26.0.1","failure_category":"assertion_error","recommended_action":"check","status":"pending"}' > "${TMP_PLAN_SYMLINK_DIR}/.claude/state/pending-fix-proposals.jsonl"

plan_symlink_output="$(printf '%s' '{"prompt":"approve fix 26.0.1"}' | PROJECT_ROOT="${TMP_PLAN_SYMLINK_DIR}" bash "${FIX_INJECTOR_SCRIPT}")"

grep -q '^| 26.0.1 | original task | existing DoD | - | cc:完了 |$' "${TMP_PLAN_SYMLINK_DIR}/real-target.md" || {
  echo "fix injector should not overwrite symlinked Plans target"
  exit 1
}

echo "${plan_symlink_output}" | grep -q 'Plans.md path is a symlink' || {
  echo "fix injector should report symlinked Plans path"
  exit 1
}

echo "OK"
