#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILED=0

PUBLIC_SKILL_ROOTS=(
  "skills"
  "opencode/skills"
  "codex/.codex/skills"
)

PRIVATE_SKILL_NAMES=(
  "allow1"
  "claude-codex-upstream-update"
  "harness-release-internal"
  "x-announce"
  "x-article"
  "x-promo"
  "x-release-harness"
  "zz-review-empty"
  "zz-review-escape"
)

OPENCODE_UNSUPPORTED_SKILL_NAMES=(
  "cc-update-review"
)

is_private_skill_name() {
  local skill_name="$1"

  case "${skill_name}" in
    test-*|x-*|zz-review-*)
      return 0
      ;;
  esac

  for private_name in "${PRIVATE_SKILL_NAMES[@]}"; do
    if [ "${skill_name}" = "${private_name}" ]; then
      return 0
    fi
  done

  return 1
}

is_opencode_unsupported_skill_name() {
  local skill_name="$1"

  for unsupported_name in "${OPENCODE_UNSUPPORTED_SKILL_NAMES[@]}"; do
    if [ "${skill_name}" = "${unsupported_name}" ]; then
      return 0
    fi
  done

  return 1
}

for root in "${PUBLIC_SKILL_ROOTS[@]}"; do
  [ -d "${ROOT_DIR}/${root}" ] || continue

  while IFS= read -r skill_file; do
    rel_path="${skill_file#${ROOT_DIR}/}"
    skill_name="$(basename "$(dirname "${skill_file}")")"

    if git -C "${ROOT_DIR}" check-ignore --no-index -q -- "${rel_path}"; then
      echo "ignored/private skill is inside public plugin surface: ${rel_path}"
      FAILED=1
    fi
    if is_private_skill_name "${skill_name}"; then
      echo "private/dev-only skill is inside public plugin surface: ${rel_path}"
      FAILED=1
    fi
    if [ "${root}" = "opencode/skills" ] && is_opencode_unsupported_skill_name "${skill_name}"; then
      echo "OpenCode-unsupported skill is inside opencode mirror: ${rel_path}"
      FAILED=1
    fi
  done < <(find "${ROOT_DIR}/${root}" -mindepth 2 -maxdepth 2 -type f -name "SKILL.md" | sort)
done

if command -v claude >/dev/null 2>&1; then
  DETAILS_OUTPUT="$(cd "${ROOT_DIR}" && claude --bare --plugin-dir . plugin details company-ai-harness 2>/dev/null || true)"
  if [ -n "${DETAILS_OUTPUT}" ]; then
    for skill_name in "${PRIVATE_SKILL_NAMES[@]}"; do
      if grep -Eq "(^|[[:space:],])${skill_name}($|[[:space:],])" <<<"${DETAILS_OUTPUT}"; then
        echo "private skill exposed by local plugin inventory: ${skill_name}"
        FAILED=1
      fi
    done
  fi
else
  echo "SKIP: claude CLI not found; deterministic public-surface inventory gate still ran"
fi

if [ "${FAILED}" -ne 0 ]; then
  exit 1
fi

echo "OK"
