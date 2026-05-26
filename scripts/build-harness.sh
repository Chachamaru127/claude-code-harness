#!/usr/bin/env bash
# Build the harness binary for the current platform.
# Output: bin/harness (relative to repo root)
#
# Usage:
#   bash scripts/build-harness.sh          # build with version from VERSION file
#   bash scripts/build-harness.sh --dev    # build with version="dev"
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GO_DIR="${REPO_ROOT}/go"
OUT="${REPO_ROOT}/bin/harness"
mkdir -p "${REPO_ROOT}/bin"

VERSION="dev"
if [[ "${1:-}" != "--dev" ]]; then
  VERSION="$(cat "${REPO_ROOT}/VERSION" 2>/dev/null || echo "dev")"
fi

LDFLAGS="-s -w -X main.version=${VERSION}"

echo "Building harness v${VERSION} for $(go env GOOS)/$(go env GOARCH)..."
(cd "${GO_DIR}" && go build -ldflags="${LDFLAGS}" -o "${OUT}" ./cmd/harness/)
echo "Built: ${OUT}"
