#!/usr/bin/env bash
#
# test-codex-package.sh
# Validate Codex CLI package contents
#
# Usage: ./tests/test-codex-package.sh
#

set -euo pipefail

PASSED=0
FAILED=0

log_test() { echo "[TEST] $1"; }
log_pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
log_fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Test 1: required files
log_test "Required files exist"
required_files=(
  "codex/AGENTS.md"
  "codex/README.md"
  "codex/.codex/rules/harness.rules"
)
all_exist=true
for file in "${required_files[@]}"; do
  if [ -f "$file" ]; then
    echo "  ok: $file"
  else
    echo "  missing: $file"
    all_exist=false
  fi
done
if $all_exist; then
  log_pass "Required files present"
else
  log_fail "Missing required files"
fi

# Test 1.5: execpolicy rules examples are consistent (prevents Codex startup parse errors)
log_test "Execpolicy rules examples are valid"
if command -v python3 >/dev/null 2>&1; then
  if python3 - <<'PY'
from __future__ import annotations

import shlex
import sys
from pathlib import Path


def _matches_prefix(pattern: list[object], tokens: list[str]) -> bool:
    if len(tokens) < len(pattern):
        return False

    for i, pe in enumerate(pattern):
        t = tokens[i]
        if isinstance(pe, str):
            if t != pe:
                return False
        elif isinstance(pe, (list, tuple)):
            if t not in pe:
                return False
        else:
            raise TypeError(f"Unsupported pattern element at index {i}: {pe!r}")
    return True


def _load_rules(path: Path) -> list[dict[str, object]]:
    rules: list[dict[str, object]] = []

    def prefix_rule(**kwargs):  # type: ignore[no-redef]
        rules.append(kwargs)

    g = {"prefix_rule": prefix_rule}
    code = path.read_text(encoding="utf-8")
    exec(compile(code, str(path), "exec"), g, {})
    return rules


def _validate(path: Path) -> list[str]:
    errs: list[str] = []
    rules = _load_rules(path)
    if not rules:
        return [f"{path}: no prefix_rule() found"]

    for idx, rule in enumerate(rules):
        pattern = rule.get("pattern")
        if not isinstance(pattern, list):
            errs.append(f"{path}: rule {idx} missing/invalid pattern: {pattern!r}")
            continue

        for field, should_match in (("match", True), ("not_match", False)):
            examples = rule.get(field, [])
            if examples is None:
                continue
            if not isinstance(examples, list):
                errs.append(f"{path}: rule {idx} {field} is not a list: {examples!r}")
                continue

            for ex in examples:
                if not isinstance(ex, str):
                    errs.append(f"{path}: rule {idx} {field} example is not str: {ex!r}")
                    continue
                tokens = shlex.split(ex)
                ok = _matches_prefix(pattern, tokens)
                if ok != should_match:
                    verdict = "matches" if ok else "does not match"
                    errs.append(
                        f"{path}: rule {idx} {field} example {ex!r} {verdict} pattern {pattern!r}"
                    )
    return errs


errors: list[str] = []
for p in [Path("codex/.codex/rules/harness.rules")]:
    errors.extend(_validate(p))

if errors:
    print("ERROR: execpolicy rules examples invalid:")
    for e in errors:
        print("  -", e)
    sys.exit(1)

print("ok")
PY
  then
    log_pass "Rules examples are consistent"
  else
    log_fail "Rules examples invalid (Codex may ignore custom rules)"
  fi
else
  echo "  skipped: python3 not found"
  log_pass "Rules examples check skipped"
fi

# Test 1.6: path-based skill bundle is present
log_test "Codex path-based core skills exist"
required_skill_dirs=(
  "codex/.codex/skills/harness-plan"
  "codex/.codex/skills/harness-sync"
  "codex/.codex/skills/harness-work"
  "codex/.codex/skills/harness-review"
  "codex/.codex/skills/harness-release"
  "codex/.codex/skills/harness-setup"
  "codex/.codex/skills/breezing"
  "codex/.codex/skills/harness-loop"
)
skills_ok=true
for dir in "${required_skill_dirs[@]}"; do
  if [ -d "$dir" ] && [ ! -L "$dir" ]; then
    echo "  ok: $dir"
  else
    if [ -L "$dir" ]; then
      echo "  symlink: $dir"
    else
      echo "  missing: $dir"
    fi
    skills_ok=false
  fi
done
if $skills_ok; then
  log_pass "Path-based core skills are present"
else
  log_fail "Missing path-based core skills"
fi

log_test "Shipped Codex/OpenCode skills have required description frontmatter"
skill_frontmatter_ok=true
while IFS= read -r skill_file; do
  if ! rg -q '^description:' "$skill_file"; then
    echo "  missing description: $skill_file"
    skill_frontmatter_ok=false
  fi
done < <(find codex/.codex/skills opencode/skills -name SKILL.md | sort)
if $skill_frontmatter_ok; then
  log_pass "All shipped skill bundles have description frontmatter"
else
  log_fail "Some shipped skill bundles are invalid for Codex skill loading"
fi

log_test "Public skill mirrors stay in sync"
if ./scripts/sync-skill-mirrors.sh --check >/tmp/codex-skill-mirrors.$$ 2>&1; then
  log_pass "Public skill mirrors match skills"
else
  cat /tmp/codex-skill-mirrors.$$ | sed 's/^/  /'
  log_fail "Public skill mirrors drifted from skills"
fi
rm -f /tmp/codex-skill-mirrors.$$ || true

log_test "Non-breezing Codex skills are CLI-only"
cli_only_targets=(
  "codex/.codex/skills/harness-work/SKILL.md"
  "codex/.codex/skills/harness-review/SKILL.md"
  "codex/.codex/skills/routing-rules.md"
)
forbidden_cli_terms=(
  "Codex MCP"
  "claude mcp add --scope user codex"
  "claude mcp list | grep -i codex"
  "@openai/codex-cli"
  "MCP server connection error"
  "all MCP calls"
)
cli_only_ok=true
for pat in "${forbidden_cli_terms[@]}"; do
  if rg -n --fixed-strings "$pat" "${cli_only_targets[@]}" >/tmp/codex-cli-only.$$ 2>/dev/null; then
    echo "  forbidden CLI-only pattern found: $pat"
    head -5 /tmp/codex-cli-only.$$ | sed 's/^/    /'
    cli_only_ok=false
  fi
done
rm -f /tmp/codex-cli-only.$$ || true
if $cli_only_ok; then
  log_pass "CLI-only vocabulary checks passed for non-breezing Codex skills"
else
  log_fail "CLI-only vocabulary check failed for non-breezing Codex skills"
fi

log_test "Codex docs point at harness-* workflow surfaces"
workflow_surface_ok=true
for required_surface in '$harness-plan' '$harness-sync' '$harness-work' '$breezing' '$harness-review' '$harness-loop'; do
  if ! rg -q --fixed-strings "$required_surface" "codex/README.md" "codex/AGENTS.md"; then
    echo "  missing: ${required_surface} in codex docs"
    workflow_surface_ok=false
  fi
done
if ! rg -q --fixed-strings '$harness-work' "codex/README.md"; then
  echo "  missing: \$harness-work in codex/README.md"
  workflow_surface_ok=false
fi
if ! rg -q --fixed-strings '$harness-review' "codex/README.md"; then
  echo "  missing: \$harness-review in codex/README.md"
  workflow_surface_ok=false
fi
if ! rg -q --fixed-strings 'harness codex-loop start/status/stop' "codex/README.md" "codex/.codex/skills/harness-loop/SKILL.md"; then
  echo "  missing: codex-loop runtime note"
  workflow_surface_ok=false
fi
if ! rg -q --fixed-strings 'Realtime Handoff / Silence Policy' "codex/.codex/skills/harness-loop/SKILL.md" "codex/.codex/skills/breezing/SKILL.md"; then
  echo "  missing: realtime handoff silence policy in Codex skills"
  workflow_surface_ok=false
fi
if ! rg -q --fixed-strings 'Advisor / Reviewer drift' "codex/.codex/skills/harness-loop/SKILL.md"; then
  echo "  missing: Advisor / Reviewer drift exception in harness-loop silence policy"
  workflow_surface_ok=false
fi
if ! rg -q --fixed-strings 'Realtime Handoff And Silence Policy' "codex/README.md"; then
  echo "  missing: realtime handoff silence policy in codex/README.md"
  workflow_surface_ok=false
fi
if ! rg -q --fixed-strings 'spawn_agent' "codex/README.md" "codex/.codex/skills/breezing/SKILL.md"; then
  echo "  missing: spawn_agent native orchestration note"
  workflow_surface_ok=false
fi
if ! rg -q --fixed-strings '| `--max-workers N` | ready task の同時 spawn 数上限' "codex/.codex/skills/breezing/SKILL.md"; then
  echo "  missing: breezing default max-workers guidance"
  workflow_surface_ok=false
fi
if ! rg -q --fixed-strings 'breezing --max-workers 1 all' "codex/.codex/skills/breezing/SKILL.md"; then
  echo "  missing: breezing serial escape hatch"
  workflow_surface_ok=false
fi
if ! rg -q --fixed-strings 'ready batch' "codex/README.md" "codex/.codex/skills/harness-loop/SKILL.md"; then
  echo "  missing: harness-loop ready batch guidance"
  workflow_surface_ok=false
fi
if ! rg -q --fixed-strings -- '--executor task' "codex/README.md" "codex/.codex/skills/harness-loop/SKILL.md"; then
  echo "  missing: harness-loop task executor escape hatch"
  workflow_surface_ok=false
fi
if ! rg -q --fixed-strings -- '--codex' "codex/.codex/skills/harness-work/SKILL.md"; then
  echo "  missing: --codex in harness-work/SKILL.md"
  workflow_surface_ok=false
fi
if ! rg -q --fixed-strings 'harness-work' "codex/.codex/skills/breezing/SKILL.md"; then
  echo "  missing: harness-work alias note in breezing/SKILL.md"
  workflow_surface_ok=false
fi
if [ -L "codex/.codex/skills/breezing" ]; then
  echo "  symlink: codex/.codex/skills/breezing must be a real directory"
  workflow_surface_ok=false
fi
codex_breezing_ssot="skills/breezing"
if [ -d "skills-codex/breezing" ]; then
  codex_breezing_ssot="skills-codex/breezing"
fi
if ! diff -qr "${codex_breezing_ssot}" "codex/.codex/skills/breezing" >/dev/null 2>&1; then
  echo "  drift: codex breezing mirror does not match ${codex_breezing_ssot}"
  workflow_surface_ok=false
fi
for forbidden_pat in '$plan-with-agent' '$work' '$verify' '$remember'; do
  if rg -n --fixed-strings "$forbidden_pat" "codex/AGENTS.md" "codex/.codex/skills/workflow-guide/SKILL.md" "codex/.codex/skills/workflow-guide/references/commands.md" >/tmp/codex-surface-forbidden.$$ 2>/dev/null; then
    echo "  forbidden legacy command remains: $forbidden_pat"
    head -5 /tmp/codex-surface-forbidden.$$ | sed 's/^/    /'
    workflow_surface_ok=false
  fi
done
rm -f /tmp/codex-surface-forbidden.$$ || true
if $workflow_surface_ok; then
  log_pass "Harness workflow surfaces are documented for Codex"
else
  log_fail "Harness workflow surface checks failed"
fi

log_test "codex/.codex/config.toml has multi_agent + harness roles"
config_ok=true
if ! rg -q --fixed-strings "multi_agent = true" "codex/.codex/config.toml"; then
  echo "  missing: multi_agent = true"
  config_ok=false
fi
for role in "implementer" "reviewer" "claude_implementer" "claude_reviewer"; do
  if ! rg -q --fixed-strings "[agents.${role}]" "codex/.codex/config.toml"; then
    echo "  missing: [agents.${role}]"
    config_ok=false
  fi
done
if $config_ok; then
  log_pass "config.toml has required multi-agent defaults"
else
  log_fail "config.toml missing required multi-agent defaults"
fi

# Test 1.7: setup scripts should not create duplicate skill listings
log_test "Codex setup scripts guard against duplicate skill listings"
scripts_ok=true
setup_scripts=(
  "scripts/setup-codex.sh"
  "scripts/codex-setup-local.sh"
)

for script in "${setup_scripts[@]}"; do
  if rg -q --fixed-strings '${target}.backup.' "$script"; then
    echo "  legacy in-place backup naming remains: $script"
    scripts_ok=false
  fi
  if ! rg -q --fixed-strings 'should_skip_sync_entry' "$script"; then
    echo "  missing should_skip_sync_entry: $script"
    scripts_ok=false
  fi
  if ! rg -q --fixed-strings 'cleanup_legacy_skill_entries' "$script"; then
    echo "  missing cleanup_legacy_skill_entries: $script"
    scripts_ok=false
  fi
  if ! rg -q --fixed-strings 'extract_skill_frontmatter_name' "$script"; then
    echo "  missing extract_skill_frontmatter_name: $script"
    scripts_ok=false
  fi
  if ! rg -q --fixed-strings 'cleanup_legacy_skill_name_duplicates' "$script"; then
    echo "  missing cleanup_legacy_skill_name_duplicates: $script"
    scripts_ok=false
  fi
  if ! rg -q --fixed-strings 'is_legacy_harness_skill_name' "$script"; then
    echo "  missing is_legacy_harness_skill_name: $script"
    scripts_ok=false
  fi
  if ! rg -q --fixed-strings 'is_harness_managed_skill_entry' "$script"; then
    echo "  missing is_harness_managed_skill_entry: $script"
    scripts_ok=false
  fi
  if ! rg -q --fixed-strings 'cleanup_removed_harness_skill_entries' "$script"; then
    echo "  missing cleanup_removed_harness_skill_entries: $script"
    scripts_ok=false
  fi
  if ! rg -q --fixed-strings '_archived|*.backup.*' "$script"; then
    echo "  missing legacy skip rule (_archived|*.backup.*): $script"
    scripts_ok=false
  fi
  if ! rg -q --fixed-strings '/backups/' "$script"; then
    echo "  missing external backup root (/backups/): $script"
    scripts_ok=false
  fi
done

if $scripts_ok; then
  log_pass "Setup script duplicate-skill guards are present"
else
  log_fail "Setup script duplicate-skill guards are missing"
fi

log_test "codex-setup-local handles symlinked skill installs safely"
if bash tests/test-codex-setup-local.sh >/tmp/codex-setup-symlink.$$ 2>&1; then
  log_pass "Symlinked skill installs are safe"
else
  cat /tmp/codex-setup-symlink.$$ | sed 's/^/  /'
  log_fail "Symlinked skill install safety check failed"
fi
rm -f /tmp/codex-setup-symlink.$$ || true

# Test 1.7b: setup-codex should not inject stale notify config
log_test "setup-codex.sh avoids stale notify config"
if rg -q '^\[notify\]' "scripts/setup-codex.sh"; then
  echo "  stale [notify] section remains in scripts/setup-codex.sh"
  log_fail "setup-codex.sh still injects invalid notify config"
else
  log_pass "setup-codex.sh does not inject stale notify config"
fi

# Test 1.7c: codex README should document the reliable update path
log_test "codex README documents the reliable user update path"
readme_update_path_ok=true
if ! rg -q --fixed-strings 'Option 1: Script (recommended, user-based)' "codex/README.md"; then
  echo "  missing recommended script wording"
  readme_update_path_ok=false
fi
if ! rg -q --fixed-strings 'rerun the same script to sync `~/.codex/skills`' "codex/README.md"; then
  echo "  missing rerun update guidance"
  readme_update_path_ok=false
fi
if $readme_update_path_ok; then
  log_pass "codex README points users to the reliable update path"
else
  log_fail "codex README update-path guidance is incomplete"
fi

log_test "codex README documents MCP verbose diagnostics and .mcp.json loading"
readme_mcp_ok=true
if ! rg -q --fixed-strings 'Codex `0.123.0` keeps the normal `/mcp` view fast' "codex/README.md"; then
  echo "  missing: plain /mcp fast-path guidance"
  readme_mcp_ok=false
fi
if ! rg -q --fixed-strings '/mcp verbose' "codex/README.md"; then
  echo "  missing: /mcp verbose guidance"
  readme_mcp_ok=false
fi
if ! rg -q --fixed-strings 'diagnostics, resources, and resource templates' "codex/README.md"; then
  echo "  missing: diagnostics/resources/resource templates guidance"
  readme_mcp_ok=false
fi
if ! rg -q --fixed-strings '"mcpServers"' "codex/README.md"; then
  echo "  missing: mcpServers .mcp.json example"
  readme_mcp_ok=false
fi
if ! rg -q --fixed-strings 'top-level server map' "codex/README.md"; then
  echo "  missing: top-level server map loading guidance"
  readme_mcp_ok=false
fi
if ! rg -q --fixed-strings 'not Claude Code `claude mcp` or `.claude/mcp.json` guidance' "codex/README.md"; then
  echo "  missing: Codex vs Claude Code MCP terminology boundary"
  readme_mcp_ok=false
fi
if $readme_mcp_ok; then
  log_pass "codex README documents MCP diagnostics and plugin loading"
else
  log_fail "codex README MCP guidance is incomplete"
fi

log_test "codex README documents sandbox and exec policy"
readme_sandbox_ok=true
if ! rg -q --fixed-strings 'Codex `0.123.0` adds host-specific `remote_sandbox_config` requirements' "codex/README.md"; then
  echo "  missing: remote_sandbox_config guidance"
  readme_sandbox_ok=false
fi
if ! rg -q --fixed-strings 'requirements.toml' "codex/README.md"; then
  echo "  missing: requirements.toml policy placement"
  readme_sandbox_ok=false
fi
if ! rg -q --fixed-strings 'hostname_patterns' "codex/README.md"; then
  echo "  missing: hostname_patterns example"
  readme_sandbox_ok=false
fi
if ! rg -q --fixed-strings 'allowed_sandbox_modes' "codex/README.md"; then
  echo "  missing: allowed_sandbox_modes example"
  readme_sandbox_ok=false
fi
if ! rg -q --fixed-strings 'root-level shared flags' "codex/README.md"; then
  echo "  missing: codex exec shared flags inheritance guidance"
  readme_sandbox_ok=false
fi
if ! rg -q --fixed-strings 'duplicate `--approval-policy` / `--sandbox` pairs' "codex/README.md"; then
  echo "  missing: duplicate approval/sandbox flag guidance"
  readme_sandbox_ok=false
fi
if ! rg -q --fixed-strings 'docs/codex-sandbox-execution-policy.md' "codex/README.md"; then
  echo "  missing: sandbox execution policy docs pointer"
  readme_sandbox_ok=false
fi
if $readme_sandbox_ok; then
  log_pass "codex README documents sandbox and exec policy"
else
  log_fail "codex README sandbox/exec guidance is incomplete"
fi

log_test "Codex multi-environment write guard is wired and documented"
primary_guard_ok=true
if [ ! -x "scripts/codex-primary-environment-guard.sh" ]; then
  echo "  missing executable guard: scripts/codex-primary-environment-guard.sh"
  primary_guard_ok=false
fi
if ! rg -q --fixed-strings 'codex-primary-environment-guard.sh' "scripts/codex-companion.sh" "scripts/codex/codex-exec-wrapper.sh"; then
  echo "  missing guard wiring in Codex write entrypoints"
  primary_guard_ok=false
fi
if ! rg -q --fixed-strings 'HARNESS_CODEX_EXECUTION_ROOT="${EXECUTION_ROOT}"' "scripts/codex-companion.sh"; then
  echo "  missing execution-root anchored guard call in scripts/codex-companion.sh"
  primary_guard_ok=false
fi
if ! rg -q --fixed-strings 'HARNESS_CODEX_ALLOW_NON_PRIMARY_WRITE=1' "codex/README.md"; then
  echo "  missing override guidance in codex/README.md"
  primary_guard_ok=false
fi
if ! rg -q --fixed-strings 'HARNESS_CODEX_RESET_PRIMARY_ENVIRONMENT=1' "codex/README.md"; then
  echo "  missing primary reset guidance in codex/README.md"
  primary_guard_ok=false
fi
if ! rg -q --fixed-strings 'HARNESS_CODEX_DISABLE_PRIMARY_ENV_GUARD=1' "codex/README.md"; then
  echo "  missing guard disable guidance in codex/README.md"
  primary_guard_ok=false
fi
if $primary_guard_ok; then
  log_pass "Codex multi-environment write guard is wired and documented"
else
  log_fail "Codex multi-environment write guard checks failed"
fi

log_test "primary environment guard behavior"
if bash tests/test-codex-primary-environment-guard.sh >/tmp/codex-primary-env-guard.$$ 2>&1; then
  log_pass "Primary environment guard behavior works"
else
  cat /tmp/codex-primary-env-guard.$$ | sed 's/^/  /'
  log_fail "Primary environment guard behavior failed"
fi
rm -f /tmp/codex-primary-env-guard.$$ || true

# Test 1.8: codex-setup-local should cleanup duplicate frontmatter names
log_test "codex-setup-local cleans duplicate frontmatter skill aliases"
if PROJECT_ROOT="$PROJECT_ROOT" bash -lc '
set -euo pipefail
project_root="$PROJECT_ROOT"
tmp_home="$(mktemp -d)"
trap "rm -rf \"$tmp_home\"" EXIT

export HOME="$tmp_home"
export CODEX_HOME="$tmp_home/.codex"
mkdir -p "$CODEX_HOME/skills/legacy-harness-plan/references"
cat > "$CODEX_HOME/skills/legacy-harness-plan/SKILL.md" <<'"'"'EOF'"'"'
---
name: harness-plan
description: duplicate frontmatter name for migration test
allowed-tools: ["Read"]
---
EOF

CLAUDE_PLUGIN_ROOT="$project_root" bash "$project_root/scripts/codex-setup-local.sh" --user >/dev/null

test -f "$CODEX_HOME/skills/harness-plan/SKILL.md"
if [ -d "$CODEX_HOME/skills/legacy-harness-plan" ]; then
  echo "  duplicate alias directory still exists"
  exit 1
fi
if ! find "$CODEX_HOME/backups/codex-setup-local" -type d -name "legacy-harness-plan.*" | grep -q .; then
  echo "  duplicate alias backup not found"
  exit 1
fi
'; then
  log_pass "Duplicate frontmatter alias cleanup works"
else
  log_fail "Duplicate frontmatter alias cleanup failed"
fi

# Test 1.8b: codex-setup-local should archive removed legacy harness skills but keep custom skills
log_test "codex-setup-local archives removed legacy Harness skills"
if PROJECT_ROOT="$PROJECT_ROOT" bash -lc '
set -euo pipefail
project_root="$PROJECT_ROOT"
tmp_home="$(mktemp -d)"
trap "rm -rf \"$tmp_home\"" EXIT

export HOME="$tmp_home"
export CODEX_HOME="$tmp_home/.codex"
mkdir -p "$CODEX_HOME/skills/work" "$CODEX_HOME/skills/plan-with-agent" "$CODEX_HOME/skills/custom-helper"

cat > "$CODEX_HOME/skills/work/SKILL.md" <<'"'"'EOF'"'"'
---
name: work
description: Claude Code Harness legacy work skill
allowed-tools: ["Read"]
---

# Harness v3 legacy work skill
Plans.md
EOF

cat > "$CODEX_HOME/skills/plan-with-agent/SKILL.md" <<'"'"'EOF'"'"'
---
name: plan-with-agent
description: Claude Code Harness legacy plan skill
allowed-tools: ["Read"]
---

# Claude Code Harness legacy planner
/harness-plan
EOF

cat > "$CODEX_HOME/skills/custom-helper/SKILL.md" <<'"'"'EOF'"'"'
---
name: custom-helper
description: personal custom skill
allowed-tools: ["Read"]
---
EOF

CLAUDE_PLUGIN_ROOT="$project_root" bash "$project_root/scripts/codex-setup-local.sh" --user >/dev/null

test -d "$CODEX_HOME/skills/harness-work"
test -d "$CODEX_HOME/skills/custom-helper"

if [ -d "$CODEX_HOME/skills/work" ] || [ -d "$CODEX_HOME/skills/plan-with-agent" ]; then
  echo "  legacy harness skills still exist"
  exit 1
fi

if ! find "$CODEX_HOME/backups/codex-setup-local" -type d \( -name "work.*" -o -name "plan-with-agent.*" \) | grep -q .; then
  echo "  removed legacy harness skills were not archived"
  exit 1
fi
'; then
  log_pass "Removed legacy Harness skills are archived safely"
else
  log_fail "Removed legacy Harness skills were not archived correctly"
fi

# Test 2: skills directory parity
log_test "Skills parity by SKILL name"
if [ -d "opencode/skills" ] && [ -d "codex/.codex/skills" ]; then
  get_skill_names() {
    local root="$1"
    find "$root" -mindepth 1 -maxdepth 1 -type d | while IFS= read -r d; do
      local dirname
      dirname="$(basename "$d")"
      # Skip dev/test/unsupported skills (matches build-opencode.js logic)
      case "$dirname" in
        test-*|x-*|breezing|cc-update-review|claude-codex-upstream-update|harness-release-internal|maintenance|zz-review-empty|zz-review-escape|_archived|harness-ui) continue ;;
      esac
      if [ -f "$d/SKILL.md" ]; then
        sed -n 's/^name:[[:space:]]*//p' "$d/SKILL.md" | head -n 1 | tr -d '\"'
      fi
    done | sort
  }

  source_list=$(get_skill_names opencode/skills)
  target_list=$(get_skill_names codex/.codex/skills)

  if diff -u <(echo "$source_list") <(echo "$target_list") >/dev/null; then
    log_pass "Skill names match"
  else
    echo "[DETAIL] opencode vs codex skill names differ"
    diff -u <(echo "$source_list") <(echo "$target_list") || true
    log_fail "Skill names mismatch"
  fi
else
  log_fail "Skills directories missing"
fi

# Test 3: SKILL.md exists for each Codex skill
log_test "Each Codex skill has SKILL.md"
missing_skill=false
while IFS= read -r skill_dir; do
  skill_name="$(basename "$skill_dir")"
  case "$skill_name" in
    _archived|harness-ui)
      # distribution-excluded buckets are allowed without SKILL.md
      continue
      ;;
  esac
  if [ ! -f "$skill_dir/SKILL.md" ]; then
    echo "  missing: $skill_dir/SKILL.md"
    missing_skill=true
  fi
done < <(find codex/.codex/skills -mindepth 1 -maxdepth 1 -type d | sort)

if $missing_skill; then
  log_fail "Missing SKILL.md"
else
  log_pass "All skills have SKILL.md"
fi

# Summary
if [ "$FAILED" -eq 0 ]; then
  echo "All tests passed: $PASSED"
  exit 0
fi

echo "Tests failed: $FAILED (passed: $PASSED)"
exit 1
