# Agent View (`claude agents`) Policy

`claude agents` (agent view, Research Preview) was introduced as a single entry point in CC `2.1.139`+,
with `--cwd <path>` added in `2.1.141` and `--add-dir` / `--settings` / `--mcp-config` /
`--plugin-dir` / `--permission-mode` / `--model` / `--effort` / `--dangerously-skip-permissions`
flags added in `2.1.142`.

Harness treats this as a **standalone entry point for the Lead (operator) to monitor multiple Worker /
Reviewer / Scaffolder sessions at once**, separate from the Harness internal teammate spawn workflow.

## Scope

| Target | Usage |
|------|----------|
| Lead (operator, human) | Use `claude agents` to check the status of multiple projects on one screen |
| Harness teammate spawn (Worker / Reviewer / Scaffolder) | Use Agent tool / breezing skill, not `claude agents` |
| Codex teammate *(archived for v1)* | Use `bash scripts/codex-companion.sh task` (do not use raw `codex exec` or `claude agents`) |

## Behavior assumptions (2.1.139–2.1.142)

- Agent view shows **running / blocked on you / done** per session.
- `claude agents --cwd <path>` can scope the session list to a directory (2.1.141).
- When launching `claude agents`, dispatched background sessions can be configured with
  `--add-dir`, `--settings`, `--mcp-config`, `--plugin-dir`,
  `--permission-mode`, `--model`, `--effort`, `--dangerously-skip-permissions` (2.1.142).
- A teammate started in a background session retains its permission mode (2.1.141) — it does not revert to default.

## Harness Safe Operation Policy

### A. Permitted uses

| Use case | Recommended |
|-----------|------|
| Working in the current project while checking the status of another | `claude agents --cwd <other-project>` |
| Background dispatching safe long-running tasks (tests / lint) in another project | `claude agents --cwd <path> --permission-mode default --effort low` |
| Parallel read-only investigation tasks | Launch in parallel via `claude agents` |

### B. Flag usage conditions

| Flag | Permitted condition | Prohibited condition |
|------|----------|----------|
| `--cwd <path>` | When viewing the state of another project | — |
| `--add-dir` | When expanding the search scope | Paths containing secrets (`.env*`, `secrets/**`, `.ssh/**`) are opt-in forbidden even after denyRead |
| `--settings <path>` | During development to trial project-specific settings | Continuously overriding `.claude-plugin/settings.json` per agent is prohibited (SSOT breakdown) |
| `--mcp-config <path>` | For temporary MCP server trials | Persistent project MCPs must be consolidated in `.mcp.json` |
| `--plugin-dir <path>` | For local testing of unpublished plugins | — |
| `--permission-mode <mode>` | Explicitly set `default` / `acceptEdits` / `plan` | Using `bypassPermissions` on a protected branch (`main`/`master`) is prohibited |
| `--model <model-id>` | Temporary model switching | Downgrading to a smaller model in release / hotfix sessions is prohibited |
| `--effort <level>` | Setting intensity according to task size | Guard rails (R01-R13) must not be relaxed by effort setting |
| `--dangerously-skip-permissions` | Only inside trusted ephemeral sandboxes | Prohibited in: (a) sessions on protected branches, (b) sessions reading credentials, (c) production deployment sessions |

### C. Separation from teammate spawn

- `claude agents` is a **UI for the operator (human Lead) to view multiple sessions**.
  Harness teammate spawn (Worker / Reviewer / Scaffolder) is launched by **Agent tool / breezing skill**.
- Worker / Reviewer do not spawn other sessions from `claude agents`. This is Lead-only
  (see: `.claude/rules/opus-4-7-prompt-audit.md` for permission and responsibility boundaries).
- The breezing skill uses `claude --teammate-mode in-process` / `tmux`. It does not depend on `claude agents`.

### D. Background permission mode retention (2.1.141)

- A teammate moved to the background via `/bg` / `←←` / `claude agents` retains its permission mode from launch time.
- **No need to re-inject permission mode on the Harness side.** The breezing teammate launch contract can be used as-is.
- Confirmed: if a teammate was started in `plan` mode, it remains in `plan` mode after backgrounding (guaranteed by CC core).

### E. Agent view launch sequence (recommended)

1. Operator opens an interactive session with `claude`.
2. Use `claude agents` as needed to check the status of other sessions.
3. To dispatch a separate task, use `claude agents --cwd <path> --permission-mode <mode> --effort <level>` explicitly.
4. When the Lead starts breezing, launch from the `/breezing` skill, not via `claude agents`.

## Violation examples

| Violation | Impact | Recommended action |
|------|------|----------|
| Worker subagent calls `claude agents` to spawn another session | Permission boundary breakdown (Lead-only spawn) | Remove `claude agents` calls from Worker procedures |
| `claude agents ... --dangerously-skip-permissions` on a protected branch (`main`) | Bypasses guard rail (R12 ask) | Use `--permission-mode default` or `acceptEdits` instead |
| Overriding `.claude-plugin/settings.json` per agent with `--settings` | Settings SSOT breakdown | Consolidate changes in project-level `.claude/settings.local.json` |
| Using `--dangerously-skip-permissions` in a session handling credentials like `harness-mem` | Risk of secrets leakage | Remove the flag |

## CI / gate

- `tests/validate-plugin.sh` does not validate `claude agents` flag presence (as it is a CC core feature).
- Instead, the permission boundaries in `.claude/rules/opus-4-7-prompt-audit.md` and the deny rules
  in `.claude-plugin/settings.json` serve as multi-layered defense.
- To audit `claude agents` usage operationally, record `CLAUDE_CODE_SESSION_ID` via webhook
  (`scripts/hook-handlers/webhook-notify.sh`).

## Related

- `docs/team-composition.md` — SSOT for teammate spawn and parallelism
- `agents/worker.md` — Worker contract
- `.claude/rules/opus-4-7-prompt-audit.md` — Agent contract audit rules (Lead-only spawn explicitly stated)
- `docs/upstream-update-snapshot-2026-05-15.md` — Phase 69 snapshot
- `.claude/rules/hooks-2.1.139-plus.md` — 2.1.133+ hook rules

## Review conditions

- When CC `claude agents` graduates from Research Preview to GA → review entire policy
- When `--dangerously-skip-permissions` flag is deprecated / renamed → update the relevant cell
- When Harness teammate spawn becomes integrable with the `claude agents` API → reconsider Section C (separation from teammate spawn)
