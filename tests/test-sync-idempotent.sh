#!/bin/bash
# test-sync-idempotent.sh
# harness sync を 3 回連続実行しても plugin.json が安定することを検証
#
# Usage: bash tests/test-sync-idempotent.sh

set -euo pipefail

# Resolve project root from script location so this test runs correctly
# regardless of the caller's cwd. validate-plugin.sh invokes us by absolute
# path, so we must not depend on $PWD.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

PLUGIN_JSON=".claude-plugin/plugin.json"

# Portable SHA256 helper: macOS has shasum (Perl), most Linux distros have
# sha256sum but not shasum. Detect once and dispatch.
sha256_of() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    echo "FAIL: neither shasum nor sha256sum is available on PATH" >&2
    exit 1
  fi
}

# Drift detection: capture pre-sync checksum so the test fails when the
# checked-in plugin.json differs from what `harness sync` produces. Without
# this, the very first sync silently rewrites stale manifests and subsequent
# runs match, masking real drift.
SHA1_PRE_SYNC=$(sha256_of "$PLUGIN_JSON")

# 初回 sync — capture output to verify the platform binary actually ran.
# bin/harness shim exits 0 with no output when no harness-${OS}-${ARCH} binary
# is available, which would silently skip every sync below and falsely pass
# this test. We require the "harness sync: done" marker to confirm execution.
SYNC_OUTPUT="$(./bin/harness sync 2>&1)"
if ! grep -q "harness sync: done" <<<"$SYNC_OUTPUT"; then
  echo "FAIL: ./bin/harness sync did not produce expected output (silent no-op?)"
  echo "  Got: $SYNC_OUTPUT"
  echo "  This usually means the platform binary harness-\$(uname-os)-\$(uname-arch)"
  echo "  is missing from bin/, so the shim exits 0 without dispatching."
  exit 1
fi
SHA1_AFTER_1ST=$(sha256_of "$PLUGIN_JSON")

if [ "$SHA1_PRE_SYNC" != "$SHA1_AFTER_1ST" ]; then
  echo "FAIL: plugin.json drift detected — checked-in version differs from sync output"
  echo "  checked-in: $SHA1_PRE_SYNC"
  echo "  post-sync:  $SHA1_AFTER_1ST"
  echo "  Run './bin/harness sync' and commit the regenerated .claude-plugin/plugin.json."
  exit 1
fi

# 連続 2 回 sync — idempotency verification
./bin/harness sync > /dev/null
SHA1_AFTER_2ND=$(sha256_of "$PLUGIN_JSON")

./bin/harness sync > /dev/null
SHA1_AFTER_3RD=$(sha256_of "$PLUGIN_JSON")

# checksum 一致確認 (idempotent across N runs)
if [ "$SHA1_AFTER_1ST" != "$SHA1_AFTER_2ND" ] || [ "$SHA1_AFTER_1ST" != "$SHA1_AFTER_3RD" ]; then
  echo "FAIL: plugin.json checksum changed across sync runs (not idempotent)"
  echo "  1st: $SHA1_AFTER_1ST"
  echo "  2nd: $SHA1_AFTER_2ND"
  echo "  3rd: $SHA1_AFTER_3RD"
  exit 1
fi

# 公式 SSOT 外 field の不在確認
if grep -q '"monitors"' "$PLUGIN_JSON"; then
  echo "FAIL: plugin.json contains monitors field (should be in monitors/monitors.json)"
  exit 1
fi
if grep -q '"agents"' "$PLUGIN_JSON"; then
  echo "FAIL: plugin.json contains agents field (should be auto-discovery from agents/)"
  exit 1
fi

echo "PASS: harness sync is idempotent and emits no phantom fields"
