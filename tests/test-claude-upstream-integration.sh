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
UPSTREAM_SKILL_NAMES=(
  "cc-update-review"
  "claude-codex-upstream-update"
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

# Phase 52: snapshot doc referenced from CHANGELOG / Feature Table / Plans must exist
UPSTREAM_SNAPSHOT_DOC="${ROOT_DIR}/docs/upstream-update-snapshot-2026-04-21.md"
[ -f "${UPSTREAM_SNAPSHOT_DOC}" ] || {
  echo "${UPSTREAM_SNAPSHOT_DOC} does not exist (referenced from CHANGELOG, Feature Table, and Plans)"
  exit 1
}
for referencing_file in \
  "${ROOT_DIR}/CHANGELOG.md" \
  "${ROOT_DIR}/docs/CLAUDE-feature-table.md" \
  "${ROOT_DIR}/Plans.md"; do
  grep -q 'upstream-update-snapshot-2026-04-21' "${referencing_file}" || {
    echo "${referencing_file} is missing the expected upstream-update-snapshot-2026-04-21 reference"
    exit 1
  }
done

# Phase 52: upstream update skill review contract and mirror drift checks
for skill_name in "${UPSTREAM_SKILL_NAMES[@]}"; do
  CANONICAL_SKILL="${ROOT_DIR}/skills/${skill_name}/SKILL.md"
  CODEX_SKILL="${ROOT_DIR}/codex/.codex/skills/${skill_name}/SKILL.md"
  LOCAL_AGENT_SKILL="${ROOT_DIR}/.agents/skills/${skill_name}/SKILL.md"

  [ -f "${CANONICAL_SKILL}" ] || {
    echo "${CANONICAL_SKILL} does not exist"
    exit 1
  }
  [ -f "${CODEX_SKILL}" ] || {
    echo "${CODEX_SKILL} does not exist"
    exit 1
  }
  cmp -s "${CANONICAL_SKILL}" "${CODEX_SKILL}" || {
    echo "${skill_name} skill mirror drift: skills/ and codex/.codex/ differ"
    exit 1
  }
  if [ -f "${LOCAL_AGENT_SKILL}" ]; then
    cmp -s "${CANONICAL_SKILL}" "${LOCAL_AGENT_SKILL}" || {
      echo "${skill_name} skill mirror drift: skills/ and .agents/ differ"
      exit 1
    }
  fi
done

CC_UPDATE_REVIEW="${ROOT_DIR}/skills/cc-update-review/SKILL.md"
grep -q 'allowed-tools: \["Read", "Grep", "Glob", "Bash"\]' "${CC_UPDATE_REVIEW}" || {
  echo "cc-update-review must allow read-only Bash for git diff inspection"
  exit 1
}
grep -q 'git diff -- docs/CLAUDE-feature-table.md' "${CC_UPDATE_REVIEW}" || {
  echo "cc-update-review is missing explicit Feature Table diff inspection guidance"
  exit 1
}
grep -q '## A/B/C/P 分類' "${CC_UPDATE_REVIEW}" || {
  echo "cc-update-review must name the actual A/B/C/P classification model"
  exit 1
}

UPSTREAM_UPDATE_SKILL="${ROOT_DIR}/skills/claude-codex-upstream-update/SKILL.md"
grep -q 'no-op adaptation' "${UPSTREAM_UPDATE_SKILL}" || {
  echo "claude-codex-upstream-update must allow documented no-op adaptation cycles"
  exit 1
}
grep -q 'Codex `0.122.0` 以降で確認する項目' "${UPSTREAM_UPDATE_SKILL}" || {
  echo "claude-codex-upstream-update is missing Codex 0.122.0+ watchlist"
  exit 1
}
grep -q 'Claude Code `2.1.116` 以降の UX / 運用改善' "${UPSTREAM_UPDATE_SKILL}" || {
  echo "claude-codex-upstream-update is missing Claude Code 2.1.116+ watchlist"
  exit 1
}

# Phase 53: snapshot doc and MCP hook safety decision
PHASE53_SNAPSHOT_DOC="${ROOT_DIR}/docs/upstream-update-snapshot-2026-04-23.md"
[ -f "${PHASE53_SNAPSHOT_DOC}" ] || {
  echo "${PHASE53_SNAPSHOT_DOC} does not exist"
  exit 1
}
for referencing_file in \
  "${ROOT_DIR}/CHANGELOG.md" \
  "${ROOT_DIR}/docs/CLAUDE-feature-table.md" \
  "${ROOT_DIR}/Plans.md"; do
  grep -q 'upstream-update-snapshot-2026-04-23' "${referencing_file}" || {
    echo "${referencing_file} is missing the expected upstream-update-snapshot-2026-04-23 reference"
    exit 1
  }
done
grep -q '53.1.2 MCP tool hook decision' "${PHASE53_SNAPSHOT_DOC}" || {
  echo "Phase 53 snapshot is missing the 53.1.2 MCP tool hook decision"
  exit 1
}
grep -q 'hooks/hooks.json` / `.claude-plugin/hooks.json` は今回は no-op' "${PHASE53_SNAPSHOT_DOC}" || {
  echo "Phase 53 snapshot must record that hook manifests are no-op for 53.1.2"
  exit 1
}
grep -q '読み取り専用の MCP health / resource list 診断' "${PHASE53_SNAPSHOT_DOC}" || {
  echo "Phase 53 snapshot must document the intended read-only MCP diagnostic use case"
  exit 1
}
grep -q '書き込み系 MCP tool は hook から呼ばない' "${PHASE53_SNAPSHOT_DOC}" || {
  echo "Phase 53 snapshot must forbid write-capable MCP tools from hooks"
  exit 1
}

# Phase 53.1.3: claude plugin tag must be visible in release preflight / dry-run guidance
HARNESS_RELEASE_SKILL="${ROOT_DIR}/skills/harness-release/SKILL.md"
grep -q 'claude plugin tag .claude-plugin --dry-run' "${HARNESS_RELEASE_SKILL}" || {
  echo "harness-release is missing claude plugin tag dry-run guidance"
  exit 1
}
grep -q 'claude plugin tag .claude-plugin --push --remote origin' "${HARNESS_RELEASE_SKILL}" || {
  echo "harness-release is missing claude plugin tag push guidance"
  exit 1
}
grep -q 'VERSION と .claude-plugin/plugin.json が不一致なら tag に進まない' "${HARNESS_RELEASE_SKILL}" || {
  echo "harness-release must stop before tagging when VERSION and plugin.json disagree"
  exit 1
}
grep -q '53.1.3 plugin tag release flow decision' "${PHASE53_SNAPSHOT_DOC}" || {
  echo "Phase 53 snapshot is missing the 53.1.3 plugin tag release flow decision"
  exit 1
}
grep -q 'claude plugin tag .claude-plugin --dry-run' "${PHASE53_SNAPSHOT_DOC}" || {
  echo "Phase 53 snapshot must record the claude plugin tag dry-run command"
  exit 1
}

# Phase 53.1.4: Auto Mode policy must extend built-in defaults instead of replacing them
grep -Fq '53.1.4 Auto Mode "$defaults" permission and sandbox policy' "${PHASE53_SNAPSHOT_DOC}" || {
  echo "Phase 53 snapshot is missing the 53.1.4 Auto Mode defaults policy"
  exit 1
}
grep -Fq 'Auto Mode built-in defaults stay in place through "$defaults"' "${PHASE53_SNAPSHOT_DOC}" || {
  echo 'Phase 53 snapshot must say Auto Mode built-in defaults are extended with $defaults'
  exit 1
}
grep -Fq 'R05 guardrail and sandbox.network.deniedDomains are not duplicated by Auto Mode' "${PHASE53_SNAPSHOT_DOC}" || {
  echo "Phase 53 snapshot must explain why R05 / deniedDomains remain separate guardrails"
  exit 1
}
jq -e '._harness_auto_mode_note | contains("Auto Mode guidance: keep \"$defaults\" and append only project-specific entries")' "${SECURITY_TEMPLATE}" >/dev/null || {
  echo 'settings.security.json.template must document additive Auto Mode $defaults guidance'
  exit 1
}
if jq -e 'has("autoMode")' "${SETTINGS_FILE}" >/dev/null; then
  jq -e '
    .autoMode
    | [
        to_entries[]
        | select(.key == "allow" or .key == "soft_deny" or .key == "environment")
        | (.value | type == "array" and index("$defaults") != null)
      ]
    | all
  ' "${SETTINGS_FILE}" >/dev/null || {
    echo 'settings.json autoMode allow/soft_deny/environment entries must include $defaults when present'
    exit 1
  }
fi
jq -e '
  (.permissions.deny | index("Bash(sudo:*)") != null and index("Bash(rm -rf:*)") != null and index("Bash(rm -fr:*)") != null)
  and
  (.permissions.ask | index("Bash(git reset --hard:*)") != null and index("Bash(git push --force:*)") != null)
  and
  (.sandbox.network.deniedDomains | index("169.254.169.254") != null and index("metadata.google.internal") != null and index("metadata.azure.com") != null)
' "${SETTINGS_FILE}" >/dev/null || {
  echo "settings.json must preserve existing deny, ask, and deniedDomains guardrails"
  exit 1
}

# Phase 53.1.5: plugin / managed settings policy docs must stay explicit
PLUGIN_POLICY_DOC="${ROOT_DIR}/docs/plugin-managed-settings-policy.md"
[ -f "${PLUGIN_POLICY_DOC}" ] || {
  echo "${PLUGIN_POLICY_DOC} does not exist"
  exit 1
}
grep -q 'DISABLE_UPDATES は手動 `claude update` まで止める' "${PLUGIN_POLICY_DOC}" || {
  echo "plugin policy doc must explain DISABLE_UPDATES vs DISABLE_AUTOUPDATER"
  exit 1
}
grep -q '通常ユーザー向け default には入れない' "${PLUGIN_POLICY_DOC}" || {
  echo "plugin policy doc must not over-apply managed marketplace restrictions to normal defaults"
  exit 1
}
grep -q 'Harness 独自の dependency resolver は追加しない' "${PLUGIN_POLICY_DOC}" || {
  echo "plugin policy doc must leave dependency resolution to Claude Code"
  exit 1
}
grep -q 'plugin `themes/` directory は今回は P' "${PLUGIN_POLICY_DOC}" || {
  echo "plugin policy doc must record the themes decision"
  exit 1
}
grep -q 'plugin-managed-settings-policy.md' "${ROOT_DIR}/skills/harness-setup/SKILL.md" || {
  echo "harness-setup must link to plugin managed settings policy"
  exit 1
}
grep -q '53.1.5 plugin / managed settings policy' "${PHASE53_SNAPSHOT_DOC}" || {
  echo "Phase 53 snapshot is missing the 53.1.5 plugin managed settings policy"
  exit 1
}
grep -q 'Plugin themes / managed settings / dependency auto-resolve.*A: docs 化済み' "${ROOT_DIR}/docs/CLAUDE-feature-table.md" || {
  echo "Feature Table must mark 53.1.5 plugin policy docs as done"
  exit 1
}

# Phase 53.1.6: Claude Code UX updates must stay documented as automatic inheritance / follow-up only
grep -q '53.1.6 Claude Code UX automatic inheritance policy' "${PHASE53_SNAPSHOT_DOC}" || {
  echo "Phase 53 snapshot is missing the 53.1.6 Claude Code UX automatic inheritance policy"
  exit 1
}
grep -q '`/usage` を利用量・コスト・統計の primary entrypoint として扱う' "${PHASE53_SNAPSHOT_DOC}" || {
  echo "Phase 53 snapshot must make /usage the primary usage/cost/statistics entrypoint"
  exit 1
}
grep -q '`/cost` / `/stats` は legacy typing shortcut として扱う' "${PHASE53_SNAPSHOT_DOC}" || {
  echo "Phase 53 snapshot must treat /cost and /stats as legacy shortcuts"
  exit 1
}
grep -q '`--agent` + `mcpServers` は agents audit の後続候補に残す' "${PHASE53_SNAPSHOT_DOC}" || {
  echo "Phase 53 snapshot must keep --agent + mcpServers as an agents audit follow-up"
  exit 1
}
grep -q 'CLAUDE_CODE_FORK_SUBAGENT=1` は Harness default に強制しない' "${PHASE53_SNAPSHOT_DOC}" || {
  echo "Phase 53 snapshot must not force CLAUDE_CODE_FORK_SUBAGENT by default"
  exit 1
}
grep -q 'native `bfs` / `ugrep` search は wrapper を追加しない' "${PHASE53_SNAPSHOT_DOC}" || {
  echo "Phase 53 snapshot must not add wrappers around native bfs / ugrep search"
  exit 1
}
grep -q '高 effort default は Claude Code 本体の model/account policy として自動継承する' "${PHASE53_SNAPSHOT_DOC}" || {
  echo "Phase 53 snapshot must inherit high effort defaults from Claude Code"
  exit 1
}
grep -q 'Claude Code UX / runtime fixes.*C/P: 自動継承 + Plans 化' "${ROOT_DIR}/docs/CLAUDE-feature-table.md" || {
  echo "Feature Table must mark 53.1.6 UX runtime fixes as C/P"
  exit 1
}
grep -q '`/usage` usage / cost / stats view' "${ROOT_DIR}/docs/CLAUDE-feature-table.md" || {
  echo "Feature Table must use /usage as the current usage/cost/stats view"
  exit 1
}

# Phase 53.2.1: Codex Bedrock provider and model metadata setup policy
CODEX_PROVIDER_POLICY_DOC="${ROOT_DIR}/docs/codex-provider-setup-policy.md"
[ -f "${CODEX_PROVIDER_POLICY_DOC}" ] || {
  echo "${CODEX_PROVIDER_POLICY_DOC} does not exist"
  exit 1
}
grep -q 'model_provider = "amazon-bedrock"' "${CODEX_PROVIDER_POLICY_DOC}" || {
  echo "Codex provider policy doc must show the amazon-bedrock provider id"
  exit 1
}
grep -q 'model_providers.amazon-bedrock.aws' "${CODEX_PROVIDER_POLICY_DOC}" || {
  echo "Codex provider policy doc must document the AWS profile config path"
  exit 1
}
grep -q 'Harness の配布用 `codex/.codex/config.toml` には `model = "gpt-5.4"` を default として書かない' "${CODEX_PROVIDER_POLICY_DOC}" || {
  echo "Codex provider policy doc must not pin gpt-5.4 in shipped setup defaults"
  exit 1
}
grep -q 'Claude Code 側の Bedrock guidance' "${CODEX_PROVIDER_POLICY_DOC}" || {
  echo "Codex provider policy doc must separate Claude Code Bedrock guidance from Codex provider config"
  exit 1
}
grep -q 'docs/codex-provider-setup-policy.md' "${ROOT_DIR}/skills/harness-setup/SKILL.md" || {
  echo "harness-setup must link to Codex provider setup policy"
  exit 1
}
grep -q 'amazon-bedrock' "${ROOT_DIR}/skills/harness-setup/SKILL.md" || {
  echo "harness-setup must mention the amazon-bedrock provider"
  exit 1
}
grep -q 'model_provider = "amazon-bedrock"' "${ROOT_DIR}/codex/README.md" || {
  echo "codex/README.md must show the amazon-bedrock provider setup"
  exit 1
}
grep -q 'model_provider = "amazon-bedrock"' "${ROOT_DIR}/codex/.codex/config.toml" || {
  echo "codex/.codex/config.toml must include a commented amazon-bedrock setup note"
  exit 1
}
if grep -q 'gpt-5.2-codex  # 推奨モデル' "${ROOT_DIR}/scripts/check-codex.sh"; then
  echo "check-codex.sh must not recommend the stale gpt-5.2-codex model slug"
  exit 1
fi
grep -q '53.2.1 Codex provider and model metadata setup policy' "${PHASE53_SNAPSHOT_DOC}" || {
  echo "Phase 53 snapshot is missing the 53.2.1 Codex provider/model policy"
  exit 1
}
grep -q '古い固定 model slug の点検' "${PHASE53_SNAPSHOT_DOC}" || {
  echo "Phase 53 snapshot must record the fixed model slug rg inspection"
  exit 1
}
grep -q 'Codex 0.123.0 provider / model metadata.*A: docs 化済み' "${ROOT_DIR}/docs/CLAUDE-feature-table.md" || {
  echo "Feature Table must mark 53.2.1 provider/model metadata guidance as done"
  exit 1
}

# Phase 53.2.2: Codex /mcp verbose diagnostics and plugin .mcp.json loading policy
CODEX_MCP_DIAGNOSTICS_DOC="${ROOT_DIR}/docs/codex-mcp-diagnostics.md"
[ -f "${CODEX_MCP_DIAGNOSTICS_DOC}" ] || {
  echo "${CODEX_MCP_DIAGNOSTICS_DOC} does not exist"
  exit 1
}
grep -q 'Codex MCP diagnostics / plugin loading' "${ROOT_DIR}/CHANGELOG.md" || {
  echo "CHANGELOG must mention Codex MCP diagnostics / plugin loading"
  exit 1
}
grep -q '53.2.2 Codex MCP diagnostics and plugin loading policy' "${PHASE53_SNAPSHOT_DOC}" || {
  echo "Phase 53 snapshot is missing the 53.2.2 Codex MCP diagnostics policy"
  exit 1
}
grep -q '普段の Codex TUI では `/mcp` を軽量な server 状態確認として使う' "${PHASE53_SNAPSHOT_DOC}" || {
  echo "Phase 53 snapshot must preserve the plain /mcp fast-path guidance"
  exit 1
}
grep -q '`/mcp verbose` は diagnostics、resources、resource templates を見る troubleshoot 用の入口' "${PHASE53_SNAPSHOT_DOC}" || {
  echo "Phase 53 snapshot must preserve the /mcp verbose troubleshoot guidance"
  exit 1
}
grep -q 'Claude Code 側の `claude mcp ...`、`.claude/mcp.json`、hook `type: "mcp_tool"` は別 surface' "${PHASE53_SNAPSHOT_DOC}" || {
  echo "Phase 53 snapshot must separate Codex MCP guidance from Claude Code MCP guidance"
  exit 1
}
grep -q 'Codex `0.123.0` 以降の MCP diagnostics / plugin MCP loading guidance' "${ROOT_DIR}/skills/harness-setup/SKILL.md" || {
  echo "harness-setup must link to Codex MCP diagnostics guidance"
  exit 1
}
grep -q '/mcp verbose' "${ROOT_DIR}/skills/harness-setup/SKILL.md" || {
  echo "harness-setup must mention /mcp verbose"
  exit 1
}
grep -q 'docs/codex-mcp-diagnostics.md' "${ROOT_DIR}/skills/harness-setup/SKILL.md" || {
  echo "harness-setup must point to docs/codex-mcp-diagnostics.md"
  exit 1
}
grep -q 'Codex `0.123.0` keeps the normal `/mcp` view fast' "${ROOT_DIR}/codex/README.md" || {
  echo "codex/README.md must document the fast plain /mcp behavior"
  exit 1
}
grep -q '/mcp verbose' "${ROOT_DIR}/codex/README.md" || {
  echo "codex/README.md must mention /mcp verbose"
  exit 1
}
grep -q 'diagnostics, resources, and resource templates' "${ROOT_DIR}/codex/README.md" || {
  echo "codex/README.md must mention diagnostics/resources/resource templates"
  exit 1
}
grep -q '"mcpServers"' "${ROOT_DIR}/codex/README.md" || {
  echo "codex/README.md must show the mcpServers .mcp.json shape"
  exit 1
}
grep -q 'top-level server map' "${ROOT_DIR}/codex/README.md" || {
  echo "codex/README.md must mention top-level server map .mcp.json loading"
  exit 1
}
grep -q 'This is Codex plugin loading guidance, not Claude Code `claude mcp` or `.claude/mcp.json` guidance' "${ROOT_DIR}/codex/README.md" || {
  echo "codex/README.md must keep Codex and Claude Code MCP terminology separate"
  exit 1
}
grep -q '`/mcp verbose` は、困った時だけ使う' "${CODEX_MCP_DIAGNOSTICS_DOC}" || {
  echo "Codex MCP diagnostics doc must say /mcp verbose is for troubleshooting"
  exit 1
}
grep -q 'diagnostics、resources、resource templates' "${CODEX_MCP_DIAGNOSTICS_DOC}" || {
  echo "Codex MCP diagnostics doc must mention diagnostics/resources/resource templates"
  exit 1
}
grep -q '`mcpServers` 形式' "${CODEX_MCP_DIAGNOSTICS_DOC}" || {
  echo "Codex MCP diagnostics doc must document mcpServers shape"
  exit 1
}
grep -q 'top-level server map 形式' "${CODEX_MCP_DIAGNOSTICS_DOC}" || {
  echo "Codex MCP diagnostics doc must document top-level server map shape"
  exit 1
}
grep -q 'Claude Code 側の `claude mcp`、`.claude/mcp.json`、hook `type: "mcp_tool"` の話とは混ぜない' "${CODEX_MCP_DIAGNOSTICS_DOC}" || {
  echo "Codex MCP diagnostics doc must separate Codex and Claude Code MCP guidance"
  exit 1
}
grep -q 'Codex 0.123.0 MCP diagnostics / plugin loading.*A: docs 化済み' "${ROOT_DIR}/docs/CLAUDE-feature-table.md" || {
  echo "Feature Table must mark 53.2.2 MCP diagnostics/plugin loading guidance as done"
  exit 1
}

# Phase 53.2.3: Codex realtime handoff / background agent silence policy
grep -q '53.2.3 Codex realtime handoff silence policy' "${PHASE53_SNAPSHOT_DOC}" || {
  echo "Phase 53 snapshot is missing the 53.2.3 realtime handoff silence policy"
  exit 1
}
grep -q 'transcript delta を受け取っただけで task status、review verdict、advisor decision が変わっていない場合は明示的に沈黙する' "${PHASE53_SNAPSHOT_DOC}" || {
  echo "Phase 53 snapshot must define silence for unchanged transcript deltas"
  exit 1
}
grep -q 'advisor / reviewer drift は silence 対象にしない' "${PHASE53_SNAPSHOT_DOC}" || {
  echo "Phase 53 snapshot must keep advisor / reviewer drift outside silence policy"
  exit 1
}
grep -q 'Realtime Handoff / Silence Policy' "${ROOT_DIR}/skills-codex/harness-loop/SKILL.md" || {
  echo "Codex harness-loop skill must document realtime handoff silence policy"
  exit 1
}
grep -q 'Realtime Handoff / Silence Policy' "${ROOT_DIR}/codex/.codex/skills/harness-loop/SKILL.md" || {
  echo "Codex harness-loop mirror must document realtime handoff silence policy"
  exit 1
}
grep -q 'Realtime Handoff / Silence Policy' "${ROOT_DIR}/skills-codex/breezing/SKILL.md" || {
  echo "Codex breezing skill must document realtime handoff silence policy"
  exit 1
}
grep -q 'Realtime Handoff / Silence Policy' "${ROOT_DIR}/codex/.codex/skills/breezing/SKILL.md" || {
  echo "Codex breezing mirror must document realtime handoff silence policy"
  exit 1
}
grep -q 'Silence Policy（長時間実行の通知整理）' "${ROOT_DIR}/skills/breezing/SKILL.md" || {
  echo "shared breezing skill must document long-running silence policy"
  exit 1
}
grep -q '途中報告 / Silence Policy' "${ROOT_DIR}/skills/harness-loop/SKILL.md" || {
  echo "shared harness-loop skill must document long-running silence policy"
  exit 1
}
grep -q 'advisor / reviewer drift、plateau、contract readiness failure' "${ROOT_DIR}/skills/breezing/SKILL.md" || {
  echo "shared breezing silence policy must not suppress drift / plateau / contract failures"
  exit 1
}
grep -q 'Stay silent unless there is a material state change, a block/failure, an advisor/reviewer drift risk' "${ROOT_DIR}/scripts/codex-loop.sh" || {
  echo "codex-loop prompt must tell background agents when to stay silent"
  exit 1
}
grep -q 'Codex 0.123.0 realtime handoff silence.*A: docs 化済み' "${ROOT_DIR}/docs/CLAUDE-feature-table.md" || {
  echo "Feature Table must mark 53.2.3 realtime handoff silence guidance as done"
  exit 1
}
grep -q 'Codex realtime handoff silence policy' "${ROOT_DIR}/CHANGELOG.md" || {
  echo "CHANGELOG must mention Codex realtime handoff silence policy"
  exit 1
}

# Phase 53.2.4: Codex remote_sandbox_config and exec shared flags policy
CODEX_SANDBOX_POLICY_DOC="${ROOT_DIR}/docs/codex-sandbox-execution-policy.md"
[ -f "${CODEX_SANDBOX_POLICY_DOC}" ] || {
  echo "${CODEX_SANDBOX_POLICY_DOC} does not exist"
  exit 1
}
grep -q '53.2.4 Codex sandbox / execution policy' "${PHASE53_SNAPSHOT_DOC}" || {
  echo "Phase 53 snapshot is missing the 53.2.4 sandbox / execution policy"
  exit 1
}
grep -q 'remote environment ごとの sandbox 要件比較' "${ROOT_DIR}/docs/CLAUDE-feature-table.md" || {
  echo "Feature Table must record the 53.2.4 remote sandbox comparison"
  exit 1
}
grep -q 'Codex 0.123.0 sandbox / exec changes.*A: docs 化済み' "${ROOT_DIR}/docs/CLAUDE-feature-table.md" || {
  echo "Feature Table must mark 53.2.4 sandbox / exec changes as docs done"
  exit 1
}
grep -q 'Codex sandbox / exec policy' "${ROOT_DIR}/CHANGELOG.md" || {
  echo "CHANGELOG must mention Codex sandbox / exec policy"
  exit 1
}
grep -q 'remote_sandbox_config' "${CODEX_SANDBOX_POLICY_DOC}" || {
  echo "Codex sandbox policy doc must mention remote_sandbox_config"
  exit 1
}
grep -q 'requirements.toml' "${CODEX_SANDBOX_POLICY_DOC}" || {
  echo "Codex sandbox policy doc must place remote_sandbox_config in requirements.toml"
  exit 1
}
grep -q 'hostname_patterns' "${CODEX_SANDBOX_POLICY_DOC}" || {
  echo "Codex sandbox policy doc must show hostname_patterns"
  exit 1
}
grep -q 'allowed_sandbox_modes' "${CODEX_SANDBOX_POLICY_DOC}" || {
  echo "Codex sandbox policy doc must show allowed_sandbox_modes"
  exit 1
}
grep -q 'Remote environment' "${CODEX_SANDBOX_POLICY_DOC}" || {
  echo "Codex sandbox policy doc must include the remote environment comparison table"
  exit 1
}
grep -q 'best-effort classification' "${CODEX_SANDBOX_POLICY_DOC}" || {
  echo "Codex sandbox policy doc must explain host matching is best-effort"
  exit 1
}
grep -q 'Source precedence still matters' "${CODEX_SANDBOX_POLICY_DOC}" || {
  echo "Codex sandbox policy doc must preserve requirements source precedence"
  exit 1
}
grep -q 'Do not add duplicate `--approval-policy` / `--sandbox` pairs' "${CODEX_SANDBOX_POLICY_DOC}" || {
  echo "Codex sandbox policy doc must forbid duplicate approval/sandbox flag pairs"
  exit 1
}
grep -q 'No runtime wrapper behavior changes in this task' "${CODEX_SANDBOX_POLICY_DOC}" || {
  echo "Codex sandbox policy doc must record the no-runtime-change wrapper decision"
  exit 1
}
grep -q 'automatic inheritance として残す項目' "${PHASE53_SNAPSHOT_DOC}" || {
  echo "Phase 53 snapshot must record codex exec shared flags as automatic inheritance"
  exit 1
}
grep -q '53.2.4 では runtime wrapper behavior は変更しない' "${PHASE53_SNAPSHOT_DOC}" || {
  echo "Phase 53 snapshot must record no runtime wrapper behavior change for 53.2.4"
  exit 1
}
grep -q 'Codex sandbox / execution policy (0.123.0+)' "${ROOT_DIR}/skills/harness-setup/SKILL.md" || {
  echo "harness-setup must link to Codex sandbox / execution policy"
  exit 1
}
grep -q 'docs/codex-sandbox-execution-policy.md' "${ROOT_DIR}/skills/harness-setup/SKILL.md" || {
  echo "harness-setup must point to docs/codex-sandbox-execution-policy.md"
  exit 1
}
grep -q 'Codex `0.123.0` adds host-specific `remote_sandbox_config` requirements' "${ROOT_DIR}/codex/README.md" || {
  echo "codex/README.md must document remote_sandbox_config"
  exit 1
}
grep -q 'Details: `docs/codex-sandbox-execution-policy.md`' "${ROOT_DIR}/codex/README.md" || {
  echo "codex/README.md must point to codex sandbox execution policy docs"
  exit 1
}
grep -Fq 'Codex 0.123.0+ inherits root-level shared flags for `codex exec`' "${ROOT_DIR}/scripts/codex-companion.sh" || {
  echo "codex-companion must document codex exec shared flags inheritance"
  exit 1
}
grep -Fq 'does not add duplicate --approval-policy / --sandbox pairs' "${ROOT_DIR}/scripts/codex/codex-exec-wrapper.sh" || {
  echo "codex-exec-wrapper must document no duplicate approval/sandbox flag pairs"
  exit 1
}

# Phase 53.2.5: Codex automatic bug fixes must stay C/self-inherited without Harness workarounds
grep -q '53.2.5 Codex automatic bug fix inheritance policy' "${PHASE53_SNAPSHOT_DOC}" || {
  echo "Phase 53 snapshot is missing the 53.2.5 Codex automatic bug fix inheritance policy"
  exit 1
}
grep -q 'Codex `0.123.0` の `/copy` after rollback、manual shell follow-up queue、Unicode / dead-key input、stale proxy env、VS Code WSL keyboard は `C: 自動継承`' "${PHASE53_SNAPSHOT_DOC}" || {
  echo "Phase 53 snapshot must classify the Codex 0.123.0 bug fixes as C automatic inheritance"
  exit 1
}
grep -q '直接実装しない理由は、本体修正を自動継承するため' "${PHASE53_SNAPSHOT_DOC}" || {
  echo "Phase 53 snapshot must say these fixes are not implemented because Harness inherits the upstream fix"
  exit 1
}
grep -q 'Harness workaround、copy wrapper、manual shell queue shim、proxy snapshot scrubber は追加しない' "${PHASE53_SNAPSHOT_DOC}" || {
  echo "Phase 53 snapshot must explicitly reject Harness workarounds for Codex automatic bug fixes"
  exit 1
}
grep -q 'Codex 0.123.0 automatic bug fixes.*C: Codex 自動継承' "${ROOT_DIR}/docs/CLAUDE-feature-table.md" || {
  echo "Feature Table must mark 53.2.5 automatic bug fixes as Codex automatic inheritance"
  exit 1
}
grep -q 'Codex automatic bug fix inheritance' "${ROOT_DIR}/CHANGELOG.md" || {
  echo "CHANGELOG must mention Codex automatic bug fix inheritance"
  exit 1
}
grep -q 'Codex 0.123.0 automatic bug fix inheritance' "${ROOT_DIR}/skills/harness-loop/SKILL.md" || {
  echo "shared harness-loop skill must document Codex automatic bug fix inheritance for long-running UX"
  exit 1
}
grep -q 'manual shell follow-up queue' "${ROOT_DIR}/skills/harness-loop/SKILL.md" || {
  echo "shared harness-loop skill must mention manual shell follow-up queue inheritance"
  exit 1
}
grep -q 'stale proxy env' "${ROOT_DIR}/skills/session/SKILL.md" || {
  echo "session skill must mention stale proxy env inheritance for shell snapshots"
  exit 1
}
grep -q 'Unicode / dead-key' "${ROOT_DIR}/skills/session/SKILL.md" || {
  echo "session skill must mention Unicode / dead-key input inheritance for WSL terminals"
  exit 1
}

# Phase 53.3.1: closeout must keep Phase 51.2 audit ownership separate
grep -q '53.3.1 Phase 53 closeout / Phase 51.2 dependency note' "${PHASE53_SNAPSHOT_DOC}" || {
  echo "Phase 53 snapshot is missing the 53.3.1 closeout / Phase 51.2 dependency note"
  exit 1
}
grep -q 'Phase 51.2.1-51.2.4 に残る Codex-native tool model、memory/session path drift、review / loop / release mirror path policy、media skill metadata は引き続き Phase 51.2 の owns とする' "${PHASE53_SNAPSHOT_DOC}" || {
  echo "Phase 53 snapshot must keep broad Codex-native skill audit ownership in Phase 51.2"
  exit 1
}
grep -q 'Phase 53 closeout では、Codex mirror / path drift の広い棚卸しを Phase 51.2 の Codex-native skill audit TODO に残します' "${ROOT_DIR}/docs/CLAUDE-feature-table.md" || {
  echo "Feature Table must record Phase 53 closeout dependency on Phase 51.2"
  exit 1
}

# Phase 56: Claude Code 2.1.119 / Codex 0.124.0 snapshot and no-op adaptation
PHASE56_SNAPSHOT_DOC="${ROOT_DIR}/docs/upstream-update-snapshot-2026-04-25.md"
[ -f "${PHASE56_SNAPSHOT_DOC}" ] || {
  echo "${PHASE56_SNAPSHOT_DOC} does not exist"
  exit 1
}
PHASE56_FOLLOWUP_DOC="${ROOT_DIR}/docs/upstream-followups-phase56-2026-04-25.md"
[ -f "${PHASE56_FOLLOWUP_DOC}" ] || {
  echo "${PHASE56_FOLLOWUP_DOC} does not exist"
  exit 1
}
for referencing_file in \
  "${ROOT_DIR}/CHANGELOG.md" \
  "${ROOT_DIR}/docs/CLAUDE-feature-table.md" \
  "${ROOT_DIR}/Plans.md"; do
  grep -q 'upstream-update-snapshot-2026-04-25' "${referencing_file}" || {
    echo "${referencing_file} is missing the expected upstream-update-snapshot-2026-04-25 reference"
    exit 1
  }
done
grep -q 'https://code.claude.com/docs/en/changelog' "${PHASE56_SNAPSHOT_DOC}" || {
  echo "Phase 56 snapshot must include the Claude Code docs changelog URL"
  exit 1
}
grep -q 'https://github.com/openai/codex/releases' "${PHASE56_SNAPSHOT_DOC}" || {
  echo "Phase 56 snapshot must include the OpenAI Codex releases URL"
  exit 1
}
grep -q 'Claude Code `2.1.119`' "${PHASE56_SNAPSHOT_DOC}" || {
  echo "Phase 56 snapshot must include Claude Code 2.1.119"
  exit 1
}
grep -q 'Codex `0.124.0` stable' "${PHASE56_SNAPSHOT_DOC}" || {
  echo "Phase 56 snapshot must include Codex 0.124.0 stable"
  exit 1
}
grep -q 'Codex `0.125.0-alpha.2` pre-release' "${PHASE56_SNAPSHOT_DOC}" || {
  echo "Phase 56 snapshot must include Codex 0.125.0-alpha.2 pre-release"
  exit 1
}
grep -q -- '--print` honors agent `tools:` and `disallowedTools:` frontmatter' "${PHASE56_SNAPSHOT_DOC}" || {
  echo "Phase 56 snapshot must classify --print frontmatter parity"
  exit 1
}
grep -q 'PostToolUse` and `PostToolUseFailure` inputs include `duration_ms`' "${PHASE56_SNAPSHOT_DOC}" || {
  echo "Phase 56 snapshot must classify PostToolUse duration_ms"
  exit 1
}
grep -q 'Status line stdin JSON includes `effort.level` and `thinking.enabled`' "${PHASE56_SNAPSHOT_DOC}" || {
  echo "Phase 56 snapshot must classify status line effort/thinking fields"
  exit 1
}
grep -q 'Hooks are stable, configurable inline in `config.toml` and managed `requirements.toml`' "${PHASE56_SNAPSHOT_DOC}" || {
  echo "Phase 56 snapshot must classify Codex stable hooks"
  exit 1
}
grep -q 'docs/upstream-followups-phase56-2026-04-25.md' "${PHASE56_SNAPSHOT_DOC}" || {
  echo "Phase 56 snapshot must link to the follow-up decisions doc"
  exit 1
}
grep -q 'alpha から推測実装しない' "${PHASE56_SNAPSHOT_DOC}" || {
  echo "Phase 56 snapshot must forbid speculative alpha implementation"
  exit 1
}
grep -q 'B: 書いただけ 0 件の理由' "${PHASE56_SNAPSHOT_DOC}" || {
  echo "Phase 56 snapshot must explain why B is zero"
  exit 1
}
grep -q 'PostToolUse.duration_ms は今回は no-op' "${PHASE56_FOLLOWUP_DOC}" || {
  echo "Phase 56 follow-up doc must record the no-op decision for PostToolUse.duration_ms"
  exit 1
}
grep -q 'status line 1 行目に `effort:<level>` を表示する' "${PHASE56_FOLLOWUP_DOC}" || {
  echo "Phase 56 follow-up doc must describe the statusline effort display"
  exit 1
}
grep -q 'Codex hooks は parity review のみ行い、shipped config は no-op にする' "${PHASE56_FOLLOWUP_DOC}" || {
  echo "Phase 56 follow-up doc must record the Codex hooks no-op decision"
  exit 1
}
grep -q 'GitHub CLI remains primary' "${PHASE56_FOLLOWUP_DOC}" || {
  echo "Phase 56 follow-up doc must keep GitHub CLI as the primary automation path"
  exit 1
}
grep -q 'one primary environment per write turn' "${PHASE56_FOLLOWUP_DOC}" || {
  echo "Phase 56 follow-up doc must define the multi-environment safe default"
  exit 1
}
grep -q 'scripts/codex-primary-environment-guard.sh' "${PHASE56_FOLLOWUP_DOC}" || {
  echo "Phase 56 follow-up doc must mention the primary-environment guard"
  exit 1
}
grep -q 'Phase 56 Claude Code 2.1.119 / Codex 0.124.0 snapshot' "${ROOT_DIR}/docs/CLAUDE-feature-table.md" || {
  echo "Feature Table must include the Phase 56 upstream snapshot row"
  exit 1
}
grep -q 'Plans `56.1.1`-`56.2.4`' "${ROOT_DIR}/docs/CLAUDE-feature-table.md" || {
  echo "Feature Table must link the Phase 56 row back to Plans 56.1.1-56.2.4"
  exit 1
}
grep -q 'Phase 56: Claude Code 2.1.119 / Codex 0.124.0 upstream snapshot' "${ROOT_DIR}/CHANGELOG.md" || {
  echo "CHANGELOG must include the Phase 56 upstream snapshot"
  exit 1
}
grep -q 'docs/upstream-followups-phase56-2026-04-25.md' "${ROOT_DIR}/CHANGELOG.md" || {
  echo "CHANGELOG must mention the Phase 56 follow-up decisions doc"
  exit 1
}
grep -q 'effort.level` / `thinking.enabled` を表示・記録する' "${ROOT_DIR}/CHANGELOG.md" || {
  echo "CHANGELOG must mention the statusline effort/thinking adoption"
  exit 1
}
grep -q 'shipped `codex/.codex/config.toml` は no-op' "${ROOT_DIR}/CHANGELOG.md" || {
  echo "CHANGELOG must mention the Codex hooks no-op decision"
  exit 1
}
grep -q 'one primary environment per write turn' "${ROOT_DIR}/CHANGELOG.md" || {
  echo "CHANGELOG must mention the multi-environment safe default"
  exit 1
}
grep -q 'codex-primary-environment-guard.sh' "${ROOT_DIR}/CHANGELOG.md" || {
  echo "CHANGELOG must mention the primary-environment write guard"
  exit 1
}
grep -qi 'details: docs/upstream-followups-phase56-2026-04-25.md' "${ROOT_DIR}/codex/.codex/config.toml" || {
  echo "codex/.codex/config.toml must explain why no Codex hooks are shipped"
  exit 1
}
grep -q 'one primary environment per write turn' "${ROOT_DIR}/codex/README.md" || {
  echo "codex/README.md must document the multi-environment safe default"
  exit 1
}
grep -q 'HARNESS_CODEX_ALLOW_NON_PRIMARY_WRITE=1' "${ROOT_DIR}/codex/README.md" || {
  echo "codex/README.md must document the non-primary write override"
  exit 1
}
grep -q 'GitHub-first' "${ROOT_DIR}/skills/harness-review/SKILL.md" || {
  echo "harness-review must document the GitHub-first PR host boundary"
  exit 1
}
grep -q 'docs-only' "${ROOT_DIR}/skills/harness-release/SKILL.md" || {
  echo "harness-release must document the docs-only multi-host boundary"
  exit 1
}
grep -q '56.2.2 | Codex `0.124.0` stable hooks' "${ROOT_DIR}/Plans.md" || {
  echo "Plans.md must keep the Codex 0.124.0 hooks follow-up task"
  exit 1
}
grep -q '56.2.1 | Claude Code `PostToolUse.duration_ms`' "${ROOT_DIR}/Plans.md" || {
  echo "Plans.md must keep the Claude Code duration/statusline follow-up task"
  exit 1
}
grep -q '56.2.3 | `prUrlTemplate` / `--from-pr` multi-host review support' "${ROOT_DIR}/Plans.md" || {
  echo "Plans.md must keep the multi-host review follow-up task"
  exit 1
}
grep -q '56.2.4 | Codex `0.124.0` multi-environment app-server と branch/workdir policy' "${ROOT_DIR}/Plans.md" || {
  echo "Plans.md must keep the multi-environment app-server follow-up task"
  exit 1
}
grep -q '56.2.1 .* cc:完了' "${ROOT_DIR}/Plans.md" || {
  echo "Plans.md must mark 56.2.1 as complete"
  exit 1
}
grep -q '56.2.2 .* cc:完了' "${ROOT_DIR}/Plans.md" || {
  echo "Plans.md must mark 56.2.2 as complete"
  exit 1
}
grep -q '56.2.3 .* cc:完了' "${ROOT_DIR}/Plans.md" || {
  echo "Plans.md must mark 56.2.3 as complete"
  exit 1
}
grep -q '56.2.4 .* cc:完了' "${ROOT_DIR}/Plans.md" || {
  echo "Plans.md must mark 56.2.4 as complete"
  exit 1
}

for hooks_file in "${HOOK_FILES[@]}"; do
  MCP_TOOL_COUNT="$(jq '[.. | objects | select(.type? == "mcp_tool")] | length' "${hooks_file}")"
  if [ "${MCP_TOOL_COUNT}" -eq 0 ]; then
    continue
  fi

  jq -e '
    [.. | objects | select(.type? == "mcp_tool")] |
    all(
      ((.tool // .tool_name // .name // "") | test("(health|list|read|get|status|diagnostic|resource)"; "i"))
      and
      ((.tool // .tool_name // .name // "") | test("(write|create|update|delete|remove|record|mutate|set|insert|upsert|patch)"; "i") | not)
    )
  ' "${hooks_file}" >/dev/null || {
    echo "${hooks_file} has an mcp_tool hook that is not clearly read-only"
    exit 1
  }
done

echo "OK"
