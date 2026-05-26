#!/bin/bash
# detect-test-framework.sh
# Phase 68 - Auto-detection helper for the project test framework
#
# Scans the project root following the language definitions in
# .claude/rules/tdd-paths.yaml and outputs the detected framework /
# command / language / test pattern as JSON to stdout.
# This is the SSOT path shared by the scaffolder (sprint-contract emission)
# and the R14 guardrail rule (Phase B implementation).
#
# Usage:
#   bash scripts/detect-test-framework.sh \
#     [--project-root <path>] \
#     [--target-file <path>]
#
#   If --target-file is given, detection starts from that file's directory
#   and walks up (polyglot monorepo support).
#
# Output (JSON, single line):
#   {
#     "framework": "vitest|jest|npm|pytest|go|cargo|none",
#     "command":   "npm test",
#     "language":  "node|go|python|rust|unknown",
#     "test_pattern": "**/*.test.ts",
#     "detected_via": "vitest.config.ts"
#   }
#
# Exit codes:
#   0: detection successful (includes none)
#   1: argument error or project_root not found

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/path-utils.sh" ]; then
  # shellcheck source=/dev/null
  source "${SCRIPT_DIR}/path-utils.sh"
fi

# === Args ===
PROJECT_ROOT_ARG=""
TARGET_FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --project-root) PROJECT_ROOT_ARG="${2:-}"; shift 2 ;;
    --target-file)  TARGET_FILE="${2:-}"; shift 2 ;;
    --help|-h)
      sed -n '2,28p' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    *)
      echo "Error: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# === Determine root ===
if [ -n "${PROJECT_ROOT_ARG}" ]; then
  PROJECT_ROOT="${PROJECT_ROOT_ARG}"
elif command -v detect_project_root >/dev/null 2>&1; then
  PROJECT_ROOT="${PROJECT_ROOT:-$(detect_project_root 2>/dev/null || pwd)}"
else
  PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
fi

if [ ! -d "${PROJECT_ROOT}" ]; then
  echo "Error: project root not found: ${PROJECT_ROOT}" >&2
  exit 1
fi

# === If target-file is provided, start detection from its directory ===
SEARCH_ROOT="${PROJECT_ROOT}"
if [ -n "${TARGET_FILE}" ]; then
  if [ -f "${TARGET_FILE}" ]; then
    SEARCH_ROOT="$(cd "$(dirname "${TARGET_FILE}")" && pwd)"
  elif [ -d "${TARGET_FILE}" ]; then
    SEARCH_ROOT="$(cd "${TARGET_FILE}" && pwd)"
  fi
fi

# === JSON emitter ===
emit_json() {
  local framework="$1"
  local command="$2"
  local language="$3"
  local test_pattern="$4"
  local detected_via="$5"

  if command -v jq >/dev/null 2>&1; then
    jq -nc \
      --arg framework "${framework}" \
      --arg command "${command}" \
      --arg language "${language}" \
      --arg test_pattern "${test_pattern}" \
      --arg detected_via "${detected_via}" \
      '{framework:$framework, command:$command, language:$language, test_pattern:$test_pattern, detected_via:$detected_via}'
  else
    # fallback: safe printf (assumes no quotes in input; values above are internally fixed)
    printf '{"framework":"%s","command":"%s","language":"%s","test_pattern":"%s","detected_via":"%s"}\n' \
      "${framework}" "${command}" "${language}" "${test_pattern}" "${detected_via}"
  fi
}

# === Detection within a single directory ===
detect_in_dir() {
  local root="$1"

  # --- Node (vitest > jest > package.json scripts.test) ---
  if [ -f "${root}/vitest.config.ts" ] || [ -f "${root}/vitest.config.js" ] || [ -f "${root}/vitest.config.mjs" ]; then
    emit_json "vitest" "npx vitest run" "node" "**/*.test.ts" "vitest.config.*"
    return 0
  fi
  if [ -f "${root}/jest.config.js" ] || [ -f "${root}/jest.config.ts" ] || [ -f "${root}/jest.config.mjs" ]; then
    emit_json "jest" "npx jest" "node" "**/*.test.{ts,tsx,js,jsx}" "jest.config.*"
    return 0
  fi
  if [ -f "${root}/package.json" ]; then
    local has_test_script="" lower=""
    if command -v jq >/dev/null 2>&1; then
      has_test_script="$(jq -r '.scripts.test // ""' "${root}/package.json" 2>/dev/null || printf '')"
    fi
    if [ -n "${has_test_script}" ] && [ "${has_test_script}" != "echo \"Error: no test specified\" && exit 1" ]; then
      lower="$(printf '%s' "${has_test_script}" | tr '[:upper:]' '[:lower:]')"
      if printf '%s' "${lower}" | grep -q 'vitest'; then
        emit_json "vitest" "npm test" "node" "**/*.test.ts" "package.json:scripts.test"
      elif printf '%s' "${lower}" | grep -q 'jest'; then
        emit_json "jest" "npm test" "node" "**/*.test.{ts,tsx,js,jsx}" "package.json:scripts.test"
      else
        emit_json "npm" "npm test" "node" "**/*.test.{ts,tsx,js,jsx}" "package.json:scripts.test"
      fi
      return 0
    fi
  fi

  # --- Go ---
  if [ -f "${root}/go.mod" ]; then
    emit_json "go" "go test ./..." "go" "**/*_test.go" "go.mod"
    return 0
  fi

  # --- Python (pytest) ---
  if [ -f "${root}/pyproject.toml" ]; then
    if grep -q 'pytest' "${root}/pyproject.toml" 2>/dev/null; then
      emit_json "pytest" "pytest" "python" "tests/**/test_*.py" "pyproject.toml"
      return 0
    fi
  fi
  if [ -f "${root}/pytest.ini" ]; then
    emit_json "pytest" "pytest" "python" "tests/**/test_*.py" "pytest.ini"
    return 0
  fi
  if [ -f "${root}/setup.cfg" ] && grep -q '\[tool:pytest\]\|\[pytest\]' "${root}/setup.cfg" 2>/dev/null; then
    emit_json "pytest" "pytest" "python" "tests/**/test_*.py" "setup.cfg"
    return 0
  fi

  # --- Rust ---
  if [ -f "${root}/Cargo.toml" ]; then
    emit_json "cargo" "cargo test" "rust" "tests/**/*.rs" "Cargo.toml"
    return 0
  fi

  return 1
}

# === Walk up from SEARCH_ROOT toward parent (do not go outside PROJECT_ROOT) ===
TRY_ROOT="${SEARCH_ROOT}"
# Normalize with realpath (considering symbolic links)
if command -v realpath >/dev/null 2>&1; then
  PROJECT_ROOT_REAL="$(realpath "${PROJECT_ROOT}" 2>/dev/null || printf '%s' "${PROJECT_ROOT}")"
else
  PROJECT_ROOT_REAL="${PROJECT_ROOT}"
fi

while [ -n "${TRY_ROOT}" ] && [ "${TRY_ROOT}" != "/" ]; do
  if detect_in_dir "${TRY_ROOT}"; then
    exit 0
  fi
  PARENT="$(dirname "${TRY_ROOT}")"
  if [ "${PARENT}" = "${TRY_ROOT}" ]; then
    break
  fi
  # Do not go above PROJECT_ROOT
  case "${PARENT}/" in
    "${PROJECT_ROOT_REAL}/"*) TRY_ROOT="${PARENT}" ;;
    "${PROJECT_ROOT_REAL}/")  TRY_ROOT="${PARENT}" ;;
    "${PROJECT_ROOT_REAL}")   TRY_ROOT="${PARENT}" ;;
    *)
      # Final check at PROJECT_ROOT itself
      if [ "${TRY_ROOT}" != "${PROJECT_ROOT_REAL}" ]; then
        if detect_in_dir "${PROJECT_ROOT_REAL}"; then
          exit 0
        fi
      fi
      break
      ;;
  esac
done

# No match found → none
emit_json "none" "" "unknown" "" ""
exit 0
