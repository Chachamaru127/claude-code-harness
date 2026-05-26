#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN="${ROOT_DIR}/opencode/plugins/harness-bootstrap.mjs"
SMOKE_REQUIRED="${HARNESS_OPENCODE_RUNTIME_SMOKE_REQUIRED:-0}"

fail() {
  echo "test-opencode-bootstrap-plugin: FAIL: $1" >&2
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

assert_file "$PLUGIN"
assert_contains "$PLUGIN" "export const HarnessBootstrapPlugin"
assert_contains "$PLUGIN" "experimental.chat.messages.transform"
assert_contains "$PLUGIN" "HARNESS_BOOTSTRAP"
assert_contains "$PLUGIN" "not_observed != absent"

node --input-type=module - "$PLUGIN" <<'NODE'
const pluginPath = process.argv[2];
const mod = await import(`file://${pluginPath}`);
mod.__resetHarnessBootstrapCacheForTest();

const content = mod.__getHarnessBootstrapContentForTest();
if (!content || !content.includes("HARNESS_BOOTSTRAP")) {
  throw new Error("bootstrap content did not load");
}
if (!content.includes("internal-compatible")) {
  throw new Error("bootstrap boundary must keep OpenCode internal-compatible");
}
if (mod.__getHarnessBootstrapReadCountForTest() !== 1) {
  throw new Error("bootstrap should read source exactly once after initial load");
}
mod.__getHarnessBootstrapContentForTest();
if (mod.__getHarnessBootstrapReadCountForTest() !== 1) {
  throw new Error("bootstrap cache did not prevent a second read");
}

const plugin = await mod.HarnessBootstrapPlugin({});
const config = {};
await plugin.config(config);
await plugin.config(config);
if (!config.skills || !Array.isArray(config.skills.paths) || config.skills.paths.length !== 1) {
  throw new Error("config hook must register one deduped skills path");
}

const output = {
  messages: [
    {
      info: { role: "user" },
      parts: [{ type: "text", text: "Please plan this." }]
    }
  ]
};
await plugin["experimental.chat.messages.transform"]({}, output);
if (output.messages[0].parts.length !== 2) {
  throw new Error("bootstrap was not injected into first user message");
}
await plugin["experimental.chat.messages.transform"]({}, output);
if (output.messages[0].parts.length !== 2) {
  throw new Error("bootstrap duplicate guard failed");
}
NODE

RUNTIME_OUTPUT="$(mktemp)"
trap 'rm -f "$RUNTIME_OUTPUT"' EXIT

if command -v opencode >/dev/null 2>&1 && opencode --version >"$RUNTIME_OUTPUT" 2>&1; then
  echo "test-opencode-bootstrap-plugin: opencode CLI observed: $(head -n 1 "$RUNTIME_OUTPUT")"
else
  if [ "$SMOKE_REQUIRED" = "1" ]; then
    cat "$RUNTIME_OUTPUT" >&2 || true
    fail "opencode unavailable; runtime smoke is required"
  fi
  echo "test-opencode-bootstrap-plugin: WARNING opencode unavailable; Node-level bootstrap checks passed, runtime smoke skipped"
fi

echo "test-opencode-bootstrap-plugin: ok"
