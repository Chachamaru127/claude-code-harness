#!/bin/bash
# test-guardrails-r01-r13.sh
# Smoke test that runs all Go tests for guardrail rule table R01-R13.
# Phase 44.3.1 extension: added CC 2.1.110 regression tests (TestCC2110_*).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GO_DIR="$PROJECT_ROOT/go"

if [ ! -d "$GO_DIR" ]; then
  echo "go directory not found: $GO_DIR" >&2
  exit 1
fi

echo "Running guardrail R01-R13 tests..."
(
  cd "$GO_DIR"
  go test ./internal/guardrail -run '^TestR(0[1-9]|1[0-3])_'
)

echo "Running CC 2.1.110 regression tests (Phase 44.3.1)..."
(
  cd "$GO_DIR"
  go test ./internal/guardrail -run '^TestCC2110_' -v
)

echo "Guardrail R01-R13 and CC 2.1.110 regression tests passed."
