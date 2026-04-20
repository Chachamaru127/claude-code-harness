#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SETTINGS_FILE="${ROOT_DIR}/.claude-plugin/settings.json"
HOOK_FILES=(
  "${ROOT_DIR}/hooks/hooks.json"
  "${ROOT_DIR}/.claude-plugin/hooks.json"
)
TEMPLATE_FILES=(
  "${ROOT_DIR}/templates/rules/coding-standards.md.template"
  "${ROOT_DIR}/templates/rules/testing.md.template"
  "${ROOT_DIR}/templates/rules/plans-management.md.template"
)
SKILL_FILES=(
  "${ROOT_DIR}/skills/harness-work/SKILL.md"
  "${ROOT_DIR}/skills/harness-review/SKILL.md"
  "${ROOT_DIR}/skills/harness-plan/SKILL.md"
)
AGENT_FILES=(
  "${ROOT_DIR}/agents/worker.md"
  "${ROOT_DIR}/agents/reviewer.md"
  "${ROOT_DIR}/agents/scaffolder.md"
)

jq -e '.env.CLAUDE_CODE_SUBPROCESS_ENV_SCRUB == "1"' "${SETTINGS_FILE}" >/dev/null || {
  echo "settings.json is missing CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1"
  exit 1
}

jq -e '.sandbox.failIfUnavailable == true' "${SETTINGS_FILE}" >/dev/null || {
  echo "settings.json is missing sandbox.failIfUnavailable=true"
  exit 1
}

jq -e '.sandbox.network.deniedDomains | type == "array" and (index("169.254.169.254") != null)' "${SETTINGS_FILE}" >/dev/null || {
  echo "settings.json is missing sandbox.network.deniedDomains metadata protection"
  exit 1
}

for hooks_file in "${HOOK_FILES[@]}"; do
  for event in TaskCreated CwdChanged FileChanged; do
    jq -e ".hooks.${event}[]?.hooks[]? | select(.command | contains(\"runtime-reactive\"))" "${hooks_file}" >/dev/null || {
      echo "${hooks_file} is missing ${event} -> runtime-reactive wiring"
      exit 1
    }
  done
done

for hooks_file in "${HOOK_FILES[@]}"; do
  jq -e '.hooks.PreToolUse[]? | select(.matcher == "AskUserQuestion") | .hooks[]? | select(.command | contains("ask-user-question-normalize"))' "${hooks_file}" >/dev/null || {
    echo "${hooks_file} is missing PreToolUse AskUserQuestion -> ask-user-question-normalize wiring"
    exit 1
  }

  jq -e '.hooks.PermissionRequest[]? | select(.matcher == "Edit|Write|MultiEdit")' "${hooks_file}" >/dev/null || {
    echo "${hooks_file} is missing PermissionRequest matcher for Edit|Write|MultiEdit"
    exit 1
  }

  jq -e '.hooks.PermissionRequest[]? | select(.matcher == "Bash" and (.if // "" | contains("Bash(git status*)")) and (.if // "" | contains("Bash(pytest*)")))' "${hooks_file}" >/dev/null || {
    echo "${hooks_file} is missing PermissionRequest Bash conditional if guard"
    exit 1
  }
done

for template_file in "${TEMPLATE_FILES[@]}"; do
  grep -q '^paths:$' "${template_file}" || {
    echo "${template_file} is missing YAML list paths header"
    exit 1
  }
  grep -q '^  - "' "${template_file}" || {
    echo "${template_file} does not use YAML list paths entries"
    exit 1
  }
done

for skill_file in "${SKILL_FILES[@]}"; do
  grep -q '^effort:' "${skill_file}" || {
    echo "${skill_file} is missing effort frontmatter"
    exit 1
  }
done

for agent_file in "${AGENT_FILES[@]}"; do
  grep -q '^initialPrompt:' "${agent_file}" || {
    echo "${agent_file} is missing initialPrompt frontmatter"
    exit 1
  }
done

# v2.1.89: PermissionDenied hook wiring check
for hooks_file in "${HOOK_FILES[@]}"; do
  jq -e '.hooks.PermissionDenied[]?.hooks[]? | select(.command | contains("permission-denied"))' "${hooks_file}" >/dev/null || {
    echo "${hooks_file} is missing PermissionDenied -> permission-denied wiring"
    exit 1
  }
done

# v2.1.89: PermissionDenied handler script exists and is executable
PERM_DENIED_HANDLER="${ROOT_DIR}/scripts/hook-handlers/permission-denied-handler.sh"
[ -f "${PERM_DENIED_HANDLER}" ] || {
  echo "permission-denied-handler.sh does not exist"
  exit 1
}
[ -x "${PERM_DENIED_HANDLER}" ] || {
  echo "permission-denied-handler.sh is not executable"
  exit 1
}

# v2.1.89+: AskUserQuestion updatedInput answer bridge exists in Go fast path
ASK_NORMALIZER_GO="${ROOT_DIR}/go/internal/hookhandler/ask_user_question_normalizer.go"
[ -f "${ASK_NORMALIZER_GO}" ] || {
  echo "ask_user_question_normalizer.go does not exist"
  exit 1
}
grep -q 'HARNESS_ASK_USER_QUESTION_ANSWERS' "${ASK_NORMALIZER_GO}" || {
  echo "ask_user_question_normalizer.go is missing explicit answer source support"
  exit 1
}
grep -q 'updatedInput' "${ASK_NORMALIZER_GO}" || {
  echo "ask_user_question_normalizer.go is missing updatedInput output"
  exit 1
}

# v2.1.113: Bash hardening parity checks for find deletion and macOS dangerous removal paths
GUARDRAIL_HELPERS_GO="${ROOT_DIR}/go/internal/guardrail/helpers.go"
GUARDRAIL_RULES_TEST_GO="${ROOT_DIR}/go/internal/guardrail/rules_test.go"
grep -q 'hasDangerousFindDelete' "${GUARDRAIL_HELPERS_GO}" || {
  echo "guardrail helpers are missing find -delete / -exec rm detection"
  exit 1
}
grep -q 'hasDangerousMacOSRemovalPath' "${GUARDRAIL_HELPERS_GO}" || {
  echo "guardrail helpers are missing macOS dangerous removal path detection"
  exit 1
}
grep -q 'TestR05_FindDelete' "${GUARDRAIL_RULES_TEST_GO}" || {
  echo "guardrail tests are missing find -delete coverage"
  exit 1
}
grep -q 'TestR05_MacOSPrivatePath' "${GUARDRAIL_RULES_TEST_GO}" || {
  echo "guardrail tests are missing macOS dangerous path coverage"
  exit 1
}

# v2.1.113: template parity for deniedDomains (consumer init must inherit metadata protection)
SECURITY_TEMPLATE="${ROOT_DIR}/templates/claude/settings.security.json.template"
[ -f "${SECURITY_TEMPLATE}" ] || {
  echo "settings.security.json.template does not exist"
  exit 1
}
jq -e '.sandbox.network.deniedDomains | type == "array" and (index("169.254.169.254") != null)' "${SECURITY_TEMPLATE}" >/dev/null || {
  echo "${SECURITY_TEMPLATE} is missing deniedDomains parity with .claude-plugin/settings.json"
  exit 1
}

# v2.1.113: end-to-end exercise of ask-user-question-normalize hook (binary contract smoke)
HARNESS_BIN="${ROOT_DIR}/bin/harness"
if [ -x "${HARNESS_BIN}" ]; then
  ASK_HOOK_INPUT='{"tool_name":"AskUserQuestion","tool_input":{"questions":[{"question":"Execution mode?","header":"Mode","options":[{"label":"solo"},{"label":"team"}],"multiSelect":false}],"answers":{"Execution mode?":"solo"}}}'
  ASK_HOOK_OUTPUT="$(printf '%s' "${ASK_HOOK_INPUT}" | "${HARNESS_BIN}" hook ask-user-question-normalize 2>/dev/null || true)"
  if [ -z "${ASK_HOOK_OUTPUT}" ]; then
    echo "ask-user-question-normalize hook produced no output for a valid single-select answer"
    exit 1
  fi
  printf '%s' "${ASK_HOOK_OUTPUT}" | jq -e '.hookSpecificOutput.permissionDecision == "allow" and .hookSpecificOutput.hookEventName == "PreToolUse"' >/dev/null || {
    echo "ask-user-question-normalize hook output missing expected permissionDecision/hookEventName"
    echo "output: ${ASK_HOOK_OUTPUT}"
    exit 1
  }
  printf '%s' "${ASK_HOOK_OUTPUT}" | jq -e '.hookSpecificOutput.updatedInput.answers["Execution mode?"] == "solo"' >/dev/null || {
    echo "ask-user-question-normalize hook did not echo answers in updatedInput"
    echo "output: ${ASK_HOOK_OUTPUT}"
    exit 1
  }
else
  echo "skip: bin/harness is not executable, skipping end-to-end ask-user-question-normalize exercise"
fi

echo "OK"
