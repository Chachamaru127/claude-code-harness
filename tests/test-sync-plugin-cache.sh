#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_HOME="$(mktemp -d)"
PRIVATE_SYNC_TEST_DIR="${ROOT_DIR}/skills/test-private-sync"
trap 'rm -rf "${TMP_HOME}" "${PRIVATE_SYNC_TEST_DIR}"' EXIT

# This directory is intentionally ignored by .gitignore (skills/test-*). It
# simulates local-only development skills that must not be copied into the
# installed plugin cache just because plugin.json declares ./skills/.
mkdir -p "${PRIVATE_SYNC_TEST_DIR}"
printf '%s\n' '---' 'name: test-private-sync' 'description: local-only sync test' '---' > "${PRIVATE_SYNC_TEST_DIR}/SKILL.md"

SOURCE_VERSION="$(tr -d '[:space:]' < "${ROOT_DIR}/VERSION")"
CACHE_DIR="${TMP_HOME}/.claude/plugins/cache/company-ai-harness-marketplace/company-ai-harness/${SOURCE_VERSION}"
MARKETPLACE_DIR="${TMP_HOME}/.claude/plugins/marketplaces/company-ai-harness-marketplace"
mkdir -p "${CACHE_DIR}" "${MARKETPLACE_DIR}/.claude-plugin"
mkdir -p \
  "${CACHE_DIR}/codex/.codex/skills/x-article" \
  "${CACHE_DIR}/skills/harness-release-internal" \
  "${CACHE_DIR}/docs/private" \
  "${MARKETPLACE_DIR}/codex/.codex/skills/x-article" \
  "${MARKETPLACE_DIR}/skills/harness-release-internal" \
  "${MARKETPLACE_DIR}/docs/private"

# 古い/欠落したキャッシュと marketplace copy を用意して、CLAUDE_PLUGIN_ROOT を
# plugin root として渡したときに正しく同期元解決できることを確認する。
printf 'stale\n' > "${CACHE_DIR}/VERSION"
printf 'stale\n' > "${MARKETPLACE_DIR}/VERSION"
printf 'stale\n' > "${CACHE_DIR}/codex/.codex/skills/x-article/SKILL.md"
printf 'stale\n' > "${CACHE_DIR}/skills/harness-release-internal/SKILL.md"
printf 'stale\n' > "${CACHE_DIR}/docs/private/stale-note.md"
printf 'stale\n' > "${MARKETPLACE_DIR}/codex/.codex/skills/x-article/SKILL.md"
printf 'stale\n' > "${MARKETPLACE_DIR}/skills/harness-release-internal/SKILL.md"
printf 'stale\n' > "${MARKETPLACE_DIR}/docs/private/stale-note.md"
printf '{"hooks":{"SessionStart":[{"hooks":[{"command":"\"${CLAUDE_PLUGIN_ROOT}/bin/harness\" hook session-start"}]}]}}' > "${MARKETPLACE_DIR}/.claude-plugin/hooks.json"

HOME="${TMP_HOME}" CLAUDE_PLUGIN_ROOT="${ROOT_DIR}" bash "${ROOT_DIR}/scripts/sync-plugin-cache.sh" >/dev/null 2>&1

# 間違った CLAUDE_PLUGIN_ROOT が来ても、script path から実際の plugin root へ
# 戻れることを確認する。hook 実行環境の変数揺れに対する回帰テスト。
INVALID_ROOT="${TMP_HOME}/not-a-plugin-root"
mkdir -p "${INVALID_ROOT}"
HOME="${TMP_HOME}" CLAUDE_PLUGIN_ROOT="${INVALID_ROOT}" bash "${ROOT_DIR}/scripts/sync-plugin-cache.sh" >/dev/null 2>&1

required_cached_files=(
  "${CACHE_DIR}/scripts/lib/harness-mem-bridge.sh"
  "${CACHE_DIR}/scripts/hook-handlers/memory-bridge.sh"
  "${CACHE_DIR}/scripts/hook-handlers/memory-session-start.sh"
  "${CACHE_DIR}/scripts/hook-handlers/memory-user-prompt.sh"
  "${CACHE_DIR}/scripts/hook-handlers/memory-post-tool-use.sh"
  "${CACHE_DIR}/scripts/hook-handlers/memory-stop.sh"
  "${CACHE_DIR}/scripts/hook-handlers/runtime-reactive.sh"
  "${CACHE_DIR}/hooks/hooks.json"
  "${CACHE_DIR}/.claude-plugin/hooks.json"
  "${CACHE_DIR}/.claude-plugin/settings.json"
  "${MARKETPLACE_DIR}/scripts/lib/harness-mem-bridge.sh"
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

for private_path in \
  "${CACHE_DIR}/skills/test-private-sync" \
  "${CACHE_DIR}/skills/harness-release-internal" \
  "${CACHE_DIR}/codex/.codex/skills/x-article" \
  "${CACHE_DIR}/docs/private" \
  "${MARKETPLACE_DIR}/skills/test-private-sync" \
  "${MARKETPLACE_DIR}/skills/harness-release-internal" \
  "${MARKETPLACE_DIR}/codex/.codex/skills/x-article" \
  "${MARKETPLACE_DIR}/docs/private"; do
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

echo "OK"
