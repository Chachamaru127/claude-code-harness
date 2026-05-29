#!/usr/bin/env bash
# Static CONTRACT test for TASK 83.9.
# Asserts that the Codex-native execution skills wire in the execution-backend
# switch (HARNESS_IMPL_BACKEND) so that driving the harness FROM the Codex host
# also honors the resolved backend. Pure grep — no network, no cursor-agent.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_SKILL="${ROOT}/skills-codex/harness-work/SKILL.md"
BREEZING_SKILL="${ROOT}/skills-codex/breezing/SKILL.md"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[ -f "$WORK_SKILL" ] || fail "missing ${WORK_SKILL}"
[ -f "$BREEZING_SKILL" ] || fail "missing ${BREEZING_SKILL}"

# 1. harness-work (codex) must declare the backend section + resolver.
grep -q "Execution Backend Selection" "$WORK_SKILL" \
  || fail "harness-work: missing 'Execution Backend Selection' section"
grep -q "resolve-impl-backend.sh" "$WORK_SKILL" \
  || fail "harness-work: missing resolve-impl-backend.sh resolver"

# 2. cursor delegation command via the companion wrapper.
grep -q "cursor-companion.sh" "$WORK_SKILL" \
  || fail "harness-work: missing cursor-companion.sh delegation"

# 3. role-scoped: reviewer/advisor stay on the brain (claude/Opus).
grep -Eq "Reviewer.*(claude|Opus|brain)" "$WORK_SKILL" \
  || fail "harness-work: missing role-scoped reviewer-stays-on-claude line"

# 4. breezing (codex) references the backend selection SSOT.
grep -q "Execution Backend" "$BREEZING_SKILL" \
  || fail "breezing: missing reference to Execution Backend selection"
grep -q "HARNESS_IMPL_BACKEND" "$BREEZING_SKILL" \
  || fail "breezing: missing HARNESS_IMPL_BACKEND reference"

echo "ok"
