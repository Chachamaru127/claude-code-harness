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

if command -v codex >/dev/null 2>&1; then
  TMP_HOME="$(mktemp -d)"
  TMP_CODEX_HOME="$(mktemp -d)"
  TMP_MARKETPLACE="$(mktemp -d)"
  trap 'rm -rf "$TMP_HOME" "$TMP_CODEX_HOME" "$TMP_MARKETPLACE"' EXIT

  mkdir -p "$TMP_MARKETPLACE/.claude-plugin" "$TMP_MARKETPLACE/claude-code-harness/codex/.codex"
  cp -R "$ROOT_DIR/.codex-plugin" "$TMP_MARKETPLACE/claude-code-harness/.codex-plugin"
  cp -R "$ROOT_DIR/codex/.codex/skills" "$TMP_MARKETPLACE/claude-code-harness/codex/.codex/skills"
  node - "$MANIFEST" "$TMP_MARKETPLACE/.claude-plugin/marketplace.json" <<'NODE'
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
  [ -f "$CACHE_ROOT/codex/.codex/skills/harness-plan/SKILL.md" ] || fail "Codex harness-plan skill was not cached"
  rm -f /tmp/codex-plugin-smoke.$$ /tmp/codex-plugin-list.$$ /tmp/codex-plugin-add.$$
else
  if [ "$SMOKE_REQUIRED" = "1" ]; then
    fail "codex unavailable; runtime smoke is required"
  fi
  echo "test-codex-plugin-adapter: WARNING codex unavailable; static checks passed, runtime smoke skipped"
fi

echo "test-codex-plugin-adapter: ok"
