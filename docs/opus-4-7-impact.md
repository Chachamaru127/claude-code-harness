# Opus 4.7 Impact Summary

In a nutshell:
In Opus 4.7, `literal instruction following`, `xhigh`, `/ultrareview`, and Auto Mode
expansion are the most practically important changes for Harness. They require rewriting
the assumptions in docs, agents, and skills.

By analogy:
It is like having the same driver but with a more responsive steering wheel. The car turns
more precisely than before, but if instructions remain ambiguous the car will also go
precisely in the wrong direction.

## How to read this document

- Primary source: `Claude Code 2.1.111` changelog and Phase 44 planning
- 8 items to watch for Harness in relation to Opus 4.7
- `Has impact` means Harness needs to explicitly follow up
- `No impact` means automatically inherited or out of scope for this cycle

## 8-item mapping

| Item | Impact | Affected area | Response policy |
|------|--------|---------------|-----------------|
| literal instruction following | Has impact | `agents/`, `skills/`, `CLAUDE.md`, docs | Reduce ambiguous language; make decision conditions concrete |
| `xhigh` effort | Has impact | `skills/`, `agents/`, `docs/effort-level-policy.md` | Formally adopt and document the decision |
| task budgets | Has impact | docs, future `skills/` | Treat as a research memo this phase; do not implement yet |
| tokenizer improvement | No impact | all | Inherited automatically from the model |
| vision 2576px | Has impact | review docs / references | Document the operational upper limit for high-resolution reviews |
| memory improvement | Has impact | `session-memory`, docs | Update session continuity and long-run quality descriptions |
| `/ultrareview` | Has impact | `skills/harness-review/`, docs | Document the relationship with `harness-review` (not a conflict) |
| Auto Mode expansion | Has impact | docs, guardrails policy | Drop the `--enable-auto-mode` prerequisite |

## Per-item notes

### 1. literal instruction following

- Opus 4.7 leans toward following instructions exactly as written rather than filling in
  gaps with good judgment.
- Therefore Harness agent prompts need to be more explicit about:
  - when to stop
  - what to report
  - which files to touch
  - what is prohibited

Concrete example:
"Confirm when necessary" is better expressed as "Confirm only before destructive operations"
for Opus 4.7 compatibility.

### 2. `xhigh` effort

- `xhigh` sits between `high` and `max`.
- In docs it is treated as a formal option, not a candidate to skip.
- However, because the mapping between Claude Code frontmatter and API effort is not always
  1:1, an operational policy document is needed.

### 3. task budgets

- Task budgets are attractive, but Harness already has `max_consults` and cost controls.
- Introducing them now would likely create double management, so Phase 44 treats this as
  a research memo only.

### 4. tokenizer improvement

- The same content now consumes slightly fewer tokens.
- No Harness-specific code change is needed; docs treat this as "automatically inherited".

### 5. vision 2576px

- A larger safe upper limit for image reviews means better accuracy when reading schematics
  and PDFs.
- However, "larger is always better" does not apply; pre-resize workflows for images above the
  limit are still required.

### 6. memory improvement

- Improves session resume quality and stability for long-running tasks.
- Harness needs to update `session-memory` and long-running docs to reflect current reality.

### 7. `/ultrareview`

- `/ultrareview` is a dedicated cloud-based parallel multi-agent review.
- Its role differs slightly from Harness's `/harness-review`.
- The value that Harness adds is:
  - Plans.md integration
  - sprint contract / scope review
  - Codex adversarial review

The question is not "which one to remove" but "when to use which".

### 8. Auto Mode expansion

- As of `2.1.111`, Auto Mode no longer requires `--enable-auto-mode`.
- Any old activation instructions remaining in docs will mislead users.
- This docs update removes that prerequisite.

## Conclusions for Harness

| Area | Conclusion |
|------|-----------|
| docs | Update with highest priority |
| agents | Reduce ambiguous language to support literal following |
| skills | Formally document `xhigh` and `/ultrareview` usage |
| hooks / guardrails | Update Auto Mode and permission-related descriptions |
| code | Do not force changes for model-level benefits like tokenizer improvements |

## Why this policy

The essence of Opus 4.7's change is not "it can do slightly more things" but "how it
relates to instructions has changed." Therefore, fixing docs and prompt design first
delivers the highest return on investment.

---

## Phase 44 trace table

Maps each Phase 44 sub-phase back to the 8 items above.
Aligns with `Plans.md` Phase 44 definition and `docs/cc-2.1.99-2.1.110-impact.md`.

| # | Item | Impact weight | Primary phase | Supporting phase |
|---|------|--------------|--------------|-----------------|
| 1 | literal instruction following | **High** | **44.4.1 (agents)** + **44.4.2 (skills)** | 44.11.1 (Feature Table entry) |
| 2 | `xhigh` effort | Medium | **44.5.1** | 44.11.1 |
| 3 | task budgets (public beta) | Low | **44.10.1** (research only) | — |
| 4 | tokenizer 1.0-1.35× | Low | — (auto-inherited) | 44.6.1 (integrated into 1h cache measurement) / 44.11.1 (1 paragraph) |
| 5 | vision 2576px | Low | **44.9.1 (Optional)** | 44.11.1 |
| 6 | file-system memory improvement | Medium | **44.4.1** (consolidated into agent memory description audit) | next memory maintenance cycle |
| 7 | `/ultrareview` | Medium | **44.8.1** | 44.7.1 (built-in slash via Skill tool) |
| 8 | Auto Mode expansion | Low | — (not adopted in this phase) | 44.12.1 (smoke test behavior check only) |

### Highest-priority starting point

**44.4 (literal prompt re-tune) is the top priority.** With Opus 4.7, behaviors that were
silently filled in under 4.6 may break. Other items can be deferred without fatal consequences,
but leaving 44.4 unaddressed risks making Worker / Reviewer / Advisor behavior unstable.

### Execution guidelines for 44.4

1. **grep for ambiguous terms**: search `agents/` and `skills/` for vague phrases such as
   "appropriately", "as needed", "when possible", "automatically"
2. **Replace each result**: substitute concrete decision criteria (thresholds, markers,
   file names, command names)
3. **Turn into an audit checklist**: record before/after examples and open items in
   `.claude/rules/opus-4-7-prompt-audit.md`
4. **Sync Codex mirror**: apply the same standards to `agents-codex/` and `skills-codex/`

### Out of scope for this phase (explicit)

The following items are related to Opus 4.7 but are outside the scope of Phase 44.
They will be considered in a later phase or the next release cycle.

- **Full adoption of Task Budgets** — public beta; deferred to next cycle
- **Full switch to Auto Mode** — behavior differences are unclear; keep `bypassPermissions`
- **Full maintenance of `decisions.md` / `patterns.md`** — next memory maintenance cycle
- **Pinning new model ID as Harness default** — do not explicitly fix `claude-opus-4-7` in
  frontmatter; follow CC model picker / config

---

## References

- Primary source: https://www.anthropic.com/news/claude-opus-4-7
- Claude Code changes: [cc-2.1.99-2.1.110-impact.md](./cc-2.1.99-2.1.110-impact.md)
- Phase 44 definition: [../Plans.md](../Plans.md) "Phase 44: Opus 4.7 / Claude Code 2.1.99-2.1.110 follow-up"
- Classification rules: [../.claude/rules/cc-update-policy.md](../.claude/rules/cc-update-policy.md)
