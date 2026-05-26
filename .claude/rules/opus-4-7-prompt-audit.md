---
description: Agent prompt audit rules for Phase 44 / 2.1.111
globs:
  - "agents/worker.md"
  - "agents/reviewer.md"
  - "agents/advisor.md"
  - "agents/scaffolder.md"
  - "agents/team-composition.md"
---

# Opus 4.7 Prompt Audit Rule

Audit standards for updating agent prompts and team composition in Phase 44 / 2.1.111.

## Pass Conditions

1. Behavioral instructions must always include at least one of the following:
   - Name of the command to execute
   - File path
   - JSON schema name
   - A numeric threshold
   - A condition that can be evaluated as true or false
2. When writing retry/count controls, express the upper limit as a number.
   - Example: `maximum 3 times`
   - Example: `if the same cause fails 2 times in a row`
3. When writing output formats, fix the schema name and enumerated values.
   - `advisor-request.v1`
   - `advisor-response.v1`
   - `review-result.v1`
   - `worker-report.v1`
   - `PLAN | CORRECTION | STOP`
   - `APPROVE | REQUEST_CHANGES`
   - `self_review[].rule` enumerated values (default 6): `dry-violation-none | plans-cc-markers-untouched | all-declared-symbols-called | dod-items-verified-with-evidence | no-existing-test-regression | tdd-red-evidence-attached`
   - `memory_updates[].scope` enumerated values: `universal | task-specific` (string arrays are treated as `task-specific` for backward compatibility)
4. When writing Codex integration, use the wrapper command.
   - Allowed: `bash scripts/codex-companion.sh task --write "..."`
   - Allowed: `bash scripts/codex-companion.sh review --base "${TASK_BASE_REF}"`
   - Prohibited: writing raw `codex exec` as the standard method in agent procedures
5. Write the 2.1.111 operational knobs separately for agent contracts and operator entrypoints.
   - `xhigh`: reasoning intensity chosen by the caller. Agent prompts must not infer this from free-text markers.
   - `/ultrareview`: the caller's review entrypoint. On the agent definition side, use `review-result.v1` as the contract.
   - `--auto-mode`: opt-in rollout. Do not write as the default value.
6. Make the permission and responsibility boundary determinable in one line per agent.
   - Only the Lead spawns teammates
   - The Worker returns `advisor-request.v1` and does not spawn an Advisor directly
   - The Reviewer only performs quality judgment and does not implement
7. In `team-composition.md`, write the conditions for the number of parallel workers as numbers.
   - `1`: the target for change is 1 group, or the files to be written overlap
   - `2`: 2 independent groups of files to write
   - `3`: 3 or more independent groups of files to write
8. In this phase, do not include `skills/`, `docs/`, or `mirror` as update targets.

## Handling Vague Language

When using any of the following terms, follow up immediately in the same sentence or the next bullet point with clarifying conditions:

- `as needed`
- `as appropriate`
- `appropriately`
- `sufficiently`
- `flexibly`
- `properly`
- `if possible`
- `depending on the situation`
- `independent task`
- `high risk`

Failing to add a clarification results in a failed audit.

## Checklist

- [ ] No undocumented keys added to frontmatter
- [ ] Within the first 3 steps of `initialPrompt`, there is a file to read or an item to confirm
- [ ] The upper limit on the number of retries / escalations / review loops is written as a number
- [ ] The schema name and enumerated values of output JSON are fixed
- [ ] Wherever `codex-companion.sh` is used, the command name matches exactly
- [ ] No legacy free-text markers like `ultrathink` remain in agent contracts
- [ ] `xhigh` and `/ultrareview` are written as operator-side specifications
- [ ] `--auto-mode` is not written as the default value
- [ ] The reviewer's verdict conditions align with `critical | major | minor`
- [ ] The advisor's `STOP` conditions include `stop_reason`
- [ ] Spawn privileges in team composition are limited to the Lead

## Recommended Verification Commands

```bash
rg -n "as needed|as appropriate|appropriately|sufficiently|flexibly|properly|if possible|depending on the situation" \
  agents/worker.md agents/reviewer.md agents/advisor.md agents/scaffolder.md agents/team-composition.md

rg -n "codex exec|ultrathink|xhigh|/ultrareview|auto-mode|advisor-request.v1|advisor-response.v1|review-result.v1|worker-report.v1|REQUEST_CHANGES|PLAN|CORRECTION|STOP" \
  .claude/rules/opus-4-7-prompt-audit.md agents/worker.md agents/reviewer.md agents/advisor.md agents/team-composition.md
```
