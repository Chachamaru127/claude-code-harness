# v3 Architecture Details

## Directory Structure

```
claude-code-harness/
├── core/           # TypeScript core engine
│   ├── src/
│   │   ├── index.ts          # stdin → route → stdout pipeline
│   │   ├── types.ts          # Type definitions (HookInput, HookResult, etc.)
│   │   ├── guardrails/       # Guardrail engine
│   │   │   ├── rules.ts      # Declarative rule table (R01-R13)
│   │   │   ├── pre-tool.ts   # PreToolUse hook
│   │   │   ├── post-tool.ts  # PostToolUse hook
│   │   │   ├── permission.ts # PermissionRequest hook
│   │   │   └── tampering.ts  # Tampering detection
│   │   └── state/            # Session and task state management
│   │       ├── schema.ts     # DB schema definitions
│   │       ├── store.ts      # HarnessStore (SQLite)
│   │       └── migration.ts  # Migrations
│   ├── package.json          # standalone TypeScript package
│   └── tsconfig.json         # strict, NodeNext ESM
├── skills/         # 5-verb skills (SSOT)
│   ├── plan/       # planning + plans-management + sync-status consolidated
│   ├── execute/    # work + breezing + codex consolidated
│   ├── review/     # harness-review + codex-review consolidated
│   ├── release/    # release-har + handoff consolidated
│   ├── setup/      # harness-init + harness-mem consolidated
│   └── extensions/ # Extension pack
├── agents/         # 3 agents (consolidated from 11→3)
│   ├── worker.md        # Implementation agent
│   ├── reviewer.md      # Review agent (read-only)
│   ├── scaffolder.md    # Scaffolding and state update agent
│   └── team-composition.md  # Team composition guide
├── hooks/          # Thin shims (→ delegates to core/src/index.ts)
└── .claude/
    └── agent-memory/
        ├── claude-code-harness-worker/
        ├── claude-code-harness-reviewer/
        └── claude-code-harness-scaffolder/
```

## 5-Verb Skill Mapping

| v3 Skill | Consolidated from (old skills) |
|----------|----------------|
| `plan` | planning, plans-management, sync-status |
| `execute` | work, impl, breezing, parallel-workflows, ci |
| `review` | harness-review, codex-review, verify, troubleshoot |
| `release` | release-har, x-release-harness, handoff |
| `setup` | setup, harness-init, harness-update, maintenance |

## 3-Agent Mapping

| v3 Agent | Consolidated from (old agents) |
|--------------|------------------|
| `worker` | task-worker, codex-implementer, error-recovery |
| `reviewer` | code-reviewer, plan-critic, plan-analyst |
| `scaffolder` | project-analyzer, project-scaffolder, project-state-updater |

## TypeScript Configuration

- `exactOptionalPropertyTypes: true` — use conditional assignment for optional fields
- `noUncheckedIndexedAccess: true` — array access requires undefined check
- `NodeNext` module resolution — ESM
- `better-sqlite3` is in `optionalDependencies` (Node 24 compat)

## Mirror Configuration

The 5-verb skills in `codex/.codex/skills/` and `opencode/skills/` are mirror copies from `skills/`:

```bash
# skills/ is the SSOT. codex and opencode are mirrors
skills/plan -> codex/.codex/skills/plan
skills/execute -> opencode/skills/execute
# ...etc
```

`check-consistency.sh` verifies that mirrors match.
