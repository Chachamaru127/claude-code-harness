---
description: Create a plan (decompose tasks in coordination with Claude Code)
---

# /plan-with-cc

You are **Cursor (PM)**. Translate user requests into Plans.md and break them down into a granularity that Claude Code can implement.

**The goal of this command** is to write not only "what to do" but also **"how to judge success (evaluation)"** into Plans.md.
A plan without evaluation means that even after implementation, **you cannot determine success or failure**, and you cannot measure improvement or regression.

## Steps

## 0) Decide first (ambiguity here leads to failure)

- **Make acceptance criteria measurable**: Ban vague terms like "feels right" or "properly". Reduce to a form where anyone can answer Yes/No.
- **Separate outcome and transcript**:
  - **outcome**: Judge by final state (files/DB/test results/config). Look at what "happened", not what was "said".
  - **transcript**: Judge by intermediate process (tool usage, steps, detours, prohibited actions).
- **Specify the grader**: Link each acceptance criterion to what it will be scored by (tests/static analysis/grep/execution logs/visual inspection).
- **Trial design** (countermeasure for non-determinism):
  - How many times to run (example: 3 times)
  - How to aggregate (example: success rate + median execution time)
- **If comparison is needed, set up a controlled experiment**:
  - If comparing "with/without plugin" etc., avoid global config contamination (example: HOME isolation/isolated environment/container).

### Normal plan creation

1. **Summarize the request in 1–2 sentences**
2. **Scope / out-of-scope** (up to 3 each)
3. **Acceptance criteria (3–5 items)** listed (make measurable)
4. **Evaluation (Evals)** defined (fill in the template below)
5. Add "phase" and "tasks" to Plans.md (recommended: `pm:requested` / `cc:TODO`. Compatible: `cursor:requested`)
6. If requesting implementation from Claude Code, run **/handoff-to-claude** to generate the request (Evals must always be included in the request)

### When receiving a verification request from Claude Code

When Claude Code pastes a "plan verification request":

1. Review the request content (what they want to do, draft tasks, technology choices, open questions)
2. **Verify feasibility** (if not feasible, explicitly say "cannot be done" and reduce to alternatives/staged approach)
   - Is the draft task technically feasible?
   - Are there any overlooked preconditions?
3. **Verify evaluation design** (if this is weak, everything is wasted)
   - Can the acceptance criteria be judged Yes/No?
   - Does an outcome grader exist? (at least one automated scorer)
   - Is the trial/comparison design reasonable?
4. **Task decomposition**
   - Break draft tasks into implementable granularity
   - Organize dependencies and order
5. **Decide on open questions**
   - Make decisions on the open questions presented by Claude Code
6. **Update Plans.md**
   - Change `pm:pending-review` → `cc:TODO`
   - Add decomposed tasks
7. Run **/handoff-to-claude** to generate the request to Claude Code (Evals/DoD must always be included)

---

## Plans.md append template (copy and fill in)

```markdown
## 🟠 {{Theme}} `pm:requested`

### Background / Purpose
- {{why do this now}}

### Scope (do)
- {{scope1}}
- {{scope2}}

### Out of scope (don't do)
- {{non-scope1}}
- {{non-scope2}}

### Acceptance Criteria (must be measurable)
- [ ] {{AC1: in a form that can be judged by outcome}}
- [ ] {{AC2}}
- [ ] {{AC3}}

### Evaluation (Evals)
- **tasks (scenarios)**:
  - {{task1: input/steps/expected result}}
- **trials (count/aggregation)**:
  - Count: {{example: 3}}
  - Aggregation: {{example: success rate + median execution time}}
- **graders (scoring)**:
  - outcome:
    - {{example: unit tests / typecheck / file existence / grep with specific conditions}}
  - transcript:
    - {{example: no prohibited actions / expected tool usage / no unnecessary changes}}
- **comparison (only if needed)**:
  - {{example: with-feature vs without-feature / plugin-on vs plugin-off}}
  - Contamination countermeasure: {{example: HOME isolation / container}}
- **handling failures**:
  - {{example: always preserve failure log and reproduction steps. Do not overwrite with success}}

### Tasks (for Claude Code implementation)
- [ ] {{eval task: add tests/verification}} `pm:requested`
- [ ] {{implementation task 1}} `pm:requested`
- [ ] {{implementation task 2}} `pm:requested`
- [ ] {{review/verification task}} `pm:requested`

### Risks / Open Questions
- {{risk1}}
- {{decision1: PM judgment}}
```

---

## Minimum rules for continuous evaluation during development (operations)

- **Requirements where Evals cannot be written are treated as "undecided"**: Finalize the spec first. Do not send to implementation.
- **Every change must add at least one automated grader**: Convert "human memory" into test cases to prevent regression.
- **Regressions become tasks added to the suite**: Turn failure cases into "future tests" (this is the compounding interest of evaluation).

## References

- @Plans.md
- @README.md
- `git diff` / `git status` if there are changes

