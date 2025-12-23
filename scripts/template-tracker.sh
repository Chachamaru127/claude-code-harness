#!/bin/bash
# template-tracker.sh
# テンプレート追跡機能：生成ファイルの更新状況を管理
#
# 機能:
# - init: generated-files.json を初期化（既存ファイルの状態を記録）
# - check: テンプレート更新をチェックし、更新が必要なファイルを表示
# - status: 各ファイルの詳細状態を表示
#
# 使用方法:
#   template-tracker.sh init   - 初期化
#   template-tracker.sh check  - 更新チェック（SessionStart用、JSON出力）
#   template-tracker.sh status - 詳細表示（人間向け）

set -e

# スクリプトディレクトリとプラグインルートを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 定数
REGISTRY_FILE="$PLUGIN_ROOT/templates/template-registry.json"
STATE_DIR=".claude/state"
GENERATED_FILES="$STATE_DIR/generated-files.json"
VERSION_FILE="$PLUGIN_ROOT/VERSION"

# 現在のプラグインバージョンを取得
get_plugin_version() {
  cat "$VERSION_FILE" 2>/dev/null || echo "unknown"
}

# ファイルのSHA256ハッシュを取得
get_file_hash() {
  local file="$1"
  if [ -f "$file" ]; then
    if command -v sha256sum >/dev/null 2>&1; then
      sha256sum "$file" | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then
      shasum -a 256 "$file" | cut -d' ' -f1
    else
      # フォールバック: md5
      md5sum "$file" 2>/dev/null | cut -d' ' -f1 || md5 -q "$file" 2>/dev/null || echo "no-hash"
    fi
  else
    echo ""
  fi
}

# generated-files.json を読み込み
load_generated_files() {
  if [ -f "$GENERATED_FILES" ]; then
    cat "$GENERATED_FILES"
  else
    echo '{}'
  fi
}

# generated-files.json を保存
save_generated_files() {
  local content="$1"
  mkdir -p "$STATE_DIR"
  echo "$content" > "$GENERATED_FILES"
}

# template-registry.json から tracked=true のテンプレート一覧を取得
get_tracked_templates() {
  if [ ! -f "$REGISTRY_FILE" ]; then
    echo "[]"
    return
  fi

  if command -v jq >/dev/null 2>&1; then
    jq -r '.templates | to_entries | map(select(.value.tracked == true)) | .[].key' "$REGISTRY_FILE" 2>/dev/null
  else
    # jq がない場合は基本的なテンプレートのみ
    echo "CLAUDE.md.template"
    echo "AGENTS.md.template"
    echo "Plans.md.template"
  fi
}

# テンプレートの出力先パスを取得
get_output_path() {
  local template="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -r ".templates[\"$template\"].output // \"\"" "$REGISTRY_FILE" 2>/dev/null
  else
    # jq がない場合の基本マッピング
    case "$template" in
      "CLAUDE.md.template") echo "CLAUDE.md" ;;
      "AGENTS.md.template") echo "AGENTS.md" ;;
      "Plans.md.template") echo "Plans.md" ;;
      *) echo "" ;;
    esac
  fi
}

# テンプレートのバージョンを取得
get_template_version() {
  local template="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -r ".templates[\"$template\"].templateVersion // \"unknown\"" "$REGISTRY_FILE" 2>/dev/null
  else
    echo "unknown"
  fi
}

# 初期化: 既存ファイルの状態を記録
cmd_init() {
  local plugin_version
  plugin_version=$(get_plugin_version)

  local result='{"lastCheckedPluginVersion":"'"$plugin_version"'","files":{}}'

  while IFS= read -r template; do
    [ -z "$template" ] && continue

    local output_path
    output_path=$(get_output_path "$template")
    [ -z "$output_path" ] && continue

    if [ -f "$output_path" ]; then
      local file_hash
      file_hash=$(get_file_hash "$output_path")

      # 既存ファイルは templateVersion: "unknown" で記録
      if command -v jq >/dev/null 2>&1; then
        result=$(echo "$result" | jq --arg path "$output_path" --arg hash "$file_hash" \
          '.files[$path] = {"templateVersion": "unknown", "fileHash": $hash, "recordedAt": (now | strftime("%Y-%m-%dT%H:%M:%SZ"))}')
      fi
    fi
  done < <(get_tracked_templates)

  save_generated_files "$result"
  echo "Generated files initialized. Recorded $(echo "$result" | jq '.files | length') files."
}

# チェック: 更新が必要なファイルを検出（JSON出力）
cmd_check() {
  local generated
  generated=$(load_generated_files)

  local plugin_version
  plugin_version=$(get_plugin_version)

  local last_checked
  if command -v jq >/dev/null 2>&1; then
    last_checked=$(echo "$generated" | jq -r '.lastCheckedPluginVersion // "unknown"')
  else
    last_checked="unknown"
  fi

  # プラグインバージョンが変わっていない場合はスキップ
  if [ "$last_checked" = "$plugin_version" ]; then
    echo '{"needsCheck": false, "reason": "Plugin version unchanged"}'
    return
  fi

  local updates_needed=()
  local updates_details='[]'

  while IFS= read -r template; do
    [ -z "$template" ] && continue

    local output_path
    output_path=$(get_output_path "$template")
    [ -z "$output_path" ] && continue
    [ ! -f "$output_path" ] && continue

    local template_version
    template_version=$(get_template_version "$template")

    local recorded_version="unknown"
    local recorded_hash=""
    local current_hash
    current_hash=$(get_file_hash "$output_path")

    if command -v jq >/dev/null 2>&1; then
      recorded_version=$(echo "$generated" | jq -r ".files[\"$output_path\"].templateVersion // \"unknown\"")
      recorded_hash=$(echo "$generated" | jq -r ".files[\"$output_path\"].fileHash // \"\"")
    fi

    # バージョン比較（unknown は常に古いとみなす）
    local needs_update=false
    if [ "$recorded_version" = "unknown" ]; then
      needs_update=true
    elif [ "$recorded_version" != "$template_version" ]; then
      needs_update=true
    fi

    if [ "$needs_update" = true ]; then
      local is_localized=false
      if [ -n "$recorded_hash" ] && [ "$recorded_hash" != "$current_hash" ]; then
        is_localized=true
      fi

      if command -v jq >/dev/null 2>&1; then
        updates_details=$(echo "$updates_details" | jq --arg path "$output_path" \
          --arg from "$recorded_version" --arg to "$template_version" \
          --argjson localized "$is_localized" \
          '. + [{"path": $path, "from": $from, "to": $to, "localized": $localized}]')
      fi
    fi
  done < <(get_tracked_templates)

  local count
  if command -v jq >/dev/null 2>&1; then
    count=$(echo "$updates_details" | jq 'length')
  else
    count=0
  fi

  # lastCheckedPluginVersion を更新
  if command -v jq >/dev/null 2>&1; then
    generated=$(echo "$generated" | jq --arg v "$plugin_version" '.lastCheckedPluginVersion = $v')
    save_generated_files "$generated"
  fi

  if [ "$count" -gt 0 ]; then
    echo "{\"needsCheck\": true, \"updatesCount\": $count, \"updates\": $updates_details}"
  else
    echo '{"needsCheck": false, "reason": "All files up to date"}'
  fi
}

# ステータス: 人間向け詳細表示
cmd_status() {
  local generated
  generated=$(load_generated_files)

  local plugin_version
  plugin_version=$(get_plugin_version)

  echo "=== テンプレート追跡状況 ==="
  echo ""
  echo "プラグインバージョン: $plugin_version"

  if command -v jq >/dev/null 2>&1; then
    local last_checked
    last_checked=$(echo "$generated" | jq -r '.lastCheckedPluginVersion // "未チェック"')
    echo "最終チェック時: $last_checked"
  fi
  echo ""

  printf "%-40s %-12s %-12s %-10s\n" "ファイル" "記録版" "最新版" "状態"
  printf "%-40s %-12s %-12s %-10s\n" "--------" "------" "------" "----"

  while IFS= read -r template; do
    [ -z "$template" ] && continue

    local output_path
    output_path=$(get_output_path "$template")
    [ -z "$output_path" ] && continue

    local template_version
    template_version=$(get_template_version "$template")

    if [ ! -f "$output_path" ]; then
      printf "%-40s %-12s %-12s %-10s\n" "$output_path" "-" "$template_version" "未生成"
      continue
    fi

    local recorded_version="unknown"
    local recorded_hash=""
    local current_hash
    current_hash=$(get_file_hash "$output_path")

    if command -v jq >/dev/null 2>&1; then
      recorded_version=$(echo "$generated" | jq -r ".files[\"$output_path\"].templateVersion // \"unknown\"")
      recorded_hash=$(echo "$generated" | jq -r ".files[\"$output_path\"].fileHash // \"\"")
    fi

    local status="✅ 最新"
    if [ "$recorded_version" = "unknown" ]; then
      status="⚠️ 要確認"
    elif [ "$recorded_version" != "$template_version" ]; then
      if [ -n "$recorded_hash" ] && [ "$recorded_hash" != "$current_hash" ]; then
        status="🔧 マージ要"
      else
        status="🔄 上書き可"
      fi
    fi

    printf "%-40s %-12s %-12s %-10s\n" "$output_path" "$recorded_version" "$template_version" "$status"
  done < <(get_tracked_templates)

  echo ""
  echo "凡例:"
  echo "  ✅ 最新     : 更新不要"
  echo "  🔄 上書き可 : ローカライズなし、上書きで更新可能"
  echo "  🔧 マージ要 : ローカライズあり、マージが必要"
  echo "  ⚠️ 要確認   : バージョン不明、確認推奨"
}

# ファイルを最新テンプレートで更新（記録も更新）
cmd_record() {
  local file_path="$1"

  if [ -z "$file_path" ]; then
    echo "Usage: template-tracker.sh record <file_path>"
    exit 1
  fi

  if [ ! -f "$file_path" ]; then
    echo "Error: File not found: $file_path"
    exit 1
  fi

  # template-registry.json から該当するテンプレートを探す
  local template_version=""
  while IFS= read -r template; do
    [ -z "$template" ] && continue

    local output_path
    output_path=$(get_output_path "$template")

    if [ "$output_path" = "$file_path" ]; then
      template_version=$(get_template_version "$template")
      break
    fi
  done < <(get_tracked_templates)

  if [ -z "$template_version" ]; then
    echo "Error: Template not found for: $file_path"
    exit 1
  fi

  local file_hash
  file_hash=$(get_file_hash "$file_path")

  local generated
  generated=$(load_generated_files)

  if command -v jq >/dev/null 2>&1; then
    generated=$(echo "$generated" | jq --arg path "$file_path" \
      --arg version "$template_version" --arg hash "$file_hash" \
      '.files[$path] = {"templateVersion": $version, "fileHash": $hash, "recordedAt": (now | strftime("%Y-%m-%dT%H:%M:%SZ"))}')
    save_generated_files "$generated"
    echo "Recorded: $file_path (version: $template_version)"
  else
    echo "Error: jq is required for this operation"
    exit 1
  fi
}

# メイン
case "${1:-}" in
  init)
    cmd_init
    ;;
  check)
    cmd_check
    ;;
  status)
    cmd_status
    ;;
  record)
    cmd_record "$2"
    ;;
  *)
    echo "Usage: template-tracker.sh {init|check|status|record <file>}"
    echo ""
    echo "Commands:"
    echo "  init   - Initialize generated-files.json with current file states"
    echo "  check  - Check for template updates (JSON output for SessionStart)"
    echo "  status - Show detailed status (human-readable)"
    echo "  record - Record a file's current state after update"
    exit 1
    ;;
esac
