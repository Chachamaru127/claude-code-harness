#!/bin/bash
# sync-version.sh - VERSION と plugin.json のバージョンを同期
#
# 使い方:
#   ./scripts/sync-version.sh check    # 不一致をチェック
#   ./scripts/sync-version.sh sync     # plugin.json を VERSION に合わせる
#   ./scripts/sync-version.sh bump     # パッチバージョンを上げる

set -euo pipefail

VERSION_FILE="VERSION"
PLUGIN_JSON=".claude-plugin/plugin.json"
MARKETPLACE_JSON=".claude-plugin/marketplace.json"
README_FILES=("README.md" "README_ja.md")

# 現在のバージョンを取得
get_version() {
    cat "$VERSION_FILE" | tr -d '\n'
}

get_plugin_version() {
    grep '"version"' "$PLUGIN_JSON" | sed 's/.*"version": "\([^"]*\)".*/\1/'
}

# バージョン不一致チェック
check_version() {
    local v1=$(get_version)
    local v2=$(get_plugin_version)

    if [ "$v1" != "$v2" ]; then
        echo "❌ バージョン不一致:"
        echo "   VERSION:     $v1"
        echo "   plugin.json: $v2"
        return 1
    else
        echo "✅ バージョン一致: $v1"
        return 0
    fi
}

# plugin.json を VERSION に同期
sync_version() {
    local version=$(get_version)
    local current=$(get_plugin_version)

    if [ "$version" = "$current" ]; then
        echo "✅ 既に同期済み: $version"
        return 0
    fi

    # macOS と Linux 両対応
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/\"version\": \"$current\"/\"version\": \"$version\"/" "$PLUGIN_JSON"
    else
        sed -i "s/\"version\": \"$current\"/\"version\": \"$version\"/" "$PLUGIN_JSON"
    fi

    echo "✅ plugin.json を更新: $current → $version"

    # Optional: marketplace.json / README badge also follow VERSION
    sync_optional_files "$version"
}

# Optional sync for marketplace + README badge
sync_optional_files() {
    local version="$1"

    # marketplace.json
    if [ -f "$MARKETPLACE_JSON" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' -E "s/\"version\": \"[0-9]+\.[0-9]+\.[0-9]+\"/\"version\": \"$version\"/g" "$MARKETPLACE_JSON"
        else
            sed -i -E "s/\"version\": \"[0-9]+\.[0-9]+\.[0-9]+\"/\"version\": \"$version\"/g" "$MARKETPLACE_JSON"
        fi
    fi

    # README badge (README.md + README_ja.md)
    for readme in "${README_FILES[@]}"; do
        if [ -f "$readme" ]; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' -E "s|\\[!\\[Version: [0-9]+\\.[0-9]+\\.[0-9]+\\]\\(https://img\\.shields\\.io/badge/version-[0-9]+\\.[0-9]+\\.[0-9]+-blue\\.svg\\)\\]\\(VERSION\\)|[![Version: ${version}](https://img.shields.io/badge/version-${version}-blue.svg)](VERSION)|" "$readme" || true
            else
                sed -i -E "s|\\[!\\[Version: [0-9]+\\.[0-9]+\\.[0-9]+\\]\\(https://img\\.shields\\.io/badge/version-[0-9]+\\.[0-9]+\\.[0-9]+-blue\\.svg\\)\\]\\(VERSION\\)|[![Version: ${version}](https://img.shields.io/badge/version-${version}-blue.svg)](VERSION)|" "$readme" || true
            fi
        fi
    done
}

# パッチバージョンを上げる
bump_version() {
    local current=$(get_version)
    local major=$(echo "$current" | cut -d. -f1)
    local minor=$(echo "$current" | cut -d. -f2)
    local patch=$(echo "$current" | cut -d. -f3)

    local new_patch=$((patch + 1))
    local new_version="$major.$minor.$new_patch"

    echo "$new_version" > "$VERSION_FILE"
    echo "✅ VERSION を更新: $current → $new_version"

    sync_version
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
        bump_version
        ;;
    *)
        echo "Usage: $0 {check|sync|bump}"
        exit 1
        ;;
esac
