# Spec Sub-Spec: workflow-review-and-release

This sub-spec is part of the `spec.md` product contract. SSOT order is `spec.md` core > `docs/spec/*` sub-specs > `Plans.md`.

## New Session Bootstrap Rule

A new agent session must be able to start from one task id without re-inventing
the plan.

Each startable task must make these visible:

- source spec path,
- current task id,
- first action,
- expected evidence artifact,
- blocked conditions,
- stop or handoff condition.

If a phase is broad, the first task must be research/evidence or plan-freeze.
Implementation must not begin until the evidence artifact narrows the files,
tests, smoke commands, and claim boundaries for the next tasks.

## Lane Taxonomy

Harness V2 uses lanes as task metadata, not as separate primary skills.

| Lane | Use When | Required Closeout |
|------|----------|-------------------|
| `[lane:fast]` | Low-risk local docs, narrow cleanup, small isolated fixes | focused checks, concise evidence pack, no full review by default |
| `[lane:gate]` | Skill, workflow, guardrail, mirror, CI, spec, or shared behavior changes | spec alignment, TDD when required, major-only or full review, re-review until clean |
| `[lane:release]` | Public artifact, version, tag, GitHub Release, CI, binary/package surface | release preflight, version sync, tags, GitHub Release, CI/latest verification |

Fast lane is not a bypass. It still needs a scope, DoD, focused verification,
and an explicit residual-risk statement.

## Stage Gate Flow

Every non-trivial V2 plan follows this path:

1. Research and verification
   - Read current repo state, relevant docs, `Plans.md`, memory, and available
     runtime evidence.
   - Treat failed searches, unavailable APIs, missing fixtures, and unseen data
     as `unknown`.
2. Implementation plan freeze
   - Record lane, scope, DoD, dependencies, TDD tag, risk gates, and evidence
     expectations in `Plans.md`.
3. Implementation with TDD
   - For `[tdd:required]`, create or update a failing test first and keep red
     evidence via red-log or literal failing output.
   - Use `[tdd:skip:<reason>]` only when the reason is explicit and reviewable.
   - If you grep the same symbol twice in the same session, switch to harness_ast_search; for homologous bugfixes across modules, run harness_ast_search to find all implementations before editing.
   - Only when changed files include .ts or .tsx, the DoD requires zero new harness_lsp_diagnostics errors; not-connected harness MCP and non-eligible file types are not-configured and non-blocking.
4. Review
   - `harness-review` stays read-only by default.
   - `APPROVE` means the quality gate passed. It does not mean commit, push,
     PR, merge, or release may happen automatically.
5. PR closeout
   - PR artifacts include base/head refs, spec path, lane, stage, tests, review
     result, accepted/rejected findings, residual risk, and warnings handled.
   - Push and PR creation are external side effects and require an explicit
     flag or confirmation gate.
6. Release closeout
   - Release lane is complete only after version surfaces, tags, GitHub Release,
     CI, and public artifact checks are verified.

## Unknown Data Contract

Harness V2 must distinguish unobserved data from absent data.

Required rule:

```text
not_observed != absent
```

If an agent cannot see a file, API response, memory record, CI run, GitHub
object, fixture, or runtime output, it must report `unknown`, `unavailable`, or
`not observed`. It must not claim the data does not exist unless it has checked
the relevant source of truth.

Examples:

- Search timed out: `unknown`, not `no results exist`.
- Fixture was not loaded: `not observed`, not `fixture missing`.
- harness-mem was unavailable: `memory unavailable`, not `no memory`.
- Local tests passed: `local checks passed`, not `PR/release ready`.

## Review Contract

`harness-review` checks:

- spec alignment,
- `Plans.md` scope and DoD,
- TDD evidence when required,
- regression risk,
- accepted and rejected findings,
- unknown data handling,
- evidence pack completeness.

Critical or major findings produce `REQUEST_CHANGES`.
Minor or recommendation-only findings can still produce `APPROVE` when the
acceptance bar is met.

## PR And Release Boundary

PR closeout belongs to `harness-work`, not `harness-review`.

Release belongs to `harness-release`, not PR closeout.

Do not merge these stages:

- PR ready means the change has a reviewable branch and evidence pack.
- Release ready means the public release path has passed preflight and the
  release artifacts are verified.

## Release Workflow Delegation Contract

The release path is split between the `harness-release` skill and the GitHub
Actions release workflow:

- The skill is responsible up to tag push only. It does not call the GitHub CLI
  release subcommand family.
- GitHub Release publication is the single responsibility of
  `.github/workflows/release.yml`, triggered by `push: tags: ['v*']`.
- The skill runs a verify step after tag push to confirm publication:
  release must have `draft=false` and at least 4 platform binary assets.
- The verify step uses the GitHub CLI API endpoint
  `repos/<owner>/<repo>/releases/tags/<tag>`. The release subcommand prefix is
  excluded from skill output to avoid Claude Code runtime hard floor deny on the
  `prod-deploy` category.
- On verify timeout the skill emits a WARN and does not abort; the tag is already
  pushed, so a human can inspect the workflow run.

## README Product Surface Contract

The root README and Japanese README are public product surfaces, not internal
closeout notes.

They must lead with:

- the user pain Harness solves,
- what changes after install,
- the fastest verified setup path,
- the first command or first prompt,
- the workflow Harness actually enforces,
- the proof boundary for supported and candidate hosts,
- links to deeper docs only after the quick path is clear.

README copy must not lead with internal code names, release archaeology,
operator-only HTML artifacts, or product-history explanations. Those may live
in architecture docs, research docs, or changelog entries when useful.

Command descriptions must explain what the command does inside in one concise
line, so a new user understands the work being delegated without reading the
skill source.

Visual assets used by README / README_ja must follow the same claim boundary:

- text-bearing images require separate English and Japanese assets,
- generated images must use the current official Claude Harness logo tone on a
  white background,
- no image may imply support tiers or host parity beyond verified evidence,
- generated prompts, source files, dimensions, and alt text must be recorded in
  an asset manifest before release,
- stale images that carry obsolete product names, dark hero styling, or
  unsupported support claims must be removed or replaced.

When multiple generated-image directions are plausible, README copy may ship
without those images, but final image generation and integration require an
explicit user approval gate for the chosen direction.

## I18n And Status Marker Contract

Harness ships with English as the default user-facing locale, while Japanese
remains available through explicit opt-in.

Status markers are both protocol values and visible user-facing text. New or
updated Plans.md rows, templates, summaries, and generated notification files
must not mix Japanese and English within the same status marker family. Writer
paths must emit the English marker family, especially `cc:done` for completed
work, alongside `cc:todo`, `cc:wip`, `pm:requested`, and `pm:approved`.

Backward compatibility is mandatory:

- existing `cc:TODO`, `cc:WIP`, `cc:完了`, `pm:依頼中`, and `pm:確認済` rows remain
  valid input,
- Japanese opt-in may preserve surrounding Japanese prose, but new and updated
  status marker writes still use the English marker family,
- readers, sync, loop, sprint-contract, and Plans validation must accept both
  legacy canonical markers and English aliases,
- bulk migration of existing Plans.md files is never implicit; it requires an
  explicit migration command or user approval.

User-facing runtime reasons, guardrail messages, status summaries, and generated
state notifications should follow the same locale resolver as other Harness
messages for prose. Status marker writes are the exception: new/update writer
paths use the English marker family while legacy Japanese markers remain
read-compatible.
