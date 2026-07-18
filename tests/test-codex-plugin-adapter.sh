#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="${ROOT_DIR}/.codex-plugin/plugin.json"
MARKETPLACE="${ROOT_DIR}/.claude-plugin/marketplace.json"
APP_PROOF="${ROOT_DIR}/docs/research/codex-app-smoke.md"
SMOKE_REQUIRED="${HARNESS_CODEX_PLUGIN_SMOKE_REQUIRED:-0}"

fail() {
  echo "test-codex-plugin-adapter: FAIL: $1" >&2
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
assert_file "$MARKETPLACE"
assert_file "$APP_PROOF"

MANIFEST_VERSION="$(node -e 'const fs=require("fs"); console.log(JSON.parse(fs.readFileSync(process.argv[1], "utf8")).version)' "$MANIFEST")"

node - "$MANIFEST" "$MARKETPLACE" "$ROOT_DIR/VERSION" <<'NODE'
const fs = require("fs");
const [manifestPath, marketplacePath, versionPath] = process.argv.slice(2);
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
const marketplace = JSON.parse(fs.readFileSync(marketplacePath, "utf8"));
const version = fs.readFileSync(versionPath, "utf8").trim();
const plugin = marketplace.plugins.find((entry) => entry.name === "claude-code-harness");
function assert(cond, msg) {
  if (!cond) {
    console.error(msg);
    process.exit(1);
  }
}
assert(manifest.name === "claude-code-harness", "manifest name mismatch");
assert(manifest.version === version, "manifest version mismatch");
assert(manifest.skills === "../codex/.codex/skills/", "manifest skills path must target Codex mirror relative to .codex-plugin");
assert(manifest.hooks && !Array.isArray(manifest.hooks), "Codex manifest hooks must be an inline object override");
assert(manifest.hooks.hooks && Object.keys(manifest.hooks.hooks).length === 0, "Codex manifest must explicitly override Claude fallback hooks with an empty hook map");
assert(manifest.interface && manifest.interface.displayName === "Claude Code Harness", "missing interface displayName");
assert(Array.isArray(manifest.interface.defaultPrompt) && manifest.interface.defaultPrompt.length >= 2, "missing default prompts");
assert(String(manifest.interface.longDescription || "").includes("Codex CLI compatibility route"), "manifest must not imply app support");
assert(plugin && plugin.source === "./", "Claude marketplace source should remain repo root");
assert(plugin.version === manifest.version, "marketplace and Codex manifest versions must match");
NODE

assert_contains "$APP_PROOF" 'Codex app remains `candidate`'
assert_contains "$APP_PROOF" "does not prove Codex app behavior"
assert_contains "$APP_PROOF" "not_observed != absent"
assert_contains "$APP_PROOF" "not inferred from Codex CLI help output"

BUILD_SCRIPT="${ROOT_DIR}/scripts/build-host-plugin-dist.sh"
[ -f "$BUILD_SCRIPT" ] || fail "missing $BUILD_SCRIPT"
chmod +x "$BUILD_SCRIPT" 2>/dev/null || true

DIST_TMP="$(mktemp -d)"
trap 'rm -rf "$DIST_TMP"' EXIT
bash "$BUILD_SCRIPT" --host codex --out "$DIST_TMP/codex-dist"

node - "$DIST_TMP/codex-dist/.codex-plugin/plugin.json" <<'NODE'
const fs = require("fs");
const manifest = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
function assert(cond, msg) {
  if (!cond) {
    console.error(msg);
    process.exit(1);
  }
}
assert(manifest.skills === "./skills/", "generated codex dist must use ./skills/");
assert(manifest.hooks && !Array.isArray(manifest.hooks), "generated Codex manifest lost inline hooks override");
assert(manifest.hooks.hooks && Object.keys(manifest.hooks.hooks).length === 0, "generated Codex manifest must not fall back to hooks/hooks.json");
assert(manifest.interface.displayName === "Claude Code Harness for Codex", "generated codex displayName mismatch");
assert(JSON.stringify(manifest).includes("../") === false, "generated codex manifest must not contain ..");
NODE

[ -f "$DIST_TMP/codex-dist/skills/harness-plan/SKILL.md" ] \
  || fail "generated codex dist missing harness-plan skill"

if command -v codex >/dev/null 2>&1; then
  TMP_HOME="$(mktemp -d)"
  TMP_CODEX_HOME="$(mktemp -d)"
  TMP_MARKETPLACE="$(mktemp -d)"
  PROBE_PROJECT="$(mktemp -d)"
  PROBE_PROJECT="$(cd "$PROBE_PROJECT" && pwd -P)"
  trap 'rm -rf "$TMP_HOME" "$TMP_CODEX_HOME" "$TMP_MARKETPLACE" "$PROBE_PROJECT" "$DIST_TMP"' EXIT

  # Simulate the full-root marketplace layout that triggered the regression:
  # a Claude-oriented default hooks/hooks.json is present next to the Codex
  # manifest. The explicit inline manifest override must prevent Codex from
  # falling back to this file.
  mkdir -p "$DIST_TMP/codex-dist/hooks"
  node - "$DIST_TMP/codex-dist/hooks/hooks.json" <<'NODE'
const fs = require("fs");
const outPath = process.argv[2];
const fixture = {
  hooks: {
    SessionStart: [{ hooks: [
      { type: "command", command: "true" },
      { type: "agent", prompt: "fixture agent hook must be ignored" },
      { type: "command", command: "true", async: true }
    ] }]
  }
};
fs.writeFileSync(outPath, JSON.stringify(fixture, null, 2) + "\n");
NODE

  mkdir -p "$TMP_MARKETPLACE/.claude-plugin"
  cp -R "$DIST_TMP/codex-dist" "$TMP_MARKETPLACE/claude-code-harness"
  node - "$DIST_TMP/codex-dist/.codex-plugin/plugin.json" "$TMP_MARKETPLACE/.claude-plugin/marketplace.json" <<'NODE'
const fs = require("fs");
const [manifestPath, outPath] = process.argv.slice(2);
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
const marketplace = {
  name: "claude-code-harness-marketplace",
  plugins: [
    {
      name: "claude-code-harness",
      version: manifest.version,
      source: "./claude-code-harness",
      description: manifest.description
    }
  ]
};
fs.writeFileSync(outPath, JSON.stringify(marketplace, null, 2) + "\n");
NODE

  HOME="$TMP_HOME" CODEX_HOME="$TMP_CODEX_HOME" codex plugin marketplace add "$TMP_MARKETPLACE" >/tmp/codex-plugin-smoke.$$ 2>&1 \
    || { cat /tmp/codex-plugin-smoke.$$ >&2; fail "codex plugin marketplace add failed"; }

  HOME="$TMP_HOME" CODEX_HOME="$TMP_CODEX_HOME" codex plugin list >/tmp/codex-plugin-list.$$ 2>&1 \
    || { cat /tmp/codex-plugin-list.$$ >&2; fail "codex plugin list failed"; }
  grep -Fq "claude-code-harness@claude-code-harness-marketplace" /tmp/codex-plugin-list.$$ \
    || { cat /tmp/codex-plugin-list.$$ >&2; fail "Codex marketplace did not list Harness plugin"; }

  HOME="$TMP_HOME" CODEX_HOME="$TMP_CODEX_HOME" codex plugin add claude-code-harness@claude-code-harness-marketplace >/tmp/codex-plugin-add.$$ 2>&1 \
    || { cat /tmp/codex-plugin-add.$$ >&2; fail "codex plugin add failed"; }

  grep -Fq '[plugins."claude-code-harness@claude-code-harness-marketplace"]' "$TMP_CODEX_HOME/config.toml" \
    || fail "installed plugin not recorded in isolated CODEX_HOME config"

  CACHE_ROOT="$TMP_CODEX_HOME/plugins/cache/claude-code-harness-marketplace/claude-code-harness/$MANIFEST_VERSION"
  [ -f "$CACHE_ROOT/.codex-plugin/plugin.json" ] || fail "Codex plugin manifest was not cached"
  [ -f "$CACHE_ROOT/skills/harness-plan/SKILL.md" ] || fail "Codex harness-plan skill was not cached in generated dist layout"
  [ -f "$CACHE_ROOT/hooks/hooks.json" ] || fail "synthetic Claude fallback hooks fixture was not cached"

  mkdir -p "$PROBE_PROJECT/.codex"
  cp "$ROOT_DIR/go/cmd/harness/testdata/gen/codex-hooks.json" "$PROBE_PROJECT/.codex/hooks.json"
  node - "$TMP_CODEX_HOME/config.toml" "$PROBE_PROJECT" <<'NODE'
const fs = require("fs");
const [configPath, projectPath] = process.argv.slice(2);
fs.appendFileSync(configPath, `\n[projects.${JSON.stringify(projectPath)}]\ntrust_level = "trusted"\n`);
NODE

  HOOK_PROBE_JSON="$(
    HOME="$TMP_HOME" CODEX_HOME="$TMP_CODEX_HOME" python3 - "$PROBE_PROJECT" <<'PY'
import json
import os
import select
import subprocess
import sys
import time

project = sys.argv[1]
process = subprocess.Popen(
    ["codex", "app-server"],
    cwd=project,
    env=os.environ.copy(),
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
    bufsize=1,
)
requests = [
    {"id": 1, "method": "initialize", "params": {"clientInfo": {"name": "cch-hook-probe", "version": "0.0.1"}, "capabilities": {"experimentalApi": True}}},
    {"method": "initialized", "params": {}},
    {"id": 2, "method": "hooks/list", "params": {"cwds": [project]}},
]
for request in requests:
    process.stdin.write(json.dumps(request) + "\n")
process.stdin.flush()

response = None
deadline = time.time() + 8
while time.time() < deadline:
    ready, _, _ = select.select([process.stdout], [], [], 0.5)
    if not ready:
        continue
    line = process.stdout.readline()
    if not line:
        break
    item = json.loads(line)
    if item.get("id") == 2:
        response = item
        break

process.terminate()
try:
    process.wait(timeout=2)
except subprocess.TimeoutExpired:
    process.kill()

if response is None:
    raise SystemExit("Codex app-server hooks/list returned no response")
entry = response.get("result", {}).get("data", [{}])[0]
hooks = entry.get("hooks", [])
print(json.dumps({
    "hook_count": len(hooks),
    "hooks": [
        {
            "event_name": hook.get("eventName"),
            "handler_type": hook.get("handlerType"),
            "source": hook.get("source"),
            "plugin_id": hook.get("pluginId"),
            "source_path": hook.get("sourcePath"),
        }
        for hook in hooks
    ],
    "warnings": entry.get("warnings", []),
    "errors": entry.get("errors", []),
}))
PY
  )" || fail "Codex app-server hook probe failed"

  node - "$HOOK_PROBE_JSON" <<'NODE'
const probe = JSON.parse(process.argv[2]);
const hooks = probe.hooks || [];
const warnings = probe.warnings || [];
const forbidden = warnings.filter((warning) => /agent hooks are not supported|async hooks are not supported|failed to parse hooks config|floor_policy/i.test(String(warning)));
if (probe.hook_count !== 2) {
  console.error(`expected exactly two generated Codex project command hooks, got ${probe.hook_count}: ${JSON.stringify(probe)}`);
  process.exit(1);
}
const eventNames = hooks.map((hook) => hook.event_name).sort();
const projectCommandsOnly = hooks.every((hook) => hook.source === "project" && hook.plugin_id === null && hook.handler_type === "command");
if (!projectCommandsOnly || JSON.stringify(eventNames) !== JSON.stringify(["preToolUse", "stop"])) {
  console.error(`expected only generated project command hooks, got: ${JSON.stringify(probe)}`);
  process.exit(1);
}
if (forbidden.length > 0 || (probe.errors || []).length > 0) {
  console.error(`Codex hook compatibility warnings/errors remain: ${JSON.stringify(probe)}`);
  process.exit(1);
}
NODE
  echo "test-codex-plugin-adapter: hooks/list loaded 2 project command hooks with no compatibility warnings"

  rm -f /tmp/codex-plugin-smoke.$$ /tmp/codex-plugin-list.$$ /tmp/codex-plugin-add.$$
else
  if [ "$SMOKE_REQUIRED" = "1" ]; then
    fail "codex unavailable; runtime smoke is required"
  fi
  echo "test-codex-plugin-adapter: WARNING codex unavailable; static checks passed, runtime smoke skipped"
fi

echo "test-codex-plugin-adapter: ok"
