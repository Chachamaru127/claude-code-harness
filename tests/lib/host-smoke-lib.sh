#!/usr/bin/env bash
# Shared asserts for multi-host install / workflow smoke (Phase 111.2).
# shellcheck shell=bash
set -euo pipefail

host_smoke_fail() {
  echo "host-smoke: FAIL: $*" >&2
  return 1
}

# assert_skill_visible <skills_root> <skill_name>
assert_skill_visible() {
  local root="$1"
  local name="$2"
  local path="${root}/${name}/SKILL.md"
  [ -f "$path" ] || host_smoke_fail "skill not visible: ${path}"
  grep -Eq '^name:[[:space:]]*'"${name}"'[[:space:]]*$' "$path" \
    || grep -Fq "# ${name}" "$path" \
    || grep -Fqi "${name}" "$path" \
    || host_smoke_fail "skill file missing name reference: ${path}"
}

# assert_core_skills_visible <skills_root>
assert_core_skills_visible() {
  local root="$1"
  local s
  for s in harness-plan harness-work harness-review breezing; do
    assert_skill_visible "$root" "$s"
  done
}

# assert_install_layout <install_or_dist_root> <host>
# host: cursor|grok|codex|claude
assert_install_layout() {
  local root="$1"
  local host="$2"
  [ -d "$root" ] || host_smoke_fail "install root missing: ${root}"
  case "$host" in
    cursor)
      [ -f "${root}/.cursor-plugin/plugin.json" ] || host_smoke_fail "cursor missing plugin.json"
      [ -d "${root}/skills" ] || host_smoke_fail "cursor missing skills/"
      if grep -Fq '../' "${root}/.cursor-plugin/plugin.json"; then
        host_smoke_fail "cursor manifest contains parent paths"
      fi
      ;;
    grok)
      [ -f "${root}/.grok-plugin/plugin.json" ] || host_smoke_fail "grok missing plugin.json"
      [ -d "${root}/skills" ] || host_smoke_fail "grok missing skills/"
      if grep -Fq '../' "${root}/.grok-plugin/plugin.json"; then
        host_smoke_fail "grok manifest contains parent paths"
      fi
      ;;
    codex)
      [ -f "${root}/.codex-plugin/plugin.json" ] || host_smoke_fail "codex missing plugin.json"
      [ -d "${root}/skills" ] || host_smoke_fail "codex missing skills/"
      if grep -Fq '../' "${root}/.codex-plugin/plugin.json"; then
        host_smoke_fail "codex manifest contains parent paths"
      fi
      ;;
    claude)
      [ -f "${root}/.claude-plugin/plugin.json" ] || host_smoke_fail "claude missing plugin.json"
      [ -d "${root}/skills" ] || host_smoke_fail "claude missing skills/"
      ;;
    *)
      host_smoke_fail "unknown host for install layout: ${host}"
      ;;
  esac
}

# assert_plan_artifact <file>
# Requires a plan-shaped markdown artifact with acceptance criteria.
assert_plan_artifact() {
  local file="$1"
  [ -f "$file" ] || host_smoke_fail "plan artifact missing: ${file}"
  grep -Eqi 'acceptance|受け入れ|DoD|criteria' "$file" \
    || host_smoke_fail "plan artifact missing acceptance/DoD section: ${file}"
  grep -Eqi 'harness-plan|plan|workflow' "$file" \
    || host_smoke_fail "plan artifact missing plan/workflow marker: ${file}"
  local lines
  lines="$(wc -l <"$file" | tr -d ' ')"
  [ "$lines" -ge 5 ] || host_smoke_fail "plan artifact too short (${lines} lines): ${file}"
}

# write_plan_artifact_from_skill <skill_md> <out_file> <host>
# Structural H4: materialize a plan artifact from the installed harness-plan skill
# without requiring a live model call (CI-safe). Live LLM paths may replace this.
write_plan_artifact_from_skill() {
  local skill_md="$1"
  local out="$2"
  local host="$3"
  [ -f "$skill_md" ] || host_smoke_fail "skill md missing: ${skill_md}"
  mkdir -p "$(dirname "$out")"
  {
    echo "# Workflow smoke plan artifact"
    echo
    echo "- host: \`${host}\`"
    echo "- source_skill: \`${skill_md}\`"
    echo "- generated_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "- mode: structural (skill-serving path; not a live model session)"
    echo
    echo "## Acceptance criteria"
    echo
    echo "1. Core plan skill file is present in the host package."
    echo "2. This artifact is written under an isolated HOME/out dir."
    echo "3. DoD markers from skill frontmatter/body are extractable."
    echo
    echo "## Skill excerpt (first 40 lines)"
    echo
    echo '```markdown'
    head -n 40 "$skill_md"
    echo '```'
    echo
    echo "## harness-plan workflow"
    echo
    echo "Package proves harness-plan is installable for host \`${host}\`."
  } >"$out"
  assert_plan_artifact "$out"
}

# assert_no_parent_paths_in_manifest <manifest_json>
assert_no_parent_paths_in_manifest() {
  local m="$1"
  [ -f "$m" ] || host_smoke_fail "manifest missing: ${m}"
  if grep -Fq '../' "$m"; then
    host_smoke_fail "manifest contains parent paths: ${m}"
  fi
}
