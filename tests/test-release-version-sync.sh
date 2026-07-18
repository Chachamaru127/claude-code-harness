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
  if ! grep -Fq "$pattern" "$file"; then
    fail "expected '$pattern' in $file"
  fi
}

write_release_surfaces() {
  local repo="$1"
  local version="$2"
  local package_version="${3:-$version}"
  local plugin_version="${4:-$version}"
  local marketplace_metadata_version="${5:-$version}"
  local marketplace_plugin_version="${6:-$version}"
  local codex_plugin_version="${7:-$version}"

  mkdir -p "$repo/.claude-plugin" "$repo/.codex-plugin"
  printf '%s\n' "$version" > "$repo/VERSION"
  cat > "$repo/package.json" <<EOF
{
  "name": "fixture",
  "version": "$package_version"
}
EOF
  cat > "$repo/.claude-plugin/plugin.json" <<EOF
{
  "name": "fixture",
  "version": "$plugin_version"
}
EOF
  cat > "$repo/.codex-plugin/plugin.json" <<EOF
{
  "name": "fixture",
  "version": "$codex_plugin_version"
}
EOF
  cat > "$repo/.claude-plugin/marketplace.json" <<EOF
{
  "name": "fixture-marketplace",
  "metadata": {
    "version": "$marketplace_metadata_version"
  },
  "plugins": [
    {
      "name": "fixture",
      "version": "$marketplace_plugin_version"
    },
    {
      "name": "fixture-extra",
      "version": "$marketplace_plugin_version"
    }
  ]
}
EOF
}

test_all_surfaces_match() {
  local repo="$TMP_DIR/match"
  mkdir -p "$repo"
  write_release_surfaces "$repo" "1.2.3"

  local output="$TMP_DIR/match.txt"
  python3 "$PROJECT_ROOT/scripts/check-release-version-sync.py" --root "$repo" > "$output"

  assert_contains "$output" "[PASS] release version sync: canonical 1.2.3 from VERSION"
  assert_contains "$output" "OK package.json: 1.2.3"
  assert_contains "$output" "OK .codex-plugin/plugin.json: 1.2.3"
  assert_contains "$output" "OK .claude-plugin/marketplace.json metadata.version: 1.2.3"
  assert_contains "$output" "OK .claude-plugin/marketplace.json plugins[1](fixture-extra).version: 1.2.3"
}

test_mismatch_blocks_release() {
  local repo="$TMP_DIR/mismatch"
  mkdir -p "$repo"
  write_release_surfaces "$repo" "1.2.3" "1.2.3" "1.2.3" "1.2.2" "1.2.1" "1.2.0"

  local output="$TMP_DIR/mismatch.txt"
  if python3 "$PROJECT_ROOT/scripts/check-release-version-sync.py" --root "$repo" > "$output" 2>&1; then
    fail "version sync check should fail on marketplace mismatch"
  fi

  assert_contains "$output" "[FAIL] release version sync: canonical 1.2.3 from VERSION (priority: VERSION > package.json > .claude-plugin/plugin.json > .codex-plugin/plugin.json > .cursor-plugin/plugin.json)"
  assert_contains "$output" "MISMATCH .codex-plugin/plugin.json: 1.2.0 (expected 1.2.3)"
  assert_contains "$output" "MISMATCH .claude-plugin/marketplace.json metadata.version: 1.2.2 (expected 1.2.3)"
  assert_contains "$output" "MISMATCH .claude-plugin/marketplace.json plugins[0](fixture).version: 1.2.1 (expected 1.2.3)"
  assert_contains "$output" "Tag/release is blocked until version surfaces are aligned."
}

test_missing_marketplace_versions_block_release() {
  local repo="$TMP_DIR/missing-marketplace"
  mkdir -p "$repo/.claude-plugin"
  printf '2.0.0\n' > "$repo/VERSION"
  cat > "$repo/package.json" <<'EOF'
{
  "name": "fixture",
  "version": "2.0.0"
}
EOF
  cat > "$repo/.claude-plugin/plugin.json" <<'EOF'
{
  "name": "fixture",
  "version": "2.0.0"
}
EOF
  cat > "$repo/.claude-plugin/marketplace.json" <<'EOF'
{
  "name": "fixture-marketplace",
  "metadata": {
    "description": "missing version fixture"
  },
  "plugins": [
    {
      "name": "fixture"
    }
  ]
}
EOF

  local output="$TMP_DIR/missing-marketplace.txt"
  if python3 "$PROJECT_ROOT/scripts/check-release-version-sync.py" --root "$repo" > "$output" 2>&1; then
    fail "version sync check should fail when marketplace versions are missing"
  fi

  assert_contains "$output" "MISSING .claude-plugin/marketplace.json metadata.version"
  assert_contains "$output" "MISSING .claude-plugin/marketplace.json plugins[0](fixture).version"
}

test_sync_version_bump_updates_marketplace() {
  local repo="$TMP_DIR/sync-bump"
  mkdir -p "$repo"
  write_release_surfaces "$repo" "1.2.3"
  cat > "$repo/harness.toml" <<'EOF'
version = "1.2.3"
EOF
  cat > "$repo/CHANGELOG.md" <<'EOF'
# Changelog

## [Unreleased]

[Unreleased]: https://github.com/Chachamaru127/claude-code-harness/compare/v1.2.3...HEAD
EOF

  local bump_output="$TMP_DIR/sync-bump.txt"
  (cd "$repo" && bash "$PROJECT_ROOT/scripts/sync-version.sh" bump patch > "$bump_output")

  assert_contains "$bump_output" "VERSION を更新 (patch): 1.2.3 → 1.2.4"
  assert_contains "$bump_output" "codex plugin.json を更新: 1.2.3 → 1.2.4"
  assert_contains "$bump_output" "marketplace.json を更新: metadata.version: 1.2.3 → 1.2.4"
  assert_contains "$bump_output" "marketplace.json を更新: plugins[1](fixture-extra).version: 1.2.3 → 1.2.4"

  local check_output="$TMP_DIR/sync-bump-check.txt"
  python3 "$PROJECT_ROOT/scripts/check-release-version-sync.py" --root "$repo" > "$check_output"
  assert_contains "$check_output" "[PASS] release version sync: canonical 1.2.4 from VERSION"
  assert_contains "$repo/harness.toml" 'version = "1.2.4"'
  assert_contains "$repo/CHANGELOG.md" "[1.2.4]: https://github.com/Chachamaru127/claude-code-harness/compare/v1.2.3...v1.2.4"
}

test_json_output_is_structured() {
  local repo="$TMP_DIR/json"
  mkdir -p "$repo"
  write_release_surfaces "$repo" "3.4.5"

  local output="$TMP_DIR/report.json"
  python3 "$PROJECT_ROOT/scripts/check-release-version-sync.py" --root "$repo" --json > "$output"

  python3 - "$output" <<'PY'
import json
import sys

report = json.load(open(sys.argv[1], encoding="utf-8"))
assert report["ok"] is True
assert report["canonical"]["name"] == "VERSION"
assert report["canonical"]["version"] == "3.4.5"
assert report["canonical_priority"] == ["VERSION", "package.json", ".claude-plugin/plugin.json", ".codex-plugin/plugin.json", ".cursor-plugin/plugin.json"]
assert any(surface["name"] == ".codex-plugin/plugin.json" for surface in report["surfaces"])
assert any(surface["name"] == ".claude-plugin/marketplace.json metadata.version" for surface in report["surfaces"])
PY
}

test_skill_docs_reference_structured_version_sync() {
  # `.agents/skills/...` は local-only mirror (clean public checkout には無い)。
  # 存在する skill ファイルだけを assert し、欠落した mirror は skip する。
  for skill in \
    "$PROJECT_ROOT/skills/harness-release/SKILL.md" \
    "$PROJECT_ROOT/codex/.codex/skills/harness-release/SKILL.md" \
    "$PROJECT_ROOT/.agents/skills/harness-release/SKILL.md"; do
    if [ ! -f "$skill" ]; then
      echo "[skip] $skill not found (local-only mirror; clean public checkout)"
      continue
    fi
    assert_contains "$skill" "scripts/check-release-version-sync.py"
    assert_contains "$skill" "VERSION > package.json > .claude-plugin/plugin.json > .codex-plugin/plugin.json"
    assert_contains "$skill" ".claude-plugin/marketplace.json"
    assert_contains "$skill" ".codex-plugin/plugin.json"
  done
}

test_all_surfaces_match
test_mismatch_blocks_release
test_missing_marketplace_versions_block_release
test_sync_version_bump_updates_marketplace
test_json_output_is_structured
test_skill_docs_reference_structured_version_sync

echo "test-release-version-sync: ok"
