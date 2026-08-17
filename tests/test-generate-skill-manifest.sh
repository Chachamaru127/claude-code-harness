#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

OUTPUT_JSON="${TMP_DIR}/skill-manifest.json"
(cd "$PROJECT_ROOT" && "${PROJECT_ROOT}/scripts/generate-skill-manifest.sh" --output "${OUTPUT_JSON}" >/dev/null)

jq -e '
  .schema_version == "skill-manifest.v1" and
  .skill_count > 5 and
  ((.skills | map(.path) | sort) == (.skills | map(.path))) and
  any(.skills[]; .name == "harness-plan" and .path == "skills/harness-plan/SKILL.md") and
  any(.skills[]; .name == "breezing" and (.path | test("skills-codex/breezing/SKILL.md")))
' "${OUTPUT_JSON}" >/dev/null

jq -e '
  any(.skills[]; .name == "harness-plan" and (.allowed_tools | index("Read")) != null and (.allowed_tools | index("Task")) != null and .effort == "medium" and .surface == "skills" and (.related_surfaces | index("codex/.codex/skills")) != null and (.do_not_use_for | index("implementation")) != null and (.do_not_use_for | index("release")) != null)
' "${OUTPUT_JSON}" >/dev/null

jq -e '
  any(.skills[];
    .path == "skills/harness-work/SKILL.md" and
    .kind == "workflow" and
    .purpose == "Execute Plans.md tasks end to end" and
    (.trigger | contains("implement")) and
    .shape == "workflow" and
    .role == "executor" and
    .pair == "harness-review" and
    .owner == "harness-core" and
    .since == "2026-05-05" and
    .base == null and
    .deprecated_in == null and
    .replaces == null
  ) and
  any(.skills[];
    .path == "skills/breezing/SKILL.md" and
    .shape == "wrap" and
    .role == "orchestrator" and
    .base == "harness-work" and
    .pair == "harness-review"
  ) and
  any(.skills[];
    .path == "skills/agent-browser/SKILL.md" and
    .kind == null and
    .purpose == null and
    .shape == null and
    .role == null
  )
' "${OUTPUT_JSON}" >/dev/null

jq -e '
  any(.skills[]; .path == "skills/agent-browser/SKILL.md" and .disable_model_invocation == true) and
  any(.skills[]; .path == "skills/cc-update-review/SKILL.md" and .user_invocable == false and .disable_model_invocation == true) and
  any(.skills[]; .path == "skills/ci/SKILL.md" and .user_invocable == true and .disable_model_invocation == null)
' "${OUTPUT_JSON}" >/dev/null

EXPECTED_MODEL_INVOKABLE='[
  "breezing",
  "ci",
  "cursor-ask",
  "cursor-do",
  "cursor-review",
  "cursor-setup",
  "failure-codifier",
  "harness-accept",
  "harness-loop",
  "harness-plan-brief",
  "harness-plan",
  "harness-progress",
  "harness-release",
  "harness-review",
  "harness-setup",
  "harness-sync",
  "harness-work",
  "japanese-writing-drafter",
  "maintenance",
  "memory"
]'

jq -e --argjson expected "${EXPECTED_MODEL_INVOKABLE}" '
  ([.skills[] | select(.surface == "skills" and .disable_model_invocation != true) | .name] == $expected)
' "${OUTPUT_JSON}" >/dev/null

VALID_TOOLS='[
  "Read", "Write", "Edit", "Glob", "Grep", "Bash",
  "Task", "WebFetch", "WebSearch", "TodoWrite",
  "AskUserQuestion", "Skill", "EnterPlanMode", "ExitPlanMode",
  "NotebookEdit", "LSP", "MCPSearch", "Append",
  "Monitor", "ScheduleWakeup", "Agent",
  "spawn_agent", "send_input", "wait_agent", "close_agent"
]'

jq -e --argjson valid "${VALID_TOOLS}" '
  [
    .skills[] as $skill
    | ($skill.allowed_tools[]? // empty) as $tool
    | select(($tool | contains("*") | not) and ($tool | startswith("mcp__") | not) and (($valid | index($tool)) == null))
    | "\($skill.path):\($tool)"
  ] as $invalid
  | if ($invalid | length) == 0 then true else error($invalid | join("\n")) end
' "${OUTPUT_JSON}" >/dev/null

echo "test-generate-skill-manifest: ok"
