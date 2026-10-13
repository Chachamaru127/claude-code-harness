#!/usr/bin/env bash
# setup-grok.sh
# Install Claude Code Harness as a Grok user plugin (isolated HOME-friendly).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${HARNESS_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
BUILD_SCRIPT="${ROOT_DIR}/scripts/build-host-plugin-dist.sh"
PLUGIN_NAME="harness"
DIST_DIR="${HARNESS_GROK_DIST:-${HOME}/.local/share/claude-code-harness/grok}"
CHECK_ONLY=0
SKIP_CLI_INSTALL=0

usage() {
  cat <<'EOF'
Usage: setup-grok.sh [--check] [--no-cli-install]

Install Claude Code Harness for Grok via package build + optional
`grok plugin install` into the current HOME's ~/.grok tree.

Environment:
  HARNESS_PROJECT_ROOT  Repo root (default: parent of scripts/)
  HARNESS_GROK_DIST     Output directory for generated grok package
  HOME                  Used for ~/.grok install target (inject for tests)

Options:
  --check            Build and validate the grok package only; do not install.
  --no-cli-install   After build, copy the package into
                     $HOME/.grok/plugins/harness instead of
                     calling `grok plugin install` (fallback for tests/CI).
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
      --no-cli-install)
        SKIP_CLI_INSTALL=1
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
  log_info "Building Grok package at $DIST_DIR"
  bash "$BUILD_SCRIPT" --host grok --out "$DIST_DIR"
  log_ok "Grok package built"
}

require_core_skill() {
  local skill="$1"
  local path="${DIST_DIR}/skills/${skill}/SKILL.md"
  [ -f "$path" ] || {
    log_err "missing core skill in grok dist: skills/${skill}/SKILL.md"
    exit 1
  }
}

validate_dist() {
  local manifest="${DIST_DIR}/.grok-plugin/plugin.json"

  [ -f "$manifest" ] || {
    log_err "missing manifest: $manifest"
    exit 1
  }

  if grep -Fq '../' "$manifest"; then
    log_err "grok manifest must not contain .. paths"
    exit 1
  fi

  require_core_skill "harness-plan"
  require_core_skill "harness-work"
  require_core_skill "harness-review"
  require_core_skill "breezing"

  for script in \
    build-host-plugin-dist.sh \
    model-routing.sh \
    setup-grok.sh; do
    if [ ! -f "${DIST_DIR}/scripts/${script}" ]; then
      log_err "grok dist missing runtime helper: scripts/${script}"
      exit 1
    fi
  done

  if command -v grok >/dev/null 2>&1; then
    if grok plugin validate "$DIST_DIR" >/dev/null 2>&1; then
      log_ok "grok plugin validate passed"
    else
      log_warn "grok plugin validate failed or unavailable; static package checks still passed"
    fi
  else
    log_warn "grok CLI unavailable; skipped plugin validate"
  fi

  log_ok "Grok package validation passed"
}

install_via_cli() {
  if ! command -v grok >/dev/null 2>&1; then
    return 1
  fi
  log_info "Installing via grok plugin install (HOME=$HOME)"
  # --trust is required so install completes non-interactively.
  if grok plugin install "$DIST_DIR" --trust; then
    log_ok "Installed Grok plugin via CLI (name: ${PLUGIN_NAME})"
    return 0
  fi
  return 1
}

install_via_copy() {
  local target="${HOME}/.grok/plugins/${PLUGIN_NAME}"
  mkdir -p "$(dirname "$target")"
  if [ -e "$target" ] || [ -L "$target" ]; then
    local archive_root="${HOME}/.harness-skill-cleanup-archive/grok-plugin-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$archive_root"
    mv "$target" "${archive_root}/$(basename "$target")"
    log_warn "Backed up existing install to $archive_root"
  fi
  cp -R "$DIST_DIR" "$target"
  if [ -L "$target" ]; then
    log_err "install must be a real directory, not a symlink"
    exit 1
  fi
  if [ ! -f "${target}/.grok-plugin/plugin.json" ]; then
    log_err "installed plugin missing manifest"
    exit 1
  fi
  # Grok may require [plugins].enabled for path-based plugins.
  local config="${HOME}/.grok/config.toml"
  mkdir -p "${HOME}/.grok"
  if [ ! -f "$config" ]; then
    cat >"$config" <<EOF
[plugins]
enabled = ["${PLUGIN_NAME}"]
paths = ["${HOME}/.grok/plugins"]
EOF
  elif ! grep -Fq "$PLUGIN_NAME" "$config" 2>/dev/null; then
    log_info "Ensure ${PLUGIN_NAME} is enabled under [plugins] in $config"
  fi
  log_ok "Installed Grok plugin copy at $target"
  log_info "Restart Grok or open a new session to load skills"
}

install_plugin() {
  if [ "$SKIP_CLI_INSTALL" -eq 0 ] && install_via_cli; then
    return 0
  fi
  if [ "$SKIP_CLI_INSTALL" -eq 0 ]; then
    log_warn "grok plugin install unavailable or failed; falling back to directory copy"
  fi
  install_via_copy
}

main() {
  parse_args "$@"
  require_build_script
  build_dist
  validate_dist

  if [ "$CHECK_ONLY" -eq 1 ]; then
    log_ok "setup-grok --check passed"
    exit 0
  fi

  install_plugin
}

main "$@"
