#!/usr/bin/env bash
# setup-cursor.sh
# Install Claude Code Harness as a Cursor local plugin (real directory copy).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${HARNESS_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
BUILD_SCRIPT="${ROOT_DIR}/scripts/build-host-plugin-dist.sh"
PLUGIN_NAME="claude-code-harness"
CURSOR_PLUGINS_LOCAL="${HOME}/.cursor/plugins/local"
INSTALL_DIR="${CURSOR_PLUGINS_LOCAL}/${PLUGIN_NAME}"
DIST_DIR="${HARNESS_CURSOR_DIST:-${HOME}/.local/share/claude-code-harness/cursor}"
CHECK_ONLY=0

usage() {
  cat <<'EOF'
Usage: setup-cursor.sh [--check]

Install Claude Code Harness for Cursor into:
  ~/.cursor/plugins/local/claude-code-harness

Environment:
  HARNESS_PROJECT_ROOT  Repo root (default: parent of scripts/)
  HARNESS_CURSOR_DIST   Output directory for generated cursor package
  HOME                  Used for ~/.cursor/plugins/local install target

Options:
  --check   Build and validate the cursor package only; do not install.
  -h, --help
EOF
}

log_info() { echo "[INFO] $1"; }
log_ok() { echo "[OK]   $1"; }
log_warn() { echo "[WARN] $1"; }
log_err() { echo "[ERR]  $1" >&2; }

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --check)
        CHECK_ONLY=1
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        log_err "unknown argument: $1"
        usage
        exit 2
        ;;
    esac
    shift
  done
}

require_build_script() {
  if [ ! -f "$BUILD_SCRIPT" ]; then
    log_err "missing build script: $BUILD_SCRIPT"
    exit 1
  fi
  chmod +x "$BUILD_SCRIPT" 2>/dev/null || true
}

build_dist() {
  log_info "Building Cursor package at $DIST_DIR"
  bash "$BUILD_SCRIPT" --host cursor --out "$DIST_DIR"
  log_ok "Cursor package built"
}

validate_dist() {
  local manifest="${DIST_DIR}/.cursor-plugin/plugin.json"
  local breezing="${DIST_DIR}/skills/breezing/SKILL.md"

  [ -f "$manifest" ] || {
    log_err "missing manifest: $manifest"
    exit 1
  }

  if grep -Fq '../' "$manifest"; then
    log_err "cursor manifest must not contain .. paths"
    exit 1
  fi

  [ -f "$breezing" ] || {
    log_err "missing breezing skill in cursor dist"
    exit 1
  }

  if grep -rEl '^user-invocable:[[:space:]]*true[[:space:]]*$' "${DIST_DIR}/skills" >/dev/null 2>&1; then
    log_err "cursor dist still contains user-invocable: true skills"
    exit 1
  fi

  if ! grep -Eq '^user-invocable:[[:space:]]*false[[:space:]]*$' "$breezing"; then
    log_err "breezing skill must be normalized to user-invocable: false"
    exit 1
  fi

  log_ok "Cursor package validation passed"
}

backup_existing_install() {
  local target="$1"
  if [ -L "$target" ]; then
    log_warn "Removing symlink install (Cursor rejects external symlink targets): $target"
    rm -f "$target"
    return 0
  fi
  if [ -e "$target" ]; then
    local archive_root="${HOME}/.harness-skill-cleanup-archive/cursor-plugin-local-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$archive_root"
    mv "$target" "${archive_root}/$(basename "$target")"
    log_warn "Backed up existing install to $archive_root"
  fi
}

install_plugin() {
  mkdir -p "$CURSOR_PLUGINS_LOCAL"
  backup_existing_install "$INSTALL_DIR"
  cp -R "$DIST_DIR" "$INSTALL_DIR"

  if [ -L "$INSTALL_DIR" ]; then
    log_err "install must be a real directory, not a symlink"
    exit 1
  fi

  if [ ! -f "${INSTALL_DIR}/.cursor-plugin/plugin.json" ]; then
    log_err "installed plugin missing manifest"
    exit 1
  fi

  log_ok "Installed Cursor plugin at $INSTALL_DIR"
  log_info "Reload Cursor (Developer: Reload Window) to load skills/agents"
}

main() {
  parse_args "$@"
  require_build_script
  build_dist
  validate_dist

  if [ "$CHECK_ONLY" -eq 1 ]; then
    log_ok "setup-cursor --check passed"
    exit 0
  fi

  install_plugin
}

main "$@"
