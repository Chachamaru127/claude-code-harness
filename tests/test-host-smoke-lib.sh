#!/usr/bin/env bash
# Unit tests for tests/lib/host-smoke-lib.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/host-smoke-lib.sh
source "${ROOT_DIR}/tests/lib/host-smoke-lib.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "${TMP}/skills/harness-plan" "${TMP}/skills/harness-work" \
  "${TMP}/skills/harness-review" "${TMP}/skills/breezing" \
  "${TMP}/.grok-plugin"

for s in harness-plan harness-work harness-review breezing; do
  cat >"${TMP}/skills/${s}/SKILL.md" <<EOF
---
name: ${s}
description: test skill ${s}
---
# ${s}
acceptance criteria: must pass structural smoke.
EOF
done

printf '%s\n' '{"name":"claude-code-harness","skills":"./skills/"}' \
  >"${TMP}/.grok-plugin/plugin.json"

assert_core_skills_visible "${TMP}/skills"
assert_install_layout "$TMP" grok
assert_no_parent_paths_in_manifest "${TMP}/.grok-plugin/plugin.json"

write_plan_artifact_from_skill \
  "${TMP}/skills/harness-plan/SKILL.md" \
  "${TMP}/out/plan-artifact.md" \
  grok

if assert_skill_visible "${TMP}/skills" "missing-skill" 2>/dev/null; then
  echo "test-host-smoke-lib: FAIL: expected missing skill to fail" >&2
  exit 1
fi

echo "test-host-smoke-lib: ok"
