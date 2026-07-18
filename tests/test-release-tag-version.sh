#!/bin/bash
# Fail closed when a release tag does not match the repository VERSION.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERIFY_SCRIPT="$ROOT_DIR/scripts/verify-release-tag.sh"
WORKFLOW="$ROOT_DIR/.github/workflows/release.yml"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"

if [ ! -x "$VERIFY_SCRIPT" ]; then
  echo "missing executable release tag verifier: scripts/verify-release-tag.sh" >&2
  exit 1
fi

if ! GITHUB_REF_NAME="v$VERSION" bash "$VERIFY_SCRIPT" >/dev/null; then
  echo "matching release tag was rejected: v$VERSION" >&2
  exit 1
fi

if GITHUB_REF_NAME="v$VERSION-mismatch" bash "$VERIFY_SCRIPT" >/dev/null 2>&1; then
  echo "mismatched release tag was accepted" >&2
  exit 1
fi

if ! grep -Fq 'bash ./scripts/verify-release-tag.sh' "$WORKFLOW"; then
  echo "release workflow does not run the tag/version verifier" >&2
  exit 1
fi

echo "test-release-tag-version: ok"
