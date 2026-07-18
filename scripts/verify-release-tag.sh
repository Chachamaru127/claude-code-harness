#!/bin/bash
# Ensure a tag-triggered release can only publish the version declared by source.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
TAG="${GITHUB_REF_NAME:-}"

if [ -z "$TAG" ]; then
  echo "release tag verification failed: GITHUB_REF_NAME is empty" >&2
  exit 1
fi

EXPECTED_TAG="v$VERSION"
if [ "$TAG" != "$EXPECTED_TAG" ]; then
  echo "release tag verification failed: tag $TAG does not match VERSION $VERSION (expected $EXPECTED_TAG)" >&2
  exit 1
fi

echo "release tag verified: $TAG matches VERSION $VERSION"
