# Claude Code Harness V2 Spec

Status: draft SSOT for Phase 72 through Phase 105
Last updated: 2026-07-05

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
- preserve release-grade checks for public artifacts,
- onboard users through the tool they already use, while only claiming support
  that has adapter evidence,
- keep repo-health gates such as formatting, linting, release preflight, and
  host runtime smoke aligned with the support tier being claimed.

### North Star (3 layers)

The ambition stacks oldest-foundation-first; each layer is the ground for the next.

- **L1 Judgment-only operation**: AI prepares the plan, implementation,
  comparison, and verification evidence; the operator (human) makes only the
  final judgment. (Foundation, already the Purpose above.)
- **L2 Tool-agnostic enforcement**: one Harness (R01-R13 guardrails +
  plan/work/review/release) applies from *any* of Claude / Codex / Cursor.
  A single policy engine adjudicates all three hosts through their native hooks
  — routing, not duplication. Two directions are equal first-class:
  (#1) harness-driven (Lead spawns another tool as an execution engine) and
  (#2) host-from (using Harness *from* Codex / Cursor).
- **L3 Collaboration (future north star)**: multiple tools co-drive the same
  project without making the human a copy-paste courier. Mode 1 = full
  autonomous orchestration (v1 keeps Lead = Claude fixed; Codex / Cursor have no
  outward spawn API yet). Mode 2 = human-present peer co-drive via live notice
  messaging. Full peer-Lead collaboration is staged in later.

## HOTL Governance Contract

This contract makes North Star **L3** concrete for the **personal harness** (this
repo). Organization-scope governance (shared constitution, team standards) lives
in **ContextHarness V2**; CCH inherits that constitution and governs only one
operator's autonomous loop. The goal is **Human-on-the-Loop**: the operator
supervises from outside the loop instead of approving every gate (HITL).

Status: **verification-first**. No autonomy rollout — and no phased adoption
ladder — until the prerequisites in `Plans.md` Phase 101 (U0-U7) are proven with
evidence. Autonomy is the *output* of a proven harness, not the starting point.

Invariants (each must become machine-checkable before the matching autonomy is
enabled):

1. **Deterministic-first judiciary.** Deterministic checks (tests, R01-R14, RTM
   coverage) hold the binding verdict (veto). LLM semantic review is advisory
   only and can never raise a gate above the deterministic layer. A unanimous
   cross-model APPROVE is corroborating advice, not proof (judge errors are
   correlated; verdicts are non-deterministic even at temperature 0).
2. **SSOT vs derived separation.** Human-approved sources (rules, spec, tests)
   are the only judgment basis. Derived artifacts (provenance maps, graphs,
   generated HTML, summaries) are navigation only, carry a `derived` marker, are
   git-ignored where generated, and must never feed back into the executor's
   decisions.
3. **Three-axis escalation.** The loop escalates to the human on (a) final
   spec/UX change, (b) security risk, OR (c) blast-radius / irreversibility
   (deletes, file/dir count over threshold, cross-repo, non-revertible ops).
   Axis (c) is machine-detectable and is the outer backstop, because (a)/(b) are
   semantic and an agent self-classifies them unreliably.
4. **In-run scope leash (zero human-load).** During execution every tool-use is
   checked against the task's declared scope. The scope is **auto-inferred** from
   the plan (task target files + RTM) — the operator never hand-declares a file
   allowlist. Out-of-scope writes raise an alarm/escalation; declared-but-
   untouched scope (dropped work) is flagged. This catches task drift and silent
   failures that a terminal review structurally cannot see.
   The same Runtime Floor has a symmetric secret-read allowlist contract for
   local files, matching the egress allowlist enforced by `isAllowlistedHost`:
   network egress is denied unless the destination host is explicitly declared,
   and secret reads are denied unless the exact path is explicitly declared.
   The only relaxation secret-read allowlisting provides is for named paths; it
   must never mean broad filesystem access. Empty strings, a bare `*`, or any
   other all-open declaration are invalid and resolve to deny. Effective
   declarations are the union of `HARNESS_RUNTIME_FLOOR_SECRET_ALLOW` and the
   project config `.claude-code-harness.config.json` key
   `runtimefloor.secretAllow`. If project config is unreadable, malformed, or
   has an invalid `runtimefloor.secretAllow` shape, the fail-safe behavior is an
   empty allowlist (all secret reads denied). Both relative and absolute
   `secretAllow` declarations are resolved to an absolute path first and then
   checked against the worktree boundary; any declaration whose resolved path
   falls outside the worktree — including a relative declaration that escapes
   via `..` segments — is invalid and discarded rather than widening the
   allowlist. This boundary check also follows symlinks: a declaration that is
   textually inside the worktree but resolves through a symlink to a target
   outside it is likewise discarded. Symlink resolution is used only to make
   that pass/deny decision — the allowlist itself always stores the
   operator's declared path, never the resolved realpath, so a declared
   symlink inside the worktree stays readable under its declared name and a
   realpath the operator never declared stays denied even when a declared
   symlink happens to point at it.
5. **Bounded, externally-anchored review.** The OK-until-clean loop is capped
   (e.g. 3 rounds) with human escalation on repeated same-cause failure. Severity
   is a fixed taxonomy: security / data-loss / correctness findings always block
   and are never eligible for "stop nitpicking, move on"; only style/preference
   may be suppressed. Cross-family review (Claude-Lead reviewed by Codex and vice
   versa, plus fresh-context) is required; when the cross-family leg is
   unavailable it is a named reduced-autonomy state, not a silent same-family
   fallback.
6. **Constitution and self-modification protection.** Rule definitions
   (`rules.go`), `deny-baseline`, settings files, and `self-audit` policy are an
   untouchable class: no AI path may modify them; human-only. The audit trail of
   autonomous decisions is derived mechanically from an immutable event log, not
   from agent self-narration. A kill switch (`~/.harness/HALT`) denies all tool
   use ahead of any LLM judgment. `.claude-code-harness.config.{json,yaml}` is a
   control-plane file at the same governance tier as settings files — it scopes
   `runtimefloor.secretAllow` (the secret-read hard floor's allowlist) and
   `runtimefloor.releaseAuto` — so it is joined to the same protected-path deny
   tier as `.claude/settings*` / `.claude-plugin/settings*`, enforced in
   `go/internal/policy/helpers.go`'s `protectedPathRules` (R02/R03, level
   `protectedPathDeny`) and fingerprinted by `go/internal/policy/selfaudit.go`'s
   deny-surface baseline (Phase 128.3). Native Claude Code deny lists
   (`.claude-plugin/settings.json`, `templates/security/deny-baseline.json`)
   remain human-only edits and are out of scope for this Go-layer control;
   AI-authored PRs enforce it purely through the guardrail engine.

Prose-quality governance is scoped, not universal. Writing-norms enforcement
(derived from the Japanese technical-writing standard validated in Phase 101)
applies only to the **Japanese opt-in surface**; English is the shipped default
and stays untouched. Only the deterministic banned-phrase subset (empty LLM-filler
strings) is eligible to become a gate, proven first as the reference instance of
rule↔check provenance (invariant 1). Semantic writing rules (causal-mechanism,
hedge-preservation, single-cause reduction) stay advisory and never veto.
Orthographic preferences such as the em-dash ban are loose recommendations, never
gates — a prose gate that fired on the agent's own output would deadlock the
in-run leash with no slack. There is one prose SSOT, not three overlapping ones.

Reuse over reinvention: rule↔check and feature→requirement→proof traceability is
the mature discipline of policy-as-code (OPA/Conftest) and Requirements
Traceability Matrices (DO-178C / ISO 26262); tamper-evidence is in-toto / SLSA.
CCH adopts these rather than rebuilding them. The genuinely novel scope is
**self-referential governance**: an agent that edits its own harness and could
game its own grader.

## Users And Workflows

Primary user:

- An operator who prefers AI to prepare the plan, implementation, comparison,
  and verification evidence, while the operator makes the final judgment.

Core workflows:

- Plan: turn intent into a scoped, reviewable contract.
- Work: implement only approved slices, with deterministic checks.
- Review: route review depth by risk and preserve evidence.
- Sync: reconcile Plans, git state, mirrors, and distribution surfaces.
- Release: package evidence and publish only after release-grade gates pass.

## SSOT Layers

`spec.md` is the root product contract and keeps the stable core readable.
Detailed contracts live under `docs/spec/` and are part of the same product
contract. `Plans.md` records scheduled work and evidence, but it does not weaken
or override the spec.

SSOT precedence:

Anchor: spec.md > sub-spec > Plans.md.

1. `spec.md` core: North Star, HOTL governance, global invariants, SSOT order,
   non-goals, and open decisions.
2. `docs/spec/*` sub-specs: detailed contract chapters linked from this file.
3. `Plans.md`: task ledger, implementation sequencing, and verification notes.
4. `CHANGELOG.md` / README / skill prose: distribution-facing summaries.

When a detail moves from `spec.md` into `docs/spec/*`, it remains spec material.
If a sub-spec conflicts with this core, this core wins until a human-approved spec
update changes the order.

## Planning Surface Contract

Planning produces co-required planning output: the `spec.md` product contract and Plans.md task contract.
Anchor: spec.md product contract and Plans.md task contract.
Every `create` output and every product-impacting `/harness-plan add` must produce either `Spec delta` or `Spec skip reason`, and must produce the spec result before producing task rows. Harness generates the spec result; the consumer approves or edits it.
Unknown data follows `not_observed != absent`; do not infer absence from missing evidence.

Non-trivial planning must be team-validated. TeamAgent or sub-agent perspectives are required when available, and the output must record `team_validation_mode`. Non-trivial work must use `native`, `subagent`, or `manual-pass`; Product / Architecture / Security / QA / Skeptic are perspectives, not required runtime `agent_type` names. Planning must include a project-scoped harness-mem / harness-recall / repo-memory wheel check, security validation for permissions, secrets, external sends, supply chain, and works-in-practice validation. Security validation must not require reading secrets.

Related sub-spec anchors: `docs/architecture/hokage-core.md`, `go/SPEC.md`, Host Adapter Boundary, Support Tiers And Host Claims, Onboarding Contract, New Session Bootstrap Rule, and `future/unsupported` host claim handling.

## Sub-Spec Index

- [Planning and host adapter](docs/spec/planning-and-host-adapter.md): Planning Surface Contract, Hokage Core And Host Adapter Boundary.
- [Execution backends and distribution](docs/spec/execution-backends-and-distribution.md): Support Tiers And Host Claims, Execution Backend Contract, Orchestration Visibility Contract, Onboarding Contract, Host Distribution Contract, Clean Mode And Compatibility Mode.
- [Workflow, review, and release](docs/spec/workflow-review-and-release.md): New Session Bootstrap Rule, Lane Taxonomy, Stage Gate Flow, Unknown Data Contract, Review Contract, PR And Release Boundary, Release Workflow Delegation Contract, README Product Surface Contract, I18n And Status Marker Contract.
- [Operations, memory, and collaboration](docs/spec/operations-memory-and-collaboration.md): Supply Chain Alert Contract, Memory Contract, Upstream Tracking Contract, Session Coordination Contract, Worktree Root Discipline, Tri-Tool Parallel Collaboration Contract, risk gate distribution, auto-approve scope.
- [Breezing and bridge](docs/spec/breezing-and-bridge.md): Breezing Brief Contract, memory lifecycle events, Bridge Daemon Contract, delivery layer, Channels-Wake, workgraph signal boundary.
- [Decision card surface](docs/spec/decision-card-surface.md): Decision Card Surface Contract, `judgment-card.v1`, past decision reference accuracy, fail-open memory behavior.

The chapter names above intentionally preserve the old `spec.md` headings so grep
based audits can still find the contract location from the core file.

## Non-Goals

1. No automatic implementation without an approved plan.
2. No release claim without a matching support-tier gate.
3. No silent fallback from cross-family review to same-family review.
4. No derived artifact may become a judgment source.
5. No host-specific distribution may load another host's private compatibility
   surface by accident.
6. No AI path may modify constitution files or self-audit policy.

## Open Decisions

- Full peer-Lead collaboration remains staged; current L3 work is Mode 2 live
  notice messaging plus generated delivery hooks where host APIs allow it.
- Organization-scope governance remains outside this repo and belongs to
  ContextHarness V2.
- Broader prose-quality gates must prove deterministic value before promotion;
  semantic prose rules stay advisory.

## Links

- `Plans.md` — task ledger and phase evidence.
- `docs/spec/` — detailed sub-specs that remain part of this product contract.
- `GOD_plans.md` — release and S3-S5 evidence tracking.
