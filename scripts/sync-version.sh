#!/bin/bash
# sync-version.sh - VERSION と plugin.json のバージョンを同期
#
# 使い方:
#   ./scripts/sync-version.sh check    # 不一致をチェック
#   ./scripts/sync-version.sh sync     # plugin.json を VERSION に合わせる
#   ./scripts/sync-version.sh bump     # パッチバージョンを上げる

set -e

VERSION_FILE="VERSION"
PLUGIN_JSON=".claude-plugin/plugin.json"

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
