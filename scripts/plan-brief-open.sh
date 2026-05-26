#!/bin/bash
# scripts/plan-brief-open.sh
# Phase 65.1.2 - OS-specific browser auto-open dispatch for Plan Brief HTML
#
# Usage: ./scripts/plan-brief-open.sh <html_path>
#
# Behavior:
#   - macOS: dispatch to default browser via `open <path>`
#   - Linux: `xdg-open <path>` (requires xdg-utils)
#   - Windows (Git Bash / MSYS): `start "" <path>`
#   - Unknown OS: print warning to stderr and output path to stdout (best-effort)
#
# Skip conditions:
#   - Env var BROWSER=true … assumed CI environment; skip open, only output path to stdout
#   - Env var PLAN_BRIEF_NO_OPEN=1 … explicit opt-out
#
# Exit code:
#   - 0: open succeeded (or skip succeeded)
#   - 2: invalid arguments
#   - other: exit code from the open command (fail-soft since best-effort)

set -euo pipefail

usage() {
  cat <<USAGE >&2
Usage: $0 <html_path>

Arguments:
  <html_path>            Absolute or relative path to the HTML file to open

Environment variables:
  BROWSER=true           Skip open and only output path to stdout
  PLAN_BRIEF_NO_OPEN=1   Skip open and only output path to stdout (explicit opt-out)
USAGE
  exit 2
}

if [[ $# -lt 1 ]]; then
  echo "ERROR: html_path is required" >&2
  usage
fi

HTML_PATH="$1"

if [[ ! -f "$HTML_PATH" ]]; then
  echo "ERROR: html_path does not exist: $HTML_PATH" >&2
  exit 2
fi

# normalize to absolute path (some OS open commands misbehave with relative paths)
case "$HTML_PATH" in
  /*) ABS_PATH="$HTML_PATH" ;;
  *)  ABS_PATH="$(pwd)/$HTML_PATH" ;;
esac

# skip if CI environment or explicit opt-out
if [[ "${BROWSER:-}" == "true" || "${PLAN_BRIEF_NO_OPEN:-}" == "1" ]]; then
  printf '%s\n' "$ABS_PATH"
  echo "INFO: skipped browser open (BROWSER=true or PLAN_BRIEF_NO_OPEN=1)" >&2
  exit 0
fi

UNAME_S="$(uname -s 2>/dev/null || echo unknown)"

case "$UNAME_S" in
  Darwin)
    if command -v open >/dev/null 2>&1; then
      open "$ABS_PATH"
      printf '%s\n' "$ABS_PATH"
    else
      echo "WARN: 'open' not found on Darwin (unexpected). Falling back to stdout." >&2
      printf '%s\n' "$ABS_PATH"
    fi
    ;;
  Linux)
    if command -v xdg-open >/dev/null 2>&1; then
      xdg-open "$ABS_PATH" >/dev/null 2>&1 &
      printf '%s\n' "$ABS_PATH"
    else
      echo "WARN: 'xdg-open' not found on Linux. Install xdg-utils to enable auto-open." >&2
      printf '%s\n' "$ABS_PATH"
    fi
    ;;
  MINGW*|MSYS*|CYGWIN*)
    if command -v start >/dev/null 2>&1; then
      start "" "$ABS_PATH"
      printf '%s\n' "$ABS_PATH"
    elif command -v cmd.exe >/dev/null 2>&1; then
      cmd.exe /c start "" "$ABS_PATH"
      printf '%s\n' "$ABS_PATH"
    else
      echo "WARN: 'start' / 'cmd.exe' not found on Windows-like shell. Falling back to stdout." >&2
      printf '%s\n' "$ABS_PATH"
    fi
    ;;
  *)
    echo "WARN: unknown OS ($UNAME_S). Skipping auto-open." >&2
    printf '%s\n' "$ABS_PATH"
    ;;
esac
