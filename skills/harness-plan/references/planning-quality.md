# Standard plan quality contract — harness-plan standard flow

`harness-plan` does not convert user-provided information directly into a work table.
For plan creation or large task additions, it filters through the latest information, existing specs, memory, and multi-perspective discussions,
then converts only the elements that should be incorporated into this product into the Plans.md task contract.

This is not a standalone subcommand. It is the standard quality gate for `create` and high-impact `add` operations.

## Step 0: Applicability check

Use this quality contract when any of the following apply:

- Creating a new plan with `create`
- Adding a task with `add` that affects product behavior / API / data model / permissions / billing / external integrations / distribution surfaces
- The user provided an external product, a competitor, a spec proposal, an improvement, or a comparison
- There is a potential conflict with existing specs, Plans.md, memory, or past decisions
- The user requested "full power", "thorough comparison", "neutral scoring", or "regression prevention"

For `create` and product-impacting `add`, read the root `spec.md` every time.
Only in consumer repos without a root `spec.md`, fall back to the existing project spec / `docs/spec/00-project-spec.md`.
The output must always include either `Spec delta` or `Spec skip reason`.
This is the co-required planning output contract; the precedence `spec.md > sub-spec > Plans.md` is maintained.

The following may be treated lightly:

- `update` that only changes markers
- `sync` that only reconciles status
- typo / format / README / CHANGELOG only
- Narrow changes where the correct outcome is already fixed by existing specs and tests

## Step 1: Decompose the input

Split the user-provided information into the following four categories:

| Category | Examples |
|----------|----------|
| What is being evaluated | External products, competitor features, spec proposals, design policies, operational plans |
| User's intent | What they want to improve, what they want to avoid |
| Uncertain facts | Recency, pricing, APIs, constraints, competitor status, existing repo state |
| Evidence needed for adoption judgment | Official docs, measured data, existing specs, memory, test results |

Do not stop to ask questions about unknowns. Evaluate the most reasonable interpretation first, and only present "decision branches" when judgment is genuinely split.

## Step 2: Fetch the latest information

When external facts are involved, use WebSearch. Priority order:

1. Official documentation, official blog, release notes, GitHub repo
2. Standards, papers, technical sources close to primary information
3. Reliable comparison articles, case studies, issues / discussions

For important facts, verify with at least 2 sources wherever possible.
When sources contradict, organize the points of contradiction and explicitly state the impact on the adoption decision.

When WebSearch is unavailable or the network fails, handle as follows:

- `Latest information: unverified`
- Provide a provisional evaluation based on local evidence only
- Explicitly state "Web verification pending here" in the final output

## Step 3: Verify local sources of truth

Any proposal to incorporate into the product must be cross-checked against the existing sources of truth.

Minimum to check:

```bash
cat Plans.md
rg -n "related keyword" README.md README_ja.md CLAUDE.md docs skills scripts tests
find docs -maxdepth 3 -type f | sort
git status --short --branch
```

What to look for:

- Does it conflict with existing product promises?
- Does it conflict with existing skill roles / triggers / allowed-tools?
- Does it conflict with incomplete tasks in Plans.md?
- Does it affect distribution mirrors, Codex mirrors, OpenCode mirrors, or i18n?
- If a spec source of truth exists, should the spec SSOT be updated before Plans.md?
- Are the root `spec.md` product contract and the Plans.md task contract kept separate?

## Step 4: Memory check

When harness-mem, harness-recall, or local memory files are available, search for past decisions using related keywords.
When searching is possible, scope to the current project / repo. Use cross-project search only when the user explicitly requests it.

Examples of what to check:

- Search results from harness-mem / harness-recall
- `.claude/agent-memory/`
- `.claude/state/memory-bridge-events.jsonl`
- Verify presence of `.harness-mem/`
- Prior decisions left in repo docs / Plans.md

Notes:

- Do not assume the harness-mem DB can be read directly
- If harness-mem is not set up, unhealthy, or unsearchable, explicitly state "memory unverified"
- Memory is weaker than the current repo state. When old memory conflicts with git / docs, prefer the current repo state
- Do not conclude that something invisible in memory or search is absent. `not_observed != absent`

## Step 5: Sub-agent discussion

When the Task tool is available, run at least 3 independent perspectives. Instruct each agent to be "read-only", "evidence-based", and "conclusion-first".

Standard roles:

| Role | Purpose |
|------|---------|
| Product / Strategy | Examine adoption value, differentiation, user value, and opportunity cost |
| Architecture / Implementation | Examine feasibility, alignment with existing design, and maintenance burden |
| QA / Regression | Examine regressions, testing, distribution mirrors, and compatibility |
| Skeptic | Attack reasons not to adopt, over-investment, and vague assumptions |

What to require from each agent's output:

- Adopt / conditional adoption / reject
- Rationale
- The greatest risk
- What else needs to be verified
- Conflicts with existing specs or memory

How to synthesize the discussion:

1. Extract the points of agreement
2. Leave the points of disagreement
3. State your own judgment
4. Classify as Required / Recommended / Optional / Reject

When sub-agents are unavailable, explicitly evaluate the same 4 perspectives alone in clearly separated sections, and note `sub-agents not used`.

## Step 6: Neutral scoring review

Scores are out of 5. A score of 5 is good; a score of 1 is weak.

| Axis | 5 | 3 | 1 |
|------|---|---|---|
| Product Fit | Directly tied to the core of the target product | Useful but peripheral | A different product or workflow would suffice |
| Evidence Strength | Primary sources + measured data + existing evidence | Only one side verified | Primarily speculative |
| User Value | Judgment quality or execution speed greatly improved | Effective for some workflows | Perceived value is thin |
| Implementation Feasibility | Small and localized | Medium scale but manageable | Large scale with high maintenance burden |
| Regression Safety | Low risk and testable | Has impact scope | Likely to break existing flows |
| Strategic Leverage | Becomes a long-term differentiator | Stays as a convenience feature | One-time benefit |

Correction rules:

- If Evidence Strength is 2 or below, Required is prohibited
- If Regression Safety is 2 or below, place a spike / spec / test first
- If Implementation Feasibility is 2 or below and User Value is 3 or below, lean toward Reject
- If Product Fit is 2 or below, keep it out of this product and route it to docs / external workflow

## Step 7: `$easy` report

The final output does not present the raw complex evaluation — transform it into a form that enables a decision.

Required structure:

```markdown
In short:
{{adoption decision in one sentence}}

Scoring review:
| Option | Score | Verdict | Rationale | Unverified |
|--------|-------|---------|-----------|------------|

Proposals to incorporate:
| Priority | Proposal | Reason | Expected outcome |
|----------|----------|--------|------------------|

Regression check:
- Spec:
- Plans.md:
- harness-mem / memory:
- mirrors / distribution:
- tests:

Next steps:
1. ...
2. ...
3. ...
```

Writing rules:

- State the conclusion first
- Translate technical terms immediately and briefly
- Do not judge on vague impressions like "amazing" or "innovative"
- Limit proposals to 1–3. Do not list too many candidates
- Distinguish facts, inferences, and unverified points

## Step 8: Translating into Plans.md / spec

Convert only the accepted proposals into the task contract.

Order:

1. Read root `spec.md`, and if necessary, update the product contract first as a `Spec delta`
2. Add only Required tasks to Plans.md
3. Attach `[needs-spike]` to high-risk proposals
4. Place a verifiable DoD on each task
5. Attach `[tdd:required]` to tasks that require TDD
6. If mirrors / i18n / package surfaces are affected, add a separate verification task
7. If no spec update is needed, leave a `Spec skip reason` in the task context / sprint contract

`Spec delta` is drafted by the agent. Do not assume the user will write the spec from scratch.
`Spec delta` / `Spec skip reason` are generated by Harness; the consumer only approves or revises them.

Prohibited:

- Creating only implementation tasks while the correct spec conditions are still ambiguous
- Handling regression checks with a "be careful" note instead of making them a task
- Omitting the `Spec skip reason` for docs-only / mechanical tasks
