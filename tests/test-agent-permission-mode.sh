#!/usr/bin/env bash
# test-agent-permission-mode.sh
# Phase 62.2.2: --agent permissionMode reaffirmation test
#
# Claude Code 2.1.119 introduced a fix where `--agent <name>` respects the
# `permissionMode` in agent frontmatter. However, Phase 59.2.3 established
# that Plugin subagent frontmatter should NOT include `permissionMode`
# (see docs/team-composition.md).
#
# This test locks in that the Phase 59.2.3 policy is upheld in the current frontmatter,
# and that Reviewer's Read-only enforcement is guaranteed via `tools` / `disallowedTools`.
# If permissionMode is reactivated in CC 2.1.119+, this test acts as a gate
# requiring an explicit decision for any additional changes.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKER="${ROOT_DIR}/agents/worker.md"
REVIEWER="${ROOT_DIR}/agents/reviewer.md"
SCAFFOLDER="${ROOT_DIR}/agents/scaffolder.md"
ADVISOR="${ROOT_DIR}/agents/advisor.md"
TEAM_DOC="${ROOT_DIR}/docs/team-composition.md"

# (1) permissionMode must NOT exist in the frontmatter of all 4 agents
for agent in "${WORKER}" "${REVIEWER}" "${SCAFFOLDER}" "${ADVISOR}"; do
  if [ -f "${agent}" ]; then
    if grep -E '^permissionMode:' "${agent}" >/dev/null 2>&1; then
      echo "FAIL (1): ${agent} contains permissionMode in frontmatter (Phase 59.2.3 violation)"
      echo "  permissionMode tends to be silently ignored in plugin subagents;"
      echo "  express permissions via tools / disallowedTools instead."
      exit 1
    fi
  fi
done

# (2) Reviewer Read-only enforcement: tools allowlist must be Read/Grep/Glob only
REVIEWER_TOOLS_LINES="$(awk '/^tools:/{flag=1; next} /^[a-zA-Z]+:/{flag=0} flag && /^  -/' "${REVIEWER}")"
if [ -z "${REVIEWER_TOOLS_LINES}" ]; then
  echo "FAIL (2a): reviewer.md must declare tools allowlist"
  exit 1
fi
for forbidden in Write Edit Bash MultiEdit; do
  if printf '%s' "${REVIEWER_TOOLS_LINES}" | grep -qw "${forbidden}"; then
    echo "FAIL (2b): reviewer.md tools allowlist must NOT include ${forbidden}"
    exit 1
  fi
done
for required in Read Grep Glob; do
  if ! printf '%s' "${REVIEWER_TOOLS_LINES}" | grep -qw "${required}"; then
    echo "FAIL (2c): reviewer.md tools allowlist must include ${required}"
    exit 1
  fi
done

# (3) Reviewer disallowedTools must include Write/Edit/Bash/Agent (defense-in-depth)
REVIEWER_DISALLOWED_LINES="$(awk '/^disallowedTools:/{flag=1; next} /^[a-zA-Z]+:/{flag=0} flag && /^  -/' "${REVIEWER}")"
for required_disallowed in Write Edit Bash Agent; do
  if ! printf '%s' "${REVIEWER_DISALLOWED_LINES}" | grep -qw "${required_disallowed}"; then
    echo "FAIL (3): reviewer.md disallowedTools must include ${required_disallowed}"
    exit 1
  fi
done

# (4) Worker disallowedTools must include at least Agent (NG-3 enforcement)
WORKER_DISALLOWED_LINES="$(awk '/^disallowedTools:/{flag=1; next} /^[a-zA-Z]+:/{flag=0} flag && /^  -/' "${WORKER}")"
if ! printf '%s' "${WORKER_DISALLOWED_LINES}" | grep -qw "Agent"; then
  echo "FAIL (4): worker.md disallowedTools must include Agent (NG-3 nested teammate spawn prohibited)"
  exit 1
fi

# (5) docs/team-composition.md must explicitly state the Phase 59.2.3 policy
if ! grep -q 'permissionMode' "${TEAM_DOC}"; then
  echo "FAIL (5): docs/team-composition.md must reference permissionMode policy (Phase 59.2.3)"
  exit 1
fi
if ! grep -q 'not set\|ignored\|silently ignored' "${TEAM_DOC}"; then
  echo "FAIL (5b): docs/team-composition.md must explain why permissionMode is not used"
  exit 1
fi

echo "PASS: test-agent-permission-mode.sh (Phase 62.2.2) — all 5 checks PASS"
echo "Note: If agent frontmatter permissionMode is reactivated in CC 2.1.119+,"
echo "      Phase 59.2.3 policy must be re-evaluated. This test acts as a gate to make changes explicit."
