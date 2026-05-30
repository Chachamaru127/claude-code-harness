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

assert_contains "$EVIDENCE" "internal-compatible"
assert_contains "$EVIDENCE" "Observed Runtime Evidence (2026-05-29)"
assert_contains "$EVIDENCE" "not_observed != absent"
assert_contains "$EVIDENCE" "PM handoff"
assert_contains "$EVIDENCE" "tests/test-cursor-adapter-candidate.sh"

assert_contains "${ROOT_DIR}/README.md" "| Cursor | \`internal-compatible\` |"
assert_contains "${ROOT_DIR}/README_ja.md" "| Cursor | \`internal-compatible\` |"
assert_contains "${ROOT_DIR}/docs/onboarding/index.md" "| Cursor | \`internal-compatible\` |"
assert_contains "${ROOT_DIR}/docs/onboarding/install.md" "### Cursor (\`internal-compatible\`)"
assert_contains "${ROOT_DIR}/docs/onboarding/install.md" "scripts/setup-cursor.sh"

assert_contains "$INTEGRATION" "not Cursor adapter support"
assert_contains "$INTEGRATION" "docs/research/cursor-adapter-candidate.md"

cursor_worker="$(bash "$ROUTER" --host cursor --role worker --field model)"
[ "$cursor_worker" = "composer-2.5-fast" ] || fail "cursor worker model routing mismatch"
assert_contains "${ROOT_DIR}/.cursor/agents/worker.md" "model: ${cursor_worker}"

cursor_reviewer="$(bash "$ROUTER" --host cursor --role reviewer --field model)"
[ "$cursor_reviewer" = "composer-2.5-fast" ] || fail "cursor reviewer model routing mismatch"
assert_contains "${ROOT_DIR}/.cursor/agents/reviewer.md" "model: ${cursor_reviewer}"

BUILD_SCRIPT="${ROOT_DIR}/scripts/build-host-plugin-dist.sh"
[ -f "$BUILD_SCRIPT" ] || fail "missing $BUILD_SCRIPT"
chmod +x "$BUILD_SCRIPT" 2>/dev/null || true

DIST_TMP="$(mktemp -d)"
trap 'rm -rf "$DIST_TMP"' EXIT
bash "$BUILD_SCRIPT" --host cursor --out "$DIST_TMP/cursor-dist"

node - "$DIST_TMP/cursor-dist/.cursor-plugin/plugin.json" <<'NODE'
const fs = require("fs");
const manifest = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
function assert(cond, msg) {
  if (!cond) {
    console.error(msg);
    process.exit(1);
  }
}
assert(manifest.skills === "./skills/", "generated cursor dist must use ./skills/");
assert(manifest.agents === "./agents/", "generated cursor dist must use ./agents/");
assert(manifest.interface.displayName === "Claude Code Harness for Cursor", "generated cursor displayName mismatch");
assert(JSON.stringify(manifest).includes("../") === false, "generated cursor manifest must not contain ..");
NODE

[ -f "$DIST_TMP/cursor-dist/skills/harness-work/SKILL.md" ] \
  || fail "generated cursor dist missing harness-work skill"
[ -f "$DIST_TMP/cursor-dist/agents/worker.md" ] \
  || fail "generated cursor dist missing worker agent"

SETUP_SCRIPT="${ROOT_DIR}/scripts/setup-cursor.sh"
[ -f "$SETUP_SCRIPT" ] || fail "missing $SETUP_SCRIPT"
chmod +x "$SETUP_SCRIPT" 2>/dev/null || true

SETUP_TMP_HOME="$(mktemp -d)"
SETUP_DIST="${SETUP_TMP_HOME}/cursor-dist"
trap 'rm -rf "$DIST_TMP" "$SETUP_TMP_HOME"' EXIT

HOME="$SETUP_TMP_HOME" HARNESS_CURSOR_DIST="$SETUP_DIST" bash "$SETUP_SCRIPT" --check >/tmp/cursor-setup-check.$$ 2>&1 \
  || { cat /tmp/cursor-setup-check.$$ >&2; fail "setup-cursor.sh --check failed"; }
rm -f /tmp/cursor-setup-check.$$

[ -f "$SETUP_DIST/.cursor-plugin/plugin.json" ] \
  || fail "setup-cursor --check must build .cursor-plugin/plugin.json"
[ -f "$SETUP_DIST/skills/breezing/SKILL.md" ] \
  || fail "setup-cursor --check dist missing breezing skill"
if grep -rEl '^user-invocable:[[:space:]]*true[[:space:]]*$' "$SETUP_DIST/skills" >/dev/null 2>&1; then
  fail "setup-cursor dist must normalize user-invocable: true skills for Cursor"
fi
if ! grep -Eq '^user-invocable:[[:space:]]*false[[:space:]]*$' "$SETUP_DIST/skills/breezing/SKILL.md"; then
  fail "setup-cursor dist breezing must be user-invocable: false"
fi

HOME="$SETUP_TMP_HOME" HARNESS_CURSOR_DIST="$SETUP_DIST" bash "$SETUP_SCRIPT" >/tmp/cursor-setup-install.$$ 2>&1 \
  || { cat /tmp/cursor-setup-install.$$ >&2; fail "setup-cursor.sh install failed"; }
rm -f /tmp/cursor-setup-install.$$

INSTALLED="${SETUP_TMP_HOME}/.cursor/plugins/local/claude-code-harness"
[ -d "$INSTALLED" ] || fail "setup-cursor must install to ~/.cursor/plugins/local/claude-code-harness"
if [ -L "$INSTALLED" ]; then
  fail "setup-cursor install must be a real directory, not a symlink"
fi
[ -f "$INSTALLED/.cursor-plugin/plugin.json" ] \
  || fail "installed cursor plugin missing manifest"

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
