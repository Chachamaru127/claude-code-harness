#!/bin/bash
# release-preflight.sh
# Vendor-neutral pre-release verification for Harness release flow.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="${HARNESS_RELEASE_PROJECT_ROOT:-$DEFAULT_ROOT}"

if [ "${1:-}" = "--help" ]; then
  cat <<'EOF'
Usage: scripts/release-preflight.sh [--root PATH] [--dry-run]
       scripts/release-preflight.sh [--root PATH] [--check-adapters|--skip-adapters]

Checks:
  - git worktree cleanliness
  - CHANGELOG.md / [Unreleased]
  - env parity / healthcheck
  - runtime residual scan
  - sprint-contract schema
  - opencode / skill mirror drift when adapter paths, release claims, or explicit flags require it
  - CI status when available
EOF
  exit 0
fi

CHECK_ADAPTERS_MODE="${HARNESS_RELEASE_CHECK_ADAPTERS:-auto}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      if [ "${2:-}" = "" ]; then
        echo "error: --root requires a path" >&2
        exit 2
      fi
      PROJECT_ROOT="$2"
      shift 2
      ;;
    --dry-run)
      shift
      ;;
    --check-adapters)
      CHECK_ADAPTERS_MODE="always"
      shift
      ;;
    --skip-adapters)
      CHECK_ADAPTERS_MODE="never"
      shift
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

case "$CHECK_ADAPTERS_MODE" in
  1|true|TRUE|yes|YES|always)
    CHECK_ADAPTERS_MODE="always"
    ;;
  0|false|FALSE|no|NO|never)
    CHECK_ADAPTERS_MODE="never"
    ;;
  ""|auto)
    CHECK_ADAPTERS_MODE="auto"
    ;;
  *)
    echo "error: invalid adapter check mode: $CHECK_ADAPTERS_MODE" >&2
    exit 2
    ;;
esac

if [ ! -d "$PROJECT_ROOT" ]; then
  echo "error: project root not found: $PROJECT_ROOT" >&2
  exit 1
fi

cd "$PROJECT_ROOT"

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

pass() {
  echo -e "[PASS] $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

warn() {
  echo -e "[WARN] $1"
  WARN_COUNT=$((WARN_COUNT + 1))
}

fail() {
  echo -e "[FAIL] $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

run_optional_command() {
  local label="$1"
  local command_text="$2"
  local output_file
  output_file="$(mktemp)"

  if bash -lc "$command_text" >"$output_file" 2>&1; then
    pass "$label"
  else
    fail "$label"
    sed 's/^/  /' "$output_file"
  fi

  rm -f "$output_file"
}

extract_env_keys() {
  local file="$1"
  awk -F= '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    {
      line=$0
      sub(/^[[:space:]]*export[[:space:]]+/, "", line)
      split(line, parts, "=")
      key=parts[1]
      gsub(/[[:space:]]+$/, "", key)
      if (key ~ /^[A-Za-z_][A-Za-z0-9_]*$/) {
        print key
      }
    }
  ' "$file" | sort -u
}

check_git_clean() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    fail "git worktree"
    return
  fi

  local status
  status="$(git status --porcelain --untracked-files=normal)"
  if [ -n "$status" ]; then
    fail "working tree clean"
    printf '%s\n' "$status" | sed 's/^/  /'
  else
    pass "working tree clean"
  fi
}

check_changelog() {
  if [ ! -f CHANGELOG.md ]; then
    fail "CHANGELOG.md exists"
    return
  fi

  if grep -q '^\## \[Unreleased\]' CHANGELOG.md; then
    pass "CHANGELOG.md has [Unreleased]"
  else
    fail "CHANGELOG.md has [Unreleased]"
  fi
}

check_release_version_sync() {
  if [ ! -f ".claude-plugin/plugin.json" ] && [ ! -f ".claude-plugin/marketplace.json" ]; then
    warn "release version sync skipped (not a Claude plugin project)"
    return
  fi

  local helper="${SCRIPT_DIR}/check-release-version-sync.py"
  if [ ! -f "$helper" ]; then
    fail "release version sync helper"
    printf '  missing: %s\n' "$helper"
    return
  fi

  local output_file
  output_file="$(mktemp)"
  if python3 "$helper" --root "$PROJECT_ROOT" >"$output_file" 2>&1; then
    pass "release version sync"
  else
    fail "release version sync"
    sed 's/^/  /' "$output_file"
  fi
  rm -f "$output_file"
}

check_cch_branch_protection_policy() {
  if [ -n "${HARNESS_RELEASE_BRANCH_PROTECTION_CMD:-}" ]; then
    run_optional_command "CCH branch protection policy" "$HARNESS_RELEASE_BRANCH_PROTECTION_CMD"
    return
  fi

  if [ ! -x scripts/check-cch-branch-protection-policy.sh ]; then
    warn "CCH branch protection policy skipped"
    return
  fi

  local output_file
  output_file="$(mktemp)"
  if bash scripts/check-cch-branch-protection-policy.sh >"$output_file" 2>&1; then
    pass "CCH branch protection policy"
  else
    if grep -Fq "Resource not accessible by integration" "$output_file"; then
      warn "CCH branch protection policy unavailable to GitHub Actions token"
      sed 's/^/  /' "$output_file"
    else
      fail "CCH branch protection policy"
      sed 's/^/  /' "$output_file"
    fi
  fi
  rm -f "$output_file"
}

check_env_and_healthcheck() {
  local env_ok=1

  if [ -f .env.example ]; then
    if [ ! -f .env ]; then
      warn ".env missing for .env.example"
      env_ok=0
    else
      local missing
      missing="$(
        comm -23 \
          <(extract_env_keys .env.example) \
          <(extract_env_keys .env)
      )"
      if [ -n "$missing" ]; then
        fail ".env matches .env.example"
        printf '%s\n' "$missing" | sed 's/^/  missing: /'
        env_ok=0
      else
        pass ".env matches .env.example"
      fi
    fi
  else
    warn ".env.example not found; env parity skipped"
  fi

  if [ -n "${HARNESS_RELEASE_HEALTHCHECK_CMD:-}" ]; then
    run_optional_command "healthcheck command" "$HARNESS_RELEASE_HEALTHCHECK_CMD"
    return
  fi

  if [ -f package.json ]; then
    local has_healthcheck=0
    local has_preflight=0

    if node -e 'const fs=require("fs"); const pkg=JSON.parse(fs.readFileSync("package.json","utf8")); process.exit(pkg.scripts && pkg.scripts.healthcheck ? 0 : 1)' >/dev/null 2>&1; then
      has_healthcheck=1
    fi

    if node -e 'const fs=require("fs"); const pkg=JSON.parse(fs.readFileSync("package.json","utf8")); process.exit(pkg.scripts && pkg.scripts.preflight ? 0 : 1)' >/dev/null 2>&1; then
      has_preflight=1
    fi

    if [ "$has_healthcheck" -eq 1 ]; then
      run_optional_command "healthcheck command" "npm run healthcheck --silent"
      return
    fi

    if [ "$has_preflight" -eq 1 ]; then
      run_optional_command "healthcheck command" "npm run preflight --silent"
      return
    fi
  fi

  if [ "$env_ok" -eq 1 ]; then
    warn "healthcheck command not configured"
  elif [ ! -f .env ] && [ -f .env.example ]; then
    warn "healthcheck command not configured"
  fi
}

check_runtime_residuals() {
  local residual_patterns="${HARNESS_RELEASE_RESIDUAL_PATTERNS:-mockData|dummy|fakeData|localhost|TODO|FIXME|test\\.skip|describe\\.skip|it\\.skip}"
  local files=()
  local file

  while IFS= read -r -d '' file; do
    case "$file" in
      agents/*|core/*|hooks/*|scripts/*)
        if [ "$file" = "scripts/release-preflight.sh" ]; then
          continue
        fi
        files+=("$file")
        ;;
      *)
        continue
        ;;
    esac
  done < <(git ls-files -z)

  if [ "${#files[@]}" -eq 0 ]; then
    warn "runtime residual scan skipped"
    return
  fi

  local matches
  if command -v rg >/dev/null 2>&1; then
    matches="$(rg -n -I --no-heading -e "$residual_patterns" -- "${files[@]}" 2>/dev/null || true)"
  else
    matches="$(grep -nIH -E "$residual_patterns" -- "${files[@]}" 2>/dev/null || true)"
  fi
  if [ -n "$matches" ]; then
    warn "runtime residual scan"
    sed -n '1,20p' <<<"$matches" | sed 's/^/  /'
  else
    pass "runtime residual scan"
  fi
}

check_sprint_contract_schema() {
  local contract_dir=".claude/state/contracts"

  if [ ! -d "$contract_dir" ]; then
    warn "sprint-contract schema scan skipped"
    return
  fi

  local contract_files=()
  local file
  while IFS= read -r file; do
    contract_files+=("$file")
  done < <(find "$contract_dir" -type f -name '*.sprint-contract.json' | sort)

  if [ "${#contract_files[@]}" -eq 0 ]; then
    warn "sprint-contract schema scan skipped"
    return
  fi

  local output_file
  output_file="$(mktemp)"

  if node - "${contract_files[@]}" >"$output_file" 2>&1 <<'NODE'
const fs = require('fs');

const files = process.argv.slice(2);
const allowedProfiles = new Set(['static', 'runtime', 'browser', 'security', 'ui-rubric']);
const allowedLoopPacing = new Set(['worker', 'ci', 'plateau', 'night']);
const allowedBrowserVerdicts = new Set([
  'APPROVE',
  'REQUEST_CHANGES',
  'PENDING_BROWSER',
  'SKIPPED',
  'DOWNGRADE_TO_STATIC',
]);

let hasErrors = false;

function report(file, issues) {
  if (issues.length === 0) {
    return;
  }

  hasErrors = true;
  console.log(file);
  for (const issue of issues) {
    console.log(`  - ${issue}`);
  }
}

for (const file of files) {
  let contract;
  try {
    contract = JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (error) {
    report(file, [`invalid JSON: ${error.message}`]);
    continue;
  }

  const review = contract.review || {};
  const issues = [];

  if (!allowedProfiles.has(review.reviewer_profile)) {
    issues.push(
      `review.reviewer_profile must be one of ${Array.from(allowedProfiles).join('|')}; got ${JSON.stringify(review.reviewer_profile)}`
    );
  }

  if (review.max_iterations !== undefined) {
    if (!Number.isInteger(review.max_iterations) || review.max_iterations < 1 || review.max_iterations > 30) {
      issues.push(`review.max_iterations must be an integer between 1 and 30; got ${JSON.stringify(review.max_iterations)}`);
    }
  }

  if (review.rubric_target !== undefined) {
    const target = review.rubric_target;
    if (target === null || Array.isArray(target) || typeof target !== 'object') {
      issues.push('review.rubric_target must be an object');
    } else {
      for (const [key, value] of Object.entries(target)) {
        if (typeof value !== 'number' || Number.isNaN(value)) {
          issues.push(`review.rubric_target.${key} must be numeric; got ${JSON.stringify(value)}`);
        }
      }
    }
  }

  if (review.loop_pacing !== undefined) {
    if (typeof review.loop_pacing !== 'string' || !allowedLoopPacing.has(review.loop_pacing)) {
      issues.push(`review.loop_pacing must be one of ${Array.from(allowedLoopPacing).join('|')}; got ${JSON.stringify(review.loop_pacing)}`);
    }
  }

  if (review.browser_verdict !== undefined) {
    if (typeof review.browser_verdict !== 'string' || !allowedBrowserVerdicts.has(review.browser_verdict)) {
      issues.push(
        `review.browser_verdict must be one of ${Array.from(allowedBrowserVerdicts).join('|')}; got ${JSON.stringify(review.browser_verdict)}`
      );
    }
  }

  report(file, issues);
}

process.exit(hasErrors ? 1 : 0);
NODE
  then
    pass "sprint-contract schema (${#contract_files[@]} files)"
  else
    fail "sprint-contract schema"
    sed 's/^/  /' "$output_file"
  fi

  rm -f "$output_file"
}

adapter_gate_paths=(
  "adapters/"
  ".codex-plugin/"
  ".cursor-plugin/"
  ".cursor/AGENTS.md"
  ".cursor/agents/"
  ".cursor/hooks.json"
  ".cursor/mcp.json"
  "codex/"
  "skills-codex/"
  "opencode/"
  ".github/workflows/opencode-compat.yml"
  "docs/architecture/hokage-core.md"
  "docs/distribution-scope.md"
  "docs/hardening-parity.md"
  "docs/hokage-spin-off-readiness.md"
  "docs/research/cursor-adapter-candidate.md"
  "docs/CURSOR_INTEGRATION.md"
  "docs/skill-orchestration-design-contract.md"
  "scripts/build-opencode.js"
  "scripts/generate-skill-manifest.sh"
  "scripts/model-routing.sh"
  "scripts/sync-skill-mirrors.sh"
  "scripts/validate-opencode.js"
  "tests/test-codex-package.sh"
  "tests/test-codex-plugin-adapter.sh"
  "tests/test-cursor-adapter-candidate.sh"
  "tests/test-opencode-bootstrap-plugin.sh"
  "tests/test-bootstrap-skill-trigger-acceptance.sh"
  "tests/test-distribution-archive.sh"
  "tests/test-hokage-spin-off-readiness.sh"
  "tests/test-skill-design-contract.sh"
)

normalize_changed_paths() {
  local output_file="$1"
  local sorted_file
  sorted_file="$(mktemp)"
  sort -u "$output_file" >"$sorted_file"
  mv "$sorted_file" "$output_file"
}

append_changed_paths() {
  local output_file="$1"
  shift
  git "$@" -- "${adapter_gate_paths[@]}" >>"$output_file" 2>/dev/null || true
}

adapter_paths_changed() {
  local output_file="$1"
  : >"$output_file"

  append_changed_paths "$output_file" diff --name-only
  append_changed_paths "$output_file" diff --name-only --cached
  append_changed_paths "$output_file" ls-files --others --exclude-standard

  local base_ref="${HARNESS_RELEASE_ADAPTER_BASE_REF:-}"
  if [ -z "$base_ref" ]; then
    base_ref="$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
  fi
  if [ -z "$base_ref" ] && git rev-parse --verify --quiet origin/main >/dev/null 2>&1; then
    base_ref="origin/main"
  fi
  if [ -n "$base_ref" ] && git rev-parse --verify --quiet "${base_ref}^{commit}" >/dev/null 2>&1; then
    append_changed_paths "$output_file" diff --name-only "${base_ref}...HEAD"
  fi

  normalize_changed_paths "$output_file"
  [ -s "$output_file" ]
}

release_claims_adapter_support() {
  if [ "${HARNESS_RELEASE_CLAIMS_ADAPTERS:-}" = "1" ] || [ "${HARNESS_RELEASE_CLAIMS_ADAPTERS:-}" = "true" ]; then
    return 0
  fi

  if [ ! -f CHANGELOG.md ]; then
    return 1
  fi

  local unreleased
  unreleased="$(awk '
    /^## \[Unreleased\]/ { in_unreleased=1; next }
    /^## \[/ { in_unreleased=0 }
    in_unreleased { print }
  ' CHANGELOG.md)"

  printf '%s\n' "$unreleased" | grep -Eiq 'OpenCode|Codex|Cursor|adapter|mirror|multi-harness|Hokage Core|capability matrix'
}

should_run_adapter_gates() {
  case "$CHECK_ADAPTERS_MODE" in
    always)
      echo "[INFO] adapter gates enabled by explicit flag"
      return 0
      ;;
    never)
      warn "release mirror drift skipped by explicit adapter gate flag"
      return 1
      ;;
  esac

  local changed_paths
  changed_paths="$(mktemp)"
  if adapter_paths_changed "$changed_paths"; then
    echo "[INFO] adapter gates enabled by adapter-relevant paths"
    sed -n '1,20p' "$changed_paths" | sed 's/^/  /'
    rm -f "$changed_paths"
    return 0
  fi
  rm -f "$changed_paths"

  if release_claims_adapter_support; then
    echo "[INFO] adapter gates enabled by release adapter claim"
    return 0
  fi

  warn "release mirror drift skipped (no adapter path changes or release adapter claim; use --check-adapters to force)"
  return 1
}

check_release_mirror_drift() {
  if ! should_run_adapter_gates; then
    return
  fi

  local has_mirror_surface=0
  [ -d opencode ] && has_mirror_surface=1
  [ -d skills-codex ] && has_mirror_surface=1
  [ -d codex/.codex/skills ] && has_mirror_surface=1

  if [ "$has_mirror_surface" -eq 0 ]; then
    warn "release mirror drift skipped"
    return
  fi

  local missing=0
  for helper in scripts/build-opencode.js scripts/validate-opencode.js scripts/sync-skill-mirrors.sh; do
    if [ ! -f "$helper" ]; then
      fail "release mirror helper: $helper"
      missing=1
    fi
  done
  if [ "$missing" -ne 0 ]; then
    return
  fi

  local output_file
  output_file="$(mktemp)"

  if node scripts/build-opencode.js >"$output_file" 2>&1; then
    pass "release mirror build"
  else
    fail "release mirror build"
    sed 's/^/  /' "$output_file"
    rm -f "$output_file"
    return
  fi

  if node scripts/validate-opencode.js >"$output_file" 2>&1; then
    pass "opencode mirror validation"
  else
    fail "opencode mirror validation"
    sed 's/^/  /' "$output_file"
  fi

  if bash scripts/sync-skill-mirrors.sh --check >"$output_file" 2>&1; then
    pass "skill mirror sync check"
  else
    fail "skill mirror sync check"
    sed 's/^/  /' "$output_file"
  fi

  rm -f "$output_file"

  local diff_paths=()
  [ -d opencode ] && diff_paths+=("opencode/")
  [ -d skills-codex ] && diff_paths+=("skills-codex/")
  [ -d codex/.codex/skills ] && diff_paths+=("codex/.codex/skills/")

  if git diff --quiet -- "${diff_paths[@]}"; then
    pass "release mirror drift"
  else
    fail "release mirror drift"
    git diff --stat -- "${diff_paths[@]}" | sed 's/^/  /'
  fi

  output_file="$(mktemp)"

  if [ -f tests/test-codex-package.sh ]; then
    if bash tests/test-codex-package.sh >"$output_file" 2>&1; then
      pass "codex package gate"
    else
      fail "codex package gate"
      sed 's/^/  /' "$output_file"
    fi
  else
    warn "codex package gate skipped"
  fi

  if [ -f tests/test-codex-plugin-adapter.sh ]; then
    if bash tests/test-codex-plugin-adapter.sh >"$output_file" 2>&1; then
      pass "codex plugin adapter smoke"
    else
      fail "codex plugin adapter smoke"
      sed 's/^/  /' "$output_file"
    fi
  else
    fail "codex plugin adapter smoke"
    printf '  missing: tests/test-codex-plugin-adapter.sh\n'
  fi

  if [ -f tests/test-opencode-bootstrap-plugin.sh ]; then
    if bash tests/test-opencode-bootstrap-plugin.sh >"$output_file" 2>&1; then
      pass "opencode bootstrap smoke"
    else
      fail "opencode bootstrap smoke"
      sed 's/^/  /' "$output_file"
    fi
  else
    fail "opencode bootstrap smoke"
    printf '  missing: tests/test-opencode-bootstrap-plugin.sh\n'
  fi

  if [ -f tests/test-cursor-adapter-candidate.sh ]; then
    if bash tests/test-cursor-adapter-candidate.sh >"$output_file" 2>&1; then
      pass "cursor adapter candidate smoke"
    else
      fail "cursor adapter candidate smoke"
      sed 's/^/  /' "$output_file"
    fi
  else
    fail "cursor adapter candidate smoke"
    printf '  missing: tests/test-cursor-adapter-candidate.sh\n'
  fi

  if [ -f tests/test-distribution-archive.sh ]; then
    if bash tests/test-distribution-archive.sh >"$output_file" 2>&1; then
      pass "distribution archive gate"
    else
      fail "distribution archive gate"
      sed 's/^/  /' "$output_file"
    fi
  else
    warn "distribution archive gate skipped"
  fi

  if [ -f tests/test-tool-capability-matrix.sh ]; then
    if bash tests/test-tool-capability-matrix.sh >"$output_file" 2>&1; then
      pass "tool capability matrix gate"
    else
      fail "tool capability matrix gate"
      sed 's/^/  /' "$output_file"
    fi
  else
    warn "tool capability matrix gate skipped"
  fi

  if [ -f tests/test-bootstrap-routing-contract.sh ]; then
    if bash tests/test-bootstrap-routing-contract.sh >"$output_file" 2>&1; then
      pass "bootstrap routing gate"
    else
      fail "bootstrap routing gate"
      sed 's/^/  /' "$output_file"
    fi
  else
    warn "bootstrap routing gate skipped"
  fi

  if [ -f tests/test-bootstrap-skill-trigger-acceptance.sh ]; then
    if bash tests/test-bootstrap-skill-trigger-acceptance.sh >"$output_file" 2>&1; then
      pass "bootstrap skill trigger acceptance gate"
    else
      fail "bootstrap skill trigger acceptance gate"
      sed 's/^/  /' "$output_file"
    fi
  else
    warn "bootstrap skill trigger acceptance gate skipped"
  fi

  if [ -f tests/test-hokage-spin-off-readiness.sh ]; then
    if bash tests/test-hokage-spin-off-readiness.sh >"$output_file" 2>&1; then
      pass "hokage spin-off readiness gate"
    else
      fail "hokage spin-off readiness gate"
      sed 's/^/  /' "$output_file"
    fi
  else
    warn "hokage spin-off readiness gate skipped"
  fi

  rm -f "$output_file"
}

check_ci_status() {
  if [ -n "${HARNESS_RELEASE_CI_STATUS_CMD:-}" ]; then
    run_optional_command "CI status" "$HARNESS_RELEASE_CI_STATUS_CMD"
    return
  fi

  if ! command -v gh >/dev/null 2>&1; then
    warn "CI status unavailable (gh not installed)"
    return
  fi

  local branch
  branch="$(git branch --show-current 2>/dev/null || true)"
  if [ -z "$branch" ] || [ "$branch" = "HEAD" ]; then
    warn "CI status unavailable (detached HEAD)"
    return
  fi

  local gh_output
  gh_output="$(gh run list --branch "$branch" --limit 1 --json status,conclusion 2>/dev/null || true)"
  if [ -z "$gh_output" ] || [ "$(printf '%s' "$gh_output" | tr -d '[:space:]')" = "[]" ]; then
    # Empty array means the branch has never been pushed (or no workflow has
    # run on it yet). Treat as warning rather than fail so first-time release
    # branches can pass preflight; CI will run on push and the release flow
    # can re-check before tagging.
    warn "CI status unavailable (no runs found for branch '$branch' — push to trigger CI)"
    return
  fi

  local status
  local conclusion
  if command -v jq >/dev/null 2>&1; then
    status="$(printf '%s' "$gh_output" | jq -r '.[0].status // empty')"
    conclusion="$(printf '%s' "$gh_output" | jq -r '.[0].conclusion // empty')"
  else
    status="$(printf '%s' "$gh_output" | sed -n 's/.*"status":"\([^"]*\)".*/\1/p' | head -n 1)"
    conclusion="$(printf '%s' "$gh_output" | sed -n 's/.*"conclusion":"\([^"]*\)".*/\1/p' | head -n 1)"
  fi

  if [ "$status" = "completed" ] && [ "$conclusion" = "success" ]; then
    pass "CI status"
  else
    fail "CI status"
    printf '  latest run status=%s conclusion=%s\n' "${status:-unknown}" "${conclusion:-unknown}"
  fi
}

printf 'Release preflight: %s\n' "$PROJECT_ROOT"
echo "----------------------------------------"

check_git_clean
check_changelog
check_release_version_sync
check_cch_branch_protection_policy
check_env_and_healthcheck
check_runtime_residuals
check_sprint_contract_schema
check_release_mirror_drift
check_ci_status

echo "----------------------------------------"
printf 'Summary: %d passed, %d warnings, %d failed\n' "$PASS_COUNT" "$WARN_COUNT" "$FAIL_COUNT"

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi

exit 0
