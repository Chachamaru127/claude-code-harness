# Codex Execution Modes

Codex `harness-work` uses native Codex tools where Claude Code would use
Agent/Task tool wording.

## Shared Preflight

1. Read `Plans.md`.
2. Stop on old table formats that lack `Task`, `DoD`, `Depends`, or `Status`.
3. Check whether a project spec SSOT exists when product behavior can drift.
   Prefer existing project-level docs, then `docs/spec/00-project-spec.md`.
4. If the task changes product behavior, API, data model, permissions, billing,
   integrations, or tenant boundaries and no stable spec exists, create or
   update the spec before implementation.
5. Skip spec creation only for mechanical work such as typo, formatting,
   dependency bump, docs-only, or behavior-preserving refactor tasks. Record
   the skip reason in the task context or sprint contract.
6. Resolve helper scripts from the Harness plugin root.
7. Keep implementation and review separate.

## Solo

Use the current Codex session for one task. Validate locally and run the normal
review loop before completion.

## Parallel / Breezing

Use Codex native subagents:

- `spawn_agent`
- `send_input`
- `wait_agent`
- `close_agent`

Default Breezing worker count is `max`, meaning the number of ready tasks whose
dependencies are already satisfied. It is not unlimited spawning.

## Companion Delegation

Use the companion script only through the resolved plugin root:

```bash
bash "${HARNESS_PLUGIN_ROOT}/scripts/codex-companion.sh" task --write "task"
```
