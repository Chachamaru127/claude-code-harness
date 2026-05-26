#!/bin/bash
#
# opencode-setup-local.sh
#
# Copy opencode templates from the installed Harness plugin.
#
# Usage:
#   ./scripts/opencode-setup-local.sh
#
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(pwd)"

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

  local fallback=""
  local candidate
  for candidate in "${candidates[@]}"; do
    [ -n "$candidate" ] || continue
    if [ -d "$candidate/opencode/skills" ]; then
      [ -z "$fallback" ] && fallback="$candidate"
      if [ -f "$candidate/opencode/AGENTS.md" ] && [ -f "$candidate/opencode/opencode.json" ]; then
        echo "$candidate"
        return 0
      fi
    fi
  done

  if [ -n "$fallback" ]; then
    echo "$fallback"
    return 0
  fi

  return 1
}

PLUGIN_DIR="$(resolve_plugin_dir || true)"
if [ -z "$PLUGIN_DIR" ]; then
  fail "Harness plugin directory not found. Set CLAUDE_PLUGIN_ROOT or install the plugin."
fi

echo "Using Harness plugin: $PLUGIN_DIR"

copy_dir_contents() {
  local src="$1"
  local dest="$2"
  local label="$3"
  local required="${4:-required}"

  if [ ! -d "$src" ]; then
    if [ "$required" = "required" ]; then
      fail "$label not found in Harness plugin source"
    fi
    echo "Warning: $label not found in plugin source."
    return
  fi

  if [ -z "$(find "$src" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
    if [ "$required" = "required" ]; then
      fail "$label is empty in Harness plugin source"
    fi
    echo "Warning: $label is empty in plugin source."
    return
  fi

  mkdir -p "$dest"
  cp -R "$src/." "$dest/"
  echo "Copied $label to: $dest"
}

backup_dir_if_nonempty() {
  local dir="$1"
  local label="$2"

  if [ -d "$dir" ] && [ -n "$(find "$dir" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
    backup_dir="$dir.backup.$(date +%Y%m%d%H%M%S)"
    mv "$dir" "$backup_dir"
    mkdir -p "$dir"
    echo "Backed up existing $label to: $backup_dir"
  fi
}

copy_file_with_backup() {
  local src="$1"
  local dest="$2"
  local label="$3"

  [ -f "$src" ] || fail "$label not found in Harness plugin source"
  mkdir -p "$(dirname "$dest")"
  if [ -f "$dest" ]; then
    backup_file="$dest.backup.$(date +%Y%m%d%H%M%S)"
    mv "$dest" "$backup_file"
    echo "Backed up existing $label to: $backup_file"
  fi
  cp "$src" "$dest"
  echo "Copied $label to: $dest"
}

mkdir -p "$PROJECT_DIR/.opencode/skills"
backup_dir_if_nonempty "$PROJECT_DIR/.opencode/skills" ".opencode/skills"
copy_dir_contents "$PLUGIN_DIR/opencode/skills" "$PROJECT_DIR/.opencode/skills" "OpenCode skills"

copy_dir_contents "$PLUGIN_DIR/opencode/commands" "$PROJECT_DIR/.opencode/commands" "OpenCode compatibility commands" "optional"

copy_file_with_backup \
  "$PLUGIN_DIR/opencode/plugins/harness-bootstrap.mjs" \
  "$PROJECT_DIR/.opencode/plugins/harness-bootstrap.mjs" \
  "OpenCode bootstrap plugin"

if [ -f "$PROJECT_DIR/AGENTS.md" ]; then
  backup_agents="$PROJECT_DIR/AGENTS.md.backup.$(date +%Y%m%d%H%M%S)"
  mv "$PROJECT_DIR/AGENTS.md" "$backup_agents"
  echo "Backed up existing AGENTS.md to: $backup_agents"
fi

if [ -f "$PLUGIN_DIR/opencode/AGENTS.md" ]; then
  cp "$PLUGIN_DIR/opencode/AGENTS.md" "$PROJECT_DIR/AGENTS.md"
else
  fail "opencode/AGENTS.md not found in Harness plugin source"
fi

if [ -f "$PROJECT_DIR/opencode.json" ]; then
  echo "opencode.json already exists, skipping."
elif [ -f "$PLUGIN_DIR/opencode/opencode.json" ]; then
  cp "$PLUGIN_DIR/opencode/opencode.json" "$PROJECT_DIR/opencode.json"
else
  fail "opencode/opencode.json not found in Harness plugin source"
fi

first_skill="$(find "$PROJECT_DIR/.opencode/skills" -mindepth 2 -maxdepth 2 -name SKILL.md -print -quit 2>/dev/null || true)"
[ -n "$first_skill" ] || fail "No OpenCode skills installed under .opencode/skills/"
[ -f "$PROJECT_DIR/AGENTS.md" ] || fail "AGENTS.md was not created"
[ -f "$PROJECT_DIR/opencode.json" ] || fail "opencode.json was not created"
[ -f "$PROJECT_DIR/.opencode/plugins/harness-bootstrap.mjs" ] || fail "OpenCode bootstrap plugin was not created"

if command -v node >/dev/null 2>&1; then
  node -e "JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'))" "$PROJECT_DIR/opencode.json" \
    || fail "opencode.json is not valid JSON"
fi

echo "Copied OpenCode-native skills, bootstrap plugin, AGENTS.md, opencode.json, and optional compatibility commands."
