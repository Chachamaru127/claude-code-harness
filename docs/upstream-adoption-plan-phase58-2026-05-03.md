# Phase 58 Upstream Adoption Plan - 2026-05-03

This document defines the adoption plan for how to leverage the Claude Code `2.1.120`-`2.1.126`
and Codex `0.125.0` / `0.128.0` updates within the Claude Code Harness.

## In a nutshell

Phase 58 does not simply add Claude / Codex new features as-is.
Instead, it translates them into a form that fits Harness's safety boundaries,
review audit trail, and Codex parallel operation before introducing them.

## Analogy

New tools have arrived.
We sort them into: ready to use immediately, needs a safety cover first,
and can stay on the shelf for now.

## Official sources

- Claude Code changelog: <https://code.claude.com/docs/en/changelog>
- Claude Code GitHub changelog: <https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md>
- Codex `rust-v0.125.0`: <https://github.com/openai/codex/releases/tag/rust-v0.125.0>
- Codex `rust-v0.128.0`: <https://github.com/openai/codex/releases/tag/rust-v0.128.0>

## Adoption menu

### 🛡️ A. Claude protected-write hardening

Updates to leverage:

- Claude Code `2.1.121`: The write prompt bypass scope for `.claude/skills/`, `.claude/agents/`, `.claude/commands/` has changed.
- Claude Code `2.1.126`: The protected path bypass scope has expanded to include `.claude/`, `.git/`, `.vscode/`, shell config files, and more.
- Claude Code `2.1.126`: `allowManagedDomainsOnly` / `allowManagedReadPathsOnly` precedence fix.

Existing implementation:

- `go/internal/guardrail/helpers.go` treats `.git/`, `.env`, secret keys, `.husky/` as protected paths.
- `go/internal/guardrail/rules.go` denies protected path writes for `Write/Edit/MultiEdit` and also denies Bash redirection writes to `.env/.git/key`.
- `templates/claude/settings.security.json.template` has deny entries for `.claude/settings*` and `.claude-plugin/settings*`.

Gaps:

- No classification for `.claude/skills`, `.claude/agents`, `.claude/commands`, `.vscode`, shell rc/profile files.
- No classification to leave `.claude/rules`, `.claude/memory`, setup metadata at warn level.
- No detection for Bash `tee` / redirection writes to `.claude/*`, `.vscode/*`, shell config files.
- Managed sandbox boundary not verified in `harness.toml` / settings / template / CI.

Non-conflicting approach:

- Do not deny all of `.claude/`.
- Split into deny / ask / warn.
- Stop at the `PreToolUse` guardrail side, not `PermissionRequest`.
- Do not relax protected path rules even in `WorkMode`.

Adoption decision:

- ✅ Recommended for introduction.
- Add first.
- Forms the foundation for accident prevention.

Implementation plan:

1. Add protected path taxonomy to `go/internal/guardrail/helpers.go`.
2. deny: `.git/`, secrets, shell rc/profile files, destructive hook entrypoints.
3. ask: `.claude/skills/`, `.claude/agents/`, `.claude/commands/`, `.vscode/`.
4. warn: `.claude/rules/`, `.claude/memory/`, setup metadata.
5. Unify `Write/Edit/MultiEdit` and Bash write classification in `go/internal/guardrail/rules.go`.
6. Verify managed sandbox boundary in `scripts/ci/check-consistency.sh`.
7. Add Phase 58.2.1 implementation detection to `tests/test-claude-upstream-integration.sh`.

Verification:

- `go test ./go/internal/guardrail/...`
- `bash tests/test-claude-upstream-integration.sh`
- `bash scripts/ci/check-consistency.sh`
- `./tests/validate-plugin.sh`

### ✂️ B. PostToolUse `updatedToolOutput` output governance

Updates to leverage:

- Claude Code `2.1.121`: `PostToolUse` hooks can replace output for all tools via `hookSpecificOutput.updatedToolOutput`.

Existing implementation:

- `go/pkg/hookproto/types.go`'s `PostToolHookSpecific` has only `hookEventName` and `additionalContext`.
- `harness hook post-tool` only returns `additionalContext` when there are warnings.
- Shell hooks are also `additionalContext`-centered and do not replace tool output.

Gaps:

- No `updatedToolOutput` type.
- No preservation of `tool_response`, `tool_use_id`, `duration_ms` input.
- No before / after / audit record model.
- No mechanical test to prevent deletion of review / test / lint evidence.

Non-conflicting approach:

- Do not rewrite tool output by default.
- Opt-in only.
- Permitted uses limited to: secret redaction, large output compaction, machine-readable normalization.
- Prohibited uses: deletion of review / test / lint / error evidence.
- stdout must be JSON contract only — do not mix in human-readable explanations.

Adoption decision:

- 🟡 Introduce design first.
- Implement after A.
- Convenient but prone to destroying evidence.

Implementation plan:

1. Add `docs/output-governance.md`.
2. Add `ToolResponse`, `ToolUseID`, `DurationMS`, `UpdatedToolOutput` to `go/pkg/hookproto`.
3. Design an opt-in like `HARNESS_OUTPUT_GOVERNANCE=redact|compact|normalize`.
4. Consolidate into a single synchronous PostToolUse mutation handler.
5. Record original hash / updated hash / policy / reason in `.claude/state/output-governance.jsonl`.
6. Fix test failure / review finding / lint error as non-replaceable in tests.

Verification:

- no-default-mutation test
- Bash secret redaction shape test
- review/test failure output non-mutation test
- audit record test
- stdout JSON-only test
- `bash tests/test-claude-upstream-integration.sh`

### 🧭 C. Claude setup / MCP / telemetry / provider guidance

Updates to leverage:

- `claude ultrareview [target] --json`
- `${CLAUDE_EFFORT}`
- `claude plugin validate` schema acceptance
- MCP `alwaysLoad`
- `claude plugin prune`
- `ANTHROPIC_BEDROCK_SERVICE_TIER`
- `claude project purge`
- `claude_code.skill_activated.invocation_trigger`
- Windows PowerShell primary shell
- forked skills/subagents deferred tools

Existing implementation:

- There is a policy not to call `/ultrareview` within Harness flow.
- `claude plugin validate` is executed in `tests/validate-plugin.sh`.
- Codex MCP / provider guidance exists.
- Windows docs are centered on Git Bash / MSYS / Cygwin / WSL2.

Gaps:

- The boundary between `claude ultrareview --json` and Harness `review-result.v1` is not updated.
- No policy for using `${CLAUDE_EFFORT}` for skill tuning.
- No guidance on the distinction between Claude Code MCP `alwaysLoad` and deferred discovery.
- No safe path for `plugin prune`.
- Claude Code Bedrock service tier guidance is not separated from Codex provider docs.
- Differences between `project purge` and Harness state cleanup are not organized.
- PowerShell primary shell route is not in docs.

Non-conflicting approach:

- Do not mix Claude Code MCP and Codex MCP docs.
- Limit `ANTHROPIC_BEDROCK_SERVICE_TIER` to Claude Code provider guidance only.
- For `plugin prune`, guide through pre-check procedures instead of a non-existent dry-run.
- Position `ultrareview --json` as a CI second-opinion candidate, not as an alternative to `/harness-review`.

Adoption decision:

- ✅ Recommended as docs / setup update.
- Do not add runtime wrappers.

Implementation plan:

1. Add `docs/claude-code-setup-mcp-telemetry-provider.md`.
2. Append the `claude ultrareview --json` boundary to `docs/ultrareview-policy.md` and `skills/harness-review/SKILL.md`.
3. Append the limited use of `${CLAUDE_EFFORT}` to `docs/effort-level-policy.md`.
4. Add MCP `alwaysLoad` vs deferred discovery guidance to `skills/harness-setup/SKILL.md`.
5. Add safe path for `plugin validate` / `plugin prune` to `docs/plugin-managed-settings-policy.md`.
6. Separate Claude Code Bedrock service tier guidance from Codex provider policy and add it.
7. Add PowerShell primary shell route to compatibility docs.

Verification:

- `bash tests/test-claude-upstream-integration.sh`
- `./tests/validate-plugin.sh`
- docs grep gate: `alwaysLoad`, `CLAUDE_EFFORT`, `plugin prune`, `ANTHROPIC_BEDROCK_SERVICE_TIER`, `project purge`, `invocation_trigger`, `PowerShell`, `deferred tools`

### 🔐 D. Codex permission profiles / `--full-auto` migration

Updates to leverage:

- Codex `0.125.0`: permission profiles round-trip across TUI, user turns, MCP sandbox state, shell escalation, app-server APIs.
- Codex `0.125.0`: `codex exec --json` reasoning-token usage.
- Codex `0.125.0`: rollout tracing records tool, code-mode, session, multi-agent relationships.
- Codex `0.128.0`: built-in permission profiles, sandbox CLI profile selection, cwd controls, active-profile metadata.
- Codex `0.128.0`: `--full-auto` deprecated in favor of explicit permission profiles and trust flows.

Existing implementation:

- Recorded in Phase 58 snapshot / follow-up / Plans.
- `codex/.codex/config.toml` has no-inline-hooks policy and agent sandbox.
- `docs/codex-sandbox-execution-policy.md` covers sandbox policy for the 0.123 series.

Gaps:

- No canonical docs for permission profile / trust flow.
- `--full-auto` remains in `scripts/codex/codex-exec-wrapper.sh`.
- `--dangerously-bypass-approvals-and-sandbox` remains in the local worker in `scripts/codex-loop.sh`.
- No storage destination for `codex exec --json` reasoning token usage.
- No duplicate cleanup between rollout trace and existing AgentTrace.
- `scripts/check-codex.sh` still shows `npm update -g @openai/codex` guidance.

Non-conflicting approach:

- Do not add `--full-auto` as default in new docs.
- Check current flags with `codex exec --help` before implementation.
- Treat `requirements.toml` as the place for org-managed policy; do not add guessed defaults to distribution defaults.
- Document the relationship between `approval_policy: never` / `sandbox: workspace-write` in the existing worker setup and permission profiles.

Adoption decision:

- ✅ Recommended for introduction.
- But confirm flag replacement with help / smoke test first.
- Second most important after A.

Implementation plan:

1. Add `docs/codex-permission-profiles-policy.md`.
2. Update `codex/README.md` and `codex/.codex/skills/harness-setup/SKILL.md` to the profile policy.
3. Move `--full-auto` to legacy fallback treatment.
4. Migrate wrapper / loop flags to explicit profiles or explicit sandbox/trust flows.
5. Add a design for saving `codex exec --json` reasoning usage to job result.
6. Create a mapper policy to avoid double-counting with `.claude/state/agent-trace.jsonl` for rollout traces.

Verification:

- `bash tests/test-codex-package.sh`
- `bash tests/test-codex-loop-cli.sh`
- fake `codex` with `--json` reasoning usage save test
- wrapper flag test
- `bash tests/test-claude-upstream-integration.sh`

### 🧩 E. Codex plugin workflows / `/goal` / MultiAgentV2

Updates to leverage:

- Codex `0.125.0`: app-server Unix socket, sticky environments, remote thread config/store.
- Codex `0.125.0`: remote plugin install and marketplace upgrade.
- Codex `0.128.0`: persisted `/goal` workflows.
- Codex `0.128.0`: plugin workflows, plugin-bundled hooks, hook enablement state, external-agent config import.
- Codex `0.128.0`: MultiAgentV2 thread caps, wait-time controls, root/subagent hints, depth handling.

Existing implementation:

- Recorded in Phase 58 snapshot / follow-up / Plans.
- `codex/.codex/config.toml` has no-inline-hooks policy, `[features].multi_agent = true`, `[agents].max_threads = 8`.
- Breezing assumes Codex native `spawn_agent` / `send_input` / `wait_agent` / `close_agent`.
- One-primary-environment policy exists in README / guard script / test.

Gaps:

- What to write in `/goal` is undefined.
- No opt-in procedure for plugin-bundled hooks / hook enablement state.
- No ownership boundary for external agent import.
- No mapping table between MultiAgentV2 controls and `agents.max_threads = 8`.
- There is a gap in state path descriptions between `${CODEX_HOME}/state/harness/` and `.claude/state/...`.

Non-conflicting approach:

- `Plans.md` is the SSOT.
- Limit `/goal` to session continuation memo use only.
- Do not write task ID / DoD / status markers in `/goal`.
- plugin-bundled hooks are opt-in and disabled by default.
- Do not use external agent import directly; create an allowlist / conversion table first.
- remote / sticky environment is read-only first.
- Writes are limited to one primary environment per write turn.

Adoption decision:

- 🟡 Suitable for design review.
- Begin after 58.3.1 permission profile policy.

Implementation plan:

1. Add `docs/codex-plugin-workflow-policy.md`.
2. Classify `/goal`, plugin hooks, hook enablement state, external agent import, MultiAgentV2, sticky environment as: adopt / opt-in / prohibited / deferred.
3. Update `codex/README.md` and `codex/AGENTS.md`.
4. Rephrase `codex/.codex/config.toml`'s no-inline-hooks policy for Codex 0.128.
5. Fix the relationship between MultiAgentV2 and `agents.max_threads = 8` in tests.
6. Separate state path descriptions into `.claude/state/...` and `${CODEX_HOME}` responsibilities.

Verification:

- `bash tests/test-codex-package.sh`
- `bash tests/test-claude-upstream-integration.sh`
- no-inline-hooks / plugin opt-in grep gate
- `/goal` and `Plans.md` SSOT boundary grep gate
- one-primary-environment regression test

## Introduction order

1. 🛡️ A. Claude protected-write hardening
2. 🔐 D. Codex permission profiles / `--full-auto` migration
3. ✂️ B. PostToolUse output governance design
4. 🧭 C. Claude setup / MCP / telemetry / provider guidance
5. 🧩 E. Codex plugin workflows / `/goal` / MultiAgentV2

## Reviewer acceptance criteria

### Acceptable to introduce

- Does not conflict with existing Harness canonical sources.
- Can prevent recurrence with tests.
- Does not over-wrap upstream features.
- Does not enable dangerous automation by default.
- Does not destroy evidence logs and review results.

### Should be deferred

- Creates a second source of truth alongside `Plans.md`.
- Breaks normal operation like denying all of `.claude/`.
- Expands `--full-auto` or dangerous bypass as new defaults.
- Hides test / review / error evidence via output mutation.
- Enables Codex plugin hooks or external agent imports without opt-in.

## Next execution commands

Launch command for a new session:

```bash
claude
```

First input after launch:

```text
/harness-work 58.2.1
```

When to use:

To establish safety boundaries first. Once 58.2.1 passes, it becomes harder to have accidents when adding the convenience features in 58.2.2 and beyond.

Alternative for parallel progress:

```text
/breezing 58.2.1 58.3.1 --parallel 2
```

When to use:

Claude-side protected path hardening and Codex-side permission profile migration have little file overlap,
making it easy for the reviewer to check them as 2 separate PRs.
