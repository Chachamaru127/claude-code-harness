#!/usr/bin/env bash
# Print ONLY the paste-ready prompt for a host (operator opens CLI and pastes).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="${ROOT_DIR}/docs/onboarding/host-live-cli-smoke.md"
HOST="${1:-}"

usage() {
  cat <<'EOF'
Usage: bash scripts/print-live-cli-smoke.sh <claude|codex|cursor|grok|keywords|all>

You open the CLI; this prints the prompt to paste. Nothing else.
EOF
}

extract_fence_after() {
  local heading="$1"
  # Print the first fenced code block after the given heading line.
  awk -v h="$heading" '
    $0 ~ h { found=1; next }
    found && /^```/ {
      if (!inblock) { inblock=1; next }
      else { exit }
    }
    found && inblock { print }
  ' "$DOC"
}

case "$HOST" in
  -h|--help|help|"")
    usage
    exit 0
    ;;
  keywords)
    cat <<'EOF'
LIVE: claude PASS
LIVE: codex PASS
LIVE: cursor PASS
LIVE: grok PASS
LIVE: all PASS
LIVE: claude FAIL: <reason>
LIVE: codex FAIL: <reason>
LIVE: cursor FAIL: <reason>
LIVE: grok FAIL: <reason>
EOF
    ;;
  claude)
    extract_fence_after "## Claude Code に貼る"
    ;;
  codex)
    extract_fence_after "## Codex に貼る"
    ;;
  cursor)
    extract_fence_after "## Cursor に貼る"
    ;;
  grok)
    extract_fence_after "## Grok に貼る"
    ;;
  all)
    for h in claude codex cursor grok; do
      echo "########## $h ##########"
      bash "$0" "$h"
      echo
    done
    ;;
  *)
    usage
    exit 2
    ;;
esac
