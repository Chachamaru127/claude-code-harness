#!/bin/bash
# sync-plugin-cache.sh
# プラグインソースとキャッシュの整合性を確認し、必要に応じて同期
#
# 使用方法: SessionStart hook から自動実行
# 
# 処理フロー:
# 1. プラグインソースのバージョンを取得
# 2. キャッシュのバージョン/ファイルハッシュを比較
# 3. 差分があれば同期

set -euo pipefail

# ===== カラー定義 =====
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# ===== パス設定 =====
# プラグインソースを検出
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load cross-platform path utilities (if available)
if [ -f "$SCRIPT_DIR/path-utils.sh" ]; then
  # shellcheck source=./path-utils.sh
  source "$SCRIPT_DIR/path-utils.sh"
fi

# Detect plugin source location
# Priority: 1. CLAUDE_PLUGIN_ROOT env var, 2. Script's parent directory (default)
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  PLUGIN_SOURCE="$CLAUDE_PLUGIN_ROOT/claude-code-harness"
else
  # Default: use script's parent directory (works for both dev and installed)
  PLUGIN_SOURCE="$(dirname "$SCRIPT_DIR")"
fi

# Note: Removed hardcoded development paths for cross-platform compatibility
# If you need to override in development, set CLAUDE_PLUGIN_ROOT environment variable

# プラグイン情報
PLUGIN_NAME="claude-code-harness"
MARKETPLACE_NAME="claude-code-harness-marketplace"

# キャッシュディレクトリ
CACHE_BASE="$HOME/.claude/plugins/cache/$MARKETPLACE_NAME/$PLUGIN_NAME"

# ===== バージョン取得 =====
get_source_version() {
  if [ -f "$PLUGIN_SOURCE/VERSION" ]; then
    cat "$PLUGIN_SOURCE/VERSION" | tr -d '[:space:]'
  else
    echo "unknown"
  fi
}

get_cache_version() {
  # キャッシュ内の最新バージョンディレクトリを取得
  if [ -d "$CACHE_BASE" ]; then
    ls -1 "$CACHE_BASE" 2>/dev/null | sort -V | tail -1
  else
    echo ""
  fi
}

# ===== ファイルハッシュ比較 =====
get_file_hash() {
  local file="$1"
  if [ -f "$file" ]; then
    if command -v md5sum >/dev/null 2>&1; then
      md5sum "$file" | cut -d' ' -f1
    elif command -v md5 >/dev/null 2>&1; then
      md5 -q "$file"
    else
      # フォールバック: ファイルサイズ
      wc -c < "$file" | tr -d '[:space:]'
    fi
  else
    echo ""
  fi
}

files_differ() {
  local source_file="$1"
  local cache_file="$2"
  
  [ ! -f "$source_file" ] && return 1
  [ ! -f "$cache_file" ] && return 0
  
  local source_hash=$(get_file_hash "$source_file")
  local cache_hash=$(get_file_hash "$cache_file")
  
  [ "$source_hash" != "$cache_hash" ]
}

# ===== 同期処理 =====
sync_file() {
  local rel_path="$1"
  local cache_dir="$2"  # Explicit argument instead of global variable
  local source_file="$PLUGIN_SOURCE/$rel_path"
  local cache_file="$cache_dir/$rel_path"

  if [ -f "$source_file" ]; then
    mkdir -p "$(dirname "$cache_file")"
    cp "$source_file" "$cache_file"
    echo "  ✓ $rel_path"
  fi
}

sync_critical_files() {
  local cache_dir="$1"
  local plugin_source="$2"  # 明示的にソースディレクトリを受け取る
  local synced=0

  # 同期対象ファイル（重要なスクリプト）
  local critical_files=(
    "scripts/path-utils.sh"
    "scripts/pretooluse-guard.sh"
    "scripts/posttooluse-log-toolname.sh"
    "scripts/session-init.sh"
    "scripts/session-monitor.sh"
    "scripts/userprompt-inject-policy.sh"
    "scripts/sync-plugin-cache.sh"
    "scripts/track-changes.sh"
    "scripts/analyze-project.sh"
    "scripts/setup-existing-project.sh"
    "hooks/hooks.json"
    "VERSION"
  )

  for rel_path in "${critical_files[@]}"; do
    local source_file="$plugin_source/$rel_path"
    local cache_file="$cache_dir/$rel_path"

    if files_differ "$source_file" "$cache_file"; then
      mkdir -p "$(dirname "$cache_file")"
      cp "$source_file" "$cache_file"
      echo -e "  ${GREEN}✓${NC} $rel_path" >&2
      synced=$((synced + 1))
    fi
  done

  printf "%d" "$synced"
}

# ===== メイン処理 =====
# 注意: Claude Code はフックの stderr のみを表示するため、出力は stderr に
main() {
  local SOURCE_VERSION=$(get_source_version)

  # デバッグ情報（環境変数で有効化）
  if [ "${CC_HARNESS_DEBUG:-0}" = "1" ]; then
    echo -e "${BLUE}[Debug] Plugin source: $PLUGIN_SOURCE${NC}" >&2
    echo -e "${BLUE}[Debug] Source version: $SOURCE_VERSION${NC}" >&2
    echo -e "${BLUE}[Debug] Cache base: $CACHE_BASE${NC}" >&2
  fi

  # キャッシュディレクトリが存在しない場合
  if [ ! -d "$CACHE_BASE" ]; then
    echo -e "${YELLOW}⚠️ キャッシュが見つかりません${NC}" >&2
    return 0
  fi

  # すべてのキャッシュバージョンに対して同期
  local total_synced=0
  for cache_version_dir in "$CACHE_BASE"/*/; do
    [ ! -d "$cache_version_dir" ] && continue

    local cache_version=$(basename "$cache_version_dir")
    local CACHE_DIR="$cache_version_dir"

    if [ "${CC_HARNESS_DEBUG:-0}" = "1" ]; then
      echo -e "${BLUE}[Debug] Checking cache: $cache_version${NC}" >&2
    fi

    # ファイル差分をチェック（VERSION も含める）
    local needs_sync=false
    for rel_path in "VERSION" "scripts/pretooluse-guard.sh" "scripts/posttooluse-log-toolname.sh" "scripts/session-init.sh"; do
      if files_differ "$PLUGIN_SOURCE/$rel_path" "$CACHE_DIR/$rel_path"; then
        needs_sync=true
        break
      fi
    done

    if [ "$needs_sync" = true ]; then
      echo -e "${YELLOW}🔄 キャッシュ v$cache_version を同期中...${NC}" >&2
      SYNCED=$(sync_critical_files "$CACHE_DIR" "$PLUGIN_SOURCE")
      total_synced=$((total_synced + SYNCED))
    fi
  done

  if [ "$total_synced" -gt 0 ]; then
    echo -e "${GREEN}✅ 合計 $total_synced ファイルを同期しました${NC}" >&2
  fi
}

main "$@"
