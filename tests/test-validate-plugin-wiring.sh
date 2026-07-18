#!/usr/bin/env bash
# Ratchet guard for scenario (a) of workflow-test-wiring red-team (2026-07-16):
# an implementing AI silently removing a test invocation from
# tests/validate-plugin.sh would keep CI green while dropping coverage.
# This pin lives in a different CI gate (check-consistency) than the file it
# guards, so shrinking coverage requires touching two independent gates.
#
# Policy (workflow-test-wiring.md): adding invocations is free — add the new
# script name to REQUIRED_INVOCATIONS in the same PR. Removing one requires
# updating this list too, which is exactly the visible, reviewable act the
# direction-asymmetric rule wants.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${ROOT_DIR}/tests/validate-plugin.sh"

REQUIRED_INVOCATIONS=(
  "tests/test-memory-hook-wiring.sh"
  "tests/test-sync-plugin-cache.sh"
  "tests/test-runtime-reactive-hooks.sh"
  "tests/test-3cli-hook-floor.sh"
  "tests/test-runtimefloor-secret-allowlist-e2e.sh"
  "tests/test-plan-preapproval.sh"
  "tests/test-release-version-sync.sh"
  "tests/test-hermes-agent-candidate.sh"
  "tests/test-lsp-workflow-wiring.sh"
  "tests/test-test-wiring-auditor.sh"
  "tests/test-claude-upstream-integration.sh"
  "tests/test-harness-review-governance.sh"
  "tests/test-phase-72-mirror-closeout.sh"
)

missing=0
for script in "${REQUIRED_INVOCATIONS[@]}"; do
  if ! grep -Fq "${script}" "${TARGET}"; then
    echo "validate-plugin.sh no longer invokes required test: ${script}" >&2
    missing=1
  fi
done

if [ "${missing}" -ne 0 ]; then
  echo "test-validate-plugin-wiring: FAIL — coverage shrink detected (see workflow-test-wiring.md)" >&2
  exit 1
fi

echo "test-validate-plugin-wiring: ok (${#REQUIRED_INVOCATIONS[@]} pinned invocations present)"
