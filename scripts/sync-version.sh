#!/bin/bash
# sync-version.sh - release metadata の VERSION / plugin.json / marketplace.json を同期
#
# 使い方:
#   ./scripts/sync-version.sh check    # 不一致をチェック
#   ./scripts/sync-version.sh sync     # release metadata を VERSION に合わせる
#   ./scripts/sync-version.sh bump             # release 用に patch version を上げる
#   ./scripts/sync-version.sh bump minor       # minor version を上げる
#   ./scripts/sync-version.sh bump major       # major version を上げる

set -euo pipefail

VERSION_FILE="VERSION"
PACKAGE_JSON="package.json"
PLUGIN_JSON=".claude-plugin/plugin.json"
CODEX_PLUGIN_JSON=".codex-plugin/plugin.json"
CURSOR_PLUGIN_JSON=".cursor-plugin/plugin.json"
MARKETPLACE_JSON=".claude-plugin/marketplace.json"
HARNESS_TOML="harness.toml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 現在のバージョンを取得
get_version() {
    cat "$VERSION_FILE" | tr -d '\n'
}

get_plugin_version() {
    grep '"version"' "$PLUGIN_JSON" | sed 's/.*"version": "\([^"]*\)".*/\1/'
}

get_toml_version() {
    grep '^version' "$HARNESS_TOML" | sed 's/.*= "\([^"]*\)".*/\1/'
}

# バージョン不一致チェック
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
        echo "❌ バージョン不一致:"
        echo "   VERSION:      $v1"
        echo "   plugin.json:  $v2"
        ok=false
    fi
    if [ -n "$v3" ] && [ "$v1" != "$v3" ]; then
        echo "❌ バージョン不一致:"
        echo "   VERSION:      $v1"
        echo "   harness.toml: $v3"
        ok=false
    fi

    if [ "$ok" = true ]; then
        echo "✅ バージョン一致: $v1"
        return 0
    fi
    return 1
}

# JSON ファイルの top-level version を VERSION に同期
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
        echo "✅ ${label} を更新: ${current:-未設定} → $version"
    fi
}

# marketplace.json の metadata.version / plugins[].version を VERSION に同期
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
    changes.append(f"metadata.version: {old_metadata or '未設定'} → {version}")

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
        changes.append(f"plugins[{index}]({name}).version: {old_plugin or '未設定'} → {version}")

if changes:
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)
        fh.write("\n")
    for change in changes:
        print(f"✅ marketplace.json を更新: {change}")
PY
}

# package.json / plugin.json / Codex plugin / marketplace.json + harness.toml を VERSION に同期
sync_version() {
    local version=$(get_version)

    sync_top_level_json_version "$PACKAGE_JSON" "package.json" "$version"
    sync_top_level_json_version "$PLUGIN_JSON" "plugin.json" "$version"
    sync_top_level_json_version "$CODEX_PLUGIN_JSON" "codex plugin.json" "$version"
    sync_top_level_json_version "$CURSOR_PLUGIN_JSON" "cursor plugin.json" "$version"
    sync_marketplace_version "$MARKETPLACE_JSON" "$version"

    # harness.toml の同期
    if [ -f "$HARNESS_TOML" ]; then
        local toml_ver=$(get_toml_version)
        if [ "$version" != "$toml_ver" ]; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s/^version = \"$toml_ver\"/version = \"$version\"/" "$HARNESS_TOML"
            else
                sed -i "s/^version = \"$toml_ver\"/version = \"$version\"/" "$HARNESS_TOML"
            fi
            echo "✅ harness.toml を更新: $toml_ver → $version"
        fi
    fi

    echo "✅ 同期完了: $version"
}

# CHANGELOG.md の compare link を更新 (Unreleased のバージョン差し替え + 新バージョン行を挿入)
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
        f"⚠️  CHANGELOG.md に [Unreleased] compare link (v{current}...HEAD) が見つかりません。手動で追加してください。",
        file=sys.stderr,
    )
    sys.exit(0)

with open(changelog, "w", encoding="utf-8") as fh:
    fh.writelines(new_lines)

print(f"✅ CHANGELOG.md に compare link を追加: [{new}]")
PY
}

# バージョンを上げる（既定は patch）
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
            echo "❌ 未対応の bump level: $level" >&2
            echo "   使用可能: patch | minor | major" >&2
            exit 1
            ;;
    esac

    echo "$new_version" > "$VERSION_FILE"
    echo "✅ VERSION を更新 ($level): $current → $new_version"

    sync_version
    update_changelog_compare_links "$current" "$new_version"
}

# メイン
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
