#!/bin/bash
# Regression tests for broadcast inbox stale-read and stale-cwd guards.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP: jq is required for session-auto-broadcast fallback parsing"
  exit 0
fi

tmp="$(mktemp -d)"
cleanup() {
  rm -rf "${tmp}" 2>/dev/null || true
}
trap cleanup EXIT

repo="${tmp}/repo"
mkdir -p "${repo}/.claude/sessions" "${repo}/.claude/state"

cat > "${repo}/.claude/state/session.json" <<'JSON'
{"session_id":"local-session-abcdef"}
JSON

cat > "${repo}/.claude/sessions/broadcast.md" <<'EOF'
## 2026-03-03T09:12:38Z [remote-sessio]
[AUTO] stale api change
EOF

output="$(
  cd "${repo}"
  printf '{"session_id":"local-session-abcdef","cwd":"%s"}' "${repo}" \
    | bash "${REPO_ROOT}/scripts/pretooluse-inbox-check.sh"
)"

if ! grep -q '2026-03-03 09:12' <<<"${output}"; then
  echo "expected inbox notification to include date-bearing timestamp" >&2
  echo "${output}" >&2
  exit 1
fi

if grep -q '\[09:12\]' <<<"${output}"; then
  echo "inbox notification must not use ambiguous HH:MM-only timestamp" >&2
  echo "${output}" >&2
  exit 1
fi

if [ ! -f "${repo}/.claude/sessions/.last_inbox_read_local-session-abcdef" ]; then
  echo "expected pretooluse inbox check to mark displayed broadcast as read" >&2
  exit 1
fi

printf '0\n' > "${repo}/.claude/sessions/.last_inbox_check"
second="$(
  cd "${repo}"
  printf '{"session_id":"local-session-abcdef","cwd":"%s"}' "${repo}" \
    | bash "${REPO_ROOT}/scripts/pretooluse-inbox-check.sh"
)"

if [ -n "${second}" ]; then
  echo "displayed stale broadcast should not repeat after auto mark" >&2
  echo "${second}" >&2
  exit 1
fi

stale_repo="${tmp}/stale-repo"
mkdir -p "${stale_repo}"
stale_cwd="${tmp}/deleted-cwd"

auto_output="$(
  cd "${stale_repo}"
  printf '{"cwd":"%s","tool_input":{"file_path":"src/api/users.ts"}}' "${stale_cwd}" \
    | bash "${REPO_ROOT}/scripts/session-auto-broadcast.sh"
)"

if ! printf '%s' "${auto_output}" | jq -e '.hookSpecificOutput.additionalContext == ""' >/dev/null; then
  echo "stale cwd auto broadcast should return empty additionalContext" >&2
  echo "${auto_output}" >&2
  exit 1
fi

if [ -f "${stale_repo}/.claude/sessions/broadcast.md" ]; then
  echo "stale cwd auto broadcast must not write broadcast.md" >&2
  exit 1
fi

echo "PASS session inbox/broadcast regression"
