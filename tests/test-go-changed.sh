#!/usr/bin/env bash
# Required test-go check: changed Go packages plus the core list.
#
# The full `go test ./...` does not complete in CI (Instabox runner loses
# communication; GitHub-hosted runners run out of memory), so this script
# covers the packages changed by the PR (including testdata-only changes) and
# the core packages. The full suite is recorded in Plans.md Phase 151.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}/go"

core=(
  ./internal/hookhandler
  ./internal/plans
  ./internal/policy
  ./internal/scopeleash
  ./internal/runtimefloor
  ./internal/floor
  ./internal/guardrail
  ./pkg/config
)

range=""
if [ -n "${BASE_REF:-}" ]; then
  git fetch --no-tags origin "${BASE_REF}"
  range="origin/${BASE_REF}...HEAD"
elif [ -n "${BEFORE_SHA:-}" ] && [ "${BEFORE_SHA}" != "0000000000000000000000000000000000000000" ]; then
  range="${BEFORE_SHA}...HEAD"
elif git rev-parse --verify HEAD~1 >/dev/null 2>&1; then
  range="HEAD~1...HEAD"
fi

changed=()
if [ -n "${range}" ]; then
  files="$(git diff --name-only "${range}" -- .)" || {
    echo "git diff failed for ${range}" >&2
    exit 1
  }
  while IFS= read -r file; do
    [ -n "${file}" ] || continue
    dir="$(dirname "${file}")"
    dir="${dir#go/}"
    [ "${dir}" = "." ] && continue
    candidate="./${dir}"
    while :; do
      [ "${candidate}" = "." ] && break
      if [ -d "${candidate}" ] && [ -n "$(find "${candidate}" -maxdepth 1 -name '*.go' -print -quit)" ]; then
        break
      fi
      candidate="$(dirname "${candidate}")"
    done
    [ "${candidate}" != "." ] && changed+=("${candidate}")
  done <<< "${files}"
fi

deduped="$(printf '%s\n' "${changed[@]:-}" | sed '/^$/d' | sort -u)"
changed=()
while IFS= read -r pkg; do
  [ -n "${pkg}" ] && changed+=("${pkg}")
done <<< "${deduped}"
echo "changed packages: ${changed[*]:-none}"
if [ "${#changed[@]}" -gt 0 ]; then
  go test -count=1 -p 1 -parallel 1 "${core[@]}" "${changed[@]}"
else
  go test -count=1 -p 1 -parallel 1 "${core[@]}"
fi
