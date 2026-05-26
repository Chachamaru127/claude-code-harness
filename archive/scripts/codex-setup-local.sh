#!/bin/bash
#
# codex-setup-local.sh
#
# Copy Codex CLI templates from the installed Harness plugin.
#
# Usage:
#   ./scripts/codex-setup-local.sh [--user|--project]
#
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(pwd)"
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
TARGET_MODE="user"

while [ $# -gt 0 ]; do
  case "$1" in
    --user)
      TARGET_MODE="user"
      ;;
    --project)
      TARGET_MODE="project"
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 [--user|--project]" >&2
      exit 1
      ;;
  esac
  shift
done

fail() {
  echo "Error: $1" >&2
  exit 1
}

pick_latest_version_dir() {
  local base_dir="$1"
  if [ ! -d "$base_dir" ]; then
    return 1
  fi

  local latest
  latest="$(ls -1 "$base_dir" 2>/dev/null | sort -V | tail -n 1)"
  if [ -z "$latest" ]; then
    return 1
  fi
  echo "$base_dir/$latest"
}

resolve_plugin_dir() {
  local repo_root
  repo_root="$(cd "$SCRIPT_DIR/.." && pwd)"

  local marketplace_dir="$HOME/.claude/plugins/marketplaces/claude-code-harness-marketplace"
  local cache_root="$HOME/.claude/plugins/cache/claude-code-harness-marketplace/claude-code-harness"
  local cache_dir
  cache_dir="$(pick_latest_version_dir "$cache_root" || true)"

  local candidates=(
    "${CLAUDE_PLUGIN_ROOT:-}"
    "$repo_root"
    "$marketplace_dir"
    "$cache_dir"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    [ -n "$candidate" ] || continue
    if [ -d "$candidate/codex/.codex/skills" ]; then
      echo "$candidate"
      return 0
    fi
  done

  return 1
}

backup_path() {
  local target="$1"
  local backup_root="$2"
  if [ -e "$target" ] || [ -L "$target" ]; then
    local ts
    local base
    local dst
    ts=$(date +%Y%m%d%H%M%S)
    base="$(basename "$target")"
    mkdir -p "$backup_root"
    dst="$backup_root/${base}.${ts}.$$"
    local suffix=1
    while [ -e "$dst" ] || [ -L "$dst" ]; do
      dst="$backup_root/${base}.${ts}.$$.$suffix"
      suffix=$((suffix + 1))
    done
    mv "$target" "$dst"
    echo "Backed up $target to $dst"
  fi
}

same_physical_path() {
  local left="$1"
  local right="$2"

  [ -e "$left" ] || return 1
  [ -e "$right" ] || return 1

  local left_real
  local right_real
  left_real="$(physical_path "$left")"
  right_real="$(physical_path "$right")"

  [ "$left_real" = "$right_real" ]
}

physical_path() {
  local path="$1"

  if [ -d "$path" ]; then
    (cd "$path" && pwd -P)
    return 0
  fi

  if [ -L "$path" ]; then
    local link_target
    link_target="$(readlink "$path")" || return 1
    case "$link_target" in
      /*)
        physical_path "$link_target"
        ;;
      *)
        physical_path "$(dirname "$path")/$link_target"
        ;;
    esac
    return $?
  fi

  (cd "$(dirname "$path")" && printf '%s/%s\n' "$(pwd -P)" "$(basename "$path")")
}

copy_sync_entry() {
  local src="$1"
  local dst_dir="$2"

  cp -R -L "$src" "$dst_dir/"
}

sync_entry_to_path() {
  local src="$1"
  local dst_path="$2"
  local dst_dir="$3"
  local backup_root="$4"

  if [ -L "$dst_path" ]; then
    if same_physical_path "$src" "$dst_path"; then
      return 1
    fi
    backup_path "$dst_path" "$backup_root"
    copy_sync_entry "$src" "$dst_dir"
    return 0
  fi

  backup_path "$dst_path" "$backup_root"
  copy_sync_entry "$src" "$dst_dir"
  return 0
}

should_skip_sync_entry() {
  local name="$1"
  case "$name" in
    _archived|*.backup.*)
      return 0
      ;;
  esac
  return 1
}

is_legacy_harness_skill_name() {
  local name="$1"
  case "$name" in
    plan-with-agent|planning|plans-management|sync-status|work|execute|impl|parallel-workflows|verify|setup|harness-init|release-har|codex-review|codex-worker|remember)
      return 0
      ;;
  esac
  return 1
}

is_harness_managed_skill_entry() {
  local skill_file="$1"
  [ -f "$skill_file" ] || return 1

  if grep -Eq 'Claude Code Harness|Harness v3|claude-code-harness|/harness-|Plans\.md' "$skill_file"; then
    return 0
  fi
  return 1
}

cleanup_legacy_skill_entries() {
  local dst_dir="$1"
  local backup_root="$2"
  [ -d "$dst_dir" ] || return 0

  local legacy_path
  for legacy_path in "$dst_dir"/_archived "$dst_dir"/*.backup.*; do
    [ -e "$legacy_path" ] || continue
    backup_path "$legacy_path" "$backup_root"
  done
}

extract_skill_frontmatter_name() {
  local skill_file="$1"
  [ -f "$skill_file" ] || return 1

  awk '
    BEGIN { in_frontmatter = 0 }
    /^---[[:space:]]*$/ {
      if (in_frontmatter == 0) {
        in_frontmatter = 1
        next
      }
      exit
    }
    in_frontmatter == 1 && /^[[:space:]]*name:[[:space:]]*/ {
      sub(/^[[:space:]]*name:[[:space:]]*/, "", $0)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
      gsub(/^"|"$/, "", $0)
      print $0
      exit
    }
  ' "$skill_file"
}

cleanup_legacy_skill_name_duplicates() {
  local src_dir="$1"
  local dst_dir="$2"
  local backup_root="$3"
  [ -d "$src_dir" ] || return 0
  [ -d "$dst_dir" ] || return 0

  local src_skill_names=""
  local src_entry
  for src_entry in "$src_dir"/*; do
    [ -d "$src_entry" ] || continue
    local src_name
    src_name="$(basename "$src_entry")"
    if should_skip_sync_entry "$src_name"; then
      continue
    fi
    local src_skill_name
    src_skill_name="$(extract_skill_frontmatter_name "$src_entry/SKILL.md" || true)"
    [ -n "$src_skill_name" ] || continue
    src_skill_names+=$'\n'"$src_skill_name"
  done

  [ -n "$src_skill_names" ] || return 0

  local deduped=0
  local dst_entry
  for dst_entry in "$dst_dir"/*; do
    [ -d "$dst_entry" ] || continue
    local dst_name
    dst_name="$(basename "$dst_entry")"
    if should_skip_sync_entry "$dst_name"; then
      continue
    fi
    [ -e "$src_dir/$dst_name" ] && continue

    local dst_skill_name
    dst_skill_name="$(extract_skill_frontmatter_name "$dst_entry/SKILL.md" || true)"
    [ -n "$dst_skill_name" ] || continue

    if printf '%s\n' "$src_skill_names" | grep -Fxq "$dst_skill_name"; then
      backup_path "$dst_entry" "$backup_root"
      deduped=$((deduped + 1))
    fi
  done

  if [ "$deduped" -gt 0 ]; then
    echo "Moved $deduped legacy skill alias(es) with duplicate frontmatter name"
  fi
}

cleanup_removed_harness_skill_entries() {
  local src_dir="$1"
  local dst_dir="$2"
  local backup_root="$3"
  [ -d "$src_dir" ] || return 0
  [ -d "$dst_dir" ] || return 0

  local removed=0
  local dst_entry
  for dst_entry in "$dst_dir"/*; do
    [ -d "$dst_entry" ] || continue
    local dst_name
    dst_name="$(basename "$dst_entry")"
    if should_skip_sync_entry "$dst_name"; then
      continue
    fi
    [ -e "$src_dir/$dst_name" ] && continue

    local dst_skill_file="$dst_entry/SKILL.md"
    local dst_skill_name
    dst_skill_name="$(extract_skill_frontmatter_name "$dst_skill_file" || true)"

    if ! is_harness_managed_skill_entry "$dst_skill_file"; then
      continue
    fi

    if is_legacy_harness_skill_name "$dst_name" || { [ -n "$dst_skill_name" ] && is_legacy_harness_skill_name "$dst_skill_name"; }; then
      backup_path "$dst_entry" "$backup_root"
      removed=$((removed + 1))
    fi
  done

  if [ "$removed" -gt 0 ]; then
    echo "Moved $removed removed legacy Harness skill(s) that are no longer shipped"
  fi
}

merge_dir_recursive() {
  local src_dir="$1"
  local dst_dir="$2"
  local backup_root="$3"
  local _copied_ref="$4"
  local _updated_ref="$5"

  mkdir -p "$dst_dir"

  local entry
  for entry in "$src_dir"/*; do
    [ -e "$entry" ] || [ -L "$entry" ] || continue
    local name
    name="$(basename "$entry")"
    local dst_path="$dst_dir/$name"

    if [ ! -e "$dst_path" ] && [ ! -L "$dst_path" ]; then
      copy_sync_entry "$entry" "$dst_dir"
      eval "$_copied_ref=\$((\$$_copied_ref + 1))"
    elif [ -L "$dst_path" ]; then
      if sync_entry_to_path "$entry" "$dst_path" "$dst_dir" "$backup_root"; then
        eval "$_updated_ref=\$((\$$_updated_ref + 1))"
      fi
    elif [ -d "$entry" ] && [ -d "$dst_path" ]; then
      merge_dir_recursive "$entry" "$dst_path" "$backup_root" "$_copied_ref" "$_updated_ref"
    else
      if sync_entry_to_path "$entry" "$dst_path" "$dst_dir" "$backup_root"; then
        eval "$_updated_ref=\$((\$$_updated_ref + 1))"
      fi
    fi
  done
}

sync_named_children() {
  local src_dir="$1"
  local dst_dir="$2"
  local label="$3"
  local backup_root="$4"

  [ -d "$src_dir" ] || fail "$label source not found: $src_dir"
  mkdir -p "$dst_dir"

  local copied=0
  local updated=0
  local skipped=0
  local preserved=0
  local entry
  for entry in "$src_dir"/*; do
    [ -e "$entry" ] || [ -L "$entry" ] || continue
    local name
    name="$(basename "$entry")"
    if should_skip_sync_entry "$name"; then
      skipped=$((skipped + 1))
      continue
    fi
    local dst_path="$dst_dir/$name"

    if [ ! -e "$dst_path" ] && [ ! -L "$dst_path" ]; then
      copy_sync_entry "$entry" "$dst_dir"
      copied=$((copied + 1))
    elif [ -L "$dst_path" ]; then
      if sync_entry_to_path "$entry" "$dst_path" "$dst_dir" "$backup_root"; then
        updated=$((updated + 1))
      else
        preserved=$((preserved + 1))
      fi
    elif [ -d "$entry" ] && [ -d "$dst_path" ]; then
      merge_dir_recursive "$entry" "$dst_path" "$backup_root" "copied" "updated"
    else
      if sync_entry_to_path "$entry" "$dst_path" "$dst_dir" "$backup_root"; then
        updated=$((updated + 1))
      fi
    fi
  done

  for entry in "$dst_dir"/*; do
    [ -e "$entry" ] || [ -L "$entry" ] || continue
    local name
    name="$(basename "$entry")"
    if should_skip_sync_entry "$name"; then
      continue
    fi
    [ -e "$src_dir/$name" ] || preserved=$((preserved + 1))
  done

  echo "$label merged to $dst_dir ($copied new, $updated updated, $preserved preserved, $skipped skipped)"
}

copy_project_agents() {
  local plugin_dir="$1"
  local backup_root="$2"
  local agents_src="$plugin_dir/codex/AGENTS.md"
  local agents_dst="$PROJECT_DIR/AGENTS.md"

  [ -f "$agents_src" ] || fail "codex/AGENTS.md not found in plugin source"

  if [ -f "$agents_dst" ]; then
    backup_path "$agents_dst" "$backup_root"
  fi

  cp "$agents_src" "$agents_dst"
  echo "AGENTS.md copied to project root"
}

ensure_multi_agent_defaults() {
  local target_root="$1"
  local cfg="$target_root/config.toml"

  mkdir -p "$target_root"

  if [ ! -f "$cfg" ]; then
    cat > "$cfg" <<'CFG'
[features]
multi_agent = true

[agents]
max_threads = 8

[agents.implementer]
description = "Codex implementation worker for harness task execution"

[agents.reviewer]
description = "Codex reviewer worker for harness review and retake loops"

[agents.claude_implementer]
description = "Claude CLI delegated implementation worker (used when --claude)"

[agents.claude_reviewer]
description = "Claude CLI delegated reviewer worker (used when --claude)"
CFG
    echo "Created $cfg with multi_agent + harness role defaults"
    return
  fi

  if ! grep -q '^[[:space:]]*multi_agent[[:space:]]*=' "$cfg"; then
    cat >> "$cfg" <<'CFG'

[features]
multi_agent = true
CFG
    echo "Enabled features.multi_agent in $cfg"
  fi

  if ! grep -q '^\[agents\]' "$cfg"; then
    cat >> "$cfg" <<'CFG'

[agents]
max_threads = 8
CFG
  fi

  if ! grep -q '^\[agents\.implementer\]' "$cfg"; then
    cat >> "$cfg" <<'CFG'

[agents.implementer]
description = "Codex implementation worker for harness task execution"
CFG
  fi

  if ! grep -q '^\[agents\.reviewer\]' "$cfg"; then
    cat >> "$cfg" <<'CFG'

[agents.reviewer]
description = "Codex reviewer worker for harness review and retake loops"
CFG
  fi

  if ! grep -q '^\[agents\.claude_implementer\]' "$cfg"; then
    cat >> "$cfg" <<'CFG'

[agents.claude_implementer]
description = "Claude CLI delegated implementation worker (used when --claude)"
CFG
  fi

  if ! grep -q '^\[agents\.claude_reviewer\]' "$cfg"; then
    cat >> "$cfg" <<'CFG'

[agents.claude_reviewer]
description = "Claude CLI delegated reviewer worker (used when --claude)"
CFG
  fi
}

PLUGIN_DIR="$(resolve_plugin_dir || true)"
if [ -z "$PLUGIN_DIR" ]; then
  fail "Harness plugin directory not found. Set CLAUDE_PLUGIN_ROOT or install the plugin."
fi

echo "Using Harness plugin: $PLUGIN_DIR"

target_root=""
backup_root=""
if [ "$TARGET_MODE" = "user" ]; then
  target_root="$CODEX_HOME_DIR"
  backup_root="$CODEX_HOME_DIR/backups/codex-setup-local"
  echo "Install mode: user (target: $target_root)"
else
  target_root="$PROJECT_DIR/.codex"
  backup_root="$target_root/backups/codex-setup-local"
  echo "Install mode: project (target: $target_root)"
fi

cleanup_legacy_skill_entries "$target_root/skills" "$backup_root"
cleanup_legacy_skill_name_duplicates "$PLUGIN_DIR/codex/.codex/skills" "$target_root/skills" "$backup_root"
cleanup_removed_harness_skill_entries "$PLUGIN_DIR/codex/.codex/skills" "$target_root/skills" "$backup_root"
sync_named_children "$PLUGIN_DIR/codex/.codex/skills" "$target_root/skills" "Skills" "$backup_root"
sync_named_children "$PLUGIN_DIR/codex/.codex/rules" "$target_root/rules" "Rules" "$backup_root"

if [ "$TARGET_MODE" = "project" ]; then
  copy_project_agents "$PLUGIN_DIR" "$backup_root"
else
  echo "User mode: project AGENTS.md is unchanged"
fi

ensure_multi_agent_defaults "$target_root"

echo "Codex CLI setup complete."
echo "Backups are stored under: $backup_root (outside skill scan path)"
if [ "$TARGET_MODE" = "user" ]; then
  echo "Restart Codex to reload user-level skills/rules if needed."
fi
echo "Use \$harness-plan / \$harness-work / \$breezing to run Harness from Codex."
