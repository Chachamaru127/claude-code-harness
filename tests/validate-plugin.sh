#!/bin/bash
# Plugin validation test
# This script validates that claude-code-harness is correctly configured.
#
# Usage: ./tests/validate-plugin.sh [--quick]
#   --quick  Run only the lightweight state consistency check for harness-loop wake-up (completes in seconds)
#            Checks: .claude/state/ existence / Plans.md presence+v2 format / sprint-contract format
#            Does not run the full validation (39 items)

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# --quick option processing
QUICK_MODE=0
for arg in "$@"; do
    if [ "$arg" = "--quick" ]; then
        QUICK_MODE=1
    fi
done

# --quick mode: lightweight state consistency check only
if [ "${QUICK_MODE}" -eq 1 ]; then
    echo "=========================================="
    echo "Claude harness - Quick consistency check"
    echo "=========================================="
    echo ""
    QUICK_FAIL=0

    # (1) .claude/state/ directory existence
    if [ -d "${PLUGIN_ROOT}/.claude/state" ]; then
        echo "✓ .claude/state/ directory exists"
    else
        echo "✗ .claude/state/ directory not found"
        QUICK_FAIL=$((QUICK_FAIL + 1))
    fi

    # (2) Plans.md existence (respecting the plansDirectory setting)
    # Resolve the path via config-utils.sh get_plans_file_path() following the SSOT
    PLANS_FILE=""
    if [ -f "${PLUGIN_ROOT}/scripts/config-utils.sh" ]; then
        # Load config-utils.sh with PLUGIN_ROOT as cwd and resolve the path
        PLANS_FILE="$(
            cd "${PLUGIN_ROOT}" && \
            CONFIG_FILE="${PLUGIN_ROOT}/.claude-code-harness.config.yaml" \
            source "${PLUGIN_ROOT}/scripts/config-utils.sh" && \
            get_plans_file_path 2>/dev/null
        )" || PLANS_FILE=""
        # get_plans_file_path returns the default path even when the file does not exist; verify it
        if [ -n "${PLANS_FILE}" ] && [ ! -f "${PLUGIN_ROOT}/${PLANS_FILE}" ] && [ ! -f "${PLANS_FILE}" ]; then
            PLANS_FILE=""
        fi
        # Prepend PLUGIN_ROOT for relative paths
        if [ -n "${PLANS_FILE}" ] && [ ! -f "${PLANS_FILE}" ] && [ -f "${PLUGIN_ROOT}/${PLANS_FILE}" ]; then
            PLANS_FILE="${PLUGIN_ROOT}/${PLANS_FILE}"
        fi
    fi
    # Fallback: check repository root when config-utils.sh is unavailable
    if [ -z "${PLANS_FILE}" ]; then
        for f in Plans.md plans.md PLANS.md; do
            if [ -f "${PLUGIN_ROOT}/${f}" ]; then
                PLANS_FILE="${PLUGIN_ROOT}/${f}"
                break
            fi
        done
    fi
    if [ -n "${PLANS_FILE}" ]; then
        echo "✓ Plans.md exists: ${PLANS_FILE}"
    else
        echo "✗ Plans.md not found"
        QUICK_FAIL=$((QUICK_FAIL + 1))
    fi

    # (3) Verify Plans.md v2 format (DoD / Depends columns)
    if [ -n "${PLANS_FILE}" ]; then
        if grep -q "DoD" "${PLANS_FILE}" && grep -q "Depends" "${PLANS_FILE}"; then
            echo "✓ Plans.md is in v2 format (DoD / Depends columns present)"
        else
            echo "✗ Plans.md is not in v2 format (DoD or Depends column missing)"
            QUICK_FAIL=$((QUICK_FAIL + 1))
        fi
    fi

    # (4) If sprint-contract exists, only verify it is parseable as JSON (syntax-only)
    # --quick is intended to detect state corruption. Approval status checks are performed
    # individually per contract by the wake-up flow (ensure-sprint-contract-ready.sh).
    # Checking all contracts against an approved whitelist would stop wake-up whenever any
    # draft/pending contract exists (excessively broad scope).
    CONTRACT_DIR="${PLUGIN_ROOT}/.claude/state/contracts"
    if [ -d "${CONTRACT_DIR}" ]; then
        contract_error=0

        # jq fallback: jq → python3 → skip (avoid false failures on macOS bare environments without jq)
        if command -v jq >/dev/null 2>&1; then
            _JSON_PARSER="jq"
        elif command -v python3 >/dev/null 2>&1; then
            _JSON_PARSER="python3"
        else
            _JSON_PARSER="skip"
            echo "⚠ Neither jq nor python3 is available; skipping contract syntax check"
        fi

        _check_json_syntax() {
            local file="$1"
            case "${_JSON_PARSER}" in
                jq)     jq empty "${file}" 2>/dev/null ;;
                python3) python3 -c "import json,sys; json.load(open(sys.argv[1]))" "${file}" 2>/dev/null ;;
                skip)   return 0 ;;
            esac
        }

        while IFS= read -r contract_file; do
            [ ! -f "${contract_file}" ] && continue

            # Syntax check only (approval status is checked per contract in wake-up Step 3)
            if ! _check_json_syntax "${contract_file}"; then
                echo "✗ Broken JSON: $(basename "${contract_file}")"
                contract_error=$((contract_error + 1))
            fi
        done < <(find "${CONTRACT_DIR}" -name "*.sprint-contract.json" -type f 2>/dev/null)

        if [ "${contract_error}" -eq 0 ]; then
            echo "✓ sprint-contract format check passed"
        else
            QUICK_FAIL=$((QUICK_FAIL + contract_error))
        fi
    else
        echo "✓ sprint-contract directory not yet created (first run)"
    fi

    echo ""
    if [ "${QUICK_FAIL}" -eq 0 ]; then
        echo "✓ Quick consistency check: OK"
        exit 0
    else
        echo "✗ Quick consistency check: ${QUICK_FAIL} issue(s) found"
        exit 1
    fi
fi

echo "=========================================="
echo "Claude harness - Plugin validation test"
echo "=========================================="
echo ""

# Color output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# Record test results
pass_test() {
    echo -e "${GREEN}✓${NC} $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail_test() {
    echo -e "${RED}✗${NC} $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

warn_test() {
    echo -e "${YELLOW}⚠${NC} $1"
    WARN_COUNT=$((WARN_COUNT + 1))
}

json_is_valid() {
    local file="$1"
    python3 - <<'PY' "$file" >/dev/null 2>&1
import json, sys
path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    json.load(f)
PY
}

json_has_key() {
    local file="$1"
    local key="$2"
    python3 - <<'PY' "$file" "$key" >/dev/null 2>&1
import json, sys
path, key = sys.argv[1], sys.argv[2]
with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)
if key not in data:
    raise SystemExit(1)
PY
}

has_frontmatter_description() {
    local file="$1"
    # Check that frontmatter exists and contains description:
    awk '
      NR==1 { if ($0 != "---") exit 1 }
      NR>1 && $0=="---" { exit 2 }  # end of frontmatter without description
      NR>1 && $0 ~ /^description:/ { exit 0 }
      NR>50 { exit 1 }              # safety
    ' "$file"
}

echo "1. Plugin structure validation"
echo "----------------------------------------"

# Check plugin.json exists
if [ -f "$PLUGIN_ROOT/.claude-plugin/plugin.json" ]; then
    pass_test "plugin.json exists"
else
    fail_test "plugin.json not found"
    exit 1
fi

# Validate plugin.json
if json_is_valid "$PLUGIN_ROOT/.claude-plugin/plugin.json"; then
    pass_test "plugin.json is valid JSON"
else
    fail_test "plugin.json is invalid JSON"
    exit 1
fi

# Check required fields
REQUIRED_FIELDS=("name" "version" "description" "author")
for field in "${REQUIRED_FIELDS[@]}"; do
    if json_has_key "$PLUGIN_ROOT/.claude-plugin/plugin.json" "$field"; then
        pass_test "plugin.json has $field field"
    else
        fail_test "plugin.json is missing $field field"
    fi
done

echo ""
echo "2. Command validation (legacy)"
echo "----------------------------------------"

# v2.17.0+: commands have been migrated to Skills
# Validate only when the commands/ directory exists (backward compatibility)
if [ -d "$PLUGIN_ROOT/commands" ]; then
    CMD_COUNT=$(find "$PLUGIN_ROOT/commands" -name "*.md" -type f | wc -l | tr -d ' ')
    pass_test "commands/ has ${CMD_COUNT} command file(s) (legacy)"

    # Show subdirectory structure
    for subdir in "$PLUGIN_ROOT/commands"/*/; do
        if [ -d "$subdir" ]; then
            subdir_name=$(basename "$subdir")
            subdir_count=$(find "$subdir" -name "*.md" -type f | wc -l | tr -d ' ')
            if [ "$subdir_count" -gt 0 ]; then
                pass_test "  └─ ${subdir_name}/ has ${subdir_count} command(s)"
            else
                warn_test "  └─ ${subdir_name}/ is empty (no command files)"
            fi
        fi
    done

    # Check frontmatter description (improves discoverability in SlashCommand tool / /help)
    MISSING_DESC=0
    while IFS= read -r cmd_file; do
        if has_frontmatter_description "$cmd_file"; then
            pass_test "frontmatter description: $(basename "$cmd_file")"
        else
            warn_test "frontmatter description not found: $(basename "$cmd_file")"
            MISSING_DESC=$((MISSING_DESC + 1))
        fi
    done < <(find "$PLUGIN_ROOT/commands" -name "*.md" -type f | sort)
else
    # v2.17.0+: commands/ is no longer needed as commands have migrated to Skills
    pass_test "commands/ has been migrated to Skills (v2.17.0+)"
fi

echo ""
echo "3. Skill validation"
echo "----------------------------------------"

# Check that SKILL.md exists under the skills path specified in plugin.json (v4.0.3 regression guard)
# Prevents a repeat of incidents where misconfiguration like skills: ["./"] caused 0 skills to load.
# Actually traverse the directory pointed to by the skills field in plugin.json and verify SKILL.md exists.
skills_path_check_output=$(python3 - "$PLUGIN_ROOT/.claude-plugin/plugin.json" "$PLUGIN_ROOT" <<'PY' 2>&1
import json
import os
import sys

manifest_path, plugin_root = sys.argv[1], sys.argv[2]
with open(manifest_path, "r", encoding="utf-8") as fh:
    manifest = json.load(fh)

skills_field = manifest.get("skills", "./skills/")
if isinstance(skills_field, str):
    paths = [skills_field]
elif isinstance(skills_field, list):
    paths = skills_field
else:
    print("skills field must be string or array of strings", file=sys.stderr)
    sys.exit(2)

errors = []
details = []
for entry in paths:
    resolved = os.path.normpath(os.path.join(plugin_root, entry))
    if not os.path.isdir(resolved):
        errors.append(f"path does not exist: {entry}")
        continue
    count = 0
    for dirpath, _dirnames, filenames in os.walk(resolved):
        if "SKILL.md" in filenames:
            count += 1
    if count == 0:
        errors.append(f"no SKILL.md found under: {entry}")
    else:
        details.append(f"{entry} -> {count} skills")

if errors:
    for err in errors:
        print(err, file=sys.stderr)
    sys.exit(1)

print(", ".join(details))
PY
)
skills_path_check_status=$?

if [ $skills_path_check_status -eq 0 ]; then
    pass_test "SKILL.md exists under the skills path in plugin.json ($skills_path_check_output)"
else
    fail_test "SKILL.md not found under the skills path in plugin.json: $skills_path_check_output"
fi

# Skills directory existence
if [ -d "$PLUGIN_ROOT/skills" ]; then
    SKILL_COUNT=$(find "$PLUGIN_ROOT/skills" -name "SKILL.md" | wc -l)
    pass_test "$SKILL_COUNT skill(s) defined"

    # Check skill frontmatter (sample)
    SKILLS_WITH_DESCRIPTION=0
    SKILLS_WITH_ALLOWED_TOOLS=0
    
    find "$PLUGIN_ROOT/skills" -name "SKILL.md" | while read -r skill_file; do
        if grep -q "^description:" "$skill_file"; then
            ((SKILLS_WITH_DESCRIPTION++))
        fi
        if grep -q "^allowed-tools:" "$skill_file"; then
            ((SKILLS_WITH_ALLOWED_TOOLS++))
        fi
    done
    
    if [ $SKILL_COUNT -gt 0 ]; then
        pass_test "Skill files are properly placed"
    fi
else
    warn_test "skills directory not found"
fi

echo ""
echo "4. Agent validation"
echo "----------------------------------------"

if [ -d "$PLUGIN_ROOT/agents" ]; then
    AGENT_COUNT=$(find "$PLUGIN_ROOT/agents" -name "*.md" | wc -l)
    if [ $AGENT_COUNT -gt 0 ]; then
        pass_test "$AGENT_COUNT agent(s) defined"
    else
        warn_test "No agents defined"
    fi
    IGNORED_AGENT_FIELDS=$(grep -rnE "^(permissionMode|hooks):" "$PLUGIN_ROOT/agents"/*.md 2>/dev/null || true)
    if [ -n "$IGNORED_AGENT_FIELDS" ]; then
        fail_test "Ignored frontmatter fields remain in plugin agent"
        echo "$IGNORED_AGENT_FIELDS" | sed 's/^/  /'
    else
        pass_test "No ignored permissionMode/hooks frontmatter in plugin agent"
    fi
else
    warn_test "agents directory not found"
fi

echo ""
echo "5. Hook validation"
echo "----------------------------------------"

if [ -f "$PLUGIN_ROOT/hooks/hooks.json" ]; then
    if json_is_valid "$PLUGIN_ROOT/hooks/hooks.json"; then
        pass_test "hooks.json is valid JSON"

        pass_test "hooks.json is readable"
    else
        fail_test "hooks.json is invalid JSON"
    fi
else
    warn_test "hooks.json not found"
fi

POST_TOOL_FAILURE="$PLUGIN_ROOT/scripts/hook-handlers/post-tool-failure.sh"
if [ -f "$POST_TOOL_FAILURE" ]; then
    tmp_dir="$(mktemp -d)"
    target_file="$tmp_dir/target.txt"
    mkdir -p "$tmp_dir/.claude/state"
    printf 'SAFE\n' > "$target_file"
    ln -s "$target_file" "$tmp_dir/.claude/state/tool-failure-counter.txt"

    hook_output="$(printf '{"tool_name":"Bash","error":"boom"}' | PROJECT_ROOT="$tmp_dir" bash "$POST_TOOL_FAILURE" 2>/dev/null || true)"
    target_after="$(cat "$target_file" 2>/dev/null || true)"

    if [ "$hook_output" = "{}" ] && [ "$target_after" = "SAFE" ]; then
        pass_test "post-tool-failure.sh does not overwrite symlink state file"
    else
        fail_test "post-tool-failure.sh is missing symlink defense"
    fi

    rm -rf "$tmp_dir"
fi

MEMORY_WRAPPERS=(
    "$PLUGIN_ROOT/scripts/lib/harness-mem-bridge.sh"
    "$PLUGIN_ROOT/scripts/hook-handlers/memory-bridge.sh"
    "$PLUGIN_ROOT/scripts/hook-handlers/memory-session-start.sh"
    "$PLUGIN_ROOT/scripts/hook-handlers/memory-user-prompt.sh"
    "$PLUGIN_ROOT/scripts/hook-handlers/memory-post-tool-use.sh"
    "$PLUGIN_ROOT/scripts/hook-handlers/memory-stop.sh"
    "$PLUGIN_ROOT/scripts/hook-handlers/memory-codex-notify.sh"
)
for wrapper in "${MEMORY_WRAPPERS[@]}"; do
    if [ -f "$wrapper" ]; then
        pass_test "memory wrapper exists: $(basename "$wrapper")"
    else
        fail_test "memory wrapper not found: $wrapper"
    fi
done

if bash "$PLUGIN_ROOT/tests/test-memory-hook-wiring.sh" >/dev/null 2>&1; then
    pass_test "memory hook wiring is valid"
else
    fail_test "memory hook wiring is broken"
fi

if bash "$PLUGIN_ROOT/tests/test-sync-plugin-cache.sh" >/dev/null 2>&1; then
    pass_test "sync-plugin-cache can sync memory wrapper to distribution cache"
else
    fail_test "sync-plugin-cache cannot sync memory wrapper to distribution cache"
fi

if bash "$PLUGIN_ROOT/tests/test-runtime-reactive-hooks.sh" >/dev/null 2>&1; then
    pass_test "reactive hook runtime (TaskCreated/FileChanged/CwdChanged) is working"
else
    fail_test "reactive hook runtime (TaskCreated/FileChanged/CwdChanged) has issues"
fi

if bash "$PLUGIN_ROOT/tests/test-claude-upstream-integration.sh" >/dev/null 2>&1; then
    pass_test "Claude Code 2.1.80-2.1.86 integration points are wired"
else
    fail_test "Claude Code 2.1.80-2.1.86 integration points have gaps"
fi

if bash "$PLUGIN_ROOT/tests/test-plans-status-markers.sh" >/dev/null 2>&1; then
    pass_test "Plans.md status marker protocol compatibility is maintained"
else
    fail_test "Plans.md status marker protocol compatibility has issues"
fi

if bash "$PLUGIN_ROOT/tests/test-named-plans.sh" >/dev/null 2>&1; then
    pass_test "Named Plans registry safely resolves manifest / active pointer / --plan"
else
    fail_test "Named Plans registry contract test failed — run 'bash tests/test-named-plans.sh' for details"
fi

echo ""
echo "6. Script validation"
echo "----------------------------------------"

if [ -d "$PLUGIN_ROOT/scripts" ]; then
    SCRIPT_COUNT=$(find "$PLUGIN_ROOT/scripts" -name "*.sh" -type f \
        ! -path "$PLUGIN_ROOT/scripts/lib/*" \
        ! -name "config-utils.sh" | wc -l)
    if [ $SCRIPT_COUNT -gt 0 ]; then
        pass_test "$SCRIPT_COUNT executable target script(s) exist"

        # Check execute permissions (GNU/BSD compatible: use -perm -111)
        # Exclude scripts/lib/* and config-utils.sh as they are sourced libraries.
        EXECUTABLE_COUNT=$(find "$PLUGIN_ROOT/scripts" -name "*.sh" -type f \
            ! -path "$PLUGIN_ROOT/scripts/lib/*" \
            ! -name "config-utils.sh" \
            -perm -111 | wc -l | tr -d ' ')
        if [ $EXECUTABLE_COUNT -eq $SCRIPT_COUNT ]; then
            pass_test "All executable target scripts have execute permission"
        else
            warn_test "Some executable target scripts are missing execute permission ($EXECUTABLE_COUNT/$SCRIPT_COUNT)"
        fi
    else
        warn_test "No scripts found"
    fi
else
    warn_test "scripts directory not found"
fi

echo ""
echo "7. Documentation validation"
echo "----------------------------------------"

if [ -f "$PLUGIN_ROOT/README.md" ]; then
    README_SIZE=$(wc -c < "$PLUGIN_ROOT/README.md")
    if [ $README_SIZE -gt 1000 ]; then
        pass_test "README.md exists (${README_SIZE} bytes)"
    else
        warn_test "README.md is too brief (${README_SIZE} bytes)"
    fi
else
    fail_test "README.md not found"
fi

if [ -f "$PLUGIN_ROOT/IMPLEMENTATION_GUIDE.md" ]; then
    pass_test "IMPLEMENTATION_GUIDE.md exists"
else
    warn_test "IMPLEMENTATION_GUIDE.md not found (recommended)"
fi

echo ""
echo "7. Claude Code plugin validation (v2.1.77+)"
echo "----------------------------------------"

# Run only when the claude command is available
if command -v claude > /dev/null 2>&1; then
    # Check that the subcommand exists (plugin validate is not available below v2.1.77)
    if claude plugin validate --help > /dev/null 2>&1; then
        if claude plugin validate "$PLUGIN_ROOT/.claude-plugin/plugin.json" > /dev/null 2>&1; then
            pass_test "claude plugin validate passed"
        else
            fail_test "claude plugin validate reported an error (CC v2.1.77+ required)"
        fi
    else
        warn_test "claude plugin validate is not supported (update to CC v2.1.77+ recommended)"
    fi
else
    warn_test "claude command is not installed (skipping claude plugin validate)"
fi

if bash "$PLUGIN_ROOT/tests/test-distribution-archive.sh" >/dev/null 2>&1; then
    pass_test "git archive distribution payload does not include development-only files"
else
    fail_test "git archive distribution payload contains development-only files — run 'bash tests/test-distribution-archive.sh' for details"
fi

if bash "$PLUGIN_ROOT/tests/test-public-plugin-inventory.sh" >/dev/null 2>&1; then
    pass_test "No private skills are exposed in local plugin inventory"
else
    fail_test "Private skills are exposed in local plugin inventory — run 'bash tests/test-public-plugin-inventory.sh' for details"
fi

echo ""
echo "8. Hardening parity validation"
echo "----------------------------------------"

HARDENING_DOC="$PLUGIN_ROOT/docs/hardening-parity.md"
HARDENING_CONTRACT="$PLUGIN_ROOT/scripts/lib/codex-hardening-contract.txt"
if [ -f "$HARDENING_DOC" ]; then
    pass_test "hardening parity document exists"
else
    fail_test "docs/hardening-parity.md not found"
fi

if [ -f "$HARDENING_CONTRACT" ] && grep -q "HARNESS_HARDENING_CONTRACT_V1" "$HARDENING_CONTRACT"; then
    pass_test "Codex hardening contract template exists"
else
    fail_test "scripts/lib/codex-hardening-contract.txt not found"
fi

if grep -q "docs/hardening-parity.md" "$PLUGIN_ROOT/README.md"; then
    pass_test "README.md links to hardening parity document"
else
    fail_test "README.md is missing link to hardening parity document"
fi

RULES_FILE="$PLUGIN_ROOT/go/internal/guardrail/rules.go"
RULE_IDS=(
    "R10:no-git-bypass-flags"
    "R11:no-reset-hard-protected-branch"
    "R12:confirm-direct-push-protected-branch"
    "R13:warn-protected-review-paths"
)
for rule_id in "${RULE_IDS[@]}"; do
    if grep -q "$rule_id" "$RULES_FILE"; then
        pass_test "guardrail rule: $rule_id"
    else
        fail_test "guardrail rule not found: $rule_id"
    fi
done

# scripts/codex/ is archived — skip Codex wrapper/engine/gate hardening checks

echo ""
echo "9. Migration residue check"
echo "----------------------------------------"

if bash "$PLUGIN_ROOT/scripts/check-residue.sh" > /dev/null 2>&1; then
    pass_test "No migration residue detected (scripts/check-residue.sh clean)"
else
    fail_test "Migration residue found — run 'bash scripts/check-residue.sh' to see details"
fi

echo ""
echo "10. Optional integration tests"
echo "----------------------------------------"

INTEGRATION_PASS_COUNT=0
INTEGRATION_FAIL_COUNT=0
INTEGRATION_WARN_COUNT=0

integration_pass_test() {
    echo -e "${GREEN}✓${NC} $1"
    INTEGRATION_PASS_COUNT=$((INTEGRATION_PASS_COUNT + 1))
}

integration_fail_test() {
    echo -e "${YELLOW}⚠${NC} $1"
    INTEGRATION_FAIL_COUNT=$((INTEGRATION_FAIL_COUNT + 1))
}

integration_warn_test() {
    echo -e "${YELLOW}⚠${NC} $1"
    INTEGRATION_WARN_COUNT=$((INTEGRATION_WARN_COUNT + 1))
}

INTEGRATION_TESTS=(
    "$PLUGIN_ROOT/tests/integration/loop-3cycle.sh"
    "$PLUGIN_ROOT/tests/integration/loop-compaction-resume.sh"
    "$PLUGIN_ROOT/tests/integration/loop-max-cycles.sh"
    "$PLUGIN_ROOT/tests/integration/loop-plans-concurrent.sh"
)

INTEGRATION_TMP_DIR="$(mktemp -d)"
INTEGRATION_PIDS=()
INTEGRATION_NAMES=()
INTEGRATION_LOGS=()

for integration_test in "${INTEGRATION_TESTS[@]}"; do
    if [ ! -f "$integration_test" ]; then
        integration_warn_test "optional integration test not found: $(basename "$integration_test")"
        continue
    fi

    if [ ! -x "$integration_test" ]; then
        integration_warn_test "optional integration test is not executable: $(basename "$integration_test")"
        continue
    fi

    integration_log_file="${INTEGRATION_TMP_DIR}/$(basename "$integration_test").log"
    bash "$integration_test" >"$integration_log_file" 2>&1 &
    INTEGRATION_PIDS+=("$!")
    INTEGRATION_NAMES+=("$(basename "$integration_test")")
    INTEGRATION_LOGS+=("$integration_log_file")
done

for i in "${!INTEGRATION_PIDS[@]}"; do
    if wait "${INTEGRATION_PIDS[$i]}"; then
        integration_pass_test "integration: ${INTEGRATION_NAMES[$i]}"
    else
        integration_fail_test "integration: ${INTEGRATION_NAMES[$i]}"
        if [ -f "${INTEGRATION_LOGS[$i]}" ]; then
            sed -n '1,160p' "${INTEGRATION_LOGS[$i]}"
        fi
    fi
done

rm -rf "$INTEGRATION_TMP_DIR" 2>/dev/null || true

echo ""
echo "Optional integration summary"
echo "----------------------------------------"
echo "Passed: ${INTEGRATION_PASS_COUNT}"
echo "Failed: ${INTEGRATION_FAIL_COUNT}"
echo "Warnings: ${INTEGRATION_WARN_COUNT}"

echo ""
echo "11. Sync idempotent check"
echo "----------------------------------------"

if bash "$PLUGIN_ROOT/tests/test-sync-idempotent.sh" > /dev/null 2>&1; then
    pass_test "harness sync is idempotent and does not output phantom fields (test-sync-idempotent.sh)"
else
    fail_test "harness sync idempotency test failed — run 'bash tests/test-sync-idempotent.sh' for details"
fi

if bash "$PLUGIN_ROOT/tests/test-reenter-worktree-json.sh" > /dev/null 2>&1; then
    pass_test "reenter-worktree.sh outputs only JSON to stdout (test-reenter-worktree-json.sh)"
else
    fail_test "reenter-worktree.sh JSON output contract test failed — run 'bash tests/test-reenter-worktree-json.sh' for details"
fi

if bash "$PLUGIN_ROOT/tests/test-statusline-harness-fields.sh" > /dev/null 2>&1; then
    pass_test "statusline-harness.sh displays effort/thinking in a null-safe manner (test-statusline-harness-fields.sh)"
else
    fail_test "statusline-harness.sh effort/thinking contract test failed — run 'bash tests/test-statusline-harness-fields.sh' for details"
fi

# test-codex-primary-environment-guard.sh is archived with the Codex runtime
if [ -f "$PLUGIN_ROOT/tests/test-codex-primary-environment-guard.sh" ]; then
    if bash "$PLUGIN_ROOT/tests/test-codex-primary-environment-guard.sh" > /dev/null 2>&1; then
        pass_test "Codex primary environment guard prevents non-primary writes (test-codex-primary-environment-guard.sh)"
    else
        fail_test "Codex primary environment guard contract test failed — run 'bash tests/test-codex-primary-environment-guard.sh' for details"
    fi
fi

if bash "$PLUGIN_ROOT/tests/test-windows-worktree-support.sh" > /dev/null 2>&1; then
    pass_test "Windows Breezing worktree support distribution and hook contract is maintained (test-windows-worktree-support.sh)"
else
    fail_test "Windows Breezing worktree support contract test failed — run 'bash tests/test-windows-worktree-support.sh' for details"
fi

if bash "$PLUGIN_ROOT/tests/test-worktree-create-hook.sh" > /dev/null 2>&1; then
    pass_test "WorktreeCreate shell hook does not treat decision JSON as cwd (test-worktree-create-hook.sh)"
else
    fail_test "WorktreeCreate shell hook cwd defense test failed — run 'bash tests/test-worktree-create-hook.sh' for details"
fi

if bash "$PLUGIN_ROOT/tests/test-session-inbox-broadcast.sh" > /dev/null 2>&1; then
    pass_test "session inbox/broadcast prevents stale notification re-display and stale cwd writes (test-session-inbox-broadcast.sh)"
else
    fail_test "session inbox/broadcast stale notification contract test failed — run 'bash tests/test-session-inbox-broadcast.sh' for details"
fi

if bash "$PLUGIN_ROOT/tests/test-render-html.sh" > /dev/null 2>&1; then
    pass_test "render-html.sh satisfies mustache expansion and Claude Harness palette validation (test-render-html.sh)"
else
    fail_test "render-html.sh contract test failed — run 'bash tests/test-render-html.sh' for details"
fi

if bash "$PLUGIN_ROOT/tests/test-plan-brief-e2e.sh" > /dev/null 2>&1; then
    pass_test "harness-plan-brief Phase 65.1.x 5-step e2e pipeline round-trips successfully (test-plan-brief-e2e.sh)"
else
    fail_test "harness-plan-brief e2e contract test failed — run 'bash tests/test-plan-brief-e2e.sh' for details"
fi

if bash "$PLUGIN_ROOT/tests/test-plan-accept-flow-e2e.sh" > /dev/null 2>&1; then
    pass_test "Phase 65.2.x Plan→Accept flow e2e joins full plan→accept trace with user_request_hash (test-plan-accept-flow-e2e.sh)"
else
    fail_test "Plan→Accept flow e2e contract test failed — run 'bash tests/test-plan-accept-flow-e2e.sh' for details"
fi

if bash "$PLUGIN_ROOT/tests/test-cross-project-groups-schema.sh" > /dev/null 2>&1; then
    pass_test "Phase 65.3.1 cross-project-group.v1 schema validator correctly parses and validates yaml SSOT (test-cross-project-groups-schema.sh)"
else
    fail_test "cross-project-groups-schema contract test failed — run 'bash tests/test-cross-project-groups-schema.sh' for details"
fi

if bash "$PLUGIN_ROOT/tests/test-redact-by-dictionary.sh" > /dev/null 2>&1; then
    pass_test "Phase 65.3.2 Layer 2a dictionary-based proper noun redaction (PiiRule compatible + double-replace guard) works (test-redact-by-dictionary.sh)"
else
    fail_test "redact-by-dictionary contract test failed — run 'bash tests/test-redact-by-dictionary.sh' for details"
fi

if bash "$PLUGIN_ROOT/tests/test-redact-by-ner.sh" > /dev/null 2>&1; then
    pass_test "Phase 65.3.3 Layer 2b NER (fugashi tokenizer + fail-open + sentinel guard) works (test-redact-by-ner.sh)"
else
    fail_test "redact-by-ner contract test failed — run 'bash tests/test-redact-by-ner.sh' for details"
fi

if bash "$PLUGIN_ROOT/tests/test-render-html-redaction.sh" > /dev/null 2>&1; then
    pass_test "Phase 65.3.4 render-html.sh --with-redaction applies dict→NER→Layer3 sequentially and aborts HTML generation when residue is detected (test-render-html-redaction.sh)"
else
    fail_test "render-html-redaction contract test failed — run 'bash tests/test-render-html-redaction.sh' for details"
fi

if bash "$PLUGIN_ROOT/tests/test-cross-project-flag.sh" > /dev/null 2>&1; then
    pass_test "Phase 65.3.5 --cross-project-group flag is integrated into plan-brief / accept skill and works with D43 Option alpha (MCP N-call) (test-cross-project-flag.sh)"
else
    fail_test "cross-project-flag contract test failed — run 'bash tests/test-cross-project-flag.sh' for details"
fi

if bash "$PLUGIN_ROOT/tests/test-cross-project-audit.sh" > /dev/null 2>&1; then
    pass_test "Phase 65.3.6 cross-project-audit.v1 audit log append + HTML audit summary display + no raw query logging (test-cross-project-audit.sh)"
else
    fail_test "cross-project-audit contract test failed — run 'bash tests/test-cross-project-audit.sh' for details"
fi

if bash "$PLUGIN_ROOT/tests/test-cross-project-redaction-e2e.sh" > /dev/null 2>&1; then
    pass_test "Phase 65.3.7 e2e: 3 member group + dict + NER + Layer 3 + audit + envelope + sentinel guard works consistently (test-cross-project-redaction-e2e.sh)"
else
    fail_test "cross-project-redaction-e2e contract test failed — run 'bash tests/test-cross-project-redaction-e2e.sh' for details"
fi

if bash "$PLUGIN_ROOT/tests/test-harness-progress.sh" > /dev/null 2>&1; then
    pass_test "Phase 65.4.1 progress-snapshot.v1 + harness-progress skill generates progress HTML from Plans.md (test-harness-progress.sh)"
else
    fail_test "harness-progress contract test failed — run 'bash tests/test-harness-progress.sh' for details"
fi

if bash "$PLUGIN_ROOT/tests/test-progress-regen.sh" > /dev/null 2>&1; then
    pass_test "Phase 65.4.2 PostToolUse hook auto-regeneration + 60-second rate limit + dual hooks.json sync works (test-progress-regen.sh)"
else
    fail_test "progress-regen contract test failed — run 'bash tests/test-progress-regen.sh' for details"
fi

if bash "$PLUGIN_ROOT/tests/test-progress-drift.sh" > /dev/null 2>&1; then
    pass_test "Phase 65.4.3 drift detection fires 5 alert kinds (scope-creep/time-overrun/repeated-failure/cost-warning/high-risk-file) (test-progress-drift.sh)"
else
    fail_test "progress-drift contract test failed — run 'bash tests/test-progress-drift.sh' for details"
fi

if bash "$PLUGIN_ROOT/tests/test-progress-past-judgments.sh" > /dev/null 2>&1; then
    pass_test "Phase 65.4.4 past judgment lookup returns rejection_rate_pct + top_3_judgments with cross-project default OFF (test-progress-past-judgments.sh)"
else
    fail_test "progress-past-judgments contract test failed — run 'bash tests/test-progress-past-judgments.sh' for details"
fi

if bash "$PLUGIN_ROOT/tests/test-progress-e2e.sh" > /dev/null 2>&1; then
    pass_test "Phase 65.4.5 e2e: initial snapshot → regenerate after edit → 5 alerts fire → past judgments shown → rate limit works consistently (test-progress-e2e.sh)"
else
    fail_test "progress-e2e contract test failed — run 'bash tests/test-progress-e2e.sh' for details"
fi

if bash "$PLUGIN_ROOT/tests/test-3-surface-e2e.sh" > /dev/null 2>&1; then
    pass_test "Phase 65.5.1 integrated e2e: 3 surfaces (plan-brief / progress / accept) complete trace with same user_request_hash + project (test-3-surface-e2e.sh)"
else
    fail_test "3-surface-e2e contract test failed — run 'bash tests/test-3-surface-e2e.sh' for details"
fi

if bash "$PLUGIN_ROOT/tests/test-audit-ui-presence.sh" > /dev/null 2>&1; then
    pass_test "Phase 65.5.2 audit UI: all 3 HTML templates have audit-trail section + 4 items (search scope/ref ID/redact/log) (test-audit-ui-presence.sh)"
else
    fail_test "audit-ui-presence contract test failed — run 'bash tests/test-audit-ui-presence.sh' for details"
fi

echo ""
echo "12. TDD compliance check (local trial)"
echo "----------------------------------------"

TDD_PATHS_FILE="$PLUGIN_ROOT/.claude/rules/tdd-paths.yaml"
TDD_DETECT_SCRIPT="$PLUGIN_ROOT/scripts/detect-test-framework.sh"
TDD_LOG_SCRIPT="$PLUGIN_ROOT/scripts/log-tdd-red.sh"
SPRINT_CONTRACT_GO="$PLUGIN_ROOT/go/internal/hookhandler/sprint_contract.go"
TDD_LOCAL_TRIAL_TEST="$PLUGIN_ROOT/tests/test-tdd-enforcement-l1l2l4.sh"
CODEX_HARNESS_WORK_SKILL="$PLUGIN_ROOT/skills-codex/harness-work/SKILL.md"
CODEX_HARNESS_WORK_MIRROR="$PLUGIN_ROOT/codex/.codex/skills/harness-work/SKILL.md"

if [ -f "$TDD_PATHS_FILE" ] &&
    grep -q "schema_version: tdd-paths.v1" "$TDD_PATHS_FILE" &&
    grep -q "languages:" "$TDD_PATHS_FILE" &&
    grep -q "src_patterns:" "$TDD_PATHS_FILE" &&
    grep -q "test_patterns:" "$TDD_PATHS_FILE"; then
    pass_test "TDD path SSOT has the expected tdd-paths.v1 shape"
else
    fail_test ".claude/rules/tdd-paths.yaml is missing or malformed"
fi

if [ -x "$TDD_DETECT_SCRIPT" ]; then
    tmp_tdd_detect_dir="$(mktemp -d)"
    printf 'module example.com/tdd\n' > "$tmp_tdd_detect_dir/go.mod"
    tdd_detect_output="$(bash "$TDD_DETECT_SCRIPT" --project-root "$tmp_tdd_detect_dir" 2>/dev/null || true)"
    rm -rf "$tmp_tdd_detect_dir" 2>/dev/null || true
    if printf '%s' "$tdd_detect_output" | python3 -c 'import json,sys; data=json.load(sys.stdin); raise SystemExit(0 if data.get("framework") == "go" and data.get("command") == "go test ./..." else 1)' 2>/dev/null; then
        pass_test "detect-test-framework.sh emits usable framework JSON"
    else
        fail_test "detect-test-framework.sh did not detect a Go framework fixture"
    fi
else
    fail_test "scripts/detect-test-framework.sh is missing or not executable"
fi

if [ -x "$TDD_LOG_SCRIPT" ]; then
    tmp_tdd_log_dir="$(mktemp -d)"
    if PROJECT_ROOT="$tmp_tdd_log_dir" bash "$TDD_LOG_SCRIPT" --task-id validate-tdd --test-file tests/tdd_test.go --exit-code 1 --framework go >/dev/null 2>&1 &&
        python3 - "$tmp_tdd_log_dir/.claude/state/tdd-red-log/validate-tdd.jsonl" <<'PY' >/dev/null 2>&1
import json
import sys
with open(sys.argv[1], "r", encoding="utf-8") as f:
    data = json.loads(f.readline())
if data.get("task_id") != "validate-tdd" or data.get("test_file") != "tests/tdd_test.go" or data.get("exit_code") != 1:
    raise SystemExit(1)
PY
    then
        pass_test "log-tdd-red.sh writes the shared red-log JSONL signal"
    else
        fail_test "log-tdd-red.sh did not write a valid red-log JSONL fixture"
    fi
    rm -rf "$tmp_tdd_log_dir" 2>/dev/null || true
else
    fail_test "scripts/log-tdd-red.sh is missing or not executable"
fi

CONTRACT_TDD_STRINGS=(
    "tdd_required"
    "test_framework"
    "test_todo_list"
    "skip_tdd_reason"
    "[tdd:required]"
    "[tdd:skip:"
    "no-test-framework-detected"
    "docs-only"
)
for needle in "${CONTRACT_TDD_STRINGS[@]}"; do
    if grep -Fq "$needle" "$SPRINT_CONTRACT_GO"; then
        pass_test "sprint-contract TDD contract string: $needle"
    else
        fail_test "sprint-contract TDD contract string missing: $needle"
    fi
done

CODEX_TDD_WORK_STRINGS=(
    "--tdd-bypass"
    "log-tdd-red.sh"
    "HARNESS_TDD_BYPASS_REASON"
)
# skills-codex/ and codex/.codex/ are archived — skip missing Codex harness-work checks
for file in "$CODEX_HARNESS_WORK_SKILL" "$CODEX_HARNESS_WORK_MIRROR"; do
    if [ -f "$file" ]; then
        if grep -Eq '^argument-hint: .*--tdd-bypass' "$file"; then
            pass_test "Codex harness-work argument-hint exposes --tdd-bypass in $(basename "$(dirname "$file")")/$(basename "$file")"
        else
            fail_test "Codex harness-work argument-hint missing --tdd-bypass in $file"
        fi
        for needle in "${CODEX_TDD_WORK_STRINGS[@]}"; do
            if grep -Fq -- "$needle" "$file"; then
                pass_test "Codex harness-work TDD contract string in $(basename "$(dirname "$file")")/$(basename "$file"): $needle"
            else
                fail_test "Codex harness-work TDD contract string missing in $file: $needle"
            fi
        done
    fi
done

if [ -x "$TDD_LOCAL_TRIAL_TEST" ]; then
    pass_test "focused L1/L2/L4 TDD local trial test is executable"
else
    fail_test "tests/test-tdd-enforcement-l1l2l4.sh is missing or not executable"
fi

TDD_ENFORCE_ENABLED="$(
    awk '
      /^\[tdd\.enforce\]/ { in_section=1; next }
      /^\[/ && in_section { exit }
      in_section && /^[[:space:]]*enabled[[:space:]]*=/ {
        gsub(/[[:space:]]/, "", $0)
        sub(/^enabled=/, "", $0)
        print $0
        exit
      }
    ' "$PLUGIN_ROOT/harness.toml" 2>/dev/null
)"
if [ "${TDD_ENFORCE_ENABLED:-false}" = "false" ]; then
    pass_test "TDD enforcement remains opt-in by default (enabled=false)"
else
    fail_test "TDD enforcement default must not require enabled=true"
fi

echo ""
echo "13. Project spec SSOT workflow check"
echo "----------------------------------------"

if bash "$PLUGIN_ROOT/tests/test-spec-ssot-workflow.sh" > /dev/null 2>&1; then
    pass_test "Plans.md task workflow includes project spec SSOT creation/update guard (test-spec-ssot-workflow.sh)"
else
    fail_test "project spec SSOT workflow contract failed — run 'bash tests/test-spec-ssot-workflow.sh' for details"
fi

echo ""
echo "14. Harness review governance check"
echo "----------------------------------------"

if bash "$PLUGIN_ROOT/tests/test-harness-review-governance.sh" > /dev/null 2>&1; then
    pass_test "harness-review satisfies TeamAgent Debate / pass threshold / spec+Plans+regression gate / AskUserQuestion / mirror sync"
else
    fail_test "harness-review governance contract failed — run 'bash tests/test-harness-review-governance.sh' for details"
fi

if bash "$PLUGIN_ROOT/tests/test-harness-release-governance.sh" > /dev/null 2>&1; then
    pass_test "harness-release satisfies bare invocation / unreviewed AskUserQuestion / review→commit→release gate / mirror sync"
else
    fail_test "harness-release governance contract failed — run 'bash tests/test-harness-release-governance.sh' for details"
fi

echo ""
echo "15. Phase 69 (CC 2.1.133-2.1.142) terminalSequence / hooks contract"
echo "----------------------------------------"

if bash "$PLUGIN_ROOT/tests/test-terminal-notify.sh" > /dev/null 2>&1; then
    pass_test "Phase 69 hook terminalSequence / rules / template baseline contract is satisfied"
else
    fail_test "Phase 69 terminalSequence contract failed — run 'bash tests/test-terminal-notify.sh' for details"
fi

echo ""
echo "=========================================="
echo "Test results summary"
echo "=========================================="
echo -e "${GREEN}Passed:${NC} $PASS_COUNT"
echo -e "${YELLOW}Warnings:${NC} $WARN_COUNT"
echo -e "${RED}Failed:${NC} $FAIL_COUNT"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ $FAIL_COUNT test(s) failed${NC}"
    exit 1
fi
