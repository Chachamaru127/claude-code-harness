# Cursor Integration

Last updated: 2026-03-06

Scope: handoff integration, not Cursor adapter support.

## Goal

Use Cursor as the PM side and Claude Code Harness as the implementation side without losing task ownership or verification discipline.

## Role Split

- Cursor: planning, review sign-off, release judgment
- Claude Code Harness: implementation, local verification, handoff back to PM

This split works best when both sides share the same repository, branch, and `Plans.md`.

## Recommended Workflow

### 1. Plan in Cursor

Use the Cursor-side command templates to create or refine `Plans.md`:

- `templates/cursor/commands/start-session.md`
- `templates/cursor/commands/plan-with-cc.md`
- `templates/cursor/commands/handoff-to-claude.md`
- `templates/cursor/commands/review-cc-work.md`

### 2. Implement in Claude Code

Inside Claude Code, run the Harness loop:

```bash
/harness-setup
/harness-plan
/harness-work
/harness-review
```

Use `/harness-work all` only after the plan is approved and only if you are comfortable with the evidence-pack contract described in `docs/evidence/work-all.md`.

### 3. Handoff Back to Cursor

For a PM-style return path, use:

```bash
/handoff-to-cursor
```

If you prefer the unified release path, `/harness-release handoff` can also be used when the implementation and review loop is complete.

## Plans.md Markers

The safest shared contract is:

- `pm:依頼中` / `cc:TODO`
- `cc:WIP`
- `cc:完了`
- `pm:確認済`

Cursor should own PM markers. Claude Code should own worker markers.

## Guardrails

- Do not let Cursor and Claude Code edit the same task block at the same time.
- Keep one source of truth for acceptance criteria: `Plans.md`.
- Treat production deployment judgment as the PM side's responsibility.
- If the worker side fails the same issue three times, stop and escalate instead of widening fallback logic.

## Minimum Sanity Check

Before starting a shared session, confirm:

1. Both tools point at the same git branch.
2. Both tools can see the same `Plans.md`.
3. The implementation request includes acceptance criteria and expected verification commands.
4. The PM side knows whether release is in or out of scope.
