#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SKILL_FILES=(
  "${ROOT_DIR}/skills/harness-work/SKILL.md"
  "${ROOT_DIR}/skills-codex/harness-work/SKILL.md"
  "${ROOT_DIR}/skills/harness-review/SKILL.md"
  "${ROOT_DIR}/skills/breezing/SKILL.md"
  "${ROOT_DIR}/skills-codex/breezing/SKILL.md"
)

LSP_WORKFLOW_LITERALS=(
  "If you grep the same symbol twice in the same session, switch to harness_ast_search."
  "For a bugfix where homologous implementations appear across multiple modules, run harness_ast_search to find all implementations before editing."
  "Only when changed files include .ts or .tsx, the DoD requires zero new harness_lsp_diagnostics errors; if the harness MCP is not connected or the changed file types are not eligible, treat diagnostics as not-configured and non-blocking."
)

for skill_file in "${SKILL_FILES[@]}"; do
  for literal in "${LSP_WORKFLOW_LITERALS[@]}"; do
    grep -q "${literal}" "${skill_file}" || {
      echo "${skill_file} is missing LSP workflow literal: ${literal}"
      exit 1
    }
  done
done
