#!/usr/bin/env bash
set -euo pipefail

# Static (+ optional version-probe) smoke for the `cursor-agent` CLI specifically
# (NOT the `cursor` editor binary). This test NEVER calls a model: the default
# path is static-only, and even with HARNESS_CURSOR_AGENT_SMOKE=1 it only runs a
# trivial local `cursor-agent --version` probe. The actual model invocation is
# owned elsewhere (see the placeholder block below) so this test never gates
# merge on a network call. It is intentionally NOT registered in
# tests/validate-plugin.sh (network-adjacent).
#
# Tri-state per .claude/rules/active-watching-test-policy.md:
#   not-configured: cursor-agent absent        -> WARNING, static checks pass, exit 0 (healthy)
#   unreachable:    present but --version fails -> hard-fail only if HARNESS_CURSOR_AGENT_SMOKE=1, else WARNING+pass
#   healthy:        present and --version works -> pass

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROUTER="${ROOT_DIR}/scripts/model-routing.sh"
EVIDENCE="${ROOT_DIR}/docs/research/cursor-adapter-candidate.md"
CURSOR_AGENT_PATH="${HOME}/.local/bin/cursor-agent"
SMOKE="${HARNESS_CURSOR_AGENT_SMOKE:-0}"

fail() {
  echo "test-cursor-agent-cli-smoke: FAIL: $1" >&2
  exit 1
}

assert_file() {
  [ -f "$1" ] || fail "missing $1"
}

assert_contains() {
  local file="$1"
  local needle="$2"
  grep -Fq "$needle" "$file" || fail "missing '$needle' in $file"
}

# --- STATIC asserts (always run, no network) -----------------------------------

assert_file "$EVIDENCE"
[ -x "$ROUTER" ] || fail "scripts/model-routing.sh must be executable"

cursor_worker="$(bash "$ROUTER" --host cursor --role worker --field model)"
[ "$cursor_worker" = "composer-2.5-fast" ] || \
  fail "cursor worker model routing mismatch: got '${cursor_worker}', want 'composer-2.5-fast'"

assert_contains "$EVIDENCE" "cursor-agent CLI fact-check"

# --- Detect the cursor-agent binary specifically (NOT `cursor`) ----------------

CURSOR_AGENT_BIN=""
if command -v cursor-agent >/dev/null 2>&1; then
  CURSOR_AGENT_BIN="$(command -v cursor-agent)"
elif [ -x "$CURSOR_AGENT_PATH" ]; then
  CURSOR_AGENT_BIN="$CURSOR_AGENT_PATH"
fi

if [ -z "$CURSOR_AGENT_BIN" ]; then
  # not-configured: opt-in CLI absent -> healthy, no error.
  echo "test-cursor-agent-cli-smoke: WARNING cursor-agent CLI unavailable; static checks passed, version probe skipped"
  echo "test-cursor-agent-cli-smoke: ok"
  exit 0
fi

# --- Version probe (trivial, local, no model call) -----------------------------

probe_out="${TMPDIR:-/tmp}/cursor-agent-cli-smoke.$$"
if "$CURSOR_AGENT_BIN" --version >"$probe_out" 2>&1; then
  # healthy: present and --version works.
  echo "test-cursor-agent-cli-smoke: cursor-agent observed: $(head -n 1 "$probe_out")"
  rm -f "$probe_out"
else
  # unreachable: present but the trivial probe failed.
  if [ "$SMOKE" = "1" ]; then
    cat "$probe_out" >&2 || true
    rm -f "$probe_out"
    fail "cursor-agent present but --version failed"
  fi
  rm -f "$probe_out"
  echo "test-cursor-agent-cli-smoke: WARNING cursor-agent present but --version failed; static checks passed"
fi

# --- Network model invocation (NOT owned by this test) -------------------------
#
# PLACEHOLDER — intentionally left empty. The actual model-call smoke (a real
# `cursor-agent -p ... --model composer-2.5-fast` round-trip) is owned by
# Lead / task 82.3, gated behind HARNESS_CURSOR_AGENT_SMOKE=1. Do NOT add a
# network model call here: this test must stay static + version-probe only so it
# never gates merge on cloud availability.
#
# if [ "$SMOKE" = "1" ]; then
#   : # (82.3) live model round-trip goes here, owned by Lead.
# fi

echo "test-cursor-agent-cli-smoke: ok"
