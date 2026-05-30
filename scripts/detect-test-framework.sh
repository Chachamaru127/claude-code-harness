#!/bin/bash
# detect-test-framework.sh
# Phase 68 - プロジェクトのテストフレームワーク自動検知ヘルパー
#
# .claude/rules/tdd-paths.yaml の言語定義に従い、project root を走査して
# 検出された framework / コマンド / 言語 / test pattern を JSON で stdout に
# 出力する。harness-setup (sprint-contract emission) と R14 guardrail rule
# (Phase B 実装) が共通参照する SSOT 経路。
#
# Usage:
#   bash scripts/detect-test-framework.sh \
#     [--project-root <path>] \
#     [--target-file <path>]
#
#   --target-file が与えられた場合、そのファイルの directory から遡って
#   framework を検出する (polyglot monorepo 対応)。
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
#   0: 検出成功 (none を含む)
#   1: 引数エラーまたは project_root 不在

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

# === Root 決定 ===
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

# === target-file がある場合、その directory から検出開始 ===
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
    # fallback: 安全な printf (引用符は input に含まれない前提、上記値は内部固定)
    printf '{"framework":"%s","command":"%s","language":"%s","test_pattern":"%s","detected_via":"%s"}\n' \
      "${framework}" "${command}" "${language}" "${test_pattern}" "${detected_via}"
  fi
}

# === 単一ディレクトリでの検出 ===
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

# === SEARCH_ROOT から親へ遡って検出 (PROJECT_ROOT の外には出ない) ===
TRY_ROOT="${SEARCH_ROOT}"
# realpath で正規化 (シンボリックリンク考慮)
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
  # PROJECT_ROOT より上には行かない
  case "${PARENT}/" in
    "${PROJECT_ROOT_REAL}/"*) TRY_ROOT="${PARENT}" ;;
    "${PROJECT_ROOT_REAL}/")  TRY_ROOT="${PARENT}" ;;
    "${PROJECT_ROOT_REAL}")   TRY_ROOT="${PARENT}" ;;
    *)
      # PROJECT_ROOT 自体での試行を最後に確認
      if [ "${TRY_ROOT}" != "${PROJECT_ROOT_REAL}" ]; then
        if detect_in_dir "${PROJECT_ROOT_REAL}"; then
          exit 0
        fi
      fi
      break
      ;;
  esac
done

# どれも該当しない → none
emit_json "none" "" "unknown" "" ""
exit 0
