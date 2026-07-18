#!/usr/bin/env bash
# Mechanical floor for test-wiring audit.
# Judgment-level auditing is agents/test-wiring-auditor.md, which invokes this script first.
#
# Usage:
#   bash scripts/test-wiring-audit-core.sh --base <ref> --head <ref> [--repo <dir>]
#
# Read-only: no file writes. Exit 0 on successful analysis (verdict in JSON).
# Exit 2 on usage errors.
set -euo pipefail

usage() {
  cat <<'EOF' >&2
Usage:
  test-wiring-audit-core.sh --base <ref> --head <ref> [--repo <dir>]
EOF
  exit 2
}

REPO="."
BASE=""
HEAD=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    --base)
      BASE="${2:-}"
      shift 2
      ;;
    --head)
      HEAD="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "test-wiring-audit-core.sh: unknown argument: $1" >&2
      usage
      ;;
  esac
done

if [[ -z "$BASE" || -z "$HEAD" ]]; then
  usage
fi

if [[ ! -d "$REPO" ]]; then
  echo "test-wiring-audit-core.sh: repo not found: $REPO" >&2
  exit 2
fi

is_product_surface() {
  local file="$1"
  case "$file" in
    hooks/*)
      return 0
      ;;
    scripts/*.sh|scripts/*/*.sh|scripts/*/*/*.sh)
      return 0
      ;;
    go/*)
      if [[ "$file" == *.go && "$file" != *_test.go ]]; then
        return 0
      fi
      ;;
  esac
  return 1
}

is_test_surface() {
  local file="$1"
  case "$file" in
    tests/*)
      return 0
      ;;
    go/*_test.go)
      return 0
      ;;
  esac
  return 1
}

product_files=()
test_files=()

while IFS= read -r file; do
  [[ -z "$file" ]] && continue
  if is_product_surface "$file"; then
    product_files+=("$file")
  fi
  if is_test_surface "$file"; then
    test_files+=("$file")
  fi
done < <(git -C "$REPO" diff --name-only --diff-filter=ACMR "${BASE}..${HEAD}")

_py_args=(python3 - "$REPO")
if ((${#product_files[@]} > 0)); then
  _py_args+=("${product_files[@]}")
fi
_py_args+=(--)
if ((${#test_files[@]} > 0)); then
  _py_args+=("${test_files[@]}")
fi

"${_py_args[@]}" <<'PY'
import json
import sys

repo = sys.argv[1]
args = sys.argv[2:]
if "--" in args:
    sep = args.index("--")
    product_files = args[:sep]
    test_files = args[sep + 1 :]
else:
    product_files = args
    test_files = []

required_tests = []
if product_files and not test_files:
    for path in product_files:
        required_tests.append(
            {
                "path": f"tests/test-{path.rsplit('/', 1)[-1].replace('.go', '').replace('.sh', '')}.sh",
                "reason": f"no test-surface change accompanies {path}",
                "covers": path,
            }
        )
    verdict = "ADD_REQUIRED"
else:
    verdict = "PASS"

payload = {
    "schema_version": "test-wiring-audit.v1",
    "verdict": verdict,
    "appeal_round": 0,
    "required_tests": required_tests,
    "evidence": [
        f"repo={repo}",
        f"product_surface_changed={len(product_files)}",
        f"test_surface_changed={len(test_files)}",
    ],
    "notes": "mechanical floor from scripts/test-wiring-audit-core.sh",
}

print(json.dumps(payload, ensure_ascii=False, indent=2))
PY
