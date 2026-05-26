#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cat > "${TMP_DIR}/Plans.md" <<'EOF'
## Phase 29.1: Plans.md ⇄ GitHub Issue bridge (opt-in)

| Task | Content | DoD | Depends | Status |
|------|---------|-----|---------|--------|
| 29.1.1 | define team mode | opt-in conditions are documented | - | cc:TODO |
| 29.1.2 | create dry-run of issue payload | task can be extracted from Plans.md | 29.1.1 | cc:TODO |

## Phase 29.3: Lightweight brief and machine-readable manifest

| Task | Content | DoD | Depends | Status |
|------|---------|-----|---------|--------|
| 29.3.1 | attach design brief | UI brief template exists | - | cc:TODO |
EOF

JSON_OUTPUT="${TMP_DIR}/bridge.json"
(cd "$TMP_DIR" && "${PROJECT_ROOT}/scripts/plans-issue-bridge.sh" --plans "${TMP_DIR}/Plans.md" --team-mode --format json --output "${JSON_OUTPUT}" >/dev/null)

jq -e '
  .schema_version == "plans-issue-bridge.v1" and
  .team_mode.enabled == true and
  .summary.phase_count == 2 and
  .summary.task_count == 3 and
  (.tracking_issue.labels | index("team-mode")) != null and
  (.sub_issues | length) == 3 and
  .sub_issues[1].depends_on == ["29.1.1"] and
  .sub_issues[2].phase.id == "29.3" and
  .sub_issues[2].status == "cc:TODO"
' "${JSON_OUTPUT}" >/dev/null

MARKDOWN_OUTPUT="${TMP_DIR}/bridge.md"
(cd "$TMP_DIR" && "${PROJECT_ROOT}/scripts/plans-issue-bridge.sh" --plans "${TMP_DIR}/Plans.md" --team-mode --format markdown --output "${MARKDOWN_OUTPUT}" >/dev/null)

grep -q "Plans.md issue bridge dry-run" "${MARKDOWN_OUTPUT}"
grep -q "Team mode: enabled" "${MARKDOWN_OUTPUT}"
grep -q "29.1.2 create dry-run of issue payload" "${MARKDOWN_OUTPUT}"

echo "test-plans-issue-bridge: ok"
