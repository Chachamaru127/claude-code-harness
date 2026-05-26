#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

LOOP_SCRIPT="${PROJECT_ROOT}/archive/non-claude/scripts/codex-loop.sh"

cat > "${TMP_DIR}/Plans.md" <<'EOF'
# Plans

## Marker Legend

Markers are protocol state values.

## Phase 55.3: status marker compatibility

| Task | Content | DoD | Depends | Status |
|------|---------|-----|---------|--------|
| 1 | legacy queued task | parser sees legacy todo | - | cc:TODO |
| 2 | legacy requested task | parser sees legacy requested | - | pm:依頼中 |
| 3 | English requested alias task | parser sees requested alias | - | pm:requested |
| 4 | English done alias task | parser sees done alias | - | cc:done |
| 5 | English approved alias task | parser sees approved alias | - | pm:approved |
| 6 | blocked task | parser skips blocked state | - | blocked |
| 7 | depends on aliases | alias completions satisfy dependencies | 4,5 | cc:TODO |
| 8 | English queued canonical task | parser sees cc:todo | - | cc:todo |
| 9 | English WIP canonical task | parser sees cc:wip | - | cc:wip |

#### H-1: Heading requested alias `pm:requested`

- [ ] Heading requested aliases are active.

#### H-2: Heading done alias `cc:done`

- [x] Heading done aliases are complete.

#### H-3: Heading WIP canonical `cc:wip`

- [ ] Heading WIP canonical markers are active.
EOF

assert_eq() {
  local got="$1"
  local want="$2"
  local label="$3"
  if [ "$got" != "$want" ]; then
    echo "[FAIL] ${label}: got '${got}', want '${want}'" >&2
    exit 1
  fi
}

(
  export HARNESS_CODEX_LOOP_SOURCE_ONLY=1
  # shellcheck source=../scripts/codex-loop.sh
  source "$LOOP_SCRIPT"

  assert_eq "$(next_task_id all "${TMP_DIR}/Plans.md")" "1" "codex-loop keeps canonical TODO first"
  assert_eq "$(next_task_id 2 "${TMP_DIR}/Plans.md")" "2" "codex-loop accepts pm:依頼中"
  assert_eq "$(next_task_id 3 "${TMP_DIR}/Plans.md")" "3" "codex-loop accepts pm:requested"
  assert_eq "$(next_task_id 8 "${TMP_DIR}/Plans.md")" "8" "codex-loop accepts cc:todo"
  assert_eq "$(next_task_id 9 "${TMP_DIR}/Plans.md")" "9" "codex-loop accepts cc:wip"
  assert_eq "$(next_task_id H-1 "${TMP_DIR}/Plans.md")" "H-1" "codex-loop accepts heading pm:requested"
  assert_eq "$(next_task_id H-3 "${TMP_DIR}/Plans.md")" "H-3" "codex-loop accepts heading cc:wip"
  assert_eq "$(next_ready_batch_ids all "${TMP_DIR}/Plans.md" max)" "1,2,3,7,8,9,H-1,H-3" "codex-loop ready batch preserves aliases"
  assert_eq "$(task_status_value "${TMP_DIR}/Plans.md" 4)" "cc:done" "codex-loop reports cc:done alias"
  assert_eq "$(task_status_value "${TMP_DIR}/Plans.md" 8)" "cc:todo" "codex-loop reports cc:todo canonical"
  assert_eq "$(task_status_value "${TMP_DIR}/Plans.md" 9)" "cc:wip" "codex-loop reports cc:wip canonical"
  assert_eq "$(task_status_value "${TMP_DIR}/Plans.md" H-2)" "cc:done" "codex-loop reports heading cc:done alias"
  assert_eq "$(task_status_value "${TMP_DIR}/Plans.md" H-3)" "cc:wip" "codex-loop reports heading cc:wip canonical"

  tasks_complete "${TMP_DIR}/Plans.md" "4,5,H-2"
  if tasks_complete "${TMP_DIR}/Plans.md" "1" 2>/dev/null; then
    echo "[FAIL] codex-loop treated cc:TODO as complete" >&2
    exit 1
  fi
)

"${PROJECT_ROOT}/scripts/plans-format-check.sh" "${TMP_DIR}/Plans.md" \
  | jq -e '.status == "ok" and .migration_needed == false' >/dev/null

cat > "${TMP_DIR}/Plans.canonical-only.md" <<'EOF'
# Plans

## Marker Legend

| Task | Content | DoD | Depends | Status |
|------|---------|-----|---------|--------|
| 1 | new queued task | canonical writer output | - | cc:todo |
| 2 | new wip task | canonical writer output | - | cc:wip |
EOF

"${PROJECT_ROOT}/scripts/plans-format-check.sh" "${TMP_DIR}/Plans.canonical-only.md" \
  | jq -e '.status == "ok" and .migration_needed == false' >/dev/null

BRIDGE_JSON="${TMP_DIR}/bridge.json"
"${PROJECT_ROOT}/scripts/plans-issue-bridge.sh" \
  --plans "${TMP_DIR}/Plans.md" \
  --team-mode \
  --format json \
  --output "${BRIDGE_JSON}" >/dev/null

jq -e '
  .summary.task_count == 9 and
  (.sub_issues[] | select(.task_id == "3").status) == "pm:requested" and
  (.sub_issues[] | select(.task_id == "4").status) == "cc:done" and
  (.sub_issues[] | select(.task_id == "5").status) == "pm:approved" and
  (.sub_issues[] | select(.task_id == "8").status) == "cc:todo" and
  (.sub_issues[] | select(.task_id == "9").status) == "cc:wip" and
  (.sub_issues[] | select(.task_id == "7").depends_on) == ["4", "5"]
' "${BRIDGE_JSON}" >/dev/null

CONTRACT_JSON="${TMP_DIR}/H-2.sprint-contract.json"
(cd "$TMP_DIR" && node "${PROJECT_ROOT}/scripts/generate-sprint-contract.js" H-2 "${TMP_DIR}/Plans.md" "${CONTRACT_JSON}" >/dev/null)

jq -e '
  .task.id == "H-2" and
  .task.status_at_generation == "cc:done" and
  (.task.title | contains("cc:done") | not)
' "${CONTRACT_JSON}" >/dev/null

# scripts/codex-worker-merge.sh and scripts/codex-loop.sh are archived
# use archive paths when checking these scripts
CODEX_WORKER_MERGE="${PROJECT_ROOT}/archive/non-claude/scripts/codex-worker-merge.sh"
CODEX_LOOP_ARCHIVE="${PROJECT_ROOT}/archive/non-claude/scripts/codex-loop.sh"
if [ -f "${CODEX_WORKER_MERGE}" ]; then
  grep -q 'cc:done' "${CODEX_WORKER_MERGE}"
  if grep -q 'Plans.md 更新: .*cc:完了' "${CODEX_WORKER_MERGE}"; then
    echo "[FAIL] codex-worker-merge must emit canonical cc:done writer output" >&2
    exit 1
  fi
fi

if [ -f "${CODEX_LOOP_ARCHIVE}" ]; then
  grep -q 'cc:done \[<commit>\]' "${CODEX_LOOP_ARCHIVE}"
  if grep -q 'update Plans.md.*cc:完了 \[<commit>\]' "${CODEX_LOOP_ARCHIVE}"; then
    echo "[FAIL] codex-loop prompts must ask workers to write cc:done" >&2
    exit 1
  fi
fi

grep -q 'cc:done' "${PROJECT_ROOT}/templates/Plans.md.template"
grep -q 'cc:done' "${PROJECT_ROOT}/templates/locales/ja/Plans.md.template"
if grep -qE '^- \[[ x]\].*cc:完了' "${PROJECT_ROOT}/templates/Plans.md.template"; then
  echo "[FAIL] default Plans template sample tasks must not generate cc:完了" >&2
  exit 1
fi
if grep -qE '^- \[[ x]\].*cc:完了' "${PROJECT_ROOT}/templates/locales/ja/Plans.md.template"; then
  echo "[FAIL] Japanese Plans template may localize prose, but status markers must stay English" >&2
  exit 1
fi

grep -q 'COMPLETED_TASKS="cc:done"' "${PROJECT_ROOT}/scripts/plans-watcher.sh"
if grep -q 'Impl Claude がタスクを完了しました。レビューをお願いします（cc:完了）。' "${PROJECT_ROOT}/scripts/plans-watcher.sh"; then
  echo "[FAIL] plans watcher notification must not keep Japanese cc:完了 marker prose" >&2
  exit 1
fi

grep -q 'cc:done' "${PROJECT_ROOT}/scripts/stop-plans-reminder.sh"
if grep -q '完了時は cc:完了' "${PROJECT_ROOT}/scripts/stop-plans-reminder.sh"; then
  echo "[FAIL] stop reminder must guide users to cc:done" >&2
  exit 1
fi

HOOK_TMP="${TMP_DIR}/hook-project"
mkdir -p "${HOOK_TMP}/plans" "${HOOK_TMP}/.claude/state"
cat > "${HOOK_TMP}/.claude-code-harness.config.yaml" <<'EOF'
plansDirectory: plans
EOF
cat > "${HOOK_TMP}/plans/Plans.md" <<'EOF'
# Plans

| Marker | Meaning |
|--------|---------|
| `pm:requested` / `pm:依頼中` | legend only |
| `cc:wip` / `cc:WIP` | legend only |
| `cc:done` / `cc:完了` | legend only |

| Task | Content | DoD | Depends | Status |
|------|---------|-----|---------|--------|
| 1 | canonical done | done marker | - | cc:done |
| 2 | legacy done | legacy marker | - | cc:完了 |
| 3 | active work | wip marker | - | cc:wip |
| 4 | queued work | todo marker | - | cc:todo |
EOF

collect_output="$(cd "${HOOK_TMP}" && bash "${PROJECT_ROOT}/scripts/collect-cleanup-context.sh")"
printf '%s' "$collect_output" | jq -e '
  .plans.completed_tasks == 2 and
  .plans.cc_done_tasks == 2 and
  .plans.wip_tasks == 1 and
  .plans.todo_tasks == 1 and
  .plans.pm_pending_tasks == 0
' >/dev/null

(cd "${HOOK_TMP}" && git init -q && touch changed-file)
stop_output="$(cd "${HOOK_TMP}" && bash "${PROJECT_ROOT}/scripts/stop-plans-reminder.sh")"
printf '%s' "$stop_output" | jq -e '
  .reason == "cc_done_tasks > 0" and
  (.systemMessage | contains("2 cc:done task(s) await PM review"))
' >/dev/null

resume_output="$(cd "${HOOK_TMP}" && printf '%s\n' '{"session_id":"cc-test"}' | CLAUDE_CODE_HARNESS_LANG=ja bash "${PROJECT_ROOT}/scripts/session-resume.sh" 2>/dev/null)"
printf '%s' "$resume_output" | jq -e '
  .hookSpecificOutput.additionalContext | contains("進行中 1 / 未着手 1")
' >/dev/null

cat > "${HOOK_TMP}/.claude/state/session.json" <<EOF
{
  "session_id": "summary-test",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "project_name": "hook-project",
  "git": {"branch": "main"},
  "changes_this_session": [{"file": "changed-file", "important": false}],
  "memory_logged": false
}
EOF
cat >> "${HOOK_TMP}/plans/Plans.md" <<'EOF'

  #### H-3: Heading WIP `cc:wip`
EOF
summary_output="$(cd "${HOOK_TMP}" && CLAUDE_CODE_HARNESS_LANG=ja bash "${PROJECT_ROOT}/scripts/session-summary.sh" 2>/dev/null)"
printf '%s' "$summary_output" | grep -q '現在のタスク: active work'
printf '%s' "$summary_output" | grep -q '完了タスク: 2件'
if grep -q 'legend only' "${HOOK_TMP}/.claude/memory/session-log.md"; then
  echo "[FAIL] session-summary must not include marker legend rows in WIP handoff" >&2
  exit 1
fi
grep -q 'H-3' "${HOOK_TMP}/.claude/memory/session-log.md"

echo "test-plans-status-markers: ok"
