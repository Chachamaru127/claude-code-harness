#!/usr/bin/env bash
# Phase 116.1 — independent test-wiring auditor contract tests
#
# Validates:
#   (1) artifact existence (agent, core script, schema)
#   (2) SHA pin on agents/test-wiring-auditor.md (tamper detection)
#   (3) fixed-prompt literals in agent initialPrompt
#   (4) frontmatter safety (read-only, no memory)
#   (5) test-wiring-audit.v1 schema structure
#   (6) deterministic core RED/GREEN fixture
#   (7) appeal-limit literal + schema version pin
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUDITOR="${ROOT_DIR}/agents/test-wiring-auditor.md"
CORE_SCRIPT="${ROOT_DIR}/scripts/test-wiring-audit-core.sh"
SCHEMA="${ROOT_DIR}/templates/schemas/test-wiring-audit.v1.json"

# intentional prompt changes require a human-reviewed pin update in the same PR
# (tamper detection: red-team scenario c)
AUDITOR_PROMPT_SHA256="bb68c20bb5a81976118d083bc7301efda3fb9d093d36603fc64489fdf7cb612c"

fail() {
  echo "test-test-wiring-auditor: FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local needle="$2"
  grep -Fq "$needle" "$file" || fail "missing '${needle}' in ${file}"
}

assert_not_contains() {
  local file="$1"
  local needle="$2"
  if grep -Fq "$needle" "$file"; then
    fail "forbidden '${needle}' found in ${file}"
  fi
}

# ---- (1) existence ----

[ -f "$AUDITOR" ] || fail "missing $AUDITOR"
[ -f "$CORE_SCRIPT" ] || fail "missing $CORE_SCRIPT"
[ -f "$SCHEMA" ] || fail "missing $SCHEMA"

# ---- (2) SHA pin ----

computed_sha="$(shasum -a 256 "$AUDITOR" | awk '{print $1}')"
if [[ "$computed_sha" != "$AUDITOR_PROMPT_SHA256" ]]; then
  fail "auditor prompt SHA mismatch: expected ${AUDITOR_PROMPT_SHA256}, got ${computed_sha}"
fi

# ---- (3) fixed-prompt literals ----

assert_contains "$AUDITOR" "test-wiring-audit.v1"
assert_contains "$AUDITOR" "PASS"
assert_contains "$AUDITOR" "ADD_REQUIRED"
assert_contains "$AUDITOR" "APPEAL_REJECTED"
assert_contains "$AUDITOR" "1 回"
assert_contains "$AUDITOR" "既存テストの削除・弱体化は提案しない"

# ---- (4) frontmatter safety ----

assert_contains "$AUDITOR" "Write"
assert_contains "$AUDITOR" "Edit"
assert_contains "$AUDITOR" "disallowedTools:"
assert_not_contains "$AUDITOR" "memory:"

# ---- (5) schema structure ----

if python3 - <<'PY' "$SCHEMA"
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    schema = json.load(f)

assert schema.get("$schema") == "http://json-schema.org/draft-07/schema#", "$schema must be draft-07"
assert schema.get("type") == "object", "type must be object"
assert schema.get("additionalProperties") is False, "additionalProperties must be false"

verdict = schema.get("properties", {}).get("verdict", {})
assert verdict.get("enum") == ["PASS", "ADD_REQUIRED", "APPEAL_REJECTED"], (
    f"verdict enum mismatch: {verdict.get('enum')}"
)

appeal = schema.get("properties", {}).get("appeal_round", {})
assert appeal.get("minimum") == 0, "appeal_round minimum must be 0"
assert appeal.get("maximum") == 1, "appeal_round maximum must be 1"

required = set(schema.get("required", []))
expected_required = {"schema_version", "verdict", "appeal_round", "required_tests"}
assert required == expected_required, f"required mismatch: {required} vs {expected_required}"

print("ok")
PY
then
  :
else
  fail "schema structure check failed"
fi

# ---- (6) deterministic core RED/GREEN fixture ----

if ! command -v jq >/dev/null 2>&1; then
  fail "jq is required for core script fixture tests"
fi

fixture_dir="$(mktemp -d)"
trap 'rm -rf "$fixture_dir"' EXIT

(
  cd "$fixture_dir"
  git init -q
  git config user.email "fixture@test.local"
  git config user.name "Fixture"
  echo "base" >README.md
  git add README.md
  git commit -q -m "base"

  base_ref="$(git rev-parse HEAD)"

  mkdir -p scripts
  echo '#!/usr/bin/env bash' >scripts/newfeat.sh
  echo 'echo newfeat' >>scripts/newfeat.sh
  chmod +x scripts/newfeat.sh
  git add scripts/newfeat.sh
  git commit -q -m "add product surface without tests"

  head_ref="$(git rev-parse HEAD)"

  red_json="$(bash "$CORE_SCRIPT" --repo . --base "$base_ref" --head "$head_ref")"
  echo "$red_json" | jq -e '.verdict == "ADD_REQUIRED"' >/dev/null \
    || fail "core script expected ADD_REQUIRED for product-only change (got: ${red_json})"

  mkdir -p tests
  cat >tests/test-newfeat.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "test-newfeat: ok"
EOF
  chmod +x tests/test-newfeat.sh
  git add tests/test-newfeat.sh
  git commit -q -m "add test surface"

  head_ref="$(git rev-parse HEAD)"

  green_json="$(bash "$CORE_SCRIPT" --repo . --base "$base_ref" --head "$head_ref")"
  echo "$green_json" | jq -e '.verdict == "PASS"' >/dev/null \
    || fail "core script expected PASS after test addition (got: ${green_json})"
)

# ---- (7) appeal-limit + schema version pin ----

assert_contains "$SCHEMA" "test-wiring-audit.v1"
assert_contains "$AUDITOR" "appeal_round"

echo "test-test-wiring-auditor: ok"
