#!/bin/bash
# Verify this repository keeps branch settings aligned with CCH's review gate policy.

set -euo pipefail

JSON_FILE=""
REPO_SLUG="${HARNESS_BRANCH_PROTECTION_REPO:-}"
BRANCH="${HARNESS_BRANCH_PROTECTION_BRANCH:-main}"
REQUIRED_CONTEXTS=(actionlint validate test-go)

usage() {
  cat <<'EOF'
Usage: scripts/check-cch-branch-protection-policy.sh [--json PATH] [--repo OWNER/REPO] [--branch NAME]

Checks:
  - required_pull_request_reviews matches the CCH review gate contract
  - required status checks are strict and include actionlint, validate, test-go
  - force pushes and branch deletion are disabled

Without --json, the script reads live GitHub branch protection via gh api.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --json)
      JSON_FILE="${2:-}"
      [ -n "$JSON_FILE" ] || { echo "error: --json requires a path" >&2; exit 2; }
      shift 2
      ;;
    --repo)
      REPO_SLUG="${2:-}"
      [ -n "$REPO_SLUG" ] || { echo "error: --repo requires OWNER/REPO" >&2; exit 2; }
      shift 2
      ;;
    --branch)
      BRANCH="${2:-}"
      [ -n "$BRANCH" ] || { echo "error: --branch requires a branch name" >&2; exit 2; }
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "FAIL: jq is required for branch protection policy validation" >&2
    exit 1
  fi
}

derive_repo_slug() {
  local remote
  remote="$(git config --get remote.origin.url 2>/dev/null || true)"
  case "$remote" in
    git@github.com:*.git)
      printf '%s\n' "${remote#git@github.com:}" | sed 's/\.git$//'
      ;;
    git@github.com:*)
      printf '%s\n' "${remote#git@github.com:}"
      ;;
    https://github.com/*.git)
      printf '%s\n' "${remote#https://github.com/}" | sed 's/\.git$//'
      ;;
    https://github.com/*)
      printf '%s\n' "${remote#https://github.com/}"
      ;;
    *)
      return 1
      ;;
  esac
}

load_json() {
  if [ -n "$JSON_FILE" ]; then
    cat "$JSON_FILE"
    return
  fi

  if [ -z "$REPO_SLUG" ]; then
    REPO_SLUG="$(derive_repo_slug || true)"
  fi
  if [ -z "$REPO_SLUG" ]; then
    echo "FAIL: could not derive GitHub owner/repo from origin remote" >&2
    exit 1
  fi
  if ! command -v gh >/dev/null 2>&1; then
    echo "FAIL: gh CLI is required for live branch protection validation" >&2
    exit 1
  fi

  gh api "repos/${REPO_SLUG}/branches/${BRANCH}/protection"
}

json="$(load_json)"
require_jq

failures=0

fail_check() {
  echo "FAIL: $1" >&2
  failures=$((failures + 1))
}

pass_check() {
  echo "PASS: $1"
}

if jq -e '.required_pull_request_reviews == null' >/dev/null <<<"$json"; then
  pass_check "required_pull_request_reviews is null"
else
  fail_check "required_pull_request_reviews must match the CCH review gate contract"
fi

if jq -e '.required_status_checks.strict == true' >/dev/null <<<"$json"; then
  pass_check "required status checks are strict"
else
  fail_check "required_status_checks.strict must be true"
fi

for context in "${REQUIRED_CONTEXTS[@]}"; do
  if jq -e --arg context "$context" '
    [
      (.required_status_checks.contexts // [])[],
      (.required_status_checks.checks // [])[].context
    ] | index($context) != null
  ' >/dev/null <<<"$json"; then
    pass_check "required status check includes ${context}"
  else
    fail_check "required status checks must include ${context}"
  fi
done

if jq -e 'def enabled: if type == "object" then (.enabled // false) else (. // false) end; (.allow_force_pushes | enabled) == false' >/dev/null <<<"$json"; then
  pass_check "force pushes are disabled"
else
  fail_check "allow_force_pushes must be disabled"
fi

if jq -e 'def enabled: if type == "object" then (.enabled // false) else (. // false) end; (.allow_deletions | enabled) == false' >/dev/null <<<"$json"; then
  pass_check "branch deletion is disabled"
else
  fail_check "allow_deletions must be disabled"
fi

if [ "$failures" -gt 0 ]; then
  exit 1
fi

echo "CCH branch protection policy: ok"
