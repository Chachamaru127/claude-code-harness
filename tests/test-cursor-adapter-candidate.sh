#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="${ROOT_DIR}/.cursor-plugin/plugin.json"
AGENTS="${ROOT_DIR}/.cursor/AGENTS.md"
EVIDENCE="${ROOT_DIR}/docs/research/cursor-adapter-candidate.md"
INTEGRATION="${ROOT_DIR}/docs/CURSOR_INTEGRATION.md"
ROUTER="${ROOT_DIR}/scripts/model-routing.sh"
SMOKE_REQUIRED="${HARNESS_CURSOR_ADAPTER_SMOKE_REQUIRED:-0}"

fail() {
  echo "test-cursor-adapter-candidate: FAIL: $1" >&2
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

assert_file "$MANIFEST"
assert_file "$AGENTS"
assert_file "$EVIDENCE"
assert_file "$INTEGRATION"
assert_file "${ROOT_DIR}/.cursor/hooks.json"
assert_file "${ROOT_DIR}/.cursor/mcp.json"
assert_file "${ROOT_DIR}/.cursor/agents/worker.md"
assert_file "${ROOT_DIR}/.cursor/agents/reviewer.md"
assert_file "${ROOT_DIR}/.cursor/agents/advisor.md"
[ -x "$ROUTER" ] || fail "scripts/model-routing.sh must be executable"

node - "$MANIFEST" "$ROOT_DIR/VERSION" <<'NODE'
const fs = require("fs");
const [manifestPath, versionPath] = process.argv.slice(2);
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
const version = fs.readFileSync(versionPath, "utf8").trim();
function assert(cond, msg) {
  if (!cond) {
    console.error(msg);
    process.exit(1);
  }
}
assert(manifest.name === "claude-code-harness", "manifest name mismatch");
assert(manifest.version === version, "manifest version mismatch");
assert(manifest.skills === "../skills/", "manifest skills path must target core skills relative to .cursor-plugin");
assert(manifest.agents === "../.cursor/agents/", "manifest agents path must target .cursor/agents");
assert(String(manifest.description || "").includes("Candidate"), "manifest description must keep candidate boundary");
assert(String(manifest.interface.shortDescription || "").includes("Candidate"), "manifest shortDescription must keep candidate boundary");
assert(String(manifest.interface.longDescription || "").includes("candidate"), "manifest must not imply supported Cursor adapter");
NODE

assert_contains "$AGENTS" "harness-plan"
assert_contains "$AGENTS" "harness-work"
assert_contains "$AGENTS" "harness-review"
assert_contains "$AGENTS" "candidate"
assert_contains "$AGENTS" "scripts/model-routing.sh --host cursor"

assert_contains "$EVIDENCE" "Cursor remains \`candidate\`"
assert_contains "$EVIDENCE" "not_observed != absent"
assert_contains "$EVIDENCE" "PM handoff"
assert_contains "$EVIDENCE" "tests/test-cursor-adapter-candidate.sh"

assert_contains "$INTEGRATION" "not Cursor adapter support"
assert_contains "$INTEGRATION" "docs/research/cursor-adapter-candidate.md"

cursor_worker="$(bash "$ROUTER" --host cursor --role worker --field model)"
[ "$cursor_worker" = "composer-2.5-fast" ] || fail "cursor worker model routing mismatch"
assert_contains "${ROOT_DIR}/.cursor/agents/worker.md" "model: ${cursor_worker}"

cursor_reviewer="$(bash "$ROUTER" --host cursor --role reviewer --field model)"
[ "$cursor_reviewer" = "composer-2.5-fast" ] || fail "cursor reviewer model routing mismatch"
assert_contains "${ROOT_DIR}/.cursor/agents/reviewer.md" "model: ${cursor_reviewer}"

if command -v cursor >/dev/null 2>&1; then
  if cursor --version >/tmp/cursor-adapter-smoke.$$ 2>&1; then
    echo "test-cursor-adapter-candidate: cursor CLI observed: $(head -n 1 /tmp/cursor-adapter-smoke.$$)"
  else
    if [ "$SMOKE_REQUIRED" = "1" ]; then
      cat /tmp/cursor-adapter-smoke.$$ >&2 || true
      fail "cursor CLI present but --version failed"
    fi
    echo "test-cursor-adapter-candidate: WARNING cursor CLI present but --version failed; static checks passed"
  fi
  rm -f /tmp/cursor-adapter-smoke.$$
else
  if [ "$SMOKE_REQUIRED" = "1" ]; then
    fail "cursor unavailable; runtime smoke is required"
  fi
  echo "test-cursor-adapter-candidate: WARNING cursor CLI unavailable; static checks passed, runtime smoke skipped"
fi

echo "test-cursor-adapter-candidate: ok"
