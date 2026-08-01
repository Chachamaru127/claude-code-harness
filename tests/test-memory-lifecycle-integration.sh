#!/bin/bash
# Claude adapter lifecycle should keep the same continuity chain across
# SessionStart -> SessionStart additionalContext -> UserPromptSubmit -> Stop.
#
# Local-only test: requires the sister repository `../harness-mem` to be cloned
# alongside this repository. On clean public checkouts (CI environments without
# the sister repo) this test skips with exit 0, matching the same pattern used
# by Phase 52's `claude-codex-upstream-update` skill check in
# `tests/test-claude-upstream-integration.sh`.
#
# Override:
#   HARNESS_MEM_REPO=/abs/path/to/harness-mem  # custom sister repo location
#   HARNESS_MEM_REQUIRE=1                       # treat missing sister repo as
#                                               # FAIL instead of skip (CI gate
#                                               # for environments that DO have
#                                               # the sister repo cloned)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Resolve sister repo location:
#   1. HARNESS_MEM_REPO env var (explicit override)
#   2. ../harness-mem (default sibling layout)
SISTER_REPO_RAW="${HARNESS_MEM_REPO:-${ROOT_DIR}/../harness-mem}"
if [ -d "${SISTER_REPO_RAW}" ]; then
  HARNESS_ROOT="$(cd "${SISTER_REPO_RAW}" && pwd)"
else
  HARNESS_ROOT=""
fi

if [ -z "${HARNESS_ROOT}" ]; then
  if [ "${HARNESS_MEM_REQUIRE:-0}" = "1" ]; then
    echo "FAIL: ${SISTER_REPO_RAW} not found and HARNESS_MEM_REQUIRE=1 is set" >&2
    exit 1
  fi
  echo "skip: ${SISTER_REPO_RAW} not found (clean public checkout; local-only integration test)"
  echo "  to run this test locally, clone harness-mem alongside claude-code-harness:"
  echo "    git clone <harness-mem-url> ${ROOT_DIR}/../harness-mem"
  echo "  or set HARNESS_MEM_REPO=/abs/path/to/harness-mem to use a custom location"
  echo "  to enforce as CI gate, set HARNESS_MEM_REQUIRE=1"
  exit 0
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

CLAUDE_TMP="${TMP_DIR}/claude-code-harness"
MEM_TMP="${TMP_DIR}/harness-mem"
PAYLOAD_LOG="${TMP_DIR}/memory-payloads.jsonl"

mkdir -p "${CLAUDE_TMP}/scripts/hook-handlers" "${CLAUDE_TMP}/scripts/lib" "${CLAUDE_TMP}/.claude/state"
mkdir -p "${MEM_TMP}/scripts/hook-handlers/lib" "${MEM_TMP}/scripts"
git -C "${CLAUDE_TMP}" init -q

cp "${ROOT_DIR}/scripts/lib/harness-mem-bridge.sh" "${CLAUDE_TMP}/scripts/lib/harness-mem-bridge.sh"
cp "${ROOT_DIR}/scripts/hook-handlers/memory-session-start.sh" "${CLAUDE_TMP}/scripts/hook-handlers/memory-session-start.sh"
cp "${ROOT_DIR}/scripts/hook-handlers/memory-user-prompt.sh" "${CLAUDE_TMP}/scripts/hook-handlers/memory-user-prompt.sh"
cp "${ROOT_DIR}/scripts/hook-handlers/memory-stop.sh" "${CLAUDE_TMP}/scripts/hook-handlers/memory-stop.sh"
cp "${ROOT_DIR}/scripts/session-init.sh" "${CLAUDE_TMP}/scripts/session-init.sh"
cp "${ROOT_DIR}/VERSION" "${CLAUDE_TMP}/VERSION"

cp "${HARNESS_ROOT}/scripts/hook-handlers/memory-session-start.sh" "${MEM_TMP}/scripts/hook-handlers/memory-session-start.sh"
cp "${HARNESS_ROOT}/scripts/hook-handlers/memory-user-prompt.sh" "${MEM_TMP}/scripts/hook-handlers/memory-user-prompt.sh"
cp "${HARNESS_ROOT}/scripts/hook-handlers/memory-stop.sh" "${MEM_TMP}/scripts/hook-handlers/memory-stop.sh"
cp "${HARNESS_ROOT}/scripts/hook-handlers/lib/hook-common.sh" "${MEM_TMP}/scripts/hook-handlers/lib/hook-common.sh"

cat > "${MEM_TMP}/scripts/harness-mem-client.sh" <<EOF
#!/bin/bash
set -euo pipefail
command="\${1:-health}"
payload=""
if [ ! -t 0 ]; then
  payload="\$(cat 2>/dev/null || true)"
fi
printf '%s\t%s\n' "\${command}" "\${payload}" >> "${PAYLOAD_LOG}"
case "\${command}" in
  health)
    printf '%s\n' '{"ok":true}'
    ;;
  record-event)
    printf '%s\n' '{"ok":true}'
    ;;
  resume-pack)
    printf '%s\n' '{"ok":true,"meta":{"count":1,"continuity_briefing":{"content":"# Continuity Briefing\n\n## Current Focus\n- Continue lifecycle verification"}},"items":[]}'
    ;;
  finalize-session)
    printf '%s\n' '{"ok":true,"items":[{"finalized_at":"2026-03-25T00:00:00Z"}]}'
    ;;
  *)
    printf '%s\n' '{"ok":true}'
    ;;
esac
EOF

cat > "${MEM_TMP}/scripts/harness-memd" <<'EOF'
#!/bin/bash
set -euo pipefail
exit 0
EOF

chmod +x \
  "${CLAUDE_TMP}/scripts/hook-handlers/memory-session-start.sh" \
  "${CLAUDE_TMP}/scripts/hook-handlers/memory-user-prompt.sh" \
  "${CLAUDE_TMP}/scripts/hook-handlers/memory-stop.sh" \
  "${CLAUDE_TMP}/scripts/session-init.sh" \
  "${MEM_TMP}/scripts/hook-handlers/memory-session-start.sh" \
  "${MEM_TMP}/scripts/hook-handlers/memory-user-prompt.sh" \
  "${MEM_TMP}/scripts/hook-handlers/memory-stop.sh" \
  "${MEM_TMP}/scripts/harness-mem-client.sh" \
  "${MEM_TMP}/scripts/harness-memd"

cat > "${CLAUDE_TMP}/Plans.md" <<'EOF'
| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 1.0 | sample | done | - | cc:WIP |
EOF

mkdir -p "${CLAUDE_TMP}/.harness-mem/state"
cat > "${CLAUDE_TMP}/.harness-mem/state/continuity.json" <<'EOF'
{
  "version": 1,
  "project": "claude-code-harness",
  "sessions": {},
  "latest_handoff": {
    "session_id": "previous-session",
    "platform": "claude",
    "correlation_id": "corr-seeded",
    "summary_mode": "standard",
    "finalized_at": "2026-03-25T00:00:00Z",
    "consumed_by_session_id": null
  }
}
EOF

START_PAYLOAD='{"session_id":"claude-session-1","source":"startup","hook_event_name":"SessionStart"}'
PROMPT_PAYLOAD='{"session_id":"claude-session-1","hook_event_name":"UserPromptSubmit","prompt":"Can you continue the previous discussion?"}'
STOP_PAYLOAD='{"session_id":"claude-session-1","summary_mode":"standard","last_assistant_message":"1. 問題: 新しいセッションを開くと前の会話の文脈が途切れる 2. 決定: continuity briefing を最初のターンで必ず表示する 3. 次にやるべきこと: adapter delivery を Claude / Codex 両方で揃える"}'

printf '%s' "${START_PAYLOAD}" | (
  cd "${CLAUDE_TMP}" &&
  HARNESS_MEM_ROOT="${MEM_TMP}" bash "./scripts/hook-handlers/memory-session-start.sh"
)

[ -f "${CLAUDE_TMP}/.claude/state/memory-resume-context.md" ] || {
  echo "memory-session-start did not prepare memory-resume-context.md"
  exit 1
}

init_output="$(cd "${CLAUDE_TMP}" && bash "./scripts/session-init.sh" < /dev/null)"
init_context="$(printf '%s' "${init_output}" | jq -r '.hookSpecificOutput.additionalContext')"
grep -q 'Continue lifecycle verification' <<<"${init_context}" || {
  echo "session-init did not surface the continuity briefing"
  exit 1
}

printf '%s' "${PROMPT_PAYLOAD}" | (
  cd "${CLAUDE_TMP}" &&
  HARNESS_MEM_ROOT="${MEM_TMP}" bash "./scripts/hook-handlers/memory-user-prompt.sh"
)

printf '%s' "${STOP_PAYLOAD}" | (
  cd "${CLAUDE_TMP}" &&
  HARNESS_MEM_ROOT="${MEM_TMP}" bash "./scripts/hook-handlers/memory-stop.sh"
)

python3 - <<'PY' "${PAYLOAD_LOG}"
import json, sys
from pathlib import Path

payload_log = Path(sys.argv[1]).read_text(encoding="utf-8").strip().splitlines()
entries = []
for line in payload_log:
    command, payload = line.split("\t", 1)
    entries.append((command, json.loads(payload) if payload else {}))

def find_first(command_name):
    for command, payload in entries:
        if command == command_name:
            return payload
    raise SystemExit(f"missing command {command_name}")

record_events = [payload for command, payload in entries if command == "record-event"]
if len(record_events) < 3:
    raise SystemExit("expected at least three record-event payloads")

resume_pack = find_first("resume-pack")
finalize = find_first("finalize-session")

start_event = record_events[0]["event"]
prompt_event = record_events[1]["event"]
assistant_event = record_events[2]["event"]

assert start_event["correlation_id"] == "corr-seeded"
assert resume_pack["correlation_id"] == "corr-seeded"
assert prompt_event["correlation_id"] == "corr-seeded"
assert assistant_event["correlation_id"] == "corr-seeded"
assert assistant_event["event_type"] == "checkpoint"
assert assistant_event["payload"]["title"] == "assistant_response"
assert "continuity briefing" in assistant_event["payload"]["content"]
assert finalize["correlation_id"] == "corr-seeded"
PY

echo "OK"
