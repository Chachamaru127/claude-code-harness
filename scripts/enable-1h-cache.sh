#!/usr/bin/env bash
# enable-1h-cache.sh
# Appends ENABLE_PROMPT_CACHING_1H=1 to env.local (idempotent).
# Script to opt in to CC v2.1.108+ 1-hour prompt cache for long Harness sessions.
#
# Usage:
#   bash scripts/enable-1h-cache.sh
#
# Effect:
#   - Appends ENABLE_PROMPT_CACHING_1H=1 to env.local in the project root
#   - Does nothing if already set (idempotent)
#   - Creates env.local if it does not exist
#
# Selection criteria:
#   - Choose 1h cache when sessions are expected to exceed 30 minutes
#   - The default 5-minute cache is sufficient for short interactions under 30 minutes
#
# Notes:
#   - Do not commit env.local to the repository (recommended to add to .gitignore)
#   - Does not modify global settings; applies only to sessions in this project

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$(cd "$(dirname "$0")/.." && pwd)")"
ENV_LOCAL="${REPO_ROOT}/env.local"
KEY="ENABLE_PROMPT_CACHING_1H"
VALUE="1"
# Use `export KEY=VALUE` so that `source env.local` propagates the variable
# to subprocesses (claude). Without `export`, `source env.local` only sets a
# shell-local variable and the spawned `claude` process never sees it.
ENTRY="export ${KEY}=${VALUE}"

# Check whether a valid entry already exists (comment lines are ignored)
if grep -qE "^export ${KEY}=${VALUE}$" "${ENV_LOCAL}" 2>/dev/null; then
  echo "[enable-1h-cache] ${ENTRY} is already set in ${ENV_LOCAL} (no change)."
  exit 0
fi

# If the same key with a different value exists, warn and exit without overwriting
if grep -qE "^(export )?${KEY}=" "${ENV_LOCAL}" 2>/dev/null; then
  existing_val=$(grep -E "^(export )?${KEY}=" "${ENV_LOCAL}" | tail -1)
  echo "[enable-1h-cache] WARNING: existing setting '${existing_val}' found in ${ENV_LOCAL}." >&2
  echo "[enable-1h-cache] Please review manually and re-run." >&2
  exit 1
fi

# Append to env.local (create the file if it does not exist)
{
  echo ""
  echo "# CC v2.1.108+ 1-hour prompt cache (recommended for sessions longer than 30 minutes)"
  echo "${ENTRY}"
} >> "${ENV_LOCAL}"

echo "[enable-1h-cache] Appended ${ENTRY} to ${ENV_LOCAL}."
echo "[enable-1h-cache] Will take effect from the next long session (over 30 minutes)."
