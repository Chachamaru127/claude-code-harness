#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HARNESS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

assert_eq() {
  local got="$1"
  local want="$2"
  local label="$3"
  if [ "$got" != "$want" ]; then
    echo "[FAIL] ${label}: got '${got}', want '${want}'" >&2
    exit 1
  fi
}

assert_fails() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "[FAIL] ${label}: command unexpectedly succeeded" >&2
    exit 1
  fi
}

cat > "${TMP_DIR}/Plans.md" <<'EOF'
# Default Plans

## Phase 1: default

| Task | Content | DoD | Depends | Status |
|------|---------|-----|---------|--------|
| 1.1.1 | default task | default DoD | - | cc:TODO |
EOF

mkdir -p "${TMP_DIR}/plans"
cat > "${TMP_DIR}/plans/roadmap.md" <<'EOF'
# Roadmap Plans

## Phase 9: roadmap

| Task | Content | DoD | Depends | Status |
|------|---------|-----|---------|--------|
| 9.1.1 | roadmap task | roadmap DoD | - | cc:TODO |
EOF

cat > "${TMP_DIR}/plans/manifest.json" <<'EOF'
{
  "schema_version": "plans-manifest.v1",
  "plans": {
    "default": "Plans.md",
    "roadmap": {
      "path": "plans/roadmap.md"
    }
  }
}
EOF

(
  export PROJECT_ROOT="${TMP_DIR}"
  export CONFIG_FILE="${TMP_DIR}/.claude-code-harness.config.yaml"
  # shellcheck source=../scripts/config-utils.sh
  source "${HARNESS_ROOT}/scripts/config-utils.sh"
  assert_eq "$(get_plans_file_path)" "Plans.md" "manifest default resolves Plans.md"
  assert_eq "$(HARNESS_PLAN_NAME=roadmap get_plans_file_path)" "plans/roadmap.md" "env plan name selects roadmap"
)

list_output="$(bash "${HARNESS_ROOT}/scripts/plan-registry.sh" --root "${TMP_DIR}" list)"
grep -q $'default\tPlans.md\tactive' <<<"$list_output"
grep -q $'roadmap\tplans/roadmap.md\t' <<<"$list_output"

assert_eq "$(bash "${HARNESS_ROOT}/scripts/plan-registry.sh" --root "${TMP_DIR}" path roadmap)" "plans/roadmap.md" "registry path resolves roadmap"
bash "${HARNESS_ROOT}/scripts/plan-registry.sh" --root "${TMP_DIR}" switch roadmap >/dev/null

(
  export PROJECT_ROOT="${TMP_DIR}"
  export CONFIG_FILE="${TMP_DIR}/.claude-code-harness.config.yaml"
  # shellcheck source=../scripts/config-utils.sh
  source "${HARNESS_ROOT}/scripts/config-utils.sh"
  assert_eq "$(get_plans_file_path)" "plans/roadmap.md" "active plan pointer selects roadmap"
  assert_eq "$(HARNESS_PLAN_NAME=default get_plans_file_path)" "Plans.md" "env plan overrides active pointer"
)

assert_fails "unknown plan fails" bash "${HARNESS_ROOT}/scripts/plan-registry.sh" --root "${TMP_DIR}" path missing

mkdir -p "${TMP_DIR}/unsafe/plans"
cat > "${TMP_DIR}/unsafe/plans/manifest.json" <<EOF
{
  "schema_version": "plans-manifest.v1",
  "plans": {
    "abs": "/tmp/nope.md",
    "escape": "../outside.md",
    "link": "plans/link.md"
  }
}
EOF
touch "${TMP_DIR}/outside.md"
ln -s "${TMP_DIR}/outside.md" "${TMP_DIR}/unsafe/plans/link.md"
assert_fails "absolute manifest path fails" bash "${HARNESS_ROOT}/scripts/plan-registry.sh" --root "${TMP_DIR}/unsafe" path abs
assert_fails "path traversal manifest path fails" bash "${HARNESS_ROOT}/scripts/plan-registry.sh" --root "${TMP_DIR}/unsafe" path escape
assert_fails "symlink escape manifest path fails" bash "${HARNESS_ROOT}/scripts/plan-registry.sh" --root "${TMP_DIR}/unsafe" path link

(
  export HARNESS_CODEX_LOOP_SOURCE_ONLY=1
  export PROJECT_ROOT="${TMP_DIR}"
  export HARNESS_INSTALL_ROOT="${HARNESS_ROOT}"
  # shellcheck source=../scripts/codex-loop.sh
  source "${HARNESS_ROOT}/scripts/codex-loop.sh"
  assert_eq "$(HARNESS_PLAN_NAME=roadmap plans_file_path)" "${TMP_DIR}/plans/roadmap.md" "codex-loop resolves named plan to absolute file"
  assert_eq "$(next_task_id all "${TMP_DIR}/plans/roadmap.md")" "9.1.1" "codex-loop next task reads roadmap task"
)

BRIDGE_JSON="${TMP_DIR}/bridge.json"
(cd "${TMP_DIR}" && "${HARNESS_ROOT}/scripts/plans-issue-bridge.sh" --plan roadmap --format json --output "${BRIDGE_JSON}" >/dev/null)
jq -e '
  .source.plans_file | endswith("plans/roadmap.md")
' "${BRIDGE_JSON}" >/dev/null
jq -e '(.summary.task_count == 1) and (.sub_issues[0].task_id == "9.1.1")' "${BRIDGE_JSON}" >/dev/null

CONTRACT_JSON="${TMP_DIR}/9.1.1.sprint-contract.json"
(cd "${TMP_DIR}" && node "${HARNESS_ROOT}/scripts/generate-sprint-contract.js" --plan roadmap 9.1.1 "${CONTRACT_JSON}" >/dev/null)
jq -e '
  (.task.id == "9.1.1") and
  (.source.plans_file | endswith("roadmap.md"))
' "${CONTRACT_JSON}" >/dev/null

echo "test-named-plans: ok"
