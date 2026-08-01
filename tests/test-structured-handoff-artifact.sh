#!/bin/bash
# structured handoff artifact が pre-compact / post-compact / session start-resume で共有されることを確認

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

mkdir -p "${TMP_DIR}/.claude/state"
mkdir -p "${TMP_DIR}/scripts/hook-handlers"

git -C "${TMP_DIR}" init -q
git -C "${TMP_DIR}" config user.name "Harness Test"
git -C "${TMP_DIR}" config user.email "harness-test@example.com"

cp "${ROOT_DIR}/VERSION" "${TMP_DIR}/VERSION"
cp "${ROOT_DIR}/scripts/hook-handlers/pre-compact-save.js" "${TMP_DIR}/scripts/hook-handlers/pre-compact-save.js"
cp "${ROOT_DIR}/scripts/hook-handlers/post-compact.sh" "${TMP_DIR}/scripts/hook-handlers/post-compact.sh"
cp "${ROOT_DIR}/scripts/session-init.sh" "${TMP_DIR}/scripts/session-init.sh"
cp "${ROOT_DIR}/scripts/session-resume.sh" "${TMP_DIR}/scripts/session-resume.sh"

cat > "${TMP_DIR}/Plans.md" <<'EOF'
| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 32.1.2 | structured handoff artifact | preserve previous_state + next_action | - | cc:WIP |
| 32.1.3 | context reset | consume handoff artifact | 32.1.2 | cc:TODO |
EOF

cat > "${TMP_DIR}/tracked.txt" <<'EOF'
v1
EOF

git -C "${TMP_DIR}" add Plans.md tracked.txt
git -C "${TMP_DIR}" commit -q -m "seed"

cat > "${TMP_DIR}/.claude/state/work-active.json" <<'EOF'
{
  "review_status": "failed",
  "last_failure": "post-compact handoff missing structure",
  "started_at": "2026-03-30T09:00:00Z",
  "failed_checks": [
    {
      "check": "structured_handoff",
      "status": "failed",
      "detail": "handoff artifact was too thin"
    }
  ]
}
EOF

cat > "${TMP_DIR}/tracked.txt" <<'EOF'
v2
EOF

export CLAUDE_SESSION_ID="test-session-123"
export HARNESS_CONTEXT_RESET_MODE="fixture"
export HARNESS_CONTEXT_RESET_DRY_RUN="1"
pre_output="$(cd "${TMP_DIR}" && CLAUDE_PLUGIN_ROOT="${ROOT_DIR}" node "${TMP_DIR}/scripts/hook-handlers/pre-compact-save.js")"
artifact_file="${TMP_DIR}/.claude/state/handoff-artifact.json"
legacy_file="${TMP_DIR}/.claude/state/precompact-snapshot.json"

[ -f "${artifact_file}" ] || {
  echo "missing canonical handoff artifact"
  exit 1
}

[ -f "${legacy_file}" ] || {
  echo "missing legacy precompact snapshot alias"
  exit 1
}

jq -e '.artifactType == "structured-handoff" and .version == "2.0.0"' "${artifact_file}" >/dev/null || {
  echo "canonical artifact does not expose the structured handoff schema"
  exit 1
}

jq -e '.previous_state.summary | length > 0' "${artifact_file}" >/dev/null || {
  echo "canonical artifact missing previous_state summary"
  exit 1
}

jq -e '.next_action.taskId == "32.1.2"' "${artifact_file}" >/dev/null || {
  echo "canonical artifact did not select the expected next action"
  exit 1
}

jq -e '.open_risks | length > 0' "${artifact_file}" >/dev/null || {
  echo "canonical artifact missing open risks"
  exit 1
}

jq -e '.failed_checks[0].check == "structured_handoff"' "${artifact_file}" >/dev/null || {
  echo "canonical artifact missing failed check details"
  exit 1
}

jq -e '.decision_log | length >= 2' "${artifact_file}" >/dev/null || {
  echo "canonical artifact missing decision log entries"
  exit 1
}

jq -e '.context_reset.recommended == true and (.context_reset.summary | test("dry-run")) and (.context_reset.candidates | length >= 4)' "${artifact_file}" >/dev/null || {
  echo "canonical artifact missing context reset recommendation details"
  exit 1
}

jq -e '.continuity.plugin_first_workflow == true and .continuity.resume_aware_effort_continuity == true and (.continuity.summary | test("plugin-first workflow"))' "${artifact_file}" >/dev/null || {
  echo "canonical artifact missing continuity details"
  exit 1
}

jq -e '.recentEdits | index("tracked.txt")' "${artifact_file}" >/dev/null || {
  echo "canonical artifact missing recent edits"
  exit 1
}

grep -q 'structured handoff artifact' <<<"${pre_output}" || {
  echo "pre-compact hook did not report the structured handoff artifact"
  exit 1
}

post_output="$(cd "${TMP_DIR}" && printf '%s' '{"event":"PostCompact"}' | bash "${TMP_DIR}/scripts/hook-handlers/post-compact.sh")"
post_context="$(printf '%s' "${post_output}" | jq -r '.additionalContext // empty')"

grep -q 'Structured Handoff' <<<"${post_context}" || {
  echo "post-compact did not re-inject the structured handoff section"
  exit 1
}

grep -q 'Next action' <<<"${post_context}" || {
  echo "post-compact did not surface the next action"
  exit 1
}

grep -q 'Failed checks' <<<"${post_context}" || {
  echo "post-compact did not surface failed checks"
  exit 1
}

grep -q 'Context reset' <<<"${post_context}" || {
  echo "post-compact did not surface context reset"
  exit 1
}

grep -q 'Continuity' <<<"${post_context}" || {
  echo "post-compact did not surface continuity"
  exit 1
}

init_output="$(cd "${TMP_DIR}" && bash "${TMP_DIR}/scripts/session-init.sh")"
init_context="$(printf '%s' "${init_output}" | jq -r '.hookSpecificOutput.additionalContext')"

grep -q 'Structured Handoff' <<<"${init_context}" || {
  echo "session-init did not consume the structured handoff artifact"
  exit 1
}

grep -q 'Next action' <<<"${init_context}" || {
  echo "session-init did not surface the next action"
  exit 1
}

grep -q 'Context reset' <<<"${init_context}" || {
  echo "session-init did not surface context reset"
  exit 1
}

grep -q 'Continuity' <<<"${init_context}" || {
  echo "session-init did not surface continuity"
  exit 1
}

jq -e '.harness.context_reset.recommended == true and .harness.continuity.plugin_first_workflow == true and (.harness.continuity.effort_hint | length > 0)' "${TMP_DIR}/.claude/state/session.json" >/dev/null || {
  echo "session-init did not persist handoff metadata to session state"
  exit 1
}

resume_output="$(cd "${TMP_DIR}" && bash "${TMP_DIR}/scripts/session-resume.sh")"
resume_context="$(printf '%s' "${resume_output}" | jq -r '.hookSpecificOutput.additionalContext')"

grep -q 'Structured Handoff' <<<"${resume_context}" || {
  echo "session-resume did not consume the structured handoff artifact"
  exit 1
}

grep -q 'Open risks' <<<"${resume_context}" || {
  echo "session-resume did not surface open risks"
  exit 1
}

grep -q 'Context reset' <<<"${resume_context}" || {
  echo "session-resume did not surface context reset"
  exit 1
}

grep -q 'Continuity' <<<"${resume_context}" || {
  echo "session-resume did not surface continuity"
  exit 1
}

jq -e '.harness.context_reset.recommended == true and .harness.continuity.resume_aware_effort_continuity == true' "${TMP_DIR}/.claude/state/session.json" >/dev/null || {
  echo "session-resume did not keep handoff metadata in session state"
  exit 1
}

echo "OK"
