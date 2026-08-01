#!/usr/bin/env bash
# test-breezing-fixture-deps.sh
# Static version floor for vitest in breezing benchmark throwaway fixtures (CVE-2026-47429).
#
# Usage: bash tests/test-breezing-fixture-deps.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BENCH_DIR="${ROOT_DIR}/benchmarks/breezing-bench"
MIN_VITEST="4.1.0"

manifests=()
while IFS= read -r -d '' manifest; do
  manifests+=("${manifest}")
done < <(
  find "${BENCH_DIR}/tasks" -mindepth 3 -maxdepth 3 -type f -path '*/setup/package.json' -print0 2>/dev/null
  find "${BENCH_DIR}/agent-eval/evals" -mindepth 2 -maxdepth 2 -type f -name 'package.json' -print0 2>/dev/null
)

if [ "${#manifests[@]}" -eq 0 ]; then
  echo "no breezing fixture manifests matched — glob guard tripped" >&2
  exit 1
fi

export MIN_VITEST
offenders=()
for manifest in "${manifests[@]}"; do
  range="$(
    grep -E '"vitest"[[:space:]]*:' "${manifest}" \
      | head -1 \
      | sed -E 's/.*"vitest"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' \
      || true
  )"
  if [ -z "${range}" ]; then
    offenders+=("${manifest}: vitest dependency missing")
    continue
  fi

  floor="${range#^}"
  if ! grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' <<<"${floor}"; then
    offenders+=("${manifest}: vitest range must be caret semver (^X.Y.Z), got ${range}")
    continue
  fi

  if ! MIN_VITEST="${MIN_VITEST}" node -e '
    const floor = process.argv[1].split(".").map(Number);
    const min = process.env.MIN_VITEST.split(".").map(Number);
    for (let i = 0; i < 3; i += 1) {
      if (floor[i] > min[i]) process.exit(0);
      if (floor[i] < min[i]) process.exit(1);
    }
    process.exit(0);
  ' "${floor}"; then
    rel="${manifest#"${ROOT_DIR}/"}"
    offenders+=("${rel}: vitest ^${floor} < ^${MIN_VITEST}")
  fi
done

if [ "${#offenders[@]}" -gt 0 ]; then
  echo "breezing fixture vitest version floor: FAIL" >&2
  for entry in "${offenders[@]}"; do
    echo "  ${entry}" >&2
  done
  exit 1
fi

echo "breezing fixture vitest version floor: ok (${#manifests[@]} manifests >= ^${MIN_VITEST})"
