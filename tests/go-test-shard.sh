#!/usr/bin/env bash
# Full Go suite split across CI jobs.
#
# Rationale: one job running `go test ./...` did not complete in CI. The paid
# Instabox runner (8 vCPU / 16 GB) lost communication about 11 minutes in, and
# GitHub-hosted runners ran out of memory. Splitting the same package list
# across jobs keeps the full scope and shortens each job.
#
# The assignment and the verification read the same source (`go list ./...`),
# so a missing or duplicated package fails the aggregate check instead of
# silently shrinking the tested scope.
#
# Usage:
#   go-test-shard.sh assign <index> <total>   Print this shard's packages.
#   go-test-shard.sh run <index> <total>      Run this shard, one package at a
#                                             time, with per-package logs.
#   go-test-shard.sh verify <root> <total>    Check that the downloaded shard
#                                             lists cover every package once.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GO_DIR="${ROOT_DIR}/go"
# Actions provides RUNNER_TEMP; the fallback keeps local runs out of the repo.
LOG_ROOT="${SHARD_LOG_DIR:-${RUNNER_TEMP:-/tmp}/go-test-shard}"

die() {
  echo "go-test-shard: $*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
usage: go-test-shard.sh assign <index> <total>
       go-test-shard.sh run <index> <total>
       go-test-shard.sh verify <artifact-root> <total>
USAGE
}

require_count() {
  local index="$1"
  local total="$2"
  [[ "${index}" =~ ^[0-9]+$ ]] || die "index must be a positive integer: ${index}"
  [[ "${total}" =~ ^[0-9]+$ ]] || die "total must be a positive integer: ${total}"
  (( total >= 1 )) || die "total must be at least 1: ${total}"
  (( index >= 1 && index <= total )) || die "index must be between 1 and ${total}: ${index}"
}

all_packages() {
  ( cd "${GO_DIR}" && go list ./... ) | LC_ALL=C sort
}

assign() {
  local index="$1"
  local total="$2"
  require_count "${index}" "${total}"
  # Round-robin over the sorted package list: deterministic, no gaps, and it
  # spreads neighbouring packages (often related) over different shards.
  all_packages | awk -v shard="${index}" -v total="${total}" 'NR % total == (shard - 1) % total'
}

run_shard() {
  local index="$1"
  local total="$2"
  require_count "${index}" "${total}"

  local dir="${LOG_ROOT}/shard-${index}"
  rm -rf "${dir}"
  mkdir -p "${dir}"
  assign "${index}" "${total}" > "${dir}/packages.txt"
  local count
  count="$(wc -l < "${dir}/packages.txt" | tr -d ' ')"
  echo "shard ${index}/${total}: ${count} packages"

  printf 'package\tseconds\tstatus\n' > "${dir}/summary.tsv"
  local fail=0 pkg status start duration safe
  while IFS= read -r pkg; do
    [ -n "${pkg}" ] || continue
    # Package paths become file names; the log name stays readable in artifacts.
    safe="$(printf '%s' "${pkg}" | sed 's|^\./||; s|/$||; s|/|__|g')"
    start="$(date +%s)"
    if ( cd "${GO_DIR}" && go test -count=1 -timeout=10m -p 1 -parallel 1 "${pkg}" ) \
        > "${dir}/${safe}.log" 2>&1; then
      status="ok"
    else
      status="fail"
      fail=1
      echo "FAILED: ${pkg}"
      tail -n 60 "${dir}/${safe}.log" || true
    fi
    duration="$(( $(date +%s) - start ))"
    printf '%s\t%s\t%s\n' "${pkg}" "${duration}" "${status}" >> "${dir}/summary.tsv"
    echo "  [${status}] ${duration}s ${pkg}"
  done < "${dir}/packages.txt"

  echo "slowest packages in shard ${index}:"
  tail -n +2 "${dir}/summary.tsv" | sort -t "$(printf '\t')" -k2,2nr | head -n 5 || true
  return "${fail}"
}

verify_shards() {
  local root="$1"
  local total="$2"
  [[ "${total}" =~ ^[0-9]+$ ]] || die "total must be a positive integer: ${total}"
  [ -d "${root}" ] || die "artifact root not found: ${root}"

  local lists
  lists="$(find "${root}" -name 'packages.txt' | wc -l | tr -d ' ')"
  [ "${lists}" = "${total}" ] || die "expected ${total} shard package lists, found ${lists}"

  local expected assigned duplicates
  expected="$(all_packages)"
  assigned="$(find "${root}" -name 'packages.txt' -print0 | xargs -0 cat | LC_ALL=C sort)"
  [ -n "${assigned}" ] || die "shard package lists under ${root} are empty"

  duplicates="$(printf '%s\n' "${assigned}" | uniq -d)"
  if [ -n "${duplicates}" ]; then
    echo "packages assigned to more than one shard:" >&2
    printf '%s\n' "${duplicates}" >&2
    exit 1
  fi

  local difference
  if ! difference="$(diff -u <(printf '%s\n' "${expected}") <(printf '%s\n' "${assigned}"))"; then
    echo "shard assignment does not cover the full package list:" >&2
    printf '%s\n' "${difference}" >&2
    exit 1
  fi

  echo "verified: ${lists} shards cover all $(printf '%s\n' "${expected}" | wc -l | tr -d ' ') packages once"
}

command="${1:-}"
case "${command}" in
  assign)
    shift
    [ "$#" -eq 2 ] || die "assign needs <index> <total>"
    assign "$1" "$2"
    ;;
  run)
    shift
    [ "$#" -eq 2 ] || die "run needs <index> <total>"
    run_shard "$1" "$2"
    ;;
  verify)
    shift
    [ "$#" -eq 2 ] || die "verify needs <artifact-root> <total>"
    verify_shards "$1" "$2"
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
