#!/usr/bin/env bash
set -euo pipefail

# Launch Claude Code with 1-hour prompt cache for long-running tasks.
# A thin wrapper to opt-in only the sessions that need it, without changing defaults.

if ! command -v claude >/dev/null 2>&1; then
  echo "ERROR: 'claude' command not found." >&2
  echo "Please install Claude Code CLI and then re-run." >&2
  exit 1
fi

export ENABLE_PROMPT_CACHING_1H=1

exec claude "$@"
