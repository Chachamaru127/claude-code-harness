#!/usr/bin/env bash
# test-pr-closeout.sh
# Evidence-pack-driven PR closeout helper contract tests (Phase 72.1.5).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLOSEOUT="${PROJECT_ROOT}/scripts/harness-pr-closeout.sh"
EVIDENCE="${SCRIPT_DIR}/fixtures/pr-closeout-evidence.json"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

command -v jq >/dev/null 2>&1 || fail "jq is required"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pr-closeout-test.XXXXXX")"
MOCK_BIN_DIR="${TMP_DIR}/bin"
MOCK_GH="${MOCK_BIN_DIR}/gh"
MOCK_GIT="${MOCK_BIN_DIR}/git"
GH_CALLS="${TMP_DIR}/gh-calls.log"
GIT_CALLS="${TMP_DIR}/git-calls.log"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

mkdir -p "${MOCK_BIN_DIR}"

make_blocking_mock() {
  local target="$1"
  local log_file="$2"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'echo "$0 $*" >> %s\n' "${log_file}"
    printf 'echo "mock blocked: $0" >&2\n'
    printf 'exit 99\n'
  } >"${target}"
  chmod +x "${target}"
}

make_recording_mock_gh() {
  {
    printf '#!/usr/bin/env bash\n'
    printf 'echo "$*" >> %s\n' "${GH_CALLS}"
    printf 'if [ "$1" = "pr" ] && [ "$2" = "create" ]; then\n'
    printf '  echo "https://github.com/example/repo/pull/1"\n'
    printf '  exit 0\n'
    printf 'fi\n'
    printf 'echo "unexpected gh invocation: $*" >&2\n'
    printf 'exit 1\n'
  } >"${MOCK_GH}"
  chmod +x "${MOCK_GH}"
}

run_closeout() {
  PATH="${MOCK_BIN_DIR}:${PATH}" bash "${CLOSEOUT}" "$@"
}

required_payload_fields=(
  base_ref
  head_ref
  spec_path
  lane
  stage
  review_command
  focused_tests
  accepted_findings
  rejected_findings
  release_preflight_warnings
  residual_risk
  title
  body
)

[ -f "${CLOSEOUT}" ] || fail "missing script: ${CLOSEOUT}"
[ -f "${EVIDENCE}" ] || fail "missing evidence fixture: ${EVIDENCE}"

# (a) build writes pr-payload.json with required fields
PAYLOAD_A="${TMP_DIR}/payload-a.json"
run_closeout build \
  --base origin/main \
  --head task/72.1.5 \
  --evidence "${EVIDENCE}" \
  --out "${PAYLOAD_A}"

[ -f "${PAYLOAD_A}" ] || fail "(a) build must write --out payload"

for field in "${required_payload_fields[@]}"; do
  jq -e --arg f "${field}" 'has($f)' "${PAYLOAD_A}" >/dev/null \
    || fail "(a) missing required field in payload: ${field}"
done

[ "$(jq -r '.base_ref' "${PAYLOAD_A}")" = "origin/main" ] \
  || fail "(a) base_ref must come from --base"
[ "$(jq -r '.head_ref' "${PAYLOAD_A}")" = "task/72.1.5" ] \
  || fail "(a) head_ref must come from --head"

# (b) dry-run must not invoke gh or git
make_blocking_mock "${MOCK_GH}" "${GH_CALLS}"
make_blocking_mock "${MOCK_GIT}" "${GIT_CALLS}"
: >"${GH_CALLS}"
: >"${GIT_CALLS}"

set +e
dry_out="$(run_closeout dry-run --payload "${PAYLOAD_A}" 2>&1)"
dry_rc=$?
set -e

[ "${dry_rc}" -eq 0 ] || fail "(b) dry-run should exit 0, got ${dry_rc}"
[ "${#dry_out}" -gt 0 ] || fail "(b) dry-run should print preview output"
[ ! -s "${GH_CALLS}" ] || fail "(b) dry-run must not call gh (calls: $(cat "${GH_CALLS}"))"
[ ! -s "${GIT_CALLS}" ] || fail "(b) dry-run must not call git (calls: $(cat "${GIT_CALLS}"))"

# push tests need real git for attached-head detection; drop the blocking git mock.
rm -f "${MOCK_GIT}"

# (c) push --yes invokes gh pr create with expected argv
make_recording_mock_gh
: >"${GH_CALLS}"

DETACHED_REPO="${TMP_DIR}/detached-repo"
mkdir -p "${DETACHED_REPO}"
git -C "${DETACHED_REPO}" init -q
git -C "${DETACHED_REPO}" config user.email "test@example.com"
git -C "${DETACHED_REPO}" config user.name "Test User"
printf 'seed\n' >"${DETACHED_REPO}/README.md"
git -C "${DETACHED_REPO}" add README.md
git -C "${DETACHED_REPO}" commit -q -m "seed"
git -C "${DETACHED_REPO}" checkout -q -b task/72.1.5

PAYLOAD_C="${TMP_DIR}/payload-c.json"
(
  cd "${DETACHED_REPO}"
  PATH="${MOCK_BIN_DIR}:${PATH}" bash "${CLOSEOUT}" build \
    --base main \
    --head task/72.1.5 \
    --evidence "${EVIDENCE}" \
    --out "${PAYLOAD_C}"
)

set +e
(
  cd "${DETACHED_REPO}"
  PATH="${MOCK_BIN_DIR}:${PATH}" bash "${CLOSEOUT}" push --payload "${PAYLOAD_C}" --yes
) >/dev/null 2>&1
push_rc=$?
set -e

[ "${push_rc}" -eq 0 ] || fail "(c) push --yes should exit 0 on attached branch, got ${push_rc}"
grep -Fq 'pr create' "${GH_CALLS}" || fail "(c) push --yes must call gh pr create"
grep -Fq -- '--base main' "${GH_CALLS}" || fail "(c) gh pr create must pass --base"
grep -Fq -- '--head task/72.1.5' "${GH_CALLS}" || fail "(c) gh pr create must pass --head"
grep -Fq -- '--title' "${GH_CALLS}" || fail "(c) gh pr create must pass --title"
grep -Fq -- '--body' "${GH_CALLS}" || fail "(c) gh pr create must pass --body"

# (d) push without --yes and non-tty stdin must exit 1
make_recording_mock_gh
: >"${GH_CALLS}"

set +e
(
  cd "${DETACHED_REPO}"
  PATH="${MOCK_BIN_DIR}:${PATH}" bash "${CLOSEOUT}" push --payload "${PAYLOAD_C}" </dev/null
) >/dev/null 2>&1
no_confirm_rc=$?
set -e

[ "${no_confirm_rc}" -eq 1 ] || fail "(d) push without --yes on non-tty stdin must exit 1, got ${no_confirm_rc}"
[ ! -s "${GH_CALLS}" ] || fail "(d) push without confirmation must not call gh"

# (e) detached HEAD must fail fast
DETACHED_ONLY="${TMP_DIR}/detached-only"
mkdir -p "${DETACHED_ONLY}"
git -C "${DETACHED_ONLY}" init -q
git -C "${DETACHED_ONLY}" config user.email "test@example.com"
git -C "${DETACHED_ONLY}" config user.name "Test User"
printf 'solo\n' >"${DETACHED_ONLY}/README.md"
git -C "${DETACHED_ONLY}" add README.md
git -C "${DETACHED_ONLY}" commit -q -m "solo"
DETACHED_SHA="$(git -C "${DETACHED_ONLY}" rev-parse HEAD)"
git -C "${DETACHED_ONLY}" checkout -q "${DETACHED_SHA}"

PAYLOAD_E="${TMP_DIR}/payload-e.json"
(
  cd "${DETACHED_ONLY}"
  PATH="${MOCK_BIN_DIR}:${PATH}" bash "${CLOSEOUT}" build \
    --base main \
    --head "${DETACHED_SHA}" \
    --evidence "${EVIDENCE}" \
    --out "${PAYLOAD_E}"
)

set +e
(
  cd "${DETACHED_ONLY}"
  PATH="${MOCK_BIN_DIR}:${PATH}" bash "${CLOSEOUT}" push --payload "${PAYLOAD_E}" --yes
) >/dev/null 2>&1
detached_rc=$?
set -e

[ "${detached_rc}" -eq 1 ] || fail "(e) detached HEAD push must exit 1, got ${detached_rc}"

# (f) title <= 70 chars; body includes accepted and rejected findings
title_len="$(jq -r '.title' "${PAYLOAD_A}" | wc -m | tr -d ' ')"
[ "${title_len}" -le 70 ] || fail "(f) title must be <= 70 chars, got ${title_len}"

body_text="$(jq -r '.body' "${PAYLOAD_A}")"
grep -Fq 'acc-1' <<<"${body_text}" || fail "(f) body must include accepted finding id"
grep -Fq 'rej-1' <<<"${body_text}" || fail "(f) body must include rejected finding id"
grep -Fq 'Accepted findings' <<<"${body_text}" || fail "(f) body must sectionize accepted findings"
grep -Fq 'Rejected findings' <<<"${body_text}" || fail "(f) body must sectionize rejected findings"

# (g) harness-review path must not auto push / create PR
review_hits="$(rg -n 'gh pr create|git push' "${PROJECT_ROOT}/skills/harness-review" 2>/dev/null || true)"
[ -z "${review_hits}" ] || fail "(g) harness-review must not reference gh pr create or git push:\n${review_hits}"

echo "test-pr-closeout: ok"
