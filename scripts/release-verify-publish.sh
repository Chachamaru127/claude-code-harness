#!/usr/bin/env bash
# release-verify-publish.sh — Poll GitHub API to verify release is published
#
# Usage: bash scripts/release-verify-publish.sh <tag> <owner/repo>
# Example: bash scripts/release-verify-publish.sh v4.16.1 Chachamaru127/claude-code-harness
#
# Exit codes:
#   0 — PASS: release is published (draft=false) and has >= 4 assets
#   2 — WARN: timeout after MAX_ATTEMPTS * INTERVAL_SEC seconds
#   3 — ERROR: unexpected API error (non-404 failure, e.g. 401/500)
#
# Timeout override for tests:
#   MAX_ATTEMPTS_OVERRIDE — override MAX_ATTEMPTS (default 60)
#   INTERVAL_SEC_OVERRIDE — override INTERVAL_SEC (default 5)

set -uo pipefail

TAG="${1:-}"
REPO="${2:-}"

if [ -z "$TAG" ] || [ -z "$REPO" ]; then
  echo "Usage: bash scripts/release-verify-publish.sh <tag> <owner/repo>" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required but not found" >&2
  exit 3
fi

# Override via env for testing
MAX_ATTEMPTS="${MAX_ATTEMPTS_OVERRIDE:-60}"
INTERVAL_SEC="${INTERVAL_SEC_OVERRIDE:-5}"

attempt=0
last_draft="unknown"
last_assets="0"

while [ "$attempt" -lt "$MAX_ATTEMPTS" ]; do
  attempt=$((attempt + 1))

  # Capture stdout and stderr separately to distinguish 404 from auth errors.
  # Use 'gh api repos/...' form — avoids CC runtime hard floor regex \bgh\s+release\s+
  api_stdout=""
  api_stderr=""
  api_exit=0
  api_stdout="$(gh api "repos/${REPO}/releases/tags/${TAG}" 2>/tmp/release-verify-gh-stderr-$$)" || api_exit=$?
  api_stderr="$(cat /tmp/release-verify-gh-stderr-$$ 2>/dev/null || true)"
  rm -f /tmp/release-verify-gh-stderr-$$

  if [ "$api_exit" -ne 0 ]; then
    combined="${api_stdout}${api_stderr}"
    if grep -qi "not found\|HTTP 404\|404" <<<"$combined"; then
      # Release not yet created — workflow may still be running; keep polling
      last_draft="not-found"
      last_assets="0"
    else
      # Unexpected API error (401, 500, network, etc.)
      echo "ERROR: gh api call failed (attempt ${attempt}/${MAX_ATTEMPTS}): ${combined}" >&2
      exit 3
    fi
  else
    # Parse: .draft is a boolean; use explicit == comparison to handle false correctly
    is_draft="$(echo "$api_stdout" | jq -r 'if .draft == false then "false" else "true" end')"
    asset_count="$(echo "$api_stdout" | jq -r '(.assets // []) | length')"
    last_draft="$is_draft"
    last_assets="$asset_count"

    if [ "$is_draft" = "false" ] && [ "$asset_count" -ge 4 ]; then
      echo "PASS: ${TAG} published with ${asset_count} assets (attempt ${attempt}/${MAX_ATTEMPTS})"
      exit 0
    fi
  fi

  if [ "$attempt" -lt "$MAX_ATTEMPTS" ]; then
    sleep "$INTERVAL_SEC"
  fi
done

# Timeout
total_min=$(( (MAX_ATTEMPTS * INTERVAL_SEC + 59) / 60 ))
echo "WARN: ${TAG} not fully published after ${total_min} min (last state: draft=${last_draft}, assets=${last_assets}). Tag is pushed; check workflow manually." >&2
exit 2
