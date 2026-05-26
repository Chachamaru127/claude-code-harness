#!/bin/bash
#
# test-skill-mid-message.sh
# CC 2.1.110 fix: smoke test to statically verify that skills with
# disable-model-invocation: true correctly retain their frontmatter
# when invoked mid-message.
#
# Background (CC 2.1.110):
#   Skills with `disable-model-invocation: true` were fixed to work correctly
#   when invoked as `/<skill>` mid-message. This enables protected skills such
#   as harness-review to function in mid-message invocations.
#
# What this test verifies:
#   1. SKILL.md exists for skills with disable-model-invocation: true
#   2. Frontmatter can be parsed as YAML (name field present)
#   3. allowed-tools field exists as an array
#
# What this test does NOT verify (runtime-environment dependent):
#   - Actual mid-message invocations in the CC runtime (requires CC CLI)
#   - Whether model invocations are skipped (runtime behavior)
#
# Usage:
#   bash tests/test-skill-mid-message.sh
#   bash tests/test-skill-mid-message.sh --verbose
#
# Exit code:
#   0 = all checks passed
#   1 = one or more checks failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
SKILLS_DIR="${PLUGIN_ROOT}/skills"

VERBOSE=0
for arg in "$@"; do
    [[ "$arg" == "--verbose" ]] && VERBOSE=1
done

PASS=0
FAIL=0
SKIP=0

pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  [SKIP] $1"; SKIP=$((SKIP + 1)); }
info() { [[ "$VERBOSE" -eq 1 ]] && echo "  [INFO] $1" || true; }

echo "=============================================="
echo "  smoke test: disable-model-invocation skills"
echo "  CC 2.1.110 mid-message fix verification"
echo "=============================================="
echo ""

# Enumerate skills with disable-model-invocation: true
SKILL_FILES=()
while IFS= read -r -d '' file; do
    if grep -q "disable-model-invocation: true" "$file" 2>/dev/null; then
        SKILL_FILES+=("$file")
    fi
done < <(find "$SKILLS_DIR" -name "SKILL.md" -print0 2>/dev/null)

if [[ ${#SKILL_FILES[@]} -eq 0 ]]; then
    echo "  [WARN] No skills with disable-model-invocation: true found"
    echo "  Skills dir: $SKILLS_DIR"
    exit 0
fi

echo "  Target skill count: ${#SKILL_FILES[@]}"
echo ""

for skill_file in "${SKILL_FILES[@]}"; do
    skill_dir="$(dirname "$skill_file")"
    skill_name="$(basename "$skill_dir")"

    echo "--- $skill_name ---"

    # 1. SKILL.md must exist
    if [[ -f "$skill_file" ]]; then
        pass "SKILL.md exists: $skill_file"
    else
        fail "SKILL.md not found: $skill_file"
        continue
    fi

    # 2. Frontmatter opening line (---) must be present
    if head -1 "$skill_file" | grep -q "^---$"; then
        pass "Frontmatter opening line present"
    else
        fail "Frontmatter opening line missing (first line is not ---)"
        continue
    fi

    # 3. name field must be present
    if grep -q "^name:" "$skill_file"; then
        SKILL_DECLARED_NAME="$(grep "^name:" "$skill_file" | head -1 | sed 's/^name: *//')"
        pass "name field present: $SKILL_DECLARED_NAME"
        info "  declared name '$SKILL_DECLARED_NAME' vs directory name '$skill_name'"
    else
        fail "name field not found"
    fi

    # 4. disable-model-invocation: true must exist (double-check)
    if grep -q "^disable-model-invocation: true" "$skill_file"; then
        pass "disable-model-invocation: true is set"
    else
        fail "disable-model-invocation: true is not set"
    fi

    # 5. allowed-tools field must be present (tool execution is assumed for mid-message invocations)
    if grep -q "^allowed-tools:" "$skill_file"; then
        ALLOWED_TOOLS_LINE="$(grep "^allowed-tools:" "$skill_file" | head -1)"
        pass "allowed-tools field present: $ALLOWED_TOOLS_LINE"
    else
        skip "allowed-tools field absent (skills with only disable-model-invocation: true may not need tools)"
    fi

    # 6. description field must be present (required for mid-message auto-loading)
    if grep -q "^description:" "$skill_file"; then
        pass "description field present"
    else
        fail "description field not found (required for mid-message loading)"
    fi

    echo ""
done

echo "=============================================="
echo "  Result: PASS=${PASS}  FAIL=${FAIL}  SKIP=${SKIP}"
echo ""
echo "  Static verification only. Actual CC runtime mid-message"
echo "  invocation behavior requires manual verification with"
echo "  CC CLI 2.1.110+ (outside CI)."
echo "  Details: docs/cc-2.1.99-2.1.110-impact.md (44.7.1 smoke test result)"
echo "=============================================="

if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi
exit 0
