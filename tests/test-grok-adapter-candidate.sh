#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="${ROOT_DIR}/.grok-plugin/plugin.json"
AGENTS="${ROOT_DIR}/.grok/AGENTS.md"
EVIDENCE="${ROOT_DIR}/docs/research/grok-adapter-candidate.md"
ROUTER="${ROOT_DIR}/scripts/model-routing.sh"
SETUP_SCRIPT="${ROOT_DIR}/scripts/setup-grok.sh"
BUILD_SCRIPT="${ROOT_DIR}/scripts/build-host-plugin-dist.sh"
SMOKE_REQUIRED="${HARNESS_GROK_ADAPTER_SMOKE_REQUIRED:-0}"

fail() {
  echo "test-grok-adapter-candidate: FAIL: $1" >&2
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

assert_not_contains() {
  local file="$1"
  local needle="$2"
  if grep -Fq "$needle" "$file"; then
    fail "unexpected '$needle' in $file"
  fi
}

assert_file "$MANIFEST"
assert_file "$AGENTS"
assert_file "$EVIDENCE"
assert_file "$SETUP_SCRIPT"
assert_file "$BUILD_SCRIPT"
[ -x "$ROUTER" ] || fail "scripts/model-routing.sh must be executable"
[ -x "$SETUP_SCRIPT" ] || chmod +x "$SETUP_SCRIPT"
[ -x "$BUILD_SCRIPT" ] || chmod +x "$BUILD_SCRIPT"

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
assert(manifest.skills === "../skills/", "manifest skills path must target core skills relative to .grok-plugin");
assert(/Candidate|Internal-compatible|internal-compatible/i.test(String(manifest.description || "")), "manifest description must keep non-supported boundary");
assert(/Candidate|Internal-compatible|internal-compatible/i.test(String(manifest.interface.shortDescription || "")), "manifest shortDescription must keep non-supported boundary");
assert(!/supported Grok adapter/i.test(JSON.stringify(manifest)), "manifest must not claim supported Grok adapter");
assert(!/Grok is `supported`/i.test(JSON.stringify(manifest)), "manifest must not claim Grok is supported");
NODE

assert_contains "$AGENTS" "harness-plan"
assert_contains "$AGENTS" "harness-work"
assert_contains "$AGENTS" "harness-review"
assert_contains "$AGENTS" "breezing"
assert_contains "$AGENTS" "internal-compatible"
assert_contains "$AGENTS" "scripts/model-routing.sh --host grok"
assert_contains "$AGENTS" "scripts/setup-grok.sh"
assert_not_contains "$AGENTS" "public support claim that Grok is supported"

assert_contains "$EVIDENCE" "internal-compatible"
assert_contains "$EVIDENCE" "not_observed != absent"
assert_contains "$EVIDENCE" "tests/test-grok-adapter-candidate.sh"
assert_contains "$EVIDENCE" "scripts/setup-grok.sh"
assert_contains "$EVIDENCE" "Observed Runtime Evidence"
assert_contains "$EVIDENCE" "Do not claim public \`supported\`"
assert_contains "$EVIDENCE" "public top-tier product claim for this host" # blocked-wording column
# Honest tier: status lines must stay non-public-supported, not claim supported.
if grep -Eqi 'Grok is `supported`|Grok is \*\*supported\*\*|Status: supported' "$EVIDENCE"; then
  fail "evidence doc must not claim supported Grok adapter as status"
fi
if grep -Eq '^Grok is a \*\*supported\*\*' "$EVIDENCE"; then
  fail "evidence doc must not promote Grok to supported"
fi

assert_contains "${ROOT_DIR}/README.md" "| Grok | \`internal-compatible\` |"
assert_contains "${ROOT_DIR}/README_ja.md" "| Grok | \`internal-compatible\` |"
assert_contains "${ROOT_DIR}/docs/onboarding/index.md" "| Grok | \`internal-compatible\` |"
assert_contains "${ROOT_DIR}/docs/onboarding/install.md" "### Grok (\`internal-compatible\`)"
assert_contains "${ROOT_DIR}/docs/onboarding/install.md" "scripts/setup-grok.sh"
assert_contains "${ROOT_DIR}/docs/bootstrap-routing-contract.md" "Grok | \`internal-compatible\`"
assert_contains "${ROOT_DIR}/docs/tool-capability-matrix.md" "| Grok | \`internal-compatible\` |"

# Model routing contract
grok_worker="$(bash "$ROUTER" --host grok --role worker --field model)"
[ -n "$grok_worker" ] || fail "grok worker model must be non-empty"
[ "$grok_worker" = "grok-composer-2.5-fast" ] || fail "grok worker model routing mismatch: got $grok_worker"

grok_explorer="$(bash "$ROUTER" --host grok --role explorer --field model)"
[ "$grok_explorer" = "grok-composer-2.5-fast" ] || fail "grok explorer model routing mismatch"

grok_reviewer="$(bash "$ROUTER" --host grok --role reviewer --field model)"
[ "$grok_reviewer" = "grok-4.5" ] || fail "grok reviewer model routing mismatch"

grok_advisor="$(bash "$ROUTER" --host grok --role advisor --field model)"
[ "$grok_advisor" = "grok-4.5" ] || fail "grok advisor model routing mismatch"

grok_release="$(bash "$ROUTER" --host grok --role release --field model)"
[ "$grok_release" = "grok-4.5" ] || fail "grok release model routing mismatch"

grok_json="$(bash "$ROUTER" --host grok --role worker --format json)"
printf '%s' "$grok_json" | grep -q '"host":"grok"' || fail "grok json format missing host"
printf '%s' "$grok_json" | grep -q '"model":"grok-composer-2.5-fast"' || fail "grok json format missing model"

grok_args="$(bash "$ROUTER" --host grok --tier review --format args | tr '\n' ' ')"
printf '%s' "$grok_args" | grep -q -- '--model grok-4.5' || fail "grok args must include review model"

grok_env="$(bash "$ROUTER" --host grok --tier standard --format env)"
printf '%s' "$grok_env" | grep -q '^GROK_MODEL=grok-composer-2.5-fast$' || fail "grok env must export GROK_MODEL"
printf '%s' "$grok_env" | grep -q '^GROK_EFFORT=medium$' || fail "grok env must export GROK_EFFORT"

# Existing hosts must remain stable when grok is added
claude_worker="$(bash "$ROUTER" --host claude --role worker --field model)"
[ "$claude_worker" = "claude-sonnet-5" ] || fail "claude worker routing regressed"
cursor_worker="$(bash "$ROUTER" --host cursor --role worker --field model)"
[ "$cursor_worker" = "composer-2.5-fast" ] || fail "cursor worker routing regressed"
codex_worker="$(bash "$ROUTER" --host codex --role worker --field model)"
[ "$codex_worker" = "gpt-5.5" ] || fail "codex worker routing regressed"

# Dist build: package-local paths, core skills present
DIST_TMP="$(mktemp -d)"
trap 'rm -rf "$DIST_TMP"' EXIT
bash "$BUILD_SCRIPT" --host grok --out "$DIST_TMP/grok-dist"

node - "$DIST_TMP/grok-dist/.grok-plugin/plugin.json" <<'NODE'
const fs = require("fs");
const manifest = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
function assert(cond, msg) {
  if (!cond) {
    console.error(msg);
    process.exit(1);
  }
}
assert(manifest.skills === "./skills/", "generated grok dist must use ./skills/");
assert(manifest.interface.displayName === "Claude Code Harness for Grok", "generated grok displayName mismatch");
assert(JSON.stringify(manifest).includes("../") === false, "generated grok manifest must not contain ..");
assert(/Candidate|Internal-compatible|internal-compatible/i.test(String(manifest.description || "")), "generated grok description must keep non-supported boundary");
NODE

for skill in harness-plan harness-work harness-review breezing; do
  [ -f "$DIST_TMP/grok-dist/skills/${skill}/SKILL.md" ] \
    || fail "generated grok dist missing ${skill} skill"
done
[ -f "$DIST_TMP/grok-dist/.grok/AGENTS.md" ] \
  || fail "generated grok dist missing .grok/AGENTS.md"
[ -f "$DIST_TMP/grok-dist/scripts/model-routing.sh" ] \
  || fail "generated grok dist missing model-routing.sh"
[ -f "$DIST_TMP/grok-dist/scripts/setup-grok.sh" ] \
  || fail "generated grok dist missing setup-grok.sh"

# setup-grok --check against isolated HOME / dist
SETUP_TMP_HOME="$(mktemp -d)"
SETUP_DIST="${SETUP_TMP_HOME}/grok-dist"
trap 'rm -rf "$DIST_TMP" "$SETUP_TMP_HOME"' EXIT

CHECK_LOG="${SETUP_TMP_HOME}/setup-check.log"
if ! HOME="$SETUP_TMP_HOME" HARNESS_GROK_DIST="$SETUP_DIST" bash "$SETUP_SCRIPT" --check >"$CHECK_LOG" 2>&1; then
  cat "$CHECK_LOG" >&2
  fail "setup-grok.sh --check failed"
fi

[ -f "$SETUP_DIST/.grok-plugin/plugin.json" ] \
  || fail "setup-grok --check must build .grok-plugin/plugin.json"
for skill in harness-plan harness-work harness-review breezing; do
  [ -f "$SETUP_DIST/skills/${skill}/SKILL.md" ] \
    || fail "setup-grok --check dist missing ${skill} skill"
done
if grep -Fq '../' "$SETUP_DIST/.grok-plugin/plugin.json"; then
  fail "setup-grok dist manifest must not contain .. paths"
fi

# Full install via directory copy (deterministic; does not require grok CLI trust)
INSTALL_LOG="${SETUP_TMP_HOME}/setup-install.log"
if ! HOME="$SETUP_TMP_HOME" HARNESS_GROK_DIST="$SETUP_DIST" bash "$SETUP_SCRIPT" --no-cli-install >"$INSTALL_LOG" 2>&1; then
  cat "$INSTALL_LOG" >&2
  fail "setup-grok.sh install failed"
fi

INSTALLED="${SETUP_TMP_HOME}/.grok/plugins/claude-code-harness"
[ -d "$INSTALLED" ] || fail "setup-grok must install to ~/.grok/plugins/claude-code-harness"
if [ -L "$INSTALLED" ]; then
  fail "setup-grok install must be a real directory, not a symlink"
fi
[ -f "$INSTALLED/.grok-plugin/plugin.json" ] \
  || fail "installed grok plugin missing manifest"
for skill in harness-plan harness-work harness-review breezing; do
  [ -f "$INSTALLED/skills/${skill}/SKILL.md" ] \
    || fail "installed grok plugin missing ${skill} skill"
done

# Optional: real CLI install + inspect when grok is available
if command -v grok >/dev/null 2>&1; then
  CLI_HOME="$(mktemp -d)"
  trap 'rm -rf "$DIST_TMP" "$SETUP_TMP_HOME" "$CLI_HOME"' EXIT
  CLI_DIST="${CLI_HOME}/grok-dist"
  if ! HOME="$CLI_HOME" HARNESS_GROK_DIST="$CLI_DIST" bash "$SETUP_SCRIPT" --check >"${CLI_HOME}/check.log" 2>&1; then
    cat "${CLI_HOME}/check.log" >&2
    fail "setup-grok --check under CLI HOME failed"
  fi
  if HOME="$CLI_HOME" grok plugin validate "$CLI_DIST" >"${CLI_HOME}/validate.log" 2>&1; then
    echo "test-grok-adapter-candidate: grok plugin validate ok"
  else
    if [ "$SMOKE_REQUIRED" = "1" ]; then
      cat "${CLI_HOME}/validate.log" >&2
      fail "grok plugin validate failed"
    fi
    echo "test-grok-adapter-candidate: WARNING grok plugin validate failed; static checks passed"
  fi
  if HOME="$CLI_HOME" grok plugin install "$CLI_DIST" --trust >"${CLI_HOME}/install.log" 2>&1; then
    OTHER_PROJECT="$(mktemp -d)"
    if (
      cd "$OTHER_PROJECT"
      HOME="$CLI_HOME" grok inspect --json >"${CLI_HOME}/inspect.json" 2>"${CLI_HOME}/inspect.err"
    ); then
      node - "${CLI_HOME}/inspect.json" <<'NODE'
const fs = require("fs");
const data = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const names = new Set((data.skills || []).map((s) => s.name));
const required = ["harness-plan", "harness-work", "harness-review", "breezing"];
const missing = required.filter((n) => !names.has(n));
if (missing.length) {
  console.error("inspect missing skills:", missing.join(", "));
  process.exit(1);
}
const fromPlugin = (data.skills || []).filter(
  (s) => required.includes(s.name) && s.source && s.source.type === "plugin"
);
if (fromPlugin.length < required.length) {
  console.error("expected core skills to load from plugin source");
  process.exit(1);
}
NODE
      echo "test-grok-adapter-candidate: grok inspect skill discovery ok (other project)"
    else
      if [ "$SMOKE_REQUIRED" = "1" ]; then
        cat "${CLI_HOME}/inspect.err" >&2 || true
        fail "grok inspect failed after install"
      fi
      echo "test-grok-adapter-candidate: WARNING grok inspect failed; static install checks passed"
    fi
    rm -rf "$OTHER_PROJECT"
  else
    if [ "$SMOKE_REQUIRED" = "1" ]; then
      cat "${CLI_HOME}/install.log" >&2
      fail "grok plugin install failed"
    fi
    echo "test-grok-adapter-candidate: WARNING grok plugin install failed; static checks passed"
  fi
else
  if [ "$SMOKE_REQUIRED" = "1" ]; then
    fail "grok unavailable; runtime smoke is required"
  fi
  echo "test-grok-adapter-candidate: WARNING grok CLI unavailable; static checks passed, runtime smoke skipped"
fi

echo "test-grok-adapter-candidate: ok"
