# Skill Telemetry Policy (Phase 62.2.3)

> **Status**: Active (2026-05-07)
> **Scope**: Operational rules for recording the `invocation_trigger` field of the
> `claude_code.skill_activated` OTel event fired by Claude Code `2.1.126+` to a local ledger.

## In a nutshell

Record the trigger type of skill activations (human / model / skill-chain) in a **local ledger**
to identify skills that are firing unnecessarily.
When recording, always follow **privacy / retention / opt-out** rules.

## Analogy

Similar to "writing only the book title in a household ledger."
The content (body = skill input / output) is not recorded — only when, by what trigger type,
and which skill was activated (the `skill_activated` event).

## Telemetry sink design assumptions

Phase 58.2.3 established that "telemetry sink design comes first." This doc defines that sink spec.

| Item | Spec |
|------|------|
| Sink type | **local-only JSON Lines ledger** (no external transmission) |
| Ledger path | `.claude/state/skill-trigger-stats.jsonl` |
| Append mode | **append-only** (append only — no compaction or deletion) |
| Ingestion path | Receive Claude Code OTel events via `scripts/skill-trigger-telemetry.sh` |
| Output format | 1 JSON object per line |

## Recorded fields

Each record contains only the following fields. **No personally identifiable information is recorded.**

```json
{
  "timestamp": "2026-05-07T00:00:00Z",
  "skill_name": "harness-work",
  "invocation_trigger": "human|model|skill-chain",
  "session_id": "session-abc123",
  "duration_ms": 0
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `timestamp` | yes | RFC3339 UTC |
| `skill_name` | yes | Name of the activated skill (e.g., `harness-work`, `harness-review`) |
| `invocation_trigger` | yes | One of `human` / `model` / `skill-chain` |
| `session_id` | yes | CC session ID (truncated to first 12 characters if longer than 12 chars) |
| `duration_ms` | no | Skill execution time. Only recorded if provided by CC |

**Fields not recorded**:
- Skill input prompt
- Skill output body
- Username / email address
- API token / authentication credentials
- Individual file paths (granularity beyond skill name is not recorded)

## Privacy principles

1. **local-only**: The ledger is stored in `.claude/state/` and not transmitted externally
2. **identifier minimization**: `session_id` is truncated to a prefix of 12 characters or fewer
3. **content opacity**: Skill input/output body is not recorded
4. **opt-out available**: Disable with the environment variable `HARNESS_SKILL_TELEMETRY_DISABLE=1`

## Retention

| Trigger | Retention period | Deletion timing |
|---------|-----------------|----------------|
| Default | **30 days** | `scripts/maintenance/prune-skill-telemetry.sh` (manual or cron) |
| User deletion request | Immediate | `rm .claude/state/skill-trigger-stats.jsonl` |
| On repo clone / sharing | Do not share | Add to `.gitignore` (existing .gitignore covers state path with bulk exclusion) |

Deletion of records older than 30 days is **recommended** but not automated
(to support long-term retention for audit use cases).
If implementing deletion, use rotation format (`stats.jsonl.{date}` move) to preserve append-only nature.

## Opt-out

### Full disable

Disable via `.claude/settings.json` or environment variable:

```bash
export HARNESS_SKILL_TELEMETRY_DISABLE=1
```

Or:

```json
{
  "env": {
    "HARNESS_SKILL_TELEMETRY_DISABLE": "1"
  }
}
```

### Partial disable (per-skill)

Add an exclude list to `.claude/settings.local.json`:

```json
{
  "harness": {
    "skill_telemetry_exclude": ["harness-work", "harness-loop"]
  }
}
```

## Related docs

- Phase 58.2.3 (`docs/upstream-followups-phase58-2026-05-03.md`) — telemetry sink design decision
- Phase 61 (`docs/sandbagging-aware-weak-supervision.md`) — follows the same append-only design as the `.claude/state/elicitation/events.jsonl` ledger
- Claude Code OTel reference (Anthropic docs)

## Acceptance criteria (Phase 62.2.3 DoD)

- [x] `docs/skill-telemetry-policy.md` exists (this doc)
- [x] privacy / retention / opt-out documented
- [x] Does not conflict with Phase 58.2.3 decision (sink design fixed as local-only)
- [x] Sink path: `.claude/state/skill-trigger-stats.jsonl`
- [x] Schema: timestamp / skill_name / invocation_trigger / session_id / duration_ms

## Reference

- Claude Code 2.1.126 CHANGELOG: `claude_code.skill_activated` OTel event includes `invocation_trigger`
- Phase 61 sandbagging-aware weak-supervision ledger design (privacy-first, append-only)
