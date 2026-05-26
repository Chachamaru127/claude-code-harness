# Skills Audit 2026-04-20

In conjunction with re-running the Claude Code / Codex upstream tracking, a full inspection was performed on `SKILL.md` files across `skills/`, `codex/.codex/skills/`, and `.agents/skills/`.

## Summary

- Scope: 3 skill lineages of `SKILL.md`
- Findings: 102 items
- `skills/` -> `codex/.codex/skills/` major sync is largely maintained
- `.agents/skills/` is a separate lineage with significant Claude/Codex mechanical-replacement drift
- Fixed in this pass:
  - Synced `claude-codex-upstream-update` across PR-target `skills/`, `codex/.codex/skills/`, and updated local-only `.agents/skills/` in the working environment
  - Redefined `cc-update-review` as a Claude/Codex upstream update review, synced across the 2 PR-target lineages and the local-only mirror
  - Removed references to non-existent Anthropic Codex repo URL, old Codex plugin directory, old Codex feature-table path, and old TypeScript guardrail path from the 2 target Skills
  - Phase 51.2.1-51.2.3 / Worker 3: Fixed Codex native skill orchestration drift, session-memory / memory policy path drift, Codex loop state policy, and harness-release-internal mirror policy
  - Phase 51.2.4 / Worker 4: Fixed media / announcement skill launch contracts, interactive input tool discrepancies, and harness-review mirror link drift

## Findings Tracker

| Priority | Area | Finding | Next action | Status |
|----------|------|---------|-------------|--------|
| P0 | `codex/.codex/skills/harness-work` | Claims to be Codex native but mixes in Claude Code-style pseudo-code for `Agent(...)`, `SendMessage`, `claude-code-harness:worker` | Unify to Codex tool model (`spawn_agent`, `send_input`, `wait_agent`, `close_agent`) | Done 2026-05-05 |
| P0 | `codex/.codex/skills/breezing` | `user-invocable: true` but no `allowed-tools`, and body assumes subagent tools | Align metadata and allowed tool contract | Done 2026-05-05 |
| P1 | `.agents/skills/memory` | Replacement drift: `Codex / Codex / OpenCode`, `.Codex/memory/decisions.md`, etc. | Separate `.claude/memory` source of truth from Codex-side expressions | Done 2026-05-05 |
| P1 | `.agents/skills/session-memory` | Treats `.Codex/memory`, `.Codex/state`, `~/.Codex` as canonical | Update to actual paths for session-state / memory | Done 2026-05-05 |
| P1 | `codex/.codex/skills/session-memory` | Treats `${CLAUDE_SESSION_ID}` as fixed Codex-side assumption | Align Codex session id retrieval convention with session-init | Done 2026-05-05 |
| P1 | `skills/session-memory` | Reference to `docs/MEMORY_POLICY.md` does not exist | Create the referenced target or replace with existing memory docs | Done 2026-05-05 |
| P1 | `harness-review` mirrors | `../../docs/ultrareview-policy.md` resolves to a non-existent relative path in the mirror | Change to repo-root-based or skill-local reference | Done 2026-05-05 |
| P1 | `x-announce`, `x-article` | `allowed-tools` includes `Agent` / `AskUserQuestion`, Codex-side handling is unclear | Add mapping table to Task / Codex input UI counterparts | Done 2026-05-05 |
| P1 | `generate-slide`, `generate-video` | `disable-model-invocation` / `user-invocable` contradicts body trigger | Align metadata with actual launch surface | Done 2026-05-05 |
| P1 | `harness-loop` Codex mirror | State storage is hardcoded to `.claude/state/codex-loop/` | Document the responsibility split between `.claude` shared state and Codex native state | Done 2026-05-05 |
| P2 | `harness-release-internal` | Mirror policy does not treat `.agents/skills/` as a sync target | Either exclude `.agents` as generated output, or include in sync targets | Done 2026-05-05 |
| P2 | `.agents/skills/harness-setup` | Rough replacement drift: old Codex state/plugin directory names, `Codex-harness-worker`, etc. | Fix together via revision of the `.agents` generation rules | Open |

## Tracking

This audit result is left as an incomplete task under `Plans.md` Phase 51.2.
In this scope, the 2 Skills directly tied to the upstream update quality gate were fixed;
all others are carved out to the next skill mirror cleanup cycle.
