# harness-review operating model

## In one sentence

`harness-review` handles everything from a lightweight closeout to a heavy quality gate through a single entry point.
No separate lightweight skill is created.

## Analogy

Rather than adding a second reception desk at a hospital, keep one desk and route patients to "routine checkup," "detailed examination," or "emergency" from the same entry point.
More entry points creates confusion.
Keep one entry point and choose the appropriate examination depth from there.

## Why single entrypoint

| Decision | Reason |
|---|---|
| No separate skill | Increases discovery noise. Both users and agents struggle to know which one to call |
| Make `harness-review` a dispatcher | Avoids contract drift. The meaning of `APPROVE` doesn't diverge between skills |
| Offload governance to references | Reduces the overhead of reading a long SKILL.md every time, while keeping quality gates |
| Read-only default | Allowing review to proceed all the way to commit/push would break the responsibilities of release/work flows |

## Mode table

| mode | When to use | Weight | Primary output |
|---|---|---:|---|
| `quick` | Closing out small uncommitted changes | Light | accepted/rejected findings and focused tests |
| `codex-closeout` *(archived for v1)* | When using Codex review as advice, confirming with actual code | Light | review command / tests / clean result |
| `code` | Regular implementation diff review | Medium | `APPROVE` / `REQUEST_CHANGES` |
| `plan` | Reviewing DoD / Depends / Status in `Plans.md` | Medium | Plan correction points |
| `scope` | Checking for over-scoping, gaps, or unnecessary changes | Medium | Scope assessment |
| `security` | Reviewing risks around permissions, input, secrets, etc. | Heavy | OWASP Top 10 findings |
| `ui-rubric` | Scoring appearance, usability, and completeness | Medium | Design quality score |
| `full` | Final gate before release or for significant changes | Heavy | TeamAgent Debate + governance gate |

## Adopted from external codex-review *(historical upstream context, Codex archived for v1)*

| Adopted item | Handling in harness-review |
|---|---|
| `advisory` | Codex findings are advisory. Adopt only after confirming with actual code, diff, and tests |
| `accepted/rejected` | Split findings into accepted findings / rejected findings with reasons |
| `stop-on-clean` | Do not run additional review just for appearances after a clean result |
| `target selection` | Fix the target (dirty / PR branch / branch range / single commit) upfront |
| `no push just to review` | Do not push just to review |
| `dirty tree handling` | Include uncommitted changes, including untracked files, in the review scope |

## Not adopted

| Not adopted | Reason |
|---|---|
| Default auto-commit for review skill | Mixes review responsibilities with those of work/release |
| Separate lightweight-only skill | Increases discovery noise and contract drift |
| Auto-applying AI suggestions | Without confirming with actual code, false positives/negatives mix in |
| Additional review loop after clean | Costs time without meaningfully improving quality |

## Side-effect boundary

`harness-review` is read-only by default.
`APPROVE` means "passed the quality gate," not "proceed to commit."

Responsibility for commit / push / release:

| Operation | Responsible party |
|---|---|
| Correction commit | `harness-work` or explicit user request |
| Release commit / tag / publish | `harness-release` |
| Review result judgment | `harness-review` |
| Push | Explicit user request or release flow |

## Concrete example

When reviewing a small docs change:

```bash
/harness-review --quick
bash scripts/harness-review-closeout.sh --dry-run --uncommitted
```

Running a heavy gate before a release:

```bash
/harness-review full --team-debate --dual
```

## Why this approach

The problem is not weak quality standards.
It's that the entry-point `SKILL.md` is too heavy, so even a lightweight closeout ends up reading the full examination guide every time.

The solution is to keep the quality standards intact and make only the entry point lighter.
This makes normal reviews fast, and important reviews thorough.
