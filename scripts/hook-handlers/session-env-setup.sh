#!/bin/bash
# session-env-setup.sh
# SessionStart hook handler: sets harness environment variables using CLAUDE_ENV_FILE
#
# Writes the following environment variables to CLAUDE_ENV_FILE at session start:
#   HARNESS_VERSION          - Harness version (read from VERSION file)
#   HARNESS_EFFORT_DEFAULT   - Default effort level (medium)
#   HARNESS_AGENT_TYPE       - Agent type (BREEZING_ROLE or "solo")
#   HARNESS_BREEZING_SESSION_ID - Breezing session ID (if present)
#   HARNESS_IS_REMOTE           - Cloud session detection (read from CLAUDE_CODE_REMOTE)
#
# Usage: bash session-env-setup.sh
# Hook event: SessionStart

set -euo pipefail

# === Configuration ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Do nothing if CLAUDE_ENV_FILE is not set
if [ -z "${CLAUDE_ENV_FILE:-}" ]; then
  exit 0
fi

# Get version from VERSION file
HARNESS_VERSION="unknown"
if [ -f "${PLUGIN_ROOT}/VERSION" ]; then
  HARNESS_VERSION="$(cat "${PLUGIN_ROOT}/VERSION" | tr -d '[:space:]')"
fi

# Determine agent type
HARNESS_AGENT_TYPE="${BREEZING_ROLE:-solo}"

# Breezing session ID (if present)
HARNESS_BREEZING_SESSION_ID="${BREEZING_SESSION_ID:-}"

# Cloud session detection
HARNESS_IS_REMOTE="${CLAUDE_CODE_REMOTE:-false}"

# Write to CLAUDE_ENV_FILE (overwriting existing harness variables)
{
  echo "HARNESS_VERSION=${HARNESS_VERSION}"
  echo "HARNESS_EFFORT_DEFAULT=medium"
  echo "HARNESS_AGENT_TYPE=${HARNESS_AGENT_TYPE}"
  echo "HARNESS_IS_REMOTE=${HARNESS_IS_REMOTE}"
  if [ -n "${HARNESS_BREEZING_SESSION_ID}" ]; then
    echo "HARNESS_BREEZING_SESSION_ID=${HARNESS_BREEZING_SESSION_ID}"
  fi
} >> "${CLAUDE_ENV_FILE}"

exit 0
