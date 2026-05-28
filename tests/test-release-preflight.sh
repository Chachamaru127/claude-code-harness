#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  if ! grep -q "$pattern" "$file"; then
    fail "expected pattern '$pattern' in $file"
  fi
}

write_contract() {
  local path="$1"
  local task_id="$2"
  local title="$3"
  local profile="$4"
  local max_iterations="$5"
  local rubric_target="${6:-}"
  local loop_pacing="${7:-}"
  local browser_verdict="${8:-}"

  {
    cat <<EOF
{
  "schema_version": "sprint-contract.v1",
  "generated_at": "2026-04-16T00:00:00Z",
  "source": {
    "plans_file": "Plans.md",
    "task_id": "$task_id"
  },
  "task": {
    "id": "$task_id",
    "title": "$title",
    "definition_of_done": "fixture",
    "depends_on": [],
    "status_at_generation": "cc:TODO"
  },
  "contract": {
    "checks": [
      {
        "id": "dod-primary",
        "source": "Plans.md.DoD",
        "description": "fixture"
      }
    ],
    "non_goals": [],
    "runtime_validation": [],
    "browser_validation": [],
    "risk_flags": []
  },
  "review": {
    "status": "approved",
    "reviewer_profile": "$profile",
    "max_iterations": $max_iterations
EOF

    if [ -n "$rubric_target" ]; then
      printf ',\n    "rubric_target": %s' "$rubric_target"
    fi

    if [ -n "$loop_pacing" ]; then
      printf ',\n    "loop_pacing": "%s"' "$loop_pacing"
    fi

    if [ -n "$browser_verdict" ]; then
      printf ',\n    "browser_verdict": "%s"' "$browser_verdict"
    fi

    cat <<EOF
,
    "reviewer_notes": [],
    "approved_at": "2026-04-16T00:00:00Z",
    "gaps": [],
    "followups": []
  }
}
EOF
  } > "$path"
}

setup_repo() {
  local repo="$1"
  local contract_mode="${2:-valid}"
  local mirror_mode="${3:-synced}"
  mkdir -p "$repo/scripts"
  mkdir -p "$repo/tests"
  mkdir -p "$repo/.claude/state/contracts"
  mkdir -p "$repo/opencode/skills/example"
  mkdir -p "$repo/skills/example"
  mkdir -p "$repo/skills-codex"
  mkdir -p "$repo/codex/.codex/skills/example"
  git init -q "$repo"
  git -C "$repo" config user.name "Test User"
  git -C "$repo" config user.email "test@example.com"

  cat > "$repo/CHANGELOG.md" <<'EOF'
# Changelog

## [Unreleased]

### Added
- Initial release preflight fixture
EOF

  cat > "$repo/.env.example" <<'EOF'
API_URL=https://example.com
API_KEY=
EOF

  cat > "$repo/.env" <<'EOF'
API_URL=https://example.com
API_KEY=secret
EOF

  cat > "$repo/package.json" <<'EOF'
{
  "name": "release-preflight-fixture",
  "private": true,
  "scripts": {
    "healthcheck": "node -e \"process.exit(0)\""
  }
}
EOF

  cat > "$repo/scripts/app.sh" <<'EOF'
#!/bin/bash
echo "ready"
EOF

  cat > "$repo/scripts/release-preflight.sh" <<'EOF'
#!/bin/bash
local residual_patterns="${HARNESS_RELEASE_RESIDUAL_PATTERNS:-mockData|dummy|fakeData|localhost|TODO|FIXME}"
EOF

  cat > "$repo/skills/example/SKILL.md" <<'EOF'
# Example

source skill
EOF

  cat > "$repo/codex/.codex/skills/example/SKILL.md" <<'EOF'
# Example

source skill
EOF

  if [ "$mirror_mode" = "drift" ]; then
    cat > "$repo/opencode/skills/example/SKILL.md" <<'EOF'
# Example

stale mirror
EOF
  else
    cat > "$repo/opencode/skills/example/SKILL.md" <<'EOF'
# Example

generated mirror
EOF
  fi

  cat > "$repo/scripts/build-opencode.js" <<'EOF'
const fs = require('fs');
fs.mkdirSync('opencode/skills/example', { recursive: true });
fs.writeFileSync('opencode/skills/example/SKILL.md', '# Example\n\ngenerated mirror\n', 'utf8');
EOF

  cat > "$repo/scripts/validate-opencode.js" <<'EOF'
const fs = require('fs');
process.exit(fs.existsSync('opencode/skills/example/SKILL.md') ? 0 : 1);
EOF

  cat > "$repo/scripts/sync-skill-mirrors.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
if [ "${1:-}" != "--check" ]; then
  exit 2
fi
exit 0
EOF
  chmod +x "$repo/scripts/sync-skill-mirrors.sh"

  cat > "$repo/tests/test-codex-plugin-adapter.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "codex plugin adapter fixture ok"
EOF
  chmod +x "$repo/tests/test-codex-plugin-adapter.sh"

  cat > "$repo/tests/test-opencode-bootstrap-plugin.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "opencode bootstrap fixture ok"
EOF
  chmod +x "$repo/tests/test-opencode-bootstrap-plugin.sh"

  cat > "$repo/tests/test-cursor-adapter-candidate.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "cursor adapter candidate fixture ok"
EOF
  chmod +x "$repo/tests/test-cursor-adapter-candidate.sh"

  cat > "$repo/tests/test-bootstrap-skill-trigger-acceptance.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "bootstrap skill trigger fixture ok"
EOF
  chmod +x "$repo/tests/test-bootstrap-skill-trigger-acceptance.sh"

  if [ "$contract_mode" = "invalid" ]; then
    write_contract \
      "$repo/.claude/state/contracts/41.4.3-invalid.sprint-contract.json" \
      "41.4.3-invalid" \
      "invalid schema fixture" \
      "browser" \
      "100" \
      "" \
      "worker" \
      "PENDING_BROWSER"
  else
    write_contract \
      "$repo/.claude/state/contracts/41.4.3-static.sprint-contract.json" \
      "41.4.3-static" \
      "static schema fixture" \
      "static" \
      "3"
    write_contract \
      "$repo/.claude/state/contracts/41.4.3-runtime.sprint-contract.json" \
      "41.4.3-runtime" \
      "runtime schema fixture" \
      "runtime" \
      "3" \
      "" \
      "ci"
    write_contract \
      "$repo/.claude/state/contracts/41.4.3-browser.sprint-contract.json" \
      "41.4.3-browser" \
      "browser schema fixture" \
      "browser" \
      "5" \
      "" \
      "worker" \
      "PENDING_BROWSER"
    write_contract \
      "$repo/.claude/state/contracts/41.4.3-security.sprint-contract.json" \
      "41.4.3-security" \
      "security schema fixture" \
      "security" \
      "4" \
      "" \
      "plateau"
    write_contract \
      "$repo/.claude/state/contracts/41.4.3-ui-rubric.sprint-contract.json" \
      "41.4.3-ui-rubric" \
      "ui rubric schema fixture" \
      "ui-rubric" \
      "10" \
      '{"design":7,"originality":6,"craft":8,"functionality":9}' \
      "night"
  fi

  git -C "$repo" add .
  git -C "$repo" commit -qm "initial"
}

test_skill_mentions_preflight() {
  assert_contains "$PROJECT_ROOT/skills/harness-release/SKILL.md" "HARNESS_RELEASE_HEALTHCHECK_CMD"
  assert_contains "$PROJECT_ROOT/skills/harness-release/SKILL.md" "dry-run"
  assert_contains "$PROJECT_ROOT/skills/harness-release/SKILL.md" "mirror drift"
  assert_contains "$PROJECT_ROOT/docs/release-preflight.md" "scripts/release-preflight.sh"
}

test_doc_mentions_overrides() {
  assert_contains "$PROJECT_ROOT/docs/release-preflight.md" "HARNESS_RELEASE_PROJECT_ROOT"
  assert_contains "$PROJECT_ROOT/docs/release-preflight.md" "HARNESS_RELEASE_CI_STATUS_CMD"
  assert_contains "$PROJECT_ROOT/docs/release-preflight.md" "actions/checkout@v6"
  assert_contains "$PROJECT_ROOT/docs/release-preflight.md" "actions/setup-go@v6"
  assert_contains "$PROJECT_ROOT/docs/release-preflight.md" ".github/workflows/release.yml"
  assert_contains "$PROJECT_ROOT/docs/release-preflight.md" "git archive HEAD"
}

test_release_workflow_runs_preflight_before_assets() {
  local workflow="$PROJECT_ROOT/.github/workflows/release.yml"

  assert_contains "$workflow" "Run release preflight"
  assert_contains "$workflow" "bash ./scripts/release-preflight.sh --check-adapters"
  assert_contains "$workflow" "Create GitHub Release"
  assert_contains "$workflow" "Upload Go binaries to existing release"

  python3 - "$workflow" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
preflight = text.index("Run release preflight")
create = text.index("Create GitHub Release")
upload = text.index("Upload Go binaries to existing release")

if not preflight < create:
    raise SystemExit("release preflight must run before GitHub Release creation")

if not preflight < upload:
    raise SystemExit("release preflight must run before release asset upload")
PY
}

test_preflight_pass_and_fail() {
  local repo="$TMP_DIR/release-preflight-repo"
  setup_repo "$repo" valid

  local success_output="$TMP_DIR/success.txt"
  HARNESS_RELEASE_PROJECT_ROOT="$repo" \
  HARNESS_RELEASE_HEALTHCHECK_CMD='true' \
  HARNESS_RELEASE_CI_STATUS_CMD='true' \
  HARNESS_RELEASE_BRANCH_PROTECTION_CMD='true' \
    "$PROJECT_ROOT/scripts/release-preflight.sh" --check-adapters >"$success_output"

  assert_contains "$success_output" "\\[PASS\\] working tree clean"
  assert_contains "$success_output" "\\[PASS\\] CHANGELOG.md has \\[Unreleased\\]"
  assert_contains "$success_output" "\\[PASS\\] .env matches .env.example"
  assert_contains "$success_output" "\\[PASS\\] healthcheck command"
  assert_contains "$success_output" "\\[PASS\\] sprint-contract schema"
  assert_contains "$success_output" "\\[PASS\\] runtime residual scan"
  assert_contains "$success_output" "\\[PASS\\] CI status"
  assert_contains "$success_output" "\\[PASS\\] release mirror build"
  assert_contains "$success_output" "\\[PASS\\] opencode mirror validation"
  assert_contains "$success_output" "\\[PASS\\] skill mirror sync check"
  assert_contains "$success_output" "\\[PASS\\] release mirror drift"
  assert_contains "$success_output" "\\[PASS\\] CCH branch protection policy"
  assert_contains "$success_output" "\\[PASS\\] codex plugin adapter smoke"
  assert_contains "$success_output" "\\[PASS\\] opencode bootstrap smoke"
  assert_contains "$success_output" "\\[PASS\\] cursor adapter candidate smoke"
  assert_contains "$success_output" "\\[PASS\\] bootstrap skill trigger acceptance gate"
  assert_contains "$success_output" "Summary: "

  printf 'BROKEN\n' >> "$repo/scripts/app.sh"
  local failure_output="$TMP_DIR/failure.txt"
  if HARNESS_RELEASE_PROJECT_ROOT="$repo" \
    HARNESS_RELEASE_HEALTHCHECK_CMD='true' \
    HARNESS_RELEASE_CI_STATUS_CMD='true' \
    HARNESS_RELEASE_BRANCH_PROTECTION_CMD='true' \
      "$PROJECT_ROOT/scripts/release-preflight.sh" --check-adapters >"$failure_output" 2>&1; then
    fail "preflight should fail on dirty tree"
  fi

  assert_contains "$failure_output" "\\[FAIL\\] working tree clean"

  local invalid_repo="$TMP_DIR/release-preflight-invalid-contract"
  setup_repo "$invalid_repo" invalid

  local schema_failure_output="$TMP_DIR/schema-failure.txt"
  if HARNESS_RELEASE_PROJECT_ROOT="$invalid_repo" \
    HARNESS_RELEASE_HEALTHCHECK_CMD='true' \
    HARNESS_RELEASE_CI_STATUS_CMD='true' \
    HARNESS_RELEASE_BRANCH_PROTECTION_CMD='true' \
      "$PROJECT_ROOT/scripts/release-preflight.sh" >"$schema_failure_output" 2>&1; then
    fail "preflight should fail on invalid sprint-contract schema"
  fi

  assert_contains "$schema_failure_output" "\\[FAIL\\] sprint-contract schema"
  assert_contains "$schema_failure_output" "review.max_iterations must be an integer between 1 and 30"
}

test_preflight_fails_on_opencode_mirror_drift() {
  local repo="$TMP_DIR/release-preflight-mirror-drift"
  setup_repo "$repo" valid drift

  local output="$TMP_DIR/mirror-drift.txt"
  if HARNESS_RELEASE_PROJECT_ROOT="$repo" \
    HARNESS_RELEASE_HEALTHCHECK_CMD='true' \
    HARNESS_RELEASE_CI_STATUS_CMD='true' \
    HARNESS_RELEASE_BRANCH_PROTECTION_CMD='true' \
      "$PROJECT_ROOT/scripts/release-preflight.sh" --check-adapters >"$output" 2>&1; then
    fail "preflight should fail on generated opencode mirror drift"
  fi

  assert_contains "$output" "\\[FAIL\\] release mirror drift"
  assert_contains "$output" "opencode/skills/example/SKILL.md"
}

test_preflight_warns_on_github_actions_branch_protection_403() {
  local repo="$TMP_DIR/release-preflight-branch-protection-403"
  setup_repo "$repo" valid

  cat > "$repo/scripts/check-cch-branch-protection-policy.sh" <<'EOF'
#!/bin/bash
printf "%s\n" "gh: Resource not accessible by integration (HTTP 403)" >&2
exit 1
EOF
  chmod +x "$repo/scripts/check-cch-branch-protection-policy.sh"
  git -C "$repo" add scripts/check-cch-branch-protection-policy.sh
  git -C "$repo" commit -qm "add branch protection 403 fixture"

  local output="$TMP_DIR/branch-protection-403.txt"
  HARNESS_RELEASE_PROJECT_ROOT="$repo" \
  HARNESS_RELEASE_HEALTHCHECK_CMD='true' \
  HARNESS_RELEASE_CI_STATUS_CMD='true' \
    "$PROJECT_ROOT/scripts/release-preflight.sh" >"$output" 2>&1

  assert_contains "$output" "\\[WARN\\] CCH branch protection policy unavailable to GitHub Actions token"
  assert_contains "$output" "Resource not accessible by integration"
  assert_contains "$output" "Summary: "
}

test_preflight_checks_plugin_version_sync() {
  local repo="$TMP_DIR/release-preflight-plugin"
  setup_repo "$repo" valid

  printf '1.2.3\n' > "$repo/VERSION"
  cat > "$repo/package.json" <<'EOF'
{
  "name": "release-preflight-plugin-fixture",
  "version": "1.2.3",
  "private": true,
  "scripts": {
    "healthcheck": "node -e \"process.exit(0)\""
  }
}
EOF
  mkdir -p "$repo/.claude-plugin"
  mkdir -p "$repo/.cursor-plugin"
  cat > "$repo/.claude-plugin/plugin.json" <<'EOF'
{
  "name": "release-preflight-plugin-fixture",
  "version": "1.2.3"
}
EOF
  cat > "$repo/.claude-plugin/marketplace.json" <<'EOF'
{
  "name": "release-preflight-plugin-marketplace",
  "metadata": {
    "version": "1.2.3"
  },
  "plugins": [
    {
      "name": "release-preflight-plugin-fixture",
      "version": "1.2.3"
    }
  ]
}
EOF
  cat > "$repo/.cursor-plugin/plugin.json" <<'EOF'
{
  "name": "release-preflight-cursor-fixture",
  "version": "1.2.3"
}
EOF
  git -C "$repo" add .
  git -C "$repo" commit -qm "add plugin metadata"

  local success_output="$TMP_DIR/plugin-version-success.txt"
  HARNESS_RELEASE_PROJECT_ROOT="$repo" \
  HARNESS_RELEASE_HEALTHCHECK_CMD='true' \
  HARNESS_RELEASE_CI_STATUS_CMD='true' \
  HARNESS_RELEASE_BRANCH_PROTECTION_CMD='true' \
    "$PROJECT_ROOT/scripts/release-preflight.sh" >"$success_output"

  assert_contains "$success_output" "\\[PASS\\] release version sync"

  python3 - "$repo/.cursor-plugin/plugin.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["version"] = "1.2.2"
path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY
  git -C "$repo" add .cursor-plugin/plugin.json
  git -C "$repo" commit -qm "drift cursor plugin version"

  local cursor_failure_output="$TMP_DIR/cursor-plugin-version-failure.txt"
  if HARNESS_RELEASE_PROJECT_ROOT="$repo" \
    HARNESS_RELEASE_HEALTHCHECK_CMD='true' \
    HARNESS_RELEASE_CI_STATUS_CMD='true' \
    HARNESS_RELEASE_BRANCH_PROTECTION_CMD='true' \
      "$PROJECT_ROOT/scripts/release-preflight.sh" >"$cursor_failure_output" 2>&1; then
    fail "preflight should fail on cursor plugin version mismatch"
  fi

  assert_contains "$cursor_failure_output" "\\[FAIL\\] release version sync"
  assert_contains "$cursor_failure_output" "MISMATCH .cursor-plugin/plugin.json"

  python3 - "$repo/.cursor-plugin/plugin.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["version"] = "1.2.3"
path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY
  git -C "$repo" add .cursor-plugin/plugin.json
  git -C "$repo" commit -qm "restore cursor plugin version"

  python3 - "$repo/.claude-plugin/marketplace.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["metadata"]["version"] = "1.2.2"
path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY
  git -C "$repo" add .claude-plugin/marketplace.json
  git -C "$repo" commit -qm "drift marketplace version"

  local failure_output="$TMP_DIR/plugin-version-failure.txt"
  if HARNESS_RELEASE_PROJECT_ROOT="$repo" \
    HARNESS_RELEASE_HEALTHCHECK_CMD='true' \
    HARNESS_RELEASE_CI_STATUS_CMD='true' \
    HARNESS_RELEASE_BRANCH_PROTECTION_CMD='true' \
      "$PROJECT_ROOT/scripts/release-preflight.sh" >"$failure_output" 2>&1; then
    fail "preflight should fail on plugin marketplace version mismatch"
  fi

  assert_contains "$failure_output" "\\[FAIL\\] release version sync"
  assert_contains "$failure_output" "MISMATCH .claude-plugin/marketplace.json metadata.version"
}

test_preflight_warns_when_env_is_managed_elsewhere() {
  local repo="$TMP_DIR/release-preflight-managed-secrets"
  setup_repo "$repo" valid

  rm -f "$repo/.env"
  git -C "$repo" add -u
  git -C "$repo" commit -qm "remove local env"

  local output="$TMP_DIR/managed-secrets.txt"
  HARNESS_RELEASE_PROJECT_ROOT="$repo" \
  HARNESS_RELEASE_HEALTHCHECK_CMD='true' \
  HARNESS_RELEASE_CI_STATUS_CMD='true' \
  HARNESS_RELEASE_BRANCH_PROTECTION_CMD='true' \
    "$PROJECT_ROOT/scripts/release-preflight.sh" >"$output"

  assert_contains "$output" "\\[WARN\\] .env missing for .env.example"
  assert_contains "$output" "\\[PASS\\] healthcheck command"
  assert_contains "$output" "\\[PASS\\] CI status"
}

test_skill_mentions_preflight
test_doc_mentions_overrides
test_release_workflow_runs_preflight_before_assets
test_preflight_pass_and_fail
test_preflight_fails_on_opencode_mirror_drift
test_preflight_warns_on_github_actions_branch_protection_403
test_preflight_checks_plugin_version_sync
test_preflight_warns_when_env_is_managed_elsewhere

echo "test-release-preflight: ok"
