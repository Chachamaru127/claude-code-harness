#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

FAILED=0

require_fixed() {
  local pattern="$1"
  local file="$2"
  if ! rg -q --fixed-strings -- "$pattern" "$file"; then
    echo "missing required pattern in ${file}: ${pattern}"
    FAILED=1
  fi
}

require_fixed "CHECK_ADAPTERS_MODE" "scripts/release-preflight.sh"
require_fixed "--check-adapters" "scripts/release-preflight.sh"
require_fixed "--skip-adapters" "scripts/release-preflight.sh"
require_fixed "adapter_gate_paths=(" "scripts/release-preflight.sh"
require_fixed "adapter_paths_changed()" "scripts/release-preflight.sh"
require_fixed "release_claims_adapter_support()" "scripts/release-preflight.sh"
require_fixed "should_run_adapter_gates()" "scripts/release-preflight.sh"
require_fixed "no adapter path changes or release adapter claim" "scripts/release-preflight.sh"
require_fixed "use --check-adapters to force" "scripts/release-preflight.sh"


call_line="$(rg -n '^check_release_mirror_drift$' scripts/release-preflight.sh | cut -d: -f1)"
gate_line="$(rg -n 'should_run_adapter_gates' scripts/release-preflight.sh | tail -n 1 | cut -d: -f1)"
if [ -z "$call_line" ] || [ -z "$gate_line" ] || [ "$gate_line" -ge "$call_line" ]; then
  echo "adapter gate must be evaluated inside check_release_mirror_drift before the release preflight call site"
  FAILED=1
fi

if [ "$FAILED" -ne 0 ]; then
  exit 1
fi

echo "test-release-preflight-adapter-gates: ok"
