#!/usr/bin/env bash
#
# install-git-hooks.sh
# Repo-managed git hooks installer (uses core.hooksPath).
#
# Usage:
#   ./scripts/install-git-hooks.sh
#
# Windows:
#   Requires Git for Windows (includes Git Bash).
#   Run from Git Bash, WSL, or PowerShell.
#

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$ROOT" ]; then
  echo "Error: not a Git repository"
  exit 1
fi

cd "$ROOT"

if [ ! -d ".githooks" ]; then
  echo "Error: .githooks/ directory not found"
  exit 1
fi

chmod +x .githooks/pre-commit 2>/dev/null || true

git config core.hooksPath .githooks

echo ""
echo "=== Git Hooks enabled ==="
echo ""
echo "  core.hooksPath = .githooks"
echo ""
echo "  pre-commit:"
echo "    - Syncs VERSION and plugin.json when release metadata is edited"
echo "    - Does not auto-bump version on normal code changes"
echo ""

# Windows note
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ -n "${WINDIR:-}" ]]; then
  echo "  [Windows note]"
  echo "    Git hooks run in Git Bash (bundled with Git for Windows)."
  echo "    If hooks do not work, please install Git for Windows:"
  echo "    https://gitforwindows.org/"
  echo ""
fi

echo "Done!"
