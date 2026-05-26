#!/bin/bash
# sync-version.sh - sync release metadata VERSION / plugin.json / marketplace.json
#
# Usage:
#   ./scripts/sync-version.sh check    # Check for mismatches
#   ./scripts/sync-version.sh sync     # Sync release metadata to VERSION
#   ./scripts/sync-version.sh bump             # Bump patch version for release
#   ./scripts/sync-version.sh bump minor       # Bump minor version
#   ./scripts/sync-version.sh bump major       # Bump major version

set -euo pipefail

VERSION_FILE="VERSION"
PACKAGE_JSON="package.json"
PLUGIN_JSON=".claude-plugin/plugin.json"
CODEX_PLUGIN_JSON=".codex-plugin/plugin.json"
MARKETPLACE_JSON=".claude-plugin/marketplace.json"
HARNESS_TOML="harness.toml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get current version
get_version() {
    cat "$VERSION_FILE" | tr -d '\n'
}

get_plugin_version() {
    grep '"version"' "$PLUGIN_JSON" | sed 's/.*"version": "\([^"]*\)".*/\1/'
}

get_toml_version() {
    grep '^version' "$HARNESS_TOML" | sed 's/.*= "\([^"]*\)".*/\1/'
}

# Version mismatch check
check_version() {
    if [ -f "$SCRIPT_DIR/check-release-version-sync.py" ]; then
        python3 "$SCRIPT_DIR/check-release-version-sync.py" --root "."
        return $?
    fi

    local v1=$(get_version)
    local v2=$(get_plugin_version)
    local v3=""
    if [ -f "$HARNESS_TOML" ]; then
        v3=$(get_toml_version)
    fi

    local ok=true
    if [ "$v1" != "$v2" ]; then
        echo "❌ Version mismatch:"
        echo "   VERSION:      $v1"
        echo "   plugin.json:  $v2"
        ok=false
    fi
    if [ -n "$v3" ] && [ "$v1" != "$v3" ]; then
        echo "❌ Version mismatch:"
        echo "   VERSION:      $v1"
        echo "   harness.toml: $v3"
        ok=false
    fi

    if [ "$ok" = true ]; then
        echo "✅ Versions match: $v1"
        return 0
    fi
    return 1
}

# Sync top-level version in JSON file to VERSION
sync_top_level_json_version() {
    local file="$1"
    local label="$2"
    local version="$3"

    [ -f "$file" ] || return 0

    local current
    current="$(python3 - "$file" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as fh:
    data = json.load(fh)
value = data.get("version", "")
print(value if isinstance(value, str) else "")
PY
)"

    if [ "$version" != "$current" ]; then
        python3 - "$file" "$version" <<'PY'
import json
import sys

path, version = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as fh:
    data = json.load(fh)
data["version"] = version
with open(path, "w", encoding="utf-8") as fh:
    json.dump(data, fh, ensure_ascii=False, indent=2)
    fh.write("\n")
PY
        echo "✅ ${label} updated: ${current:-unset} -> $version"
    fi
}

# Sync marketplace.json metadata.version / plugins[].version to VERSION
sync_marketplace_version() {
    local file="$1"
    local version="$2"

    [ -f "$file" ] || return 0

    python3 - "$file" "$version" <<'PY'
import json
import sys

path, version = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as fh:
    data = json.load(fh)

changes = []
metadata = data.setdefault("metadata", {})
if not isinstance(metadata, dict):
    raise SystemExit(f"{path}: metadata must be an object")
old_metadata = metadata.get("version")
if old_metadata != version:
    metadata["version"] = version
    changes.append(f"metadata.version: {old_metadata or 'unset'} -> {version}")

plugins = data.get("plugins")
if plugins is None:
    plugins = []
    data["plugins"] = plugins
if not isinstance(plugins, list):
    raise SystemExit(f"{path}: plugins must be an array")

for index, plugin in enumerate(plugins):
    if not isinstance(plugin, dict):
        raise SystemExit(f"{path}: plugins[{index}] must be an object")
    old_plugin = plugin.get("version")
    if old_plugin != version:
        plugin["version"] = version
        name = plugin.get("name") if isinstance(plugin.get("name"), str) else f"#{index}"
        changes.append(f"plugins[{index}]({name}).version: {old_plugin or 'unset'} -> {version}")

if changes:
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)
        fh.write("\n")
    for change in changes:
        print(f"✅ marketplace.json updated: {change}")
PY
}

# Sync package.json / plugin.json / Codex plugin / marketplace.json + harness.toml to VERSION
sync_version() {
    local version=$(get_version)

    sync_top_level_json_version "$PACKAGE_JSON" "package.json" "$version"
    sync_top_level_json_version "$PLUGIN_JSON" "plugin.json" "$version"
    sync_top_level_json_version "$CODEX_PLUGIN_JSON" "codex plugin.json" "$version"
    sync_marketplace_version "$MARKETPLACE_JSON" "$version"

    # Sync harness.toml
    if [ -f "$HARNESS_TOML" ]; then
        local toml_ver=$(get_toml_version)
        if [ "$version" != "$toml_ver" ]; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s/^version = \"$toml_ver\"/version = \"$version\"/" "$HARNESS_TOML"
            else
                sed -i "s/^version = \"$toml_ver\"/version = \"$version\"/" "$HARNESS_TOML"
            fi
            echo "✅ harness.toml updated: $toml_ver -> $version"
        fi
    fi

    echo "✅ Sync complete: $version"
}

# Update CHANGELOG.md compare link (replace Unreleased version + insert new version line)
update_changelog_compare_links() {
    local current="$1"
    local new="$2"
    local changelog="CHANGELOG.md"

    if [ ! -f "$changelog" ]; then
        return 0
    fi

    python3 - "$changelog" "$current" "$new" <<'PY'
import re
import sys

changelog, current, new = sys.argv[1], sys.argv[2], sys.argv[3]
with open(changelog, "r", encoding="utf-8") as fh:
    lines = fh.readlines()

pattern = re.compile(
    rf"^\[Unreleased\]: (https://github\.com/[^/]+/[^/]+)/compare/v{re.escape(current)}\.\.\.HEAD\s*$"
)

new_lines = []
inserted = False
for line in lines:
    match = pattern.match(line)
    if match and not inserted:
        repo = match.group(1)
        new_lines.append(f"[Unreleased]: {repo}/compare/v{new}...HEAD\n")
        new_lines.append(f"[{new}]: {repo}/compare/v{current}...v{new}\n")
        inserted = True
        continue
    new_lines.append(line)

if not inserted:
    print(
        f"⚠️  [Unreleased] compare link (v{current}...HEAD) not found in CHANGELOG.md. Please add it manually.",
        file=sys.stderr,
    )
    sys.exit(0)

with open(changelog, "w", encoding="utf-8") as fh:
    fh.writelines(new_lines)

print(f"✅ CHANGELOG.md compare link added: [{new}]")
PY
}

# Bump version (default is patch)
bump_version() {
    local level="${1:-patch}"
    local current=$(get_version)
    local major=$(echo "$current" | cut -d. -f1)
    local minor=$(echo "$current" | cut -d. -f2)
    local patch=$(echo "$current" | cut -d. -f3)

    local new_version=""
    case "$level" in
        patch)
            local new_patch=$((patch + 1))
            new_version="$major.$minor.$new_patch"
            ;;
        minor)
            local new_minor=$((minor + 1))
            new_version="$major.$new_minor.0"
            ;;
        major)
            local new_major=$((major + 1))
            new_version="$new_major.0.0"
            ;;
        *)
            echo "❌ Unsupported bump level: $level" >&2
            echo "   Available: patch | minor | major" >&2
            exit 1
            ;;
    esac

    echo "$new_version" > "$VERSION_FILE"
    echo "✅ VERSION updated ($level): $current -> $new_version"

    sync_version
    update_changelog_compare_links "$current" "$new_version"
}

# Main
case "${1:-check}" in
    check)
        check_version
        ;;
    sync)
        sync_version
        ;;
    bump)
        bump_version "${2:-patch}"
        ;;
    *)
        echo "Usage: $0 {check|sync|bump [patch|minor|major]}"
        exit 1
        ;;
esac
