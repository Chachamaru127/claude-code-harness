# Team Composition

The Harness standard team has 5 roles.
Even when adding more implementation teammates, the responsibility boundaries of these 5 roles do not change.

## Structure

```text
Lead
├── Worker x 1..3
├── Advisor x 0..1
├── Reviewer x 1
└── Scaffolder x 0..1
```

## Spawn permissions

- Only Lead spawns teammates
- Worker does not spawn teammates
- Reviewer does not spawn teammates
- Scaffolder does not spawn teammates
- When Worker needs to consult, it returns `advisor-request.v1` instead of spawning more subagents

## Role contract

| Role | subagent_type | Count | Tools used | Returns |
|------|---------------|----|------------|----------|
| Lead | Inside Execute skill | 1 | Agent, SendMessage, Bash | Task decomposition, review judgment, main branch merge |
| Worker | `claude-code-harness:worker` | 1..3 | Read, Write, Edit, Bash, Grep, Glob | Implementation result or `advisor-request.v1` |
| Advisor | `claude-code-harness:advisor` | 0..1 | Read, Grep, Glob | `advisor-response.v1` |
| Reviewer | `claude-code-harness:reviewer` | 1 | Read, Grep, Glob | `review-result.v1` |
| Scaffolder | `claude-code-harness:scaffolder` | 0..1 | Read, Write, Edit, Bash, Grep, Glob | analyze/scaffold/update-state result JSON |

## Determining the number of workers

| Condition | Number of workers |
|------|-----------|
| Write targets are 1 group, or files overlap | 1 |
| Write targets are 2 groups with no overlap | 2 |
| Write targets are 3 or more groups with no overlap | 3 |

A "group" here refers to a set of writes that can be combined into the same commit without conflicts.
Splitting writes so that 2 workers write the same file is prohibited.

## Worker stall re-spawn (CC 2.1.113+)

Lead re-spawns the same task **at most once** when either of the following conditions is met:

- Plans.md `cc:WIP` status has not been updated for more than **10 minutes** (600 seconds)
- CC core outputs a stall log (`subagents stalling mid-stream fail after 10 minutes`)

If the same condition recurs after re-spawn, escalate. This does not affect the worker parallelism decision — stall detection is Lead's responsibility only. See the "Stall Detection — 2-layer defense" section in [`agents/worker.md`](../agents/worker.md) for details.

## Execution flow

1. Lead decomposes tasks and creates a `sprint-contract`
2. Lead spawns workers
3. Worker performs implementation, preflight, verification, and commit preparation
4. Worker returns `advisor-request.v1` only when a consultation condition is met
5. Lead calls Advisor and returns `advisor-response.v1` to the same Worker
6. After Worker returns results, Lead runs the review
7. Lead merges to main only on `APPROVE`

## Review loop

| Condition | Lead's action |
|------|-------------|
| `review-result.v1.verdict == APPROVE` | Cherry-pick and commit to main |
| `review-result.v1.verdict == REQUEST_CHANGES` | Return correction request to the same Worker |
| Correction requires spec / Plans / API / permission / billing / migration decisions | Ask user for decision via AskUserQuestion. Do not guess and correct |

Correction loop maximum: 3 iterations.
Do not enter a 4th iteration — Lead escalates the task.

`harness-review` uses TeamAgent Debate when needed.
This does not expand the Reviewer's decision authority; it is a means of gathering read-only perspectives
from Spec Agent / Plans Agent / Regression Agent / Skeptic Agent.
The final verdict is still issued by Reviewer based on `review-result.v1` and clear acceptance criteria.

## Fixed SendMessage pattern

When Lead returns a correction to Worker, use the following syntax:

```text
SendMessage(
  to: "{worker_agent_id}",
  message: "Please fix the following critical/major findings:\n\n{issues}\n\nAfter fixing, run git commit --amend and return completion."
)
```

## Merging to main during breezing

Worker commits to a worktree or feature branch.
After `APPROVE`, Lead incorporates into main with the following 2 commands:

```bash
git cherry-pick --no-commit {worktree_commit_hash}
git commit -m "feat: {task_description}"
```

Worker does not update Plans.md to `cc:done` until Lead has merged to main.

## Advisor boundaries

- Advisor only returns `PLAN | CORRECTION | STOP`
- Advisor does not return `APPROVE | REQUEST_CHANGES`
- Advisor does not edit code
- Reviewer looks only at the final artifact, not the Advisor's suggestion text
- Phase 61's weak-supervision cue only increases Advisor's input information — it does not expand the response types or final decision authority

## Codex bridge

> **Archived for v1**: Codex is a non-Claude runtime and is out of scope for v1. The following is historical design context.

The two standard commands for delegating from Claude Code to Codex are:

```bash
bash scripts/codex-companion.sh task --write "task content"
bash scripts/codex-companion.sh review --base "${TASK_BASE_REF}"
```

Do not write raw `codex exec` as the team standard procedure.

## 2.1.111 Priority rules

- `xhigh` is the caller-side reasoning intensity setting. Worker prompts do not auto-detect from strings
- `/ultrareview` is the caller-side review entry point. The review artifact contract stays `review-result.v1`
- `--auto-mode` is an opt-in rollout. Do not make it the shipped default

## Permission mode

Do not include `permissionMode` in plugin subagent frontmatter.
In Claude Code plugin agents, agent-local `permissionMode` is ignored, so
permissions are inherited from the parent session and plugin settings.

Safety boundaries are maintained through:

- Plugin-level hooks
- Go guardrails
- Worker preflight
- Reviewer judgment

`--auto-mode` is an opt-in for rollout.
Do not use it as a default.

### Background permission mode retention (CC 2.1.141+)

When a teammate is moved to the background via `/bg` / `←←` / `claude agents`,
CC 2.1.141+ retains the permission mode at launch time (does not revert to default).

- Lead operates with the assumption that the mode explicitly set with
  `claude agents --permission-mode <mode>` is maintained after backgrounding.
- No need to re-inject breezing teammate permission mode.
  CC core guarantees mode retention even for special launches that previously used `--auto-mode`.
- Exception: Even teammates launched with `bypassPermissions` do not override
  `.claude-plugin/settings.json`'s `permissions.deny` / `autoMode.hard_deny` (multi-layer defense is maintained).

### Dispatched sessions via `claude agents` (CC 2.1.142+)

When Lead launches a dispatched background session with
`claude agents --add-dir / --settings / --mcp-config / --plugin-dir /
--permission-mode / --model / --effort / --dangerously-skip-permissions`,
refer to `docs/agent-view-policy.md` for flag usage conditions.
Separation from the teammate spawn workflow (breezing skill / Agent tool) is a prerequisite.

## Team size

- Standard is 3 to 5 teammates
- Typical Harness configuration is `Worker 1..3 + Reviewer 1`
- Advisor and Scaffolder are added only when needed
