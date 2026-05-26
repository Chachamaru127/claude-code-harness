#!/bin/bash
# Verify that agent telemetry is aggregated by role from statusline / trace / usage

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

mkdir -p "${TMP_DIR}/.claude/state"

cp "${ROOT_DIR}/scripts/statusline-harness.sh" "${TMP_DIR}/statusline-harness.sh"
cp "${ROOT_DIR}/scripts/emit-agent-trace.js" "${TMP_DIR}/emit-agent-trace.js"
cp "${ROOT_DIR}/scripts/record-usage.js" "${TMP_DIR}/record-usage.js"
cp "${ROOT_DIR}/scripts/generate-agent-telemetry.js" "${TMP_DIR}/generate-agent-telemetry.js"

statusline_input_worker='{"model":{"display_name":"Claude"},"context_window":{"used_percentage":42},"cost":{"total_cost_usd":1.25,"total_duration_ms":9000},"output_style":{"name":"default"},"agent":{"name":"worker"},"worktree":{"name":"worker-wt"}}'
statusline_input_reviewer='{"model":{"display_name":"Claude"},"context_window":{"used_percentage":61},"cost":{"total_cost_usd":0.75,"total_duration_ms":7000},"output_style":{"name":"default"},"agent":{"name":"reviewer"},"worktree":{"name":"reviewer-wt"}}'
statusline_input_lead='{"model":{"display_name":"Claude"},"context_window":{"used_percentage":18},"cost":{"total_cost_usd":0.4,"total_duration_ms":3000},"output_style":{"name":"default"},"agent":{"name":"lead"},"worktree":{"name":"lead-wt"}}'

(
  cd "${TMP_DIR}" &&
  printf '%s' "${statusline_input_worker}" | bash "${TMP_DIR}/statusline-harness.sh" >/dev/null &&
  printf '%s' "${statusline_input_reviewer}" | bash "${TMP_DIR}/statusline-harness.sh" >/dev/null &&
  printf '%s' "${statusline_input_lead}" | bash "${TMP_DIR}/statusline-harness.sh" >/dev/null
)

[ -f "${TMP_DIR}/.claude/state/statusline-telemetry.jsonl" ] || {
  echo "statusline telemetry file was not created"
  exit 1
}

statusline_lines="$(wc -l < "${TMP_DIR}/.claude/state/statusline-telemetry.jsonl" | tr -d ' ')"
[ "${statusline_lines}" -ge 3 ] || {
  echo "statusline telemetry should contain at least 3 samples"
  exit 1
}

(
  cd "${TMP_DIR}" &&
  CLAUDE_PLUGIN_ROOT="${ROOT_DIR}" \
  CLAUDE_TOOL_NAME="Task" \
  CLAUDE_TOOL_INPUT='{"subagent_type":"worker","task_id":"32.1.3"}' \
  CLAUDE_TOOL_RESULT='{"metrics":{"tokenCount":1200,"toolUses":5,"duration":45000}}' \
  CLAUDE_SESSION_ID="telemetry-session" \
  node "${TMP_DIR}/emit-agent-trace.js" >/dev/null &&
  CLAUDE_PLUGIN_ROOT="${ROOT_DIR}" \
  CLAUDE_TOOL_NAME="Task" \
  CLAUDE_TOOL_INPUT='{"subagent_type":"reviewer","task_id":"32.1.3"}' \
  CLAUDE_TOOL_RESULT='{"metrics":{"tokenCount":800,"toolUses":3,"duration":30000}}' \
  CLAUDE_SESSION_ID="telemetry-session" \
  node "${TMP_DIR}/emit-agent-trace.js" >/dev/null &&
  CLAUDE_PLUGIN_ROOT="${ROOT_DIR}" \
  CLAUDE_TOOL_NAME="Task" \
  CLAUDE_TOOL_INPUT='{"subagent_type":"lead","task_id":"32.1.3"}' \
  CLAUDE_TOOL_RESULT='{"metrics":{"tokenCount":600,"toolUses":2,"duration":20000}}' \
  CLAUDE_SESSION_ID="telemetry-session" \
  node "${TMP_DIR}/emit-agent-trace.js" >/dev/null
)

(
  cd "${TMP_DIR}" &&
  node "${TMP_DIR}/record-usage.js" agent worker >/dev/null &&
  node "${TMP_DIR}/record-usage.js" agent worker >/dev/null &&
  node "${TMP_DIR}/record-usage.js" agent reviewer >/dev/null &&
  node "${TMP_DIR}/record-usage.js" agent lead >/dev/null
)

cat > "${TMP_DIR}/.claude/state/session.events.jsonl" <<'EOF'
{"type":"worker.retry","role":"worker","count":1}
EOF

report_file="${TMP_DIR}/.claude/state/agent-telemetry.json"
(
  cd "${TMP_DIR}" &&
  node "${TMP_DIR}/generate-agent-telemetry.js" --state-dir "${TMP_DIR}/.claude/state" --output "${report_file}" >/dev/null
)

[ -f "${report_file}" ] || {
  echo "agent telemetry report was not written"
  exit 1
}

jq -e '
  .roles.worker.token_count >= 1200 and
  .roles.reviewer.token_count >= 800 and
  .roles.lead.token_count >= 600 and
  .roles.worker.cost_usd >= 1.25 and
  .roles.reviewer.cost_usd >= 0.75 and
  .roles.lead.cost_usd >= 0.4 and
  .roles.worker.usage_count >= 2 and
  .roles.worker.retry_count == 1 and
  .roles.worker.artifact_count == 2 and
  .totals.statusline_count >= 3 and
  .totals.trace_count >= 3 and
  .totals.session_retry_events == 1 and
  .totals.artifact_count >= 6
' "${report_file}" >/dev/null || {
  echo "telemetry summary missing expected role aggregates"
  exit 1
}

echo "OK"
