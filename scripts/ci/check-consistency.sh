#!/bin/bash
# check-consistency.sh
# Plugin consistency check
#
# Usage: ./scripts/ci/check-consistency.sh
# Exit codes:
#   0 - All checks passed
#   1 - Inconsistencies found

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ERRORS=0

echo "🔍 claude-code-harness consistency check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ================================
# 1. Verify required template files exist
# ================================
echo ""
echo "📁 [1/14] Checking required template files..."

REQUIRED_TEMPLATES=(
  "templates/AGENTS.md.template"
  "templates/CLAUDE.md.template"
  "templates/Plans.md.template"
  "templates/locales/ja/AGENTS.md.template"
  "templates/locales/ja/CLAUDE.md.template"
  "templates/locales/ja/Plans.md.template"
  "templates/locales/ja/.claude-code-harness.config.yaml.template"
  "templates/.claude-code-harness-version.template"
  "templates/.claude-code-harness.config.yaml.template"
  "templates/cursor/commands/start-session.md"
  "templates/cursor/commands/project-overview.md"
  "templates/cursor/commands/plan-with-cc.md"
  "templates/cursor/commands/handoff-to-claude.md"
  "templates/cursor/commands/review-cc-work.md"
  "templates/claude/settings.security.json.template"
  "templates/claude/settings.local.json.template"
  "templates/rules/workflow.md.template"
  "templates/rules/coding-standards.md.template"
  "templates/rules/plans-management.md.template"
  "templates/rules/testing.md.template"
  "templates/rules/ui-debugging-agent-browser.md.template"
)

for template in "${REQUIRED_TEMPLATES[@]}"; do
  if [ ! -f "$PLUGIN_ROOT/$template" ]; then
    echo "  ❌ Missing: $template"
    ERRORS=$((ERRORS + 1))
  else
    echo "  ✅ $template"
  fi
done

# ================================
# 2. Command ↔ skill reference consistency
# ================================
echo ""
echo "🔗 [2/14] Command ↔ skill reference consistency..."

# Check that templates referenced by commands exist
check_command_references() {
  local cmd_file="$1"
  local cmd_name=$(basename "$cmd_file" .md)

  # Extract template references
  local refs=$(grep -oE 'templates/[a-zA-Z0-9/_.-]+' "$cmd_file" 2>/dev/null || true)

  for ref in $refs; do
    if [ ! -e "$PLUGIN_ROOT/$ref" ] && [ ! -e "$PLUGIN_ROOT/${ref}.template" ]; then
      echo "  ❌ $cmd_name: reference target does not exist: $ref"
      ERRORS=$((ERRORS + 1))
    fi
  done
}

for cmd in "$PLUGIN_ROOT/commands"/*.md; do
  check_command_references "$cmd"
done
echo "  ✅ Command reference check complete"

# ================================
# 3. Version number consistency
# ================================
echo ""
echo "🏷️ [3/14] Version number consistency..."

VERSION_FILE="$PLUGIN_ROOT/VERSION"
PLUGIN_JSON="$PLUGIN_ROOT/.claude-plugin/plugin.json"

if [ -f "$VERSION_FILE" ] && [ -f "$PLUGIN_JSON" ]; then
  FILE_VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')
  JSON_VERSION=$(grep '"version"' "$PLUGIN_JSON" | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')

  if [ "$FILE_VERSION" != "$JSON_VERSION" ]; then
    echo "  ❌ Version mismatch: VERSION=$FILE_VERSION, plugin.json=$JSON_VERSION"
    ERRORS=$((ERRORS + 1))
  else
    echo "  ✅ VERSION and plugin.json match: $FILE_VERSION"
  fi
fi

# ================================
# 4. Expected skill file structure
# ================================
echo ""
echo "📋 [4/14] Expected skill definition file structure..."

# 2agent configuration has been merged into harness-setup
# Verify skills/harness-setup/SKILL.md exists
SETUP_SKILL="$PLUGIN_ROOT/skills/harness-setup/SKILL.md"
if [ -f "$SETUP_SKILL" ]; then
  echo "  ✅ skills/harness-setup/SKILL.md exists (includes 2agent configuration)"
else
  echo "  ❌ skills/harness-setup/SKILL.md not found"
  ERRORS=$((ERRORS + 1))
fi

# ================================
# 5. Hooks configuration consistency
# ================================
echo ""
echo "🪝 [5/14] Hooks configuration consistency..."

HOOKS_JSON="$PLUGIN_ROOT/hooks/hooks.json"
if [ -f "$HOOKS_JSON" ]; then
  # Check script references in hooks.json
  SCRIPT_REFS=$(grep -oE '\$\{CLAUDE_PLUGIN_ROOT\}/scripts/[a-zA-Z0-9_./-]+' "$HOOKS_JSON" 2>/dev/null || true)

  for ref in $SCRIPT_REFS; do
    script_name=$(echo "$ref" | sed 's|\${CLAUDE_PLUGIN_ROOT}/scripts/||')
    if [ ! -f "$PLUGIN_ROOT/scripts/$script_name" ]; then
      echo "  ❌ hooks.json: script does not exist: scripts/$script_name"
      ERRORS=$((ERRORS + 1))
    else
      echo "  ✅ scripts/$script_name"
    fi
  done
fi

# ================================
# 6. Regression check for /start-task deprecation
# ================================
echo ""
echo "🚫 [6/14] Regression check for /start-task deprecation..."

# Operational flow files (exclude history files such as CHANGELOG)
START_TASK_TARGETS=(
  "commands/"
  "skills/"
  "workflows/"
  "profiles/"
  "templates/"
  "scripts/"
  "DEVELOPMENT_FLOW_GUIDE.md"
  "IMPLEMENTATION_GUIDE.md"
  "README.md"
)

START_TASK_FOUND=0
for target in "${START_TASK_TARGETS[@]}"; do
  if [ -e "$PLUGIN_ROOT/$target" ]; then
    # Search for references to /start-task (exclude historical and migration context)
    # Excluded patterns: Removed/deleted/deprecated (history), equivalent/integrated/legacy/absorbed (migration), improved/usage (CHANGELOG)
    REFS=$(grep -rn "/start-task" "$PLUGIN_ROOT/$target" 2>/dev/null \
      | grep -v "Removed" | grep -v "deleted" | grep -v "deprecated" \
      | grep -v "equivalent" | grep -v "integrated" | grep -v "legacy" | grep -v "absorbed" \
      | grep -v "improved" | grep -v "usage" | grep -v "CHANGELOG" \
      | grep -v "check-consistency.sh" \
      || true)
    if [ -n "$REFS" ]; then
      echo "  ❌ /start-task reference still present: $target"
      sed -n '1,3p' <<<"$REFS" | sed 's/^/      /'
      START_TASK_FOUND=$((START_TASK_FOUND + 1))
    fi
  fi
done

if [ $START_TASK_FOUND -eq 0 ]; then
  echo "  ✅ No /start-task references (operational flow)"
else
  ERRORS=$((ERRORS + START_TASK_FOUND))
fi

# ================================
# 7. Regression check for docs/ normalization
# ================================
echo ""
echo "📁 [7/14] Regression check for docs/ normalization..."

# Check for root-level references to proposal.md / priority_matrix.md
DOCS_TARGETS=(
  "commands/"
  "skills/"
)

DOCS_ISSUES=0
for target in "${DOCS_TARGETS[@]}"; do
  if [ -d "$PLUGIN_ROOT/$target" ]; then
    # Search for references to root-level proposal.md / technical-spec.md / priority_matrix.md
    # Detect those missing the docs/ prefix
    REFS=$(grep -rn "proposal.md\|technical-spec.md\|priority_matrix.md" "$PLUGIN_ROOT/$target" 2>/dev/null | grep -v "docs/" | grep -v "\.template" || true)
    if [ -n "$REFS" ]; then
      echo "  ❌ Reference without docs/ prefix: $target"
      sed -n '1,3p' <<<"$REFS" | sed 's/^/      /'
      DOCS_ISSUES=$((DOCS_ISSUES + 1))
    fi
  fi
done

if [ $DOCS_ISSUES -eq 0 ]; then
  echo "  ✅ docs/ normalization OK"
else
  ERRORS=$((ERRORS + DOCS_ISSUES))
fi

# ================================
# 8. Regression check for bypassPermissions-first operation
# ================================
echo ""
echo "🔓 [8/14] Regression check for bypassPermissions-first operation..."

BYPASS_ISSUES=0

# Check 1: disableBypassPermissionsMode が templates に戻っていないこと
SECURITY_TEMPLATE="$PLUGIN_ROOT/templates/claude/settings.security.json.template"
if [ -f "$SECURITY_TEMPLATE" ]; then
  if grep -q "disableBypassPermissionsMode" "$SECURITY_TEMPLATE"; then
    echo "  ❌ disableBypassPermissionsMode still present in settings.security.json.template"
    echo "      Remove this setting for bypassPermissions-first operation"
    BYPASS_ISSUES=$((BYPASS_ISSUES + 1))
  else
    echo "  ✅ disableBypassPermissionsMode absent"
  fi
fi

# Check 2: Edit / Write must not be in the permissions.ask section
# NOTE: Edit/Write in the deny section is valid as a double defense. Check ask only.
if [ -f "$SECURITY_TEMPLATE" ]; then
  # Extract only the ask section and search for Edit/Write
  ASK_EDIT_WRITE=$(sed -n '/"ask"/,/\]/p' "$SECURITY_TEMPLATE" | grep -E '"(Edit|Write|MultiEdit)' || true)
  if [ -n "$ASK_EDIT_WRITE" ]; then
    echo "  ❌ settings.security.json.template ask section contains Edit/Write"
    echo "      Do not put Edit/Write in ask for bypassPermissions-first operation"
    BYPASS_ISSUES=$((BYPASS_ISSUES + 1))
  else
    echo "  ✅ No Edit/Write in ask"
  fi
fi

# Check 2.5: Regression check for Bash permission syntax (prefix requires :*)
if [ -f "$SECURITY_TEMPLATE" ]; then
  # Portable regex: use [(] / [*] instead of escaping to avoid BSD grep issues.
  if grep -nEq 'Bash[(][^)]*[^:][*]' "$SECURITY_TEMPLATE"; then
    echo "  ❌ settings.security.json.template contains invalid Bash permission syntax"
    echo "      Use :* for prefix matching (e.g. Bash(git status:*))"
    grep -nE 'Bash[(][^)]*[^:][*]' "$SECURITY_TEMPLATE" | sed -n '1,3p' | sed 's/^/      /'
    BYPASS_ISSUES=$((BYPASS_ISSUES + 1))
  else
    echo "  ✅ Bash permission syntax OK (:*)"
  fi
fi

# Check 3: settings.local.json.template must exist and defaultMode must be a documented permission mode
# NOTE: shipped default keeps bypassPermissions; Auto Mode is treated as a follow-up rollout for the teammate execution path
LOCAL_TEMPLATE="$PLUGIN_ROOT/templates/claude/settings.local.json.template"
if [ -f "$LOCAL_TEMPLATE" ]; then
  if grep -q '"defaultMode"[[:space:]]*:[[:space:]]*"bypassPermissions"' "$LOCAL_TEMPLATE"; then
    mode_val=$(grep '"defaultMode"' "$LOCAL_TEMPLATE" | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    echo "  ✅ settings.local.json.template: defaultMode=${mode_val}"
  else
    echo "  ❌ settings.local.json.template is missing defaultMode=bypassPermissions"
    BYPASS_ISSUES=$((BYPASS_ISSUES + 1))
  fi
else
  echo "  ❌ settings.local.json.template does not exist"
  BYPASS_ISSUES=$((BYPASS_ISSUES + 1))
fi

# Check 4: managed sandbox precedence keys are for managed settings only.
# Mixing them into standard distribution harness.toml / plugin settings / templates
# blurs the responsibility boundary with Claude Code's managed settings precedence.
MANAGED_SANDBOX_KEY_RE='allowManagedDomainsOnly|allowManagedReadPathsOnly'
MANAGED_SANDBOX_DEFAULT_TARGETS=(
  "$PLUGIN_ROOT/harness.toml"
  "$PLUGIN_ROOT/.claude-plugin/settings.json"
  "$PLUGIN_ROOT/templates/claude/settings.security.json.template"
  "$PLUGIN_ROOT/templates/sandbox-settings.json.template"
)
MANAGED_SANDBOX_ISSUES=0
for target in "${MANAGED_SANDBOX_DEFAULT_TARGETS[@]}"; do
  if [ ! -f "$target" ]; then
    continue
  fi
  FOUND_KEYS=$(grep -nE "$MANAGED_SANDBOX_KEY_RE" "$target" || true)
  if [ -n "$FOUND_KEYS" ]; then
    echo "  ❌ managed sandbox keys must not be placed in standard template/defaults: ${target#$PLUGIN_ROOT/}"
    sed -n '1,3p' <<<"$FOUND_KEYS" | sed 's/^/      /'
    MANAGED_SANDBOX_ISSUES=$((MANAGED_SANDBOX_ISSUES + 1))
  fi
done

if [ $MANAGED_SANDBOX_ISSUES -eq 0 ]; then
  echo "  ✅ managed sandbox keys are isolated to managed settings only"
else
  BYPASS_ISSUES=$((BYPASS_ISSUES + MANAGED_SANDBOX_ISSUES))
fi

if [ $BYPASS_ISSUES -eq 0 ]; then
  echo "  ✅ bypassPermissions-first operation OK"
else
  ERRORS=$((ERRORS + BYPASS_ISSUES))
fi

# ================================
# 9. Regression check for ccp-* skill deprecation
# ================================
echo ""
echo "🚫 [9/14] Regression check for ccp-* skill deprecation..."

CCP_ISSUES=0

# Check 1: name: in skills must not contain ccp-
CCP_NAMES=$(grep -rn "^name: ccp-" "$PLUGIN_ROOT/skills/" 2>/dev/null || true)
if [ -n "$CCP_NAMES" ]; then
  echo "  ❌ name: ccp-* still present in skills"
  sed -n '1,3p' <<<"$CCP_NAMES" | sed 's/^/      /'
  CCP_ISSUES=$((CCP_ISSUES + 1))
else
  echo "  ✅ No name: ccp-* in skills"
fi

# Check 2: skill: in workflows must not contain ccp-
CCP_WORKFLOWS=$(grep -rn "skill: ccp-" "$PLUGIN_ROOT/workflows/" 2>/dev/null || true)
if [ -n "$CCP_WORKFLOWS" ]; then
  echo "  ❌ skill: ccp-* still present in workflows"
  sed -n '1,3p' <<<"$CCP_WORKFLOWS" | sed 's/^/      /'
  CCP_ISSUES=$((CCP_ISSUES + 1))
else
  echo "  ✅ No skill: ccp-* in workflows"
fi

# Check 3: No ccp-* directories must remain
CCP_DIRS=$(find "$PLUGIN_ROOT/skills" -type d -name "ccp-*" 2>/dev/null || true)
if [ -n "$CCP_DIRS" ]; then
  echo "  ❌ ccp-* directories still present"
  sed -n '1,3p' <<<"$CCP_DIRS" | sed 's/^/      /'
  CCP_ISSUES=$((CCP_ISSUES + 1))
else
  echo "  ✅ No ccp-* directories"
fi

if [ $CCP_ISSUES -eq 0 ]; then
  echo "  ✅ ccp-* skill deprecation OK"
else
  ERRORS=$((ERRORS + CCP_ISSUES))
fi

# ================================
# 10. Skill mirror check
# ================================
echo ""
echo "📦 [10/14] Skill mirror check..."

SKILLS_DIR="$PLUGIN_ROOT/skills"
CODEX_SKILLS_DIR="$PLUGIN_ROOT/skills-codex"
CODEX_MIRROR="$PLUGIN_ROOT/codex/.codex/skills"
OPENCODE_MIRROR="$PLUGIN_ROOT/opencode/skills"
MIRROR_ISSUES=0

# Mirror check for core skills (5-verb harness- prefix + aux)
# SSOT: skills/ → mirror targets: codex/.codex/skills/, opencode/skills/
# NOTE: mirror copies have disable-model-invocation: true added (suppress auto-invocation)
#       This difference is intentional and is excluded from comparisons.
HARNESS_SKILLS="harness-plan harness-work harness-review harness-release harness-setup harness-sync harness-loop"

resolved_ssot_dir() {
  local mirror_name="$1"
  local skill="$2"
  if [ "$mirror_name" = "codex" ] && [ -d "$CODEX_SKILLS_DIR/$skill" ]; then
    printf '%s\n' "$CODEX_SKILLS_DIR/$skill"
    return 0
  fi
  printf '%s\n' "$SKILLS_DIR/$skill"
}

# Mirror comparison helper: diff files excluding disable-model-invocation lines
# Mirror-specific setting (suppress auto-invocation) is an intentional difference and is tolerated.
diff_mirror() {
  local src_dir="$1"
  local mirror_dir="$2"

  # Compare file lists (verify file structure matches)
  local src_files mirror_files
  src_files="$(cd "$src_dir" && find . -type f | sort)"
  mirror_files="$(cd "$mirror_dir" && find . -type f | sort)"
  if [ "$src_files" != "$mirror_files" ]; then
    return 1
  fi

  # Compare each file individually (exclude only disable-model-invocation lines)
  local f compared=0
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if ! diff -q \
      <(grep -v '^disable-model-invocation:' "$src_dir/$f") \
      <(grep -v '^disable-model-invocation:' "$mirror_dir/$f") \
      >/dev/null 2>&1; then
      return 1
    fi
    compared=$((compared + 1))
  done <<< "$src_files"

  # If no file comparisons were performed, fail safe
  [ "$compared" -gt 0 ]
}

for skill in $HARNESS_SKILLS; do
  src="$(resolved_ssot_dir codex "$skill")"
  if [ ! -d "$src" ]; then
    echo "  ❌ $(basename "$(dirname "$src")")/$skill does not exist (SSOT missing)"
    MIRROR_ISSUES=$((MIRROR_ISSUES + 1))
    continue
  fi

  for mirror_name in codex; do
    case "$mirror_name" in
      codex) mirror_root="$CODEX_MIRROR" ;;
    esac

    if [ ! -d "$mirror_root" ]; then
      continue
    fi

    mirror_path="$mirror_root/$skill"
    if [ ! -d "$mirror_path" ]; then
      echo "  ❌ $mirror_name: $skill does not exist as a directory"
      MIRROR_ISSUES=$((MIRROR_ISSUES + 1))
      continue
    fi

    if [ -L "$mirror_path" ]; then
      echo "  ❌ $mirror_name: $skill is still a symlink"
      MIRROR_ISSUES=$((MIRROR_ISSUES + 1))
      continue
    fi

    mirror_src="$(resolved_ssot_dir "$mirror_name" "$skill")"
    if [ ! -d "$mirror_src" ]; then
      echo "  ❌ $mirror_name: SSOT not found (${mirror_src})"
      MIRROR_ISSUES=$((MIRROR_ISSUES + 1))
      continue
    fi

    if diff_mirror "$mirror_src" "$mirror_path"; then
      echo "  ✅ $mirror_name: $skill mirror is in sync"
    else
      echo "  ❌ $mirror_name: $skill mirror is out of sync with SSOT"
      MIRROR_ISSUES=$((MIRROR_ISSUES + 1))
    fi
  done
done

if [ -d "$OPENCODE_MIRROR" ]; then
  if node "$PLUGIN_ROOT/scripts/validate-opencode.js" >/dev/null 2>&1; then
    echo "  ✅ opencode: generated skill mirror is valid"
  else
    echo "  ❌ opencode: generated skill mirror validation failed"
    MIRROR_ISSUES=$((MIRROR_ISSUES + 1))
  fi
fi

if [ $MIRROR_ISSUES -gt 0 ]; then
  ERRORS=$((ERRORS + MIRROR_ISSUES))
fi

# Codex and OpenCode mirrors are archived — skip mirror sync checks for non-Claude surfaces.

# ================================
# 10.5 Skill orchestration design contract
# ================================
echo ""
echo "🧭 [10.5/14] Skill orchestration design contract..."

SKILL_DESIGN_LOG="$(mktemp "${TMPDIR:-/tmp}/harness-skill-design.XXXXXX")"
if bash "$PLUGIN_ROOT/tests/test-skill-design-contract.sh" >"$SKILL_DESIGN_LOG" 2>&1; then
  echo "  ✅ core skill design metadata is consistent"
else
  echo "  ❌ core skill design metadata check failed"
  sed 's/^/      /' "$SKILL_DESIGN_LOG" | tail -80
  ERRORS=$((ERRORS + 1))
fi
rm -f "$SKILL_DESIGN_LOG"

# ================================
# 10.6 Weak-supervision contract tests
# ================================
echo ""
echo "🧪 [10.6/14] Weak-supervision contract tests..."

WEAK_SUPERVISION_LOG="$(mktemp "${TMPDIR:-/tmp}/harness-weak-supervision.XXXXXX")"
if bash "$PLUGIN_ROOT/tests/test-weak-supervision-report.sh" >"$WEAK_SUPERVISION_LOG" 2>&1; then
  echo "  ✅ weak-supervision report/schema fixtures pass"
else
  echo "  ❌ weak-supervision report/schema fixture check failed"
  sed 's/^/      /' "$WEAK_SUPERVISION_LOG" | tail -80
  ERRORS=$((ERRORS + 1))
fi
rm -f "$WEAK_SUPERVISION_LOG"

# ================================
# 11. CHANGELOG format validation
# ================================
echo ""
echo "📝 [11/14] CHANGELOG format validation..."

CHANGELOG_ISSUES=0

for changelog in "$PLUGIN_ROOT/CHANGELOG.md" "$PLUGIN_ROOT/CHANGELOG_ja.md"; do
  if [ ! -f "$changelog" ]; then
    continue
  fi

  cl_name=$(basename "$changelog")

  # Check 1: Keep a Changelog header (## [x.y.z] - YYYY-MM-DD format)
  BAD_DATES=$(grep -nE '^\#\# \[[0-9]' "$changelog" | grep -vE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | grep -v "Unreleased" || true)
  if [ -n "$BAD_DATES" ]; then
    echo "  ❌ $cl_name: entries not using ISO 8601 dates"
    sed -n '1,3p' <<<"$BAD_DATES" | sed 's/^/      /'
    CHANGELOG_ISSUES=$((CHANGELOG_ISSUES + 1))
  fi

  # Check 2: Non-standard section headings (outside the 6 types defined in Keep a Changelog 1.1.0)
  NON_STANDARD=$(grep -nE '^\#\#\# ' "$changelog" \
    | grep -viE '(Added|Changed|Deprecated|Removed|Fixed|Security|What.*Changed|あなたにとって)' \
    | grep -viE '(Internal|Breaking|Migration|Summary|Before)' \
    || true)
  if [ -n "$NON_STANDARD" ]; then
    echo "  ⚠️ $cl_name: non-standard section headings (review recommended)"
    sed -n '1,3p' <<<"$NON_STANDARD" | sed 's/^/      /'
    # Warning only (not an error)
  fi

  # Check 3: [Unreleased] section must exist
  if ! grep -q '^\#\# \[Unreleased\]' "$changelog"; then
    echo "  ❌ $cl_name: [Unreleased] section is missing"
    CHANGELOG_ISSUES=$((CHANGELOG_ISSUES + 1))
  fi
done

if [ $CHANGELOG_ISSUES -eq 0 ]; then
  echo "  ✅ CHANGELOG format OK"
else
  ERRORS=$((ERRORS + CHANGELOG_ISSUES))
fi

# ================================
# 12. README claim drift check
# ================================
echo ""
echo "📚 [12/14] README claim drift check..."

README_ISSUES=0
README_EN="$PLUGIN_ROOT/README.md"
SCOPE_DOC="$PLUGIN_ROOT/docs/distribution-scope.md"
RUBRIC_DOC="$PLUGIN_ROOT/docs/benchmark-rubric.md"
WORK_ALL_DOC="$PLUGIN_ROOT/docs/evidence/work-all.md"

check_fixed_string() {
  local file_path="$1"
  local needle="$2"
  local label="$3"

  if [ ! -f "$file_path" ]; then
    echo "  ❌ ${label}: file does not exist: $file_path"
    README_ISSUES=$((README_ISSUES + 1))
    return
  fi

  if grep -qF "$needle" "$file_path"; then
    echo "  ✅ ${label}"
  else
    echo "  ❌ ${label}: required string not found"
    README_ISSUES=$((README_ISSUES + 1))
  fi
}

check_absent_string() {
  local file_path="$1"
  local needle="$2"
  local label="$3"

  if [ ! -f "$file_path" ]; then
    echo "  ❌ ${label}: file does not exist: $file_path"
    README_ISSUES=$((README_ISSUES + 1))
    return
  fi

  if grep -qF "$needle" "$file_path"; then
    echo "  ❌ ${label}: outdated claim still present"
    README_ISSUES=$((README_ISSUES + 1))
  else
    echo "  ✅ ${label}"
  fi
}

check_exists() {
  local file_path="$1"
  local label="$2"

  if [ -f "$file_path" ]; then
    echo "  ✅ ${label}"
  else
    echo "  ❌ ${label}: file does not exist"
    README_ISSUES=$((README_ISSUES + 1))
  fi
}

# Fork-specific checks (replaced upstream public-release checks)
check_fixed_string "$README_EN" "Internal fork" "README.md internal-fork declaration"
check_fixed_string "$README_EN" "Claude Code" "README.md Claude Code-first target"
check_fixed_string "$README_EN" "archived and out of scope" "README.md marks non-Claude runtimes as archived"
check_fixed_string "$README_EN" "archive/" "README.md references archive/ for non-Claude surfaces"
check_absent_string "$README_EN" "img.shields.io/github/v/release/Chachamaru127" "README.md upstream public release badge absent"
check_absent_string "$README_EN" "Production-ready code." "README.md stale production-ready wording"

# Plugin name must be company-ai-harness
PLUGIN_NAME_CHECK=$(python3 -c "import json; d=json.load(open('$PLUGIN_JSON')); print(d.get('name',''))" 2>/dev/null || echo "")
if [ "$PLUGIN_NAME_CHECK" = "company-ai-harness" ]; then
  echo "  ✅ plugin.json name: $PLUGIN_NAME_CHECK"
else
  echo "  ❌ plugin.json name unexpected: '$PLUGIN_NAME_CHECK' (expected: company-ai-harness)"
  README_ISSUES=$((README_ISSUES + 1))
fi

# hooks/hooks.json must be valid JSON
if [ -f "$HOOKS_JSON" ] && python3 -c "import json; json.load(open('$HOOKS_JSON'))" 2>/dev/null; then
  echo "  ✅ hooks/hooks.json is valid JSON"
elif [ ! -f "$HOOKS_JSON" ]; then
  echo "  ❌ hooks/hooks.json does not exist"
  README_ISSUES=$((README_ISSUES + 1))
else
  echo "  ❌ hooks/hooks.json is not valid JSON"
  README_ISSUES=$((README_ISSUES + 1))
fi

# Archived non-Claude surfaces must not remain at top level
ARCHIVE_TOP_LEVEL_ISSUES=0
for archived_root in codex opencode ".cursor" ".codex-plugin"; do
  if [ -d "$PLUGIN_ROOT/$archived_root" ]; then
    echo "  ❌ archived surface '$archived_root' at top level (should be under archive/)"
    ARCHIVE_TOP_LEVEL_ISSUES=$((ARCHIVE_TOP_LEVEL_ISSUES + 1))
  fi
done
if [ $ARCHIVE_TOP_LEVEL_ISSUES -eq 0 ]; then
  echo "  ✅ archived non-Claude surfaces not at top level"
else
  README_ISSUES=$((README_ISSUES + ARCHIVE_TOP_LEVEL_ISSUES))
fi

check_exists "$SCOPE_DOC" "distribution-scope.md"
check_exists "$RUBRIC_DOC" "benchmark-rubric.md"
check_exists "$WORK_ALL_DOC" "work-all evidence doc"

check_fixed_string "$SCOPE_DOC" '| `commands/` | Compatibility-retained |' "distribution-scope commands classification"
check_fixed_string "$SCOPE_DOC" '| `mcp-server/` | Development-only and distribution-excluded |' "distribution-scope mcp-server classification"
check_fixed_string "$RUBRIC_DOC" "| Static evidence |" "benchmark-rubric static evidence"
check_fixed_string "$RUBRIC_DOC" "| Executed evidence |" "benchmark-rubric executed evidence"

if [ $README_ISSUES -eq 0 ]; then
  echo "  ✅ README claim drift check OK"
else
  ERRORS=$((ERRORS + README_ISSUES))
fi

# ================================
# 13. EN/JA visual sync check
# ================================
echo ""
echo "🎨 [13/14] EN/JA visual sync check..."

VISUAL_EN_DIR="$PLUGIN_ROOT/assets/readme-visuals-en/generated"
VISUAL_JA_DIR="$PLUGIN_ROOT/assets/readme-visuals-ja/generated"
VISUAL_ISSUES=0

if [ -d "$VISUAL_EN_DIR" ] && [ -d "$VISUAL_JA_DIR" ]; then
  # Verify that files present in EN also exist in JA with matching viewBox sizes
  for en_svg in "$VISUAL_EN_DIR"/*.svg; do
    [ ! -f "$en_svg" ] && continue
    svg_name=$(basename "$en_svg")
    ja_svg="$VISUAL_JA_DIR/$svg_name"

    if [ ! -f "$ja_svg" ]; then
      echo "  ❌ JA version missing: $svg_name"
      VISUAL_ISSUES=$((VISUAL_ISSUES + 1))
      continue
    fi

    # Compare viewBox height (detect major structural divergence)
    en_viewbox=$(grep -o 'viewBox="[^"]*"' "$en_svg" | head -1)
    ja_viewbox=$(grep -o 'viewBox="[^"]*"' "$ja_svg" | head -1)
    if [ "$en_viewbox" != "$ja_viewbox" ]; then
      echo "  ⚠️ viewBox mismatch: $svg_name (EN: $en_viewbox / JA: $ja_viewbox)"
      # Warning only (height differences are tolerated because Japanese characters have different widths)
    fi

    # Compare table row count (quick check using number of <rect y= elements)
    en_rows=$(grep -c '<rect y=' "$en_svg" 2>/dev/null || echo 0)
    ja_rows=$(grep -c '<rect y=' "$ja_svg" 2>/dev/null || echo 0)
    if [ "$en_rows" != "$ja_rows" ]; then
      echo "  ❌ Row count mismatch: $svg_name (EN: ${en_rows} rows / JA: ${ja_rows} rows)"
      VISUAL_ISSUES=$((VISUAL_ISSUES + 1))
    else
      echo "  ✅ $svg_name (${en_rows} rows)"
    fi
  done
else
  echo "  ⚠️ EN/JA visual directories not found (skipped)"
fi

if [ $VISUAL_ISSUES -gt 0 ]; then
  ERRORS=$((ERRORS + VISUAL_ISSUES))
fi

# ================================
# 14. i18n regression gate
# ================================
echo ""
echo "🌐 [14/14] i18n regression gate..."

I18N_ISSUES=0

run_i18n_gate() {
  local label="$1"
  shift

  local log_file
  log_file="$(mktemp "${TMPDIR:-/tmp}/harness-i18n-gate.XXXXXX")"

  if "$@" >"$log_file" 2>&1; then
    echo "  ✅ $label"
  else
    echo "  ❌ $label"
    sed 's/^/      /' "$log_file" | tail -80
    I18N_ISSUES=$((I18N_ISSUES + 1))
  fi

  rm -f "$log_file"
}

run_i18n_gate "translation metadata" \
  bash "$PLUGIN_ROOT/scripts/i18n/check-translations.sh"
run_i18n_gate "English default config/schema surfaces" \
  bash "$PLUGIN_ROOT/tests/test-i18n-default-language.sh"
run_i18n_gate "skill frontmatter bilingual metadata" \
  bash "$PLUGIN_ROOT/tests/test-i18n-skill-frontmatter.sh"
run_i18n_gate "locale roundtrip idempotency" \
  bash "$PLUGIN_ROOT/tests/test-i18n-locale-roundtrip.sh"
run_i18n_gate "setup language rendering" \
  bash "$PLUGIN_ROOT/tests/test-setup-language-rendering.sh"
run_i18n_gate "Japanese UX opt-in surfaces" \
  bash "$PLUGIN_ROOT/tests/test-i18n-japanese-ux-regression.sh"

if [ $I18N_ISSUES -eq 0 ]; then
  echo "  ✅ i18n regression gate OK"
else
  ERRORS=$((ERRORS + I18N_ISSUES))
fi

# ================================
# Result summary
# ================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $ERRORS -eq 0 ]; then
  echo "✅ All checks passed"
  exit 0
else
  echo "❌ $ERRORS issues found"
  exit 1
fi
