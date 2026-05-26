#!/bin/bash
# check-version-bump.sh
# release metadata policy check
#
# Purpose:
# - Do not require a VERSION bump on normal PRs
# - When VERSION is updated, verify that plugin.json / CHANGELOG release entry are in sync
#
# Usage:
# - For PRs: set the GITHUB_BASE_REF environment variable
# - For pushes: compare against the previous commit

set -euo pipefail

echo "🏷️ Release metadata check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -n "${GITHUB_BASE_REF:-}" ]; then
  BASE="origin/$GITHUB_BASE_REF"
  DIFF_TARGET="HEAD"
  echo "📌 PR mode: comparing against $BASE"
elif [ -n "${GITHUB_EVENT_NAME:-}" ] && [ "$GITHUB_EVENT_NAME" = "push" ]; then
  BASE="HEAD~1"
  DIFF_TARGET="HEAD"
  echo "📌 Push mode: comparing against previous commit"
else
  BASE="origin/main"
  DIFF_TARGET=""
  echo "📌 Local mode: comparing against $BASE"
fi

if ! git rev-parse "$BASE" >/dev/null 2>&1; then
  echo "⚠️ Comparison target ($BASE) not found. Skipping."
  exit 0
fi

semver_gt() {
  local left="$1"
  local right="$2"
  local l_major=0 l_minor=0 l_patch=0
  local r_major=0 r_minor=0 r_patch=0

  IFS='.' read -r l_major l_minor l_patch <<< "$left"
  IFS='.' read -r r_major r_minor r_patch <<< "$right"

  for value in "$l_major" "$l_minor" "$l_patch" "$r_major" "$r_minor" "$r_patch"; do
    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
      return 1
    fi
  done

  if ((10#$l_major > 10#$r_major)); then
    return 0
  fi
  if ((10#$l_major < 10#$r_major)); then
    return 1
  fi
  if ((10#$l_minor > 10#$r_minor)); then
    return 0
  fi
  if ((10#$l_minor < 10#$r_minor)); then
    return 1
  fi
  if ((10#$l_patch > 10#$r_patch)); then
    return 0
  fi

  return 1
}

echo ""
echo "🔍 Checking changed files..."

RELEASE_METADATA_FILES="VERSION .claude-plugin/plugin.json CHANGELOG.md"
if [ -n "$DIFF_TARGET" ]; then
  CHANGED_RELEASE_METADATA=$(git diff --name-only "$BASE" "$DIFF_TARGET" -- $RELEASE_METADATA_FILES 2>/dev/null | grep -v "^$" || true)
else
  CHANGED_RELEASE_METADATA=$(git diff --name-only "$BASE" -- $RELEASE_METADATA_FILES 2>/dev/null | grep -v "^$" || true)
fi

if [ -z "$CHANGED_RELEASE_METADATA" ]; then
  echo "  ✅ No release metadata changes (accepted as normal PR / normal push)"
  exit 0
fi

echo "  📝 Changed release metadata:"
echo "$CHANGED_RELEASE_METADATA" | head -10 | while read -r file; do
  echo "     - $file"
done
CHANGED_COUNT=$(echo "$CHANGED_RELEASE_METADATA" | wc -l | tr -d ' ')
if [ "$CHANGED_COUNT" -gt 10 ]; then
  echo "     ... and $((CHANGED_COUNT - 10)) more file(s)"
fi

echo ""
echo "🔍 Checking version change..."

CURRENT_VERSION=$(cat VERSION 2>/dev/null | tr -d '[:space:]')
BASE_VERSION=$(git show "$BASE:VERSION" 2>/dev/null | tr -d '[:space:]' || echo "")

echo "  Base:    v${BASE_VERSION:-none}"
echo "  Current: v${CURRENT_VERSION}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -z "$BASE_VERSION" ]; then
  echo "✅ New project (skipping release metadata check)"
  exit 0
fi

if [ "$CURRENT_VERSION" = "$BASE_VERSION" ]; then
  echo "✅ VERSION is unchanged. A version bump is not required for normal PRs / pushes."

  if bash ./scripts/sync-version.sh check >/dev/null 2>&1; then
    echo "✅ plugin.json also matches VERSION."
    exit 0
  fi

  echo "❌ VERSION is unchanged but plugin.json does not match."
  bash ./scripts/sync-version.sh check
  exit 1
fi

if ! semver_gt "$CURRENT_VERSION" "$BASE_VERSION"; then
  echo "❌ VERSION has been updated but is not a SemVer increment."
  echo "   Base:    $BASE_VERSION"
  echo "   Current: $CURRENT_VERSION"
  exit 1
fi

echo "✅ Detected VERSION update for release: $BASE_VERSION → $CURRENT_VERSION"

ERRORS=0

if bash ./scripts/sync-version.sh check >/dev/null 2>&1; then
  echo "✅ plugin.json version also matches."
else
  echo "❌ plugin.json version does not match VERSION."
  bash ./scripts/sync-version.sh check || true
  ERRORS=$((ERRORS + 1))
fi

if grep -Eq "^## \[$CURRENT_VERSION\] - [0-9]{4}-[0-9]{2}-[0-9]{2}$" CHANGELOG.md; then
  echo "✅ CHANGELOG.md has a release entry for v$CURRENT_VERSION."
else
  echo "❌ CHANGELOG.md is missing a release entry for v$CURRENT_VERSION."
  ERRORS=$((ERRORS + 1))
fi

if grep -Eq "^\[$CURRENT_VERSION\]: https://github.com/Chachamaru127/claude-code-harness/compare/v" CHANGELOG.md; then
  echo "✅ CHANGELOG compare link exists."
else
  echo "❌ CHANGELOG compare link is missing."
  ERRORS=$((ERRORS + 1))
fi

if [ "$ERRORS" -gt 0 ]; then
  echo ""
  echo "💡 How to fix:"
  echo "  - Do not change VERSION in normal PRs"
  echo "  - Only update VERSION / plugin.json / CHANGELOG release entry together when cutting a release"
  exit 1
fi

echo "✅ Release metadata check OK"
exit 0
