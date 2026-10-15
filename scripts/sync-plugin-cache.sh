#!/bin/bash
# sync-plugin-cache.sh — Harness plugin cache sync
# 1. Delegates CC file generation to `harness sync` (Go binary)
# 2. Syncs critical scripts to marketplace distribution cache
#
# Usage: Called from SessionStart hook or manually

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

is_harness_root() {
  local candidate="${1:-}"
  [ -n "$candidate" ] &&
    [ -x "$candidate/bin/harness" ] &&
    [ -f "$candidate/.claude-plugin/plugin.json" ] &&
    grep -q '"name"[[:space:]]*:[[:space:]]*"harness"' "$candidate/.claude-plugin/plugin.json"
}

PROJECT_ROOT="${CLAUDE_PLUGIN_ROOT:-$DEFAULT_PROJECT_ROOT}"
if ! is_harness_root "$PROJECT_ROOT"; then
  if is_harness_root "$DEFAULT_PROJECT_ROOT"; then
    PROJECT_ROOT="$DEFAULT_PROJECT_ROOT"
  else
    echo "Error: could not resolve harness plugin root." >&2
    exit 1
  fi
fi

# --- Step 1: Run harness sync (Go binary) ---
# Best-effort: if the binary is unavailable (e.g. in CI before build), skip
# and rely on the committed .claude-plugin/* files for Step 2 distribution.
sync_ok=0
if command -v harness >/dev/null 2>&1; then
  harness sync "$PROJECT_ROOT" && sync_ok=1
elif [ -x "${PROJECT_ROOT}/bin/harness" ] && "${PROJECT_ROOT}/bin/harness" sync "$PROJECT_ROOT" 2>/dev/null; then
  sync_ok=1
fi
if [ "$sync_ok" = 0 ]; then
  echo "Warning: harness binary not found or failed; using committed .claude-plugin/* files." >&2
fi

# --- Step 2: Sync plugin load surfaces to marketplace cache ---
PLUGIN_NAME="harness"
MARKETPLACE_NAME="claude-code-harness-marketplace"
SOURCE_VERSION="$(tr -d '[:space:]' < "${PROJECT_ROOT}/VERSION")"
CACHE_DIR="${HOME}/.claude/plugins/cache/${MARKETPLACE_NAME}/${PLUGIN_NAME}/${SOURCE_VERSION}"
MARKETPLACE_DIR="${HOME}/.claude/plugins/marketplaces/${MARKETPLACE_NAME}"

# The versioned cache directory is created by Claude Code's plugin installer,
# which copies the whole plugin tree into it. This script must only refresh an
# install that already exists. When it pre-created the directory (a checkout
# whose VERSION was bumped before `claude plugin update` ran), the installer
# later found the directory present and left it as-is, so users got a plugin
# holding only the subset synced here: no agents/, no bin/, no templates/
# (observed for 5.8.0, 5.9.0, 5.13.0, 5.13.1; `claude plugin list` → Agents (0)).
if [ ! -d "$CACHE_DIR" ]; then
  echo "Info: plugin cache ${SOURCE_VERSION} is not installed; skipping cache sync." >&2
  CACHE_DIR=""
fi

# The marketplace clone is a git checkout owned by Claude Code, and its
# working-tree .claude-plugin/plugin.json `version` is what
# `claude plugin update` compares against. Writing this checkout's files into a
# clone that sits on another release rewrites that version (a 5.13.0 worktree
# held the clone at 5.13.0 after 5.13.1 shipped, so the update reported
# "already at the latest version"). Refresh the clone only when it is on the
# same release, and never rewrite its version-bearing files.
MARKETPLACE_SYNC=0
if [ -d "$MARKETPLACE_DIR" ]; then
  clone_version="$(git -C "$MARKETPLACE_DIR" show HEAD:VERSION 2>/dev/null | tr -d '[:space:]' || true)"
  if [ -z "$clone_version" ] && [ -f "${MARKETPLACE_DIR}/VERSION" ]; then
    clone_version="$(tr -d '[:space:]' < "${MARKETPLACE_DIR}/VERSION")"
  fi
  if [ "$clone_version" = "$SOURCE_VERSION" ] &&
    grep -q '"name"[[:space:]]*:[[:space:]]*"harness"' "${MARKETPLACE_DIR}/.claude-plugin/plugin.json" 2>/dev/null; then
    MARKETPLACE_SYNC=1
  else
    echo "Info: marketplace clone is at ${clone_version:-unknown}, source is ${SOURCE_VERSION}; version or plugin identity differs, skipping marketplace sync." >&2
  fi
fi

is_version_bearing() {
  case "$1" in
    VERSION|.claude-plugin/plugin.json|.claude-plugin/marketplace.json) return 0 ;;
    *) return 1 ;;
  esac
}

sync_file_to_dir() {
  local rel_path="$1"
  local target_dir="$2"
  local src="${PROJECT_ROOT}/${rel_path}"
  local dst="${target_dir}/${rel_path}"
  if [ -f "$src" ]; then
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
  fi
}

sync_file() {
  local rel_path="$1"

  if [ -n "$CACHE_DIR" ]; then
    sync_file_to_dir "$rel_path" "$CACHE_DIR"
  fi

  # Keep the installed marketplace clone's hook definitions in lockstep when it
  # is on this release. Claude may load hooks from this path before the
  # versioned cache. Version-bearing files stay owned by the clone's git.
  if [ "$MARKETPLACE_SYNC" = 1 ] && ! is_version_bearing "$rel_path"; then
    sync_file_to_dir "$rel_path" "$MARKETPLACE_DIR"
  fi
}

copy_hook_script_closure() {
  local hooks_file="$1"
  local rel_path

  if [ ! -f "${PROJECT_ROOT}/${hooks_file}" ]; then
    return 0
  fi

  while IFS= read -r rel_path; do
    [ -n "$rel_path" ] || continue
    sync_file "$rel_path"
  done < <(grep -Eoh 'scripts/[A-Za-z0-9_./-]+\.sh' "${PROJECT_ROOT}/${hooks_file}" | sort -u)
}

sync_dir_to_dir() {
  local rel_path="$1"
  local target_dir="$2"
  local src="${PROJECT_ROOT}/${rel_path}"
  local dst="${target_dir}/${rel_path}"
  if [ -d "$src" ]; then
    rm -rf "$dst"
    mkdir -p "$dst"

    # When running from a source checkout, sync only tracked files. The working
    # tree can contain ignored/private skill directories, .DS_Store files, or
    # local scratch data under manifest-declared directories; those must never
    # be copied into the installed plugin cache.
    if git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      local copied=0
      while IFS= read -r -d '' tracked_path; do
        local tracked_src="${PROJECT_ROOT}/${tracked_path}"
        local tracked_dst="${target_dir}/${tracked_path}"
        if [ -f "$tracked_src" ]; then
          mkdir -p "$(dirname "$tracked_dst")"
          cp -p "$tracked_src" "$tracked_dst"
          copied=1
        fi
      done < <(git -C "$PROJECT_ROOT" ls-files -z -- "$rel_path")

      if [ "$copied" = 1 ]; then
        return
      fi
    fi

    cp -R "$src"/. "$dst"/
  fi
}

sync_dir() {
  local rel_path="$1"

  if [ -n "$CACHE_DIR" ]; then
    sync_dir_to_dir "$rel_path" "$CACHE_DIR"
  fi

  # Keep the installed marketplace checkout loadable too; Claude may inspect it
  # before the versioned cache depending on install/reload state.
  if [ "$MARKETPLACE_SYNC" = 1 ]; then
    sync_dir_to_dir "$rel_path" "$MARKETPLACE_DIR"
  fi
}

cleanup_private_paths_in_dir() {
  local target_dir="$1"
  [ -d "$target_dir" ] || return 0

  local private_paths=(
    "skills/claude-codex-upstream-update"
    "skills/harness-release-internal"
    "skills/x-announce"
    "skills/x-article"
    "opencode/skills/claude-codex-upstream-update"
    "opencode/skills/harness-release-internal"
    "opencode/skills/x-announce"
    "opencode/skills/x-article"
    "codex/.codex/skills/claude-codex-upstream-update"
    "codex/.codex/skills/harness-release-internal"
    "codex/.codex/skills/x-announce"
    "codex/.codex/skills/x-article"
    "docs/private"
    "docs/research"
  )

  local rel_path
  for rel_path in "${private_paths[@]}"; do
    rm -rf "${target_dir}/${rel_path}"
  done

  find "${target_dir}" -name .DS_Store -delete 2>/dev/null || true
}

# Critical files to sync to distribution cache
critical_files=(
  "scripts/lib/harness-mem-bridge.sh"
  "scripts/codex-companion.sh"
  "scripts/cursor-companion.sh"
  "scripts/model-routing.sh"
  "scripts/resolve-impl-backend.sh"
  "scripts/hook-handlers/memory-bridge.sh"
  "scripts/hook-handlers/memory-session-start.sh"
  "scripts/hook-handlers/memory-user-prompt.sh"
  "scripts/hook-handlers/memory-post-tool-use.sh"
  "scripts/hook-handlers/memory-stop.sh"
  "scripts/hook-handlers/memory-codex-notify.sh"
  "scripts/hook-handlers/runtime-reactive.sh"
  "hooks/hooks.json"
  ".claude-plugin/hooks.json"
  ".claude-plugin/settings.json"
  ".claude-plugin/plugin.json"
  "VERSION"
)

for file in "${critical_files[@]}"; do
  sync_file "$file"
done

copy_hook_script_closure ".claude-plugin/hooks.json"
copy_hook_script_closure "hooks/hooks.json"

# Plugin load surfaces: plugin.json declares skills / outputStyles, and Claude
# auto-discovers agents/ at the plugin root. If they are missing from the
# versioned install cache, Claude lists the plugin as enabled but failed to
# load (or with Agents (0)).
critical_dirs=(
  "skills"
  "output-styles"
  "agents"
)

for dir in "${critical_dirs[@]}"; do
  sync_dir "$dir"
done

# Only the installed cache is cleaned. The marketplace clone is a git checkout
# in which these paths are tracked files; deleting them there left the clone
# permanently dirty (21 `D docs/research/*` entries) for no privacy gain.
if [ -n "$CACHE_DIR" ]; then
  cleanup_private_paths_in_dir "$CACHE_DIR"
fi
