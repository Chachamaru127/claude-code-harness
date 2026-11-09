#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_SCRIPT="${ROOT_DIR}/scripts/build-host-plugin-dist.sh"

fail() {
  echo "test-host-plugin-dist: FAIL: $1" >&2
  exit 1
}

[ -x "$BUILD_SCRIPT" ] || chmod +x "$BUILD_SCRIPT"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

build_host() {
  local host="$1"
  local out="${TMP_ROOT}/${host}"
  bash "$BUILD_SCRIPT" --host "$host" --out "$out"
  printf '%s\n' "$out"
}

assert_absent() {
  local base="$1"
  local rel="$2"
  if [ -e "${base}/${rel}" ]; then
    fail "${base} must not contain ${rel}"
  fi
}

assert_present() {
  local base="$1"
  local rel="$2"
  if [ ! -e "${base}/${rel}" ]; then
    fail "${base} missing ${rel}"
  fi
}

assert_manifest_no_parent_paths() {
  local manifest="$1"
  if grep -Fq '../' "$manifest"; then
    fail "${manifest} contains .. paths"
  fi
}

CLAUDE_OUT="$(build_host claude)"
CODEX_OUT="$(build_host codex)"
CURSOR_OUT="$(build_host cursor)"
GROK_OUT="$(build_host grok)"

assert_present "$CLAUDE_OUT" ".claude-plugin/plugin.json"
assert_present "$CLAUDE_OUT" "skills/harness-work/SKILL.md"
assert_absent "$CLAUDE_OUT" ".codex-plugin"
assert_absent "$CLAUDE_OUT" ".cursor-plugin"
assert_absent "$CLAUDE_OUT" ".grok-plugin"
assert_absent "$CLAUDE_OUT" "codex"
assert_absent "$CLAUDE_OUT" ".cursor"
assert_present "$CLAUDE_OUT" "scripts/codex-companion.sh"
assert_present "$CLAUDE_OUT" "scripts/codex-review-app-server-proxy.mjs"
assert_present "$CLAUDE_OUT" "scripts/lib/orchestration-ledger.sh"
assert_present "$CLAUDE_OUT" "scripts/model-routing.sh"

assert_present "$CODEX_OUT" ".codex-plugin/plugin.json"
assert_present "$CODEX_OUT" "skills/harness-plan/SKILL.md"
assert_present "$CODEX_OUT" "scripts/codex-companion.sh"
assert_present "$CODEX_OUT" "scripts/codex-review-app-server-proxy.mjs"
assert_present "$CODEX_OUT" "scripts/lib/orchestration-ledger.sh"
assert_present "$CODEX_OUT" "scripts/cursor-companion.sh"
assert_present "$CODEX_OUT" "scripts/resolve-impl-backend.sh"
assert_present "$CODEX_OUT" "scripts/model-routing.sh"
assert_present "$CODEX_OUT" "VERSION"
for bin in harness harness-darwin-amd64 harness-darwin-arm64 harness-linux-amd64 harness-windows-amd64.exe; do
  assert_present "$CODEX_OUT" "bin/$bin"
  if ! cmp -s "$ROOT_DIR/bin/$bin" "$CODEX_OUT/bin/$bin"; then
    fail "Codex dist runtime binary must match the canonical artifact: $bin"
  fi
done
for profile in worker.toml reviewer.toml; do
  assert_present "$CODEX_OUT" "agents/$profile"
  if ! cmp -s "$ROOT_DIR/codex/.codex/agents/$profile" "$CODEX_OUT/agents/$profile"; then
    fail "Codex dist agent profile must be the generated canonical artifact: $profile"
  fi
done
assert_absent "$CODEX_OUT" ".claude-plugin"
assert_absent "$CODEX_OUT" ".cursor-plugin"
assert_absent "$CODEX_OUT" ".grok-plugin"
assert_absent "$CODEX_OUT" ".cursor"

for dist in "$CLAUDE_OUT" "$CODEX_OUT"; do
  for rel in \
    scripts/config-utils.sh \
    scripts/run-advisor-consultation.sh \
    scripts/build-weak-supervision-cues.sh \
    scripts/lib/advisor-response.schema.json \
    scripts/codex-loop.sh \
    scripts/generate-sprint-contract.js \
    scripts/lib/run-harness-subcommand.js \
    scripts/plan-registry.sh \
    scripts/enrich-sprint-contract.sh \
    scripts/ensure-sprint-contract-ready.sh \
    scripts/run-contract-review-checks.sh \
    scripts/write-review-result.sh \
    scripts/detect-review-plateau.sh \
    scripts/auto-checkpoint.sh \
    templates/schemas/plan-preapproval.v2.json \
    templates/schemas/brief-card.v1.json \
    templates/html/progress.html.template \
    templates/html/progress.en.html.template \
    templates/.claude-code-harness.config.yaml.template; do
    assert_present "$dist" "$rel"
    cmp -s "$ROOT_DIR/$rel" "$dist/$rel" || fail "bundled runtime source differs: $rel"
  done
  for rel in .git .claude .env docs out reports scripts/sandbox-test scripts/evidence scripts/node_modules; do
    assert_absent "$dist" "$rel"
  done
done

# A Codex dist is a runtime package, not a presence-only bundle. Exercise the
# routed Luna/max task path with a fake provider binary and an isolated HOME;
# the real bundled harness binary performs both fingerprint captures.
mkdir -p "${TMP_ROOT}/codex-fake-bin" "${TMP_ROOT}/codex-home" "${TMP_ROOT}/codex-consumer"
cat >"${TMP_ROOT}/codex-fake-bin/codex" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"${FAKE_CODEX_ARGS:?}"
cat >/dev/null
EOF
chmod +x "${TMP_ROOT}/codex-fake-bin/codex"
if ! (cd "${TMP_ROOT}/codex-consumer" && \
  HOME="${TMP_ROOT}/codex-home" \
    CODEX_HOME="${TMP_ROOT}/codex-home" \
    PATH="${TMP_ROOT}/codex-fake-bin:${PATH}" \
    FAKE_CODEX_ARGS="${TMP_ROOT}/codex-args.txt" \
    HARNESS_PLUGIN_ROOT="$CODEX_OUT" \
    CODEX_MODEL_TIER=worker \
    bash "$CODEX_OUT/scripts/codex-companion.sh" task --write "dist closure smoke"); then
  fail "Codex dist routed task must start with its bundled runtime closure"
fi
if ! grep -Fq 'model_reasoning_effort="max"' "${TMP_ROOT}/codex-args.txt"; then
  fail "Codex dist routed task did not preserve worker max effort"
fi

# Execute the packaged advisor, work-contract helpers, and loop worker from a
# consumer directory. Only the provider is stubbed; every Harness helper and
# the platform binary must resolve inside the distribution under test.
exercise_workflow_runtime() (
  local dist="$1" host="$2"
  local consumer="${TMP_ROOT}/${host}-workflow-consumer"
  local fake_bin="${TMP_ROOT}/${host}-workflow-bin"
  local fake_home="${TMP_ROOT}/${host}-workflow-home"
  mkdir -p "$consumer" "$fake_bin" "$fake_home"
  cat >"$fake_bin/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = --version ]; then
  echo 'codex-cli 0.153.4'
  exit 0
fi
[ "${1:-}" = exec ] || exit 91
printf '%s\n' "$@" >"${DIST_PROVIDER_ARGS:?}"
cat >"${DIST_PROVIDER_ARGS}.prompt"
if [ "${DIST_PROVIDER_MODE:?}" = advisor ]; then
  echo '{"schema_version":"advisor-response.v1","decision":"PLAN","summary":"Packaged advisor reached the provider.","executor_instructions":["Run the focused check."],"confidence":0.8,"stop_reason":null}'
else
  echo 'DIST_LOOP_STUB'
fi
EOF
  chmod +x "$fake_bin/codex"
  export HOME="$fake_home" CODEX_HOME="$fake_home"
  export PATH="$fake_bin:$PATH" PROJECT_ROOT="$consumer"
  export HARNESS_PLUGIN_ROOT="$dist" CLAUDE_PLUGIN_ROOT="$dist" HARNESS_INSTALL_ROOT="$dist"
  unset CODEX_ADVISOR_COMPANION CODEX_ADVISOR_MODEL CODEX_MODEL CODEX_MODEL_TIER CODEX_EFFORT
  cd "$consumer"
  cat >request.json <<'EOF'
{"schema_version":"advisor-request.v1","task_id":"1","reason_code":"retry-threshold","trigger_hash":"dist:1","question":"Which check should run next?","attempt":2,"last_error":"fixture","context_summary":["Distribution smoke test"]}
EOF
  DIST_PROVIDER_ARGS="$consumer/advisor.args" DIST_PROVIDER_MODE=advisor \
    bash "$dist/scripts/run-advisor-consultation.sh" --request-file "$consumer/request.json" \
      --response-file "$consumer/response.json" >"$consumer/advisor.stdout"
  jq -e '.decision == "PLAN" and .schema_version == "advisor-response.v1"' response.json >/dev/null \
    || fail "$host bundled advisor did not return a validated response"
  grep -Fxq gpt-6-astra advisor.args || fail "$host bundled advisor did not request astra"
  grep -Fq 'model_reasoning_effort="xhigh"' advisor.args || fail "$host bundled advisor lost xhigh effort"

  cat >Plans.md <<'EOF'
| Task | Content | DoD | Depends | Status |
|------|---------|-----|---------|--------|
| 1 | Exercise bundled helpers | Focused check passes | - | cc:TODO |
EOF
  node "$dist/scripts/generate-sprint-contract.js" 1 "$consumer/Plans.md" "$consumer/contract.json" >/dev/null
  bash "$dist/scripts/enrich-sprint-contract.sh" "$consumer/contract.json" --check "Packaged helpers execute" --approve >/dev/null
  bash "$dist/scripts/ensure-sprint-contract-ready.sh" "$consumer/contract.json" >/dev/null
  jq -e '.task.id == "1" and .review.status == "approved"' contract.json >/dev/null \
    || fail "$host bundled work-contract helpers failed"

  local state="$consumer/.claude/state/codex-loop"
  mkdir -p "$state/prompts" "$state/jobs"
  printf 'Exercise the packaged loop worker.\n' >"$state/prompts/dist-worker.md"
  jq -n --arg root "$consumer" --arg state "$state" '{
    id:"dist-worker",status:"queued",phase:"queued",title:"Distribution smoke",
    workspaceRoot:$root,jobClass:"task",write:true,
    logFile:($state+"/jobs/dist-worker.log"),
    request:{cwd:$root,promptFile:($state+"/prompts/dist-worker.md")}
  }' >"$state/jobs/dist-worker.json"
  DIST_PROVIDER_ARGS="$consumer/loop.args" DIST_PROVIDER_MODE=loop \
    "$dist/bin/harness" codex-loop local-task-worker --job-id dist-worker
  jq -e '.status == "completed" and .result.status == 0 and (.result.rawOutput | contains("DIST_LOOP_STUB"))' \
    "$state/jobs/dist-worker.json" >/dev/null || fail "$host bundled loop worker failed"
  assert_absent "$dist" .claude/state
)

exercise_workflow_runtime "$CLAUDE_OUT" claude
exercise_workflow_runtime "$CODEX_OUT" codex

assert_present "$CURSOR_OUT" ".cursor-plugin/plugin.json"
assert_present "$CURSOR_OUT" "skills/harness-work/SKILL.md"
assert_present "$CURSOR_OUT" "agents/worker.md"
assert_present "$CURSOR_OUT" "scripts/cursor-companion.sh"
assert_present "$CURSOR_OUT" "scripts/resolve-impl-backend.sh"
assert_present "$CURSOR_OUT" "scripts/model-routing.sh"
assert_absent "$CURSOR_OUT" ".claude-plugin"
assert_absent "$CURSOR_OUT" ".codex-plugin"
assert_absent "$CURSOR_OUT" ".grok-plugin"

assert_present "$GROK_OUT" ".grok-plugin/plugin.json"
assert_present "$GROK_OUT" "skills/harness-plan/SKILL.md"
assert_present "$GROK_OUT" "skills/harness-work/SKILL.md"
assert_present "$GROK_OUT" "skills/harness-review/SKILL.md"
assert_present "$GROK_OUT" "skills/breezing/SKILL.md"
assert_present "$GROK_OUT" "scripts/model-routing.sh"
assert_present "$GROK_OUT" "scripts/setup-grok.sh"
assert_present "$GROK_OUT" ".grok/AGENTS.md"
# 133.8/9a192025: grok dist intentionally carries the same guardrail closure
# as claude dist (.claude-plugin/plugin.json + hooks/hooks.json + bin/harness),
# because the valid_root bootstrap only recognizes a directory holding both
# bin/harness and a .claude-plugin/plugin.json naming this plugin. Without
# that closure, guardrail hooks silently no-op (exit 0) for grok-only
# installs. See scripts/build-host-plugin-dist.sh build_grok() comment.
assert_present "$GROK_OUT" ".claude-plugin/plugin.json"
assert_present "$GROK_OUT" "hooks/hooks.json"
assert_present "$GROK_OUT" "bin/harness"
assert_absent "$GROK_OUT" ".codex-plugin"
assert_absent "$GROK_OUT" ".cursor-plugin"

assert_manifest_no_parent_paths "${CLAUDE_OUT}/.claude-plugin/plugin.json"
assert_manifest_no_parent_paths "${CODEX_OUT}/.codex-plugin/plugin.json"
assert_manifest_no_parent_paths "${CURSOR_OUT}/.cursor-plugin/plugin.json"
assert_manifest_no_parent_paths "${GROK_OUT}/.grok-plugin/plugin.json"

# Cursor does not surface `user-invocable: true` skills. The cursor dist must
# normalize workflow skills so they register as Agent-Decides skills.
if grep -rEl '^user-invocable:[[:space:]]*true[[:space:]]*$' "${CURSOR_OUT}/skills" >/dev/null 2>&1; then
  fail "cursor dist still contains user-invocable: true skills (Cursor would drop them)"
fi
if [ ! -f "${CURSOR_OUT}/skills/breezing/SKILL.md" ]; then
  fail "cursor dist missing breezing skill"
fi
if ! grep -Eq '^user-invocable:[[:space:]]*false[[:space:]]*$' "${CURSOR_OUT}/skills/breezing/SKILL.md"; then
  fail "cursor dist breezing skill must be normalized to user-invocable: false"
fi
# Claude dist must preserve the original slash-command contract.
if ! grep -Eq '^user-invocable:[[:space:]]*true[[:space:]]*$' "${CLAUDE_OUT}/skills/breezing/SKILL.md"; then
  fail "claude dist breezing skill must keep user-invocable: true"
fi

node - "$CODEX_OUT/.codex-plugin/plugin.json" "$CURSOR_OUT/.cursor-plugin/plugin.json" "$GROK_OUT/.grok-plugin/plugin.json" <<'NODE'
const fs = require("fs");
const [codexPath, cursorPath, grokPath] = process.argv.slice(2);
const codex = JSON.parse(fs.readFileSync(codexPath, "utf8"));
const cursor = JSON.parse(fs.readFileSync(cursorPath, "utf8"));
const grok = JSON.parse(fs.readFileSync(grokPath, "utf8"));
function assert(cond, msg) {
  if (!cond) {
    console.error(msg);
    process.exit(1);
  }
}
assert(codex.skills === "./skills/", "codex dist skills path must be ./skills/");
assert(cursor.skills === "./skills/", "cursor dist skills path must be ./skills/");
assert(cursor.agents === "./agents/", "cursor dist agents path must be ./agents/");
assert(grok.skills === "./skills/", "grok dist skills path must be ./skills/");
assert(codex.interface.displayName === "Claude Code Harness for Codex", "codex displayName mismatch");
assert(cursor.interface.displayName === "Claude Code Harness for Cursor", "cursor displayName mismatch");
assert(grok.interface.displayName === "Claude Code Harness for Grok", "grok displayName mismatch");
assert(codex.interface.displayName !== cursor.interface.displayName, "displayName must differ by host");
assert(grok.interface.displayName !== cursor.interface.displayName, "grok displayName must differ from cursor");
assert(JSON.stringify(grok).includes("../") === false, "grok dist manifest must not contain ..");
NODE

# A small staged source tree tests filtering without placing synthetic private
# files in the real checkout or pointing --out at any existing directory.
FILTER_SOURCE="${TMP_ROOT}/filter-source"
FILTER_OUT="${TMP_ROOT}/filter-out"
mkdir -p "$FILTER_SOURCE"/{scripts/lib,hosts,.claude-plugin,skills,agents,hooks,output-styles,bin,templates}
cp "$BUILD_SCRIPT" "$FILTER_SOURCE/scripts/build-host-plugin-dist.sh"
cp "$ROOT_DIR/scripts/lib/host-registry.sh" "$FILTER_SOURCE/scripts/lib/host-registry.sh"
cp "$ROOT_DIR/hosts/registry.json" "$FILTER_SOURCE/hosts/registry.json"
cp "$ROOT_DIR/.claude-plugin/plugin.json" "$FILTER_SOURCE/.claude-plugin/plugin.json"
cp "$ROOT_DIR/VERSION" "$FILTER_SOURCE/VERSION"
printf '{}\n' >"$FILTER_SOURCE/hooks/hooks.json"
printf 'echo runtime-source\n' >"$FILTER_SOURCE/scripts/required.sh"
printf '{}\n' >"$FILTER_SOURCE/scripts/lib/runtime.schema.json"
printf 'fixture: true\n' >"$FILTER_SOURCE/templates/.claude-code-harness.config.yaml.template"
for rel in scripts/.hidden/fixture.sh scripts/node_modules/fixture.js scripts/evidence/fixture.sh \
  scripts/sandbox-test/fixture.py scripts/out/fixture.sh templates/reports/fixture.md \
  scripts/.secret.sh scripts/.env templates/.env .claude/state/fixture.json docs/fixture.md; do
  mkdir -p "$(dirname "$FILTER_SOURCE/$rel")"
  printf 'private-fixture\n' >"$FILTER_SOURCE/$rel"
done
printf 'outside-fixture\n' >"${TMP_ROOT}/outside-source.sh"
ln -s "${TMP_ROOT}/outside-source.sh" "$FILTER_SOURCE/scripts/external.sh"
ln -s "${TMP_ROOT}/outside-source.sh" "$FILTER_SOURCE/templates/external.json"
bash "$FILTER_SOURCE/scripts/build-host-plugin-dist.sh" --host claude --out "$FILTER_OUT"
for rel in scripts/required.sh scripts/lib/runtime.schema.json templates/.claude-code-harness.config.yaml.template; do
  assert_present "$FILTER_OUT" "$rel"
done
for rel in scripts/.hidden scripts/node_modules scripts/evidence scripts/sandbox-test scripts/out \
  templates/reports scripts/.secret.sh scripts/.env templates/.env scripts/external.sh templates/external.json .claude docs; do
  assert_absent "$FILTER_OUT" "$rel"
done

echo "test-host-plugin-dist: ok"
