#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Override to run the same contract against another revision of the script
# (used to record RED/GREEN for the distribution contract below).
SYNC_SCRIPT="${SYNC_PLUGIN_CACHE_SCRIPT:-${ROOT_DIR}/scripts/sync-plugin-cache.sh}"
TMP_HOME="$(mktemp -d)"
TMP_HOME_ABSENT="$(mktemp -d)"
TMP_HOME_MISMATCH="$(mktemp -d)"
PRIVATE_SYNC_TEST_DIR="${ROOT_DIR}/skills/test-private-sync"
trap 'rm -rf "${TMP_HOME}" "${TMP_HOME_ABSENT}" "${TMP_HOME_MISMATCH}" "${PRIVATE_SYNC_TEST_DIR}"' EXIT

# This directory is intentionally ignored by .gitignore (skills/test-*). It
# simulates local-only development skills that must not be copied into the
# installed plugin cache just because plugin.json declares ./skills/.
mkdir -p "${PRIVATE_SYNC_TEST_DIR}"
printf '%s\n' '---' 'name: test-private-sync' 'description: local-only sync test' '---' > "${PRIVATE_SYNC_TEST_DIR}/SKILL.md"

SOURCE_VERSION="$(tr -d '[:space:]' < "${ROOT_DIR}/VERSION")"
CACHE_REL="plugins/cache/claude-code-harness-marketplace/harness/${SOURCE_VERSION}"
MARKETPLACE_REL="plugins/marketplaces/claude-code-harness-marketplace"
CACHE_DIR="${TMP_HOME}/.claude/${CACHE_REL}"
MARKETPLACE_DIR="${TMP_HOME}/.claude/${MARKETPLACE_REL}"

# Fixture plugin.json for the marketplace clone. Its version matches the
# source (same release), but the content is a marker so we can prove the
# script never rewrites the clone's version-bearing files.
MARKETPLACE_PLUGIN_JSON_FIXTURE="{\"name\": \"harness\", \"version\": \"${SOURCE_VERSION}\", \"fixture\": \"clone-owned\"}"

mkdir -p "${CACHE_DIR}" "${MARKETPLACE_DIR}/.claude-plugin"
mkdir -p \
  "${CACHE_DIR}/codex/.codex/skills/x-article" \
  "${CACHE_DIR}/skills/harness-release-internal" \
  "${CACHE_DIR}/docs/private" \
  "${MARKETPLACE_DIR}/docs/research"

# 古い/欠落したキャッシュと marketplace copy を用意して、CLAUDE_PLUGIN_ROOT を
# plugin root として渡したときに正しく同期元解決できることを確認する。
printf 'stale\n' > "${CACHE_DIR}/VERSION"
printf '%s\n' "${SOURCE_VERSION}" > "${MARKETPLACE_DIR}/VERSION"
printf '%s\n' "${MARKETPLACE_PLUGIN_JSON_FIXTURE}" > "${MARKETPLACE_DIR}/.claude-plugin/plugin.json"
printf 'stale\n' > "${CACHE_DIR}/codex/.codex/skills/x-article/SKILL.md"
printf 'stale\n' > "${CACHE_DIR}/skills/harness-release-internal/SKILL.md"
printf 'stale\n' > "${CACHE_DIR}/docs/private/stale-note.md"
# Tracked in the real clone; deleting it there leaves the git checkout dirty.
printf 'tracked\n' > "${MARKETPLACE_DIR}/docs/research/tracked-note.md"
printf '{"hooks":{"SessionStart":[{"hooks":[{"command":"\"${CLAUDE_PLUGIN_ROOT}/bin/harness\" hook session-start"}]}]}}' > "${MARKETPLACE_DIR}/.claude-plugin/hooks.json"

HOME="${TMP_HOME}" CLAUDE_PLUGIN_ROOT="${ROOT_DIR}" bash "${SYNC_SCRIPT}" >/dev/null 2>&1

# 間違った CLAUDE_PLUGIN_ROOT が来ても、script path から実際の plugin root へ
# 戻れることを確認する。hook 実行環境の変数揺れに対する回帰テスト。
INVALID_ROOT="${TMP_HOME}/not-a-plugin-root"
mkdir -p "${INVALID_ROOT}"
HOME="${TMP_HOME}" CLAUDE_PLUGIN_ROOT="${INVALID_ROOT}" bash "${SYNC_SCRIPT}" >/dev/null 2>&1

required_cached_files=(
  "${CACHE_DIR}/scripts/lib/harness-mem-bridge.sh"
  "${CACHE_DIR}/scripts/codex-companion.sh"
  "${CACHE_DIR}/scripts/cursor-companion.sh"
  "${CACHE_DIR}/scripts/model-routing.sh"
  "${CACHE_DIR}/scripts/resolve-impl-backend.sh"
  "${CACHE_DIR}/scripts/hook-handlers/memory-bridge.sh"
  "${CACHE_DIR}/scripts/hook-handlers/memory-session-start.sh"
  "${CACHE_DIR}/scripts/hook-handlers/memory-user-prompt.sh"
  "${CACHE_DIR}/scripts/hook-handlers/memory-post-tool-use.sh"
  "${CACHE_DIR}/scripts/hook-handlers/memory-stop.sh"
  "${CACHE_DIR}/scripts/hook-handlers/runtime-reactive.sh"
  "${CACHE_DIR}/hooks/hooks.json"
  "${CACHE_DIR}/.claude-plugin/hooks.json"
  "${CACHE_DIR}/.claude-plugin/settings.json"
  "${CACHE_DIR}/agents/worker.md"
  "${CACHE_DIR}/agents/reviewer.md"
  "${MARKETPLACE_DIR}/scripts/lib/harness-mem-bridge.sh"
  "${MARKETPLACE_DIR}/scripts/codex-companion.sh"
  "${MARKETPLACE_DIR}/scripts/cursor-companion.sh"
  "${MARKETPLACE_DIR}/scripts/model-routing.sh"
  "${MARKETPLACE_DIR}/scripts/resolve-impl-backend.sh"
  "${MARKETPLACE_DIR}/scripts/hook-handlers/memory-bridge.sh"
  "${MARKETPLACE_DIR}/scripts/hook-handlers/memory-session-start.sh"
  "${MARKETPLACE_DIR}/scripts/hook-handlers/memory-user-prompt.sh"
  "${MARKETPLACE_DIR}/scripts/hook-handlers/memory-post-tool-use.sh"
  "${MARKETPLACE_DIR}/scripts/hook-handlers/memory-stop.sh"
  "${MARKETPLACE_DIR}/scripts/hook-handlers/runtime-reactive.sh"
  "${MARKETPLACE_DIR}/hooks/hooks.json"
  "${MARKETPLACE_DIR}/.claude-plugin/hooks.json"
  "${MARKETPLACE_DIR}/.claude-plugin/settings.json"
)

required_cached_dirs=(
  "${CACHE_DIR}/skills"
  "${CACHE_DIR}/output-styles"
  "${CACHE_DIR}/agents"
  "${MARKETPLACE_DIR}/skills"
  "${MARKETPLACE_DIR}/output-styles"
)

for file in "${required_cached_files[@]}"; do
  if [[ ! -f "${file}" ]]; then
    echo "sync-plugin-cache did not populate required file: ${file}"
    exit 1
  fi
done

for dir in "${required_cached_dirs[@]}"; do
  if [[ ! -d "${dir}" ]]; then
    echo "sync-plugin-cache did not populate required directory: ${dir}"
    exit 1
  fi
done

assert_hook_script_closure() {
  local hooks_file="$1"
  local target_root="$2"
  local rel

  if [[ ! -f "$hooks_file" ]]; then
    echo "hook script closure check missing hooks file: ${hooks_file}"
    exit 1
  fi

  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    if [[ ! -f "${target_root}/${rel}" ]]; then
      echo "sync-plugin-cache did not populate hook script ref: ${target_root}/${rel}"
      exit 1
    fi
  done < <(grep -Eoh 'scripts/[A-Za-z0-9_./-]+\.sh' "$hooks_file" | sort -u)
}

assert_hook_script_closure "${CACHE_DIR}/.claude-plugin/hooks.json" "${CACHE_DIR}"
assert_hook_script_closure "${CACHE_DIR}/hooks/hooks.json" "${CACHE_DIR}"
assert_hook_script_closure "${MARKETPLACE_DIR}/.claude-plugin/hooks.json" "${MARKETPLACE_DIR}"
assert_hook_script_closure "${MARKETPLACE_DIR}/hooks/hooks.json" "${MARKETPLACE_DIR}"

for private_path in \
  "${CACHE_DIR}/skills/test-private-sync" \
  "${CACHE_DIR}/skills/harness-release-internal" \
  "${CACHE_DIR}/codex/.codex/skills/x-article" \
  "${CACHE_DIR}/docs/private" \
  "${MARKETPLACE_DIR}/skills/test-private-sync"; do
  if [[ -e "${private_path}" ]]; then
    echo "sync-plugin-cache copied ignored/private skill path: ${private_path}"
    exit 1
  fi
done

for file in "${CACHE_DIR}/.claude-plugin/hooks.json" "${MARKETPLACE_DIR}/.claude-plugin/hooks.json"; do
  if jq -e '.. | objects | select(.command? | strings | test("^\"\\\\$\\\\{CLAUDE_PLUGIN_ROOT\\\\}/bin/harness\"|^bash \"\\\\$\\\\{CLAUDE_PLUGIN_ROOT\\\\}/scripts/"))' "${file}" >/dev/null 2>&1; then
    echo "sync-plugin-cache left raw CLAUDE_PLUGIN_ROOT hook command in: ${file}"
    exit 1
  fi
done

# ---------------------------------------------------------------------------
# Distribution contract (2026-08-29). The installed cache and the marketplace
# clone are owned by Claude Code. This script may refresh them, never seed or
# re-version them. Each assertion below is a regression that shipped:
#   - pre-created cache dir → CC installed into it as-is → Agents (0)
#   - clone plugin.json rewritten from another checkout → `claude plugin update`
#     reported "already at the latest version" while a newer release existed
#   - tracked docs/research/* deleted from the clone → 21 permanent `D` entries
# ---------------------------------------------------------------------------

# (1) The clone's version-bearing files are never rewritten, even on the same
#     release.
if [[ "$(cat "${MARKETPLACE_DIR}/.claude-plugin/plugin.json")" != "${MARKETPLACE_PLUGIN_JSON_FIXTURE}" ]]; then
  echo "sync-plugin-cache rewrote the marketplace clone's .claude-plugin/plugin.json (clone-owned version source)"
  exit 1
fi
if [[ "$(tr -d '[:space:]' < "${MARKETPLACE_DIR}/VERSION")" != "${SOURCE_VERSION}" ]]; then
  echo "sync-plugin-cache rewrote the marketplace clone's VERSION"
  exit 1
fi

# (2) Tracked private-doc paths are not deleted from the clone.
if [[ ! -f "${MARKETPLACE_DIR}/docs/research/tracked-note.md" ]]; then
  echo "sync-plugin-cache deleted a tracked path (docs/research) from the marketplace clone"
  exit 1
fi

# (3) A versioned cache dir that CC has not installed is never created.
ABSENT_CACHE_DIR="${TMP_HOME_ABSENT}/.claude/${CACHE_REL}"
mkdir -p "${TMP_HOME_ABSENT}/.claude/plugins/cache"
HOME="${TMP_HOME_ABSENT}" CLAUDE_PLUGIN_ROOT="${ROOT_DIR}" bash "${SYNC_SCRIPT}" >/dev/null 2>&1
if [[ -e "${ABSENT_CACHE_DIR}" ]]; then
  echo "sync-plugin-cache pre-created an uninstalled versioned cache dir: ${ABSENT_CACHE_DIR} (CC would install into it as-is, without agents/bin/templates)"
  exit 1
fi

# (4) A clone on another release is left untouched (no file added, changed,
#     or removed).
MISMATCH_DIR="${TMP_HOME_MISMATCH}/.claude/${MARKETPLACE_REL}"
mkdir -p "${MISMATCH_DIR}/.claude-plugin" "${MISMATCH_DIR}/docs/research" "${MISMATCH_DIR}/scripts"
printf '0.0.0-other\n' > "${MISMATCH_DIR}/VERSION"
printf '{"name": "claude-code-harness", "version": "0.0.0-other"}\n' > "${MISMATCH_DIR}/.claude-plugin/plugin.json"
printf 'tracked\n' > "${MISMATCH_DIR}/docs/research/tracked-note.md"
printf 'other-release\n' > "${MISMATCH_DIR}/scripts/model-routing.sh"
snapshot_tree() {
  (cd "$1" && find . -type f | LC_ALL=C sort | while IFS= read -r f; do printf '%s %s\n' "$f" "$(cksum < "$f")"; done)
}
before="$(snapshot_tree "${MISMATCH_DIR}")"
HOME="${TMP_HOME_MISMATCH}" CLAUDE_PLUGIN_ROOT="${ROOT_DIR}" bash "${SYNC_SCRIPT}" >/dev/null 2>&1
after="$(snapshot_tree "${MISMATCH_DIR}")"
if [[ "${before}" != "${after}" ]]; then
  echo "sync-plugin-cache modified a marketplace clone that is on another release (0.0.0-other vs ${SOURCE_VERSION})"
  diff <(printf '%s\n' "${before}") <(printf '%s\n' "${after}") || true
  exit 1
fi

# A same-version marketplace clone with the old ID must not receive new hooks.
printf '%s\n' "${SOURCE_VERSION}" > "${MISMATCH_DIR}/VERSION"
printf '{"name":"claude-code-harness","version":"%s"}\n' "${SOURCE_VERSION}" > "${MISMATCH_DIR}/.claude-plugin/plugin.json"
LEGACY_CACHE="${TMP_HOME_MISMATCH}/.claude/plugins/cache/claude-code-harness-marketplace/claude-code-harness/${SOURCE_VERSION}"
mkdir -p "${LEGACY_CACHE}"
printf 'legacy-owned\n' > "${LEGACY_CACHE}/marker"
before="$(snapshot_tree "${TMP_HOME_MISMATCH}")"
HOME="${TMP_HOME_MISMATCH}" CLAUDE_PLUGIN_ROOT="${ROOT_DIR}" bash "${SYNC_SCRIPT}" >/dev/null 2>&1
after="$(snapshot_tree "${TMP_HOME_MISMATCH}")"
if [[ "${before}" != "${after}" ]]; then
  echo "sync-plugin-cache changed an old-ID marketplace or legacy cache on the same version"
  exit 1
fi

echo "OK"
