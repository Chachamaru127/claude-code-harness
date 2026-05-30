#!/usr/bin/env bash
# test-agent-permission-mode.sh
# Phase 62.2.2: --agent permissionMode reaffirmation test
#
# Claude Code 2.1.119 で `--agent <name>` が agent frontmatter の `permissionMode`
# を尊重する fix が入った。一方で Phase 59.2.3 では Plugin subagent frontmatter には
# `permissionMode` を **置かない** 方針が確定済み (docs/team-composition.md 参照)。
#
# このテストは、Phase 59.2.3 方針が現行 frontmatter で守られていること、
# および Reviewer の Read-only enforcement が `tools` / `disallowedTools` で
# 担保されていることを固定する。CC 2.1.119+ で permissionMode が
# reactivate されても、このテストが gate として働き、追加変更は明示的判断を要する。

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKER="${ROOT_DIR}/agents/worker.md"
REVIEWER="${ROOT_DIR}/agents/reviewer.md"
ADVISOR="${ROOT_DIR}/agents/advisor.md"
TEAM_DOC="${ROOT_DIR}/docs/team-composition.md"

# (1) 3 agent の frontmatter には permissionMode が **存在しない**
for agent in "${WORKER}" "${REVIEWER}" "${ADVISOR}"; do
  if [ -f "${agent}" ]; then
    if grep -E '^permissionMode:' "${agent}" >/dev/null 2>&1; then
      echo "FAIL (1): ${agent} contains permissionMode in frontmatter (Phase 59.2.3 violation)"
      echo "  permissionMode は plugin subagent では silently ignored になりやすいため、"
      echo "  tools / disallowedTools で権限を表現する。"
      exit 1
    fi
  fi
done

# (2) Reviewer の Read-only enforcement: tools allowlist が Read/Grep/Glob のみ
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

# (3) Reviewer の disallowedTools に Write/Edit/Bash/Agent が含まれる (defense-in-depth)
REVIEWER_DISALLOWED_LINES="$(awk '/^disallowedTools:/{flag=1; next} /^[a-zA-Z]+:/{flag=0} flag && /^  -/' "${REVIEWER}")"
for required_disallowed in Write Edit Bash Agent; do
  if ! printf '%s' "${REVIEWER_DISALLOWED_LINES}" | grep -qw "${required_disallowed}"; then
    echo "FAIL (3): reviewer.md disallowedTools must include ${required_disallowed}"
    exit 1
  fi
done

# (4) Worker の disallowedTools には少なくとも Agent が含まれる (NG-3 enforcement)
WORKER_DISALLOWED_LINES="$(awk '/^disallowedTools:/{flag=1; next} /^[a-zA-Z]+:/{flag=0} flag && /^  -/' "${WORKER}")"
if ! printf '%s' "${WORKER_DISALLOWED_LINES}" | grep -qw "Agent"; then
  echo "FAIL (4): worker.md disallowedTools must include Agent (NG-3 nested teammate spawn 禁止)"
  exit 1
fi

# (5) docs/team-composition.md が Phase 59.2.3 方針を明示
if ! grep -q 'permissionMode' "${TEAM_DOC}"; then
  echo "FAIL (5): docs/team-composition.md must reference permissionMode policy (Phase 59.2.3)"
  exit 1
fi
if ! grep -q '置かない\|無視され\|silently ignored' "${TEAM_DOC}"; then
  echo "FAIL (5b): docs/team-composition.md must explain why permissionMode is not used"
  exit 1
fi

echo "PASS: test-agent-permission-mode.sh (Phase 62.2.2) — 5 観点全 PASS"
echo "Note: CC 2.1.119+ で agent frontmatter permissionMode が reactivate された場合、"
echo "      Phase 59.2.3 方針の再評価が必要。本テストが gate として変更を明示化する。"
