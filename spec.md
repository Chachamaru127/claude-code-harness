# Claude Code Harness V2 Spec

Status: draft SSOT for Phase 72 through Phase 81
Last updated: 2026-05-28

This file is the root product contract for Claude Code Harness V2.
Plans.md is the task ledger. `spec.md` is the product contract.
`spec.md` says what must stay true.

## Purpose

V2 makes Harness a faster operator workflow without weakening evidence.

The goal is to reduce human planning and verification load by letting Harness:

- classify work before execution,
- lock the correct specification before implementation,
- require TDD evidence when behavior changes,
- route review depth by risk,
- create PR-ready evidence packs,
- preserve release-grade checks for public artifacts.
- onboard users through the tool they already use, while only claiming support
  that has adapter evidence.
- keep repo-health gates such as formatting, linting, release preflight, and
  host runtime smoke aligned with the support tier being claimed.

## Users And Workflows

Primary user:

- An operator who prefers AI to prepare the plan, implementation, comparison,
  and verification evidence, while the operator makes the final judgment.

Core workflows:

- Plan from an ambiguous request into a spec-backed `Plans.md` task contract.
- Execute `Plans.md` tasks with lane-aware effort and TDD gates.
- Review implementation against `spec.md`, `Plans.md`, tests, and evidence.
- Produce PR closeout artifacts without silently pushing or merging.
- Release only after version, tag, GitHub Release, CI, and public-surface checks.
- Strengthen lint/format and host-runtime smoke without confusing static
  compatibility with public support.

## SSOT Layers

The source-of-truth order is:

1. `spec.md`: root product contract for this repository.
2. Sub-specs for specialized domains:
   - `docs/architecture/hokage-core.md` for reusable core architecture.
   - `go/SPEC.md` for Go runtime behavior.
   - Other clearly named docs under `docs/` for scoped contracts.
3. `Plans.md`: task ledger, dependencies, DoD, status, and evidence trail.
4. Runtime evidence: tests, review artifacts, PR body, CI, release output.

`Plans.md` must not replace `spec.md`. A task can be complete only if its DoD
passes and the result does not contradict the applicable spec.

## Planning Surface Contract

`/harness-plan` owns co-required planning output between the spec.md product contract and Plans.md task contract.
It must not behave as a Plans.md-only generator, and it must not flatten the
precedence order. The order remains `spec.md > sub-spec > Plans.md`:
`spec.md` is the product contract, sub-specs refine scoped domains, and
Plans.md is the task ledger.

`/harness-plan create` and product-impacting `/harness-plan add` must produce
both:

- `Spec delta` when the product contract changes, with the root `spec.md` or
  fallback spec path and the rules being added or changed.
- `Spec skip reason` when the task does not change the product contract, with
  the reason preserved in task context or the sprint contract.
- `Plans.md` task contract rows with DoD, dependencies, status, and evidence
  expectations.

For `create` and product-impacting `add`, agents must read the root `spec.md`
and produce the spec result before producing task rows. Only when a consumer
repository has no root `spec.md` may the agent fall back to an existing project
spec or `docs/spec/00-project-spec.md`.

The agent drafts the spec delta from the request, current repo evidence, memory,
and tests. The user is not expected to write a product spec from scratch before
Harness can plan. If the correct delta is ambiguous, the agent should offer the
smallest decision branch and keep unverified facts as `unknown` or
`not observed`.

Harness generates the spec result. Consumers approve or edit `Spec delta` /
`Spec skip reason`; they are not expected to write the spec from scratch.

Non-trivial planning must be team-validated before it becomes implementation
work. A request is non-trivial when it spans multiple tasks, files, sessions,
or changes product behavior, APIs, data models, permissions, billing, external
integrations, distribution, or security posture. For those requests,
`/harness-plan` must use TeamAgent or sub-agent perspectives when available.
If the runtime cannot spawn sub-agents, the plan must explicitly say
`サブエージェント未使用` and run the same checks in separated sections.
The plan must include `team_validation_mode`, one of
`not_required_lightweight`, `native`, `subagent`, `manual-pass`, or
`unavailable`. Lightweight work may use `not_required_lightweight`.
Non-trivial work must use `native`, `subagent`, or `manual-pass`; `unavailable`
cannot be marked Required.

Product, Architecture, Security, QA, and Skeptic are validation perspectives,
not required runtime `agent_type` names. Harness should pass those perspectives
to the available TeamAgent or Task mechanism rather than requiring arbitrary
agent spawning.

Every non-trivial plan must show:

- alignment with root `spec.md`, applicable sub-specs, and `Plans.md`,
- a project-scoped harness-mem / harness-recall / repo-memory wheel check,
- product-fit validation against the primary operator workflow,
- security validation for permissions, secrets, external sends, supply chain,
  branch protection, and release gates,
- works-in-practice validation that maps the plan to test, smoke, CI, review,
  and release or closeout evidence.

If any of those gates cannot pass, the plan must not mark the work Required
until it adds a spike, narrows scope, updates the product contract, or rejects
the idea.

Security validation must not require reading secrets. If a plan would need to
inspect `.env`, tokens, private keys, or customer data, it must stop at a Risk
Gate and use non-secret evidence such as guardrail rules, config shape, audit
metadata, tests, or CI/GitHub state.

## Hokage Core And Host Adapter Boundary

Hokage Core defines workflow contracts. Host adapters translate those contracts
into a specific agent runtime.

Core may define:

- workflow intent,
- user-facing triggers,
- inputs and outputs,
- required evidence,
- acceptance criteria,
- review and completion rules,
- generic capability requirements.

Core must not depend directly on Claude hook names, Claude-only tools,
Codex-only tools, OpenCode config shape, Cursor rule shape, GitHub Copilot CLI
command shape, Antigravity CLI command shape, or marketplace packaging details.

Adapters own the host-specific mechanics:

| Adapter | Owns | Must Not Claim |
|---------|------|----------------|
| Claude Code | Claude plugin manifest, hooks, settings, output styles, runtime guardrails | That non-Claude hosts have identical hook enforcement |
| Codex CLI / Codex app | Codex skills, `AGENTS.md` guidance, companion wrapper, local plugin marketplace path, post-exec quality gates | That Codex can always stop unsafe actions before execution |
| OpenCode | native skill packaging, OpenCode config, `AGENTS.md` guidance, setup docs, package validation, bootstrap injection when verified | That mirror sync alone proves runtime parity |
| Cursor | `.cursor-plugin/plugin.json`, `.cursor/AGENTS.md`, project rules/skills/agents, optional hooks/MCP config shape, `scripts/model-routing.sh --host cursor`, static adapter smoke | Support before bootstrap + workflow smoke + release preflight pass; PM handoff docs are not adapter support |
| GitHub Copilot CLI | CLI command investigation, tool mapping candidate, smoke proof when available | Support based only on Superpowers evidence |
| Antigravity CLI | CLI/rules investigation, manual profile candidate if no plugin contract exists | Adapter support without an official or verified bootstrap route |

An adapter manifest or support document may be added only when setup, docs
generation, release preflight, or an adapter smoke test consumes it in the same
phase.

## Support Tiers And Host Claims

Public support wording must use support tiers.

| Tier | Meaning | Claim Allowed |
|------|---------|---------------|
| `supported` | Install/update path, bootstrap proof, skill loading, one workflow smoke, compatibility checks, and release/preflight gate all pass. | Public support claim for the verified host and version range. |
| `internal-compatible` | Repo mirror, setup docs, static validation, or local tooling exists, but runtime proof is incomplete. | Internal compatibility or experimental wording only. |
| `candidate` | Current official docs and local evidence suggest a viable adapter path, but no complete smoke proof exists. | Research or spike wording only. |
| `future/unsupported` | No verified adapter path or no current proof. | No setup docs, README support claim, or release support claim. |

Current default stance:

| Host | Default Tier | Reason |
|------|--------------|--------|
| Claude Code | `supported` for Claude-first Harness | Primary product surface and distribution payload. |
| Codex CLI | `internal-compatible` until direct plugin install and companion smoke are verified together | Existing Codex mirror and setup path exist; direct plugin path must be proven separately. |
| Codex app | `candidate` under the Codex adapter | App behavior must be verified separately from CLI help output. |
| OpenCode | `internal-compatible` until runtime bootstrap smoke passes | Existing mirror/setup validation exists; runtime parity is not yet proven. |
| Cursor | `candidate` | Adapter skeleton, static smoke, and model routing exist; workflow smoke and release gate have not yet promoted Cursor beyond candidate. |
| GitHub Copilot CLI | `candidate` | Current CLI docs must be verified and Harness-specific bootstrap proof is missing. |
| Antigravity CLI | `future/unsupported` until an official/verified adapter route exists | No local Harness or Superpowers adapter evidence has been observed. |

Phase 73.1.2 freezes this stance from
`docs/research/superpowers-cherrypick.md`. These tiers are authoritative until
the relevant host-specific setup route, bootstrap proof, workflow smoke, and
release/preflight gate all pass in the same claim path.

README, onboarding, and release wording must not imply that `candidate` or
`future/unsupported` hosts are supported. Candidate hosts may appear only as
research, spike, or adapter-candidate work. `future/unsupported` hosts may
appear only as future scope, unsupported scope, or unknown/unobserved research.

If a host is not observed in the current runtime, Harness must say `unknown` or
`not observed`, not `unsupported`, unless the relevant source of truth was
checked.

## Execution Backend Contract

The harness has three implementation execution backends:

- `claude` (default): the Claude Task subagent.
- `codex` (existing): whole-task delegation via `scripts/codex-companion.sh`.
- `cursor` (candidate): whole-task delegation to
  `cursor-agent --model composer-2.5-fast` via `scripts/cursor-companion.sh`.
  This is the same delegation pattern as `codex`, not a model-provider bridge.

Backend selection precedence (highest first): a per-command flag (e.g.
`--backend cursor`) > the `HARNESS_IMPL_BACKEND` env var > the project
`env.local` entry > the user-scope `~/.config/claude-harness/impl-backend.env`
entry > the default `claude`. Project scope overrides user scope.

Backend is role-scoped: only the implementation (worker) role uses the selected
backend. The review and advisor roles stay on the brain (Opus / `claude` host)
so the implementing backend never reviews its own output.

The concrete model for any host+role is resolved by
`scripts/model-routing.sh --host <backend> --role <role>`. This contract does
not reimplement model selection.

Cursor stays `candidate`: opt-in only, with no public support claim, and is not
distributed (distribution prerequisites are tracked separately). Write
delegation is governed by `.claude/rules/cursor-cli-only.md`.

Containment for cursor write delegation relies on a dedicated-`.git` worktree
plus Lead diff review and cherry-pick as the real boundary. Per Cursor's
official security docs (cursor.com/docs/agent/security), file writes have no
project-folder confinement and command allowlists are "best-effort, not a
security guarantee", so containment cannot be delegated to Cursor.

## Onboarding Contract

Onboarding is not complete when files are copied. It is complete when the first
useful session can be verified.

New-user onboarding must provide:

- a tool-first front door: "which agent are you using now?",
- an install or setup route for that host,
- the first command or first prompt to try,
- what successful bootstrap looks like,
- a verification command or smoke transcript,
- the support tier and known asymmetries.

Existing-user migration must provide:

- a before-state inventory,
- backup locations outside skill scan paths,
- stale plugin/cache/residue detection,
- duplicate local skill detection,
- harness-mem state handling that never deletes memory by default,
- rollback instructions that avoid destructive cleanup unless explicitly
  confirmed.

Superpowers is the reference pattern for multi-host onboarding: common skills,
thin host adapters, bootstrap guidance, skill-trigger tests, and explicit host
tool mapping. Harness may cherry-pick that pattern, but every copied idea must
be translated into Harness lanes, Plans.md tasks, TDD/review gates, and support
tier evidence.

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

## Supply Chain Alert Contract

Open Dependabot alerts on tracked source, tooling, benchmark, or distribution
lockfiles are repo-health findings, not release noise.

Harness must handle them with evidence:

- enumerate the live GitHub alert set before planning remediation,
- group alerts by manifest path, dependency, severity, and advisory,
- prefer supported upgrades that keep the current tool line moving forward over
  security downgrades suggested only by `npm audit fix`,
- use package-manager-native override mechanisms only when the direct owner
  package has not yet published a patched dependency range,
- verify the affected tool still starts or runs an equivalent smoke command,
- add or update Dependabot configuration and CI/audit checks when a tracked
  manifest can otherwise accumulate alerts without PR automation,
- keep GitHub alert closeout, local `npm audit`, CI, and release gates separate.

Benchmark-only manifests may use focused smoke evidence instead of full
benchmark execution when model keys, Docker, or sandbox services are unavailable,
but the unavailable part must be recorded as a residual risk rather than treated
as success.

## Memory Contract

When a planning or design decision is made, Harness should record why it was
chosen, not only what changed.

Preferred memory targets:

- `harness-mem` project-scoped ingest/search when available.
- `.claude/memory/decisions.md` and `.claude/memory/patterns.md` when present.
- `Plans.md` and spec documents as local, reviewable SSOTs.

If harness-mem is unavailable, the agent must say so and keep the local SSOT
updated instead of pretending memory was written.

## Upstream Tracking Contract

Claude Code and Codex updates must be turned into Harness changes through an
evidence gate, not by copying release notes into docs.

Every non-trivial upstream refresh must:

- compare the local installed versions with the latest official upstream
  versions,
- use official Anthropic, OpenAI, or first-party GitHub release sources,
- record a dated snapshot document with release URLs, local version output, and
  observed gaps,
- classify each relevant item as `A: adopt now`, `C: inherit upstream`,
  `P: plan/spike`, or `Reject`,
- keep `B: explanation only` at zero unless the plan explicitly explains why a
  non-actionable note is still worth preserving,
- connect adopted items to `Plans.md`, tests, docs, CHANGELOG, and review gates,
- avoid support-tier upgrades until host bootstrap, runtime smoke, and release
  gates prove the claim.

The following upstream surfaces are product-affecting and must not be treated as
automatic documentation updates:

- skill or slash-command frontmatter semantics,
- hooks, message display, session start, and plugin marketplace behavior,
- agent, subagent, background-session, worktree, or permission behavior,
- sandbox, approval, profile, or managed policy behavior,
- Codex companion, CLI, SDK, MCP, app-server, or GitHub Action behavior,
- installer, package, release artifact, or supply-chain behavior.

If an upstream product weakens a previous opt-in barrier, such as an auto mode
consent change, Harness must keep its own safety default until a dedicated phase
updates the contract, tests, and release notes. Upstream convenience is evidence
to evaluate, not permission to silently relax Harness guardrails.

## Non-Goals

V2 does not:

- replace `Plans.md` with `spec.md`,
- split Fast/Gate/Release into three new primary skills,
- make every task a heavy Gate lane task,
- break existing `cc:TODO`, `cc:WIP`, or `cc:完了` marker compatibility,
- let review auto-commit, push, PR, merge, or release,
- treat local green checks as PR-ready or release-ready by themselves,
- weaken release verification to save time.
- claim Cursor, GitHub Copilot CLI, Antigravity CLI, or generic cross-host
  support before support-tier evidence exists.
- copy Superpowers slogans or trigger rules when they conflict with Harness
  verbs, lanes, or guardrails.

## Open Decisions

- Exact PR closeout command shape: `harness-work --pr` vs
  `scripts/harness-pr-closeout.sh`.
- Final machine-readable evidence schema for PR bodies and closeout artifacts.
- Whether `.claude/memory/decisions.md` and `.claude/memory/patterns.md` should
  be created in this repository or remain optional memory surfaces.
- Whether Codex direct plugin installation becomes the default Codex path or
  stays secondary to `scripts/setup-codex.sh --user`.
- Which current host docs and smoke tests are sufficient to promote Cursor,
  GitHub Copilot CLI, or Antigravity CLI from `candidate` /
  `future/unsupported`.

## Links

- Task ledger: `Plans.md` Phase 72 through Phase 76.
- Phase 76 closes the `harness-plan` planning-surface portion of Phase 72.1.2.
  `harness-work`, review, and PR closeout follow-up remains in Phase 72.
- Spec workflow policy: `docs/plans/spec-ssot.md`.
- Review operating model: `docs/harness-review-operating-model.md`.
- Architecture sub-spec: `docs/architecture/hokage-core.md`.
- Host capability matrix: `docs/tool-capability-matrix.md`.
- Spin-off readiness: `docs/hokage-spin-off-readiness.md`.
- Go runtime sub-spec: `go/SPEC.md`.
