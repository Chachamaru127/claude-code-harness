# Model Routing Policy

Status: adopted
Last updated: 2026-06-11

This document defines the default model and reasoning-effort routing for
Claude Code, Codex, Cursor, and Grok in Harness workflows.

## Decision

Use explicit role tiers, not prompt-text inference.

Harness must route model and effort from the workflow role:

- `lite`: cheap, read-heavy, low-risk work
- `standard`: ordinary implementation and setup
- `deep`: architecture, security, cross-repo, migration, and failure recovery
- `review`: quality gates and adversarial checks
- `release`: procedural release and public-surface checks
- `long-context`: large repository or long-session context work

Do not infer effort from free-text markers such as "think harder". A caller may
still ask for one-off deeper reasoning, but durable routing belongs in config,
agent frontmatter, or wrapper arguments.

## Official Evidence

Claude Code supports model aliases and explicit model IDs. `opusplan` uses Opus
in plan mode and Sonnet in execution mode, which matches Harness' Plan -> Work
split. Claude Code settings can pin `model`, restrict `availableModels`, and set
default alias targets through `ANTHROPIC_DEFAULT_*_MODEL` environment variables.
Official docs: https://code.claude.com/docs/en/model-config

Claude Code effort is configurable through `/effort`, `/model`, `--effort`,
`CLAUDE_CODE_EFFORT_LEVEL`, `effortLevel`, and skill/subagent frontmatter.
Frontmatter overrides the session level, while `CLAUDE_CODE_EFFORT_LEVEL`
overrides both. Official docs: https://code.claude.com/docs/en/model-config

Claude subagents can set `model` to an alias, full model ID, or `inherit`.
Resolution order is `CLAUDE_CODE_SUBAGENT_MODEL`, per-invocation model,
frontmatter model, then main conversation model. Therefore Harness must not set
`CLAUDE_CODE_SUBAGENT_MODEL` by default because it would flatten per-agent
routing. Official docs: https://code.claude.com/docs/en/sub-agents

Anthropic's current lineup is the Claude 5 family: Fable 5 (Mythos-class, the
most intelligent generally available model), Opus 5 for complex reasoning and
agentic coding, Sonnet 5 as the best speed / intelligence balance, and Haiku
4.5 as the fastest model. Harness retired Opus 4.8 from its claude catalog on
2026-07-25 (operator decision): brain = Opus 5, review = Fable 5,
worker = Sonnet 5. Official docs:
https://platform.claude.com/docs/en/about-claude/models/overview

Codex offers `gpt-5.6-sol` / `gpt-5.6-terra` as its top coding tier,
`gpt-5.4-mini` for lighter coding tasks and subagents, and
`gpt-5.3-codex-spark` as an optional research-preview fast iteration model for
ChatGPT Pro users. Harness routes delegated Codex work to `gpt-5.6-sol` at
`xhigh` (operator decision 2026-07-24; `terra` is the accepted alternative).
Official docs: https://developers.openai.com/codex/models

Codex config supports `model`, `review_model`, `model_reasoning_effort`, and
agent concurrency settings such as `agents.max_threads` / `agents.max_depth`.
Custom Codex agents can set their own `model`, `model_reasoning_effort`, and
`sandbox_mode`. Official docs:
https://developers.openai.com/codex/config-reference and
https://developers.openai.com/codex/subagents

Cursor subagents support frontmatter `model: inherit|<model-id>`, `readonly`,
and background execution. The Task tool accepts an explicit `model` parameter.
Cursor CLI supports `--model` for per-run selection. Cloud Agent API accepts
`model.id` and `model.params`. Official docs:
https://cursor.com/docs/subagents ,
https://cursor.com/docs/cli/overview ,
https://cursor.com/docs/cloud-agent/api/endpoints

## Override Priority (All Hosts)

1. **Explicit caller override** — Task/subagent `model`, CLI `--model`, or
   companion `--model` when the wrapper documents it.
2. **Harness routed default** — `scripts/model-routing.sh --host <host> --role …`
3. **Session inherit** — subagent `model: inherit` or host session default.

Residual risk: team/admin/plan-unavailable models may fall back silently unless
smoke or operator checks catch them. Do not treat availability in one account as
guaranteed for every Harness user.

## Claude Code Routing

| Harness tier | Claude model | Effort | Use cases |
| --- | --- | --- | --- |
| `lite` | `claude-haiku-4-5` or `haiku` | `low` or `medium` | read-only search, docs cleanup, simple summaries, cheap side research |
| `standard` | `claude-sonnet-5` | `medium` by default, `high` for code-risk tasks | normal worker implementation, setup, tests, scoped refactors |
| `deep` | `claude-opus-5` | `xhigh` | architecture, security, migration, cross-repo decisions, repeated failures |
| `review` | `claude-fable-5` | `xhigh` | independent review; primary verdict tier (operator decision 2026-07-25) |
| `advisor` | `claude-opus-5` | `xhigh` | PLAN / CORRECTION / STOP decisions after blocked execution |
| `release` | `claude-sonnet-5` | `high` | release preflight, changelog, version/tag/GitHub Release checks |
| `long-context` | `sonnet[1m]` | `high` | large repo reading, long sessions, context-heavy comparison |

Recommended Claude session default:

```json
{
  "model": "opusplan",
  "availableModels": [
    "opusplan",
    "claude-opus-5",
    "claude-fable-5",
    "claude-sonnet-5",
    "claude-haiku-4-5",
    "sonnet[1m]"
  ],
  "effortLevel": "high",
  "env": {
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-5",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-sonnet-5",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "claude-haiku-4-5"
  }
}
```

Notes:

- `opusplan` is the preferred operator default because it naturally spends Opus
  on planning and Sonnet on execution.
- Keep `CLAUDE_CODE_SUBAGENT_MODEL` unset by default. Use it only as a temporary
  emergency override, because it outranks per-agent model settings.
- Do not set `max` in shared settings. `max` is session-only and should be used
  only for explicit one-off experiments.
- `ultrathink` is a legacy free-text marker. Do not use it for durable routing.
  On the Claude 5 family, control reasoning depth with `effort` (`high`/`xhigh`),
  not prompt markers. If reasoning looks shallow on a hard task, raise effort
  rather than prompting around it.
- `HARNESS_BRAIN_MODEL=fable` opts the `deep` / `advisor` tiers into
  `claude-fable-5` (Fable 5). Unset, empty, `opus`, or `opus5` keeps
  `claude-opus-5`; any other value exits 2 instead of falling back silently.
  The opt-in is claude-host only and never changes the `standard` / `review`
  tiers.

## Codex Routing

| Harness tier | Codex model | Reasoning effort | Use cases |
| --- | --- | --- | --- |
| `lite` | `gpt-5.4-mini` | `minimal` or `low` | explorer subagents, simple docs, small cleanup, cheap parallel fan-out |
| `standard` | `gpt-5.6-sol` | `xhigh` | normal implementation, test fixes, focused refactors |
| `deep` | `gpt-5.6-sol` | `xhigh` | cross-file architecture, security, migrations, failed-loop recovery |
| `review` | `gpt-5.6-sol` via `review_model` | `xhigh` | `/review`, companion review, adversarial diff review |
| `release` | `gpt-5.6-sol` | `high` | release-preflight and PR closeout evidence |
| `spark` | `gpt-5.3-codex-spark` | `low` | optional Pro-only real-time UI micro-iteration; never required |

Recommended Codex baseline:

```toml
model = "gpt-5.6-sol"
model_reasoning_effort = "xhigh"
review_model = "gpt-5.6-sol"

[agents]
max_threads = 8
max_depth = 1
```

Recommended project-scoped Codex custom agents:

```toml
# .codex/agents/explorer.toml
name = "explorer"
description = "Read-only codebase exploration and evidence gathering."
model = "gpt-5.4-mini"
model_reasoning_effort = "low"
sandbox_mode = "read-only"
developer_instructions = "Inspect files and return concise evidence with paths. Do not edit files."
```

```toml
# .codex/agents/worker.toml
name = "worker"
description = "Scoped implementation worker for a single task."
model = "gpt-5.6-sol"
model_reasoning_effort = "xhigh"
sandbox_mode = "workspace-write"
developer_instructions = "Implement only the assigned task, run focused checks, and report changed files and validation."
```

```toml
# .codex/agents/reviewer.toml
name = "reviewer"
description = "Read-only reviewer for diffs, risk, and missing tests."
model = "gpt-5.6-sol"
model_reasoning_effort = "xhigh"
sandbox_mode = "read-only"
developer_instructions = "Review evidence-first. Report prioritized findings with file and line references. Do not edit files."
```

Notes:

- Codex CLI `codex exec` uses `--model` / `-m` for per-run model selection and
  `-c model_reasoning_effort="<level>"` for per-run effort overrides.
- `scripts/codex-companion.sh` may continue accepting Harness-level `--effort`,
  but any direct `codex exec` path must translate that into
  `-c model_reasoning_effort=...`.
- `agents.max_depth` stays `1`. Recursive fan-out increases token use and makes
  outcomes less predictable.
- `agents.max_threads = 8` is acceptable for Harness breezing because worker
  routing sends cheap exploration to `gpt-5.4-mini`; if all children use
  `gpt-5.6-sol xhigh`, lower concurrency first.
- Do not make Codex fast mode the default. It is a latency/credit trade-off,
  not an intelligence tier.

## Cursor Routing (adapter candidate)

| Harness tier | Cursor model (router default) | Effort label | Use cases |
| --- | --- | --- | --- |
| `lite` | `composer-2-fast` | `low` | read-only exploration, cheap fan-out |
| `standard` | `composer-2.5-fast` | `medium` | normal worker implementation |
| `deep` | `claude-fable-5` | `xhigh` | architecture, security, recovery |
| `review` | `composer-2.5-fast` | `xhigh` | harness-review / reviewer subagent |
| `advisor` | `claude-fable-5` | `xhigh` | advisor-request decisions |
| `release` | `composer-2.5-fast` | `high` | release preflight wording checks |
| `long-context` | `gemini-3.1-pro` | `high` | large repo reads when available |

Adapter surfaces:

- `.cursor/agents/*.md` frontmatter `model`
- Task tool explicit `model`
- Cursor CLI `--model`
- Cloud Agent API `model.id` / `model.params` (optional evidence)

Notes:

- Cursor remains `candidate`; routing defaults are contract fixtures, not a
  support claim.
- Breezing multitask/background agents may fan out Workers; Reviewer and
  cherry-pick stay serial in core.
- When explicit `model` is set on Task/subagent invocation, routed defaults must
  not override it (`tests/test-model-routing.sh` covers Codex explicit path;
  Cursor uses the same priority rule).
- The `review` tier (`composer-2.5-fast`, `xhigh`) is a fresh-context pre-review
  surface: a reviewer session that shares no conversation state with the
  producing worker may pre-review a diff before the brain's primary review. The
  session that produced a diff never reviews its own output, and the primary
  verdict stays with the brain (spec.md Execution Backend Contract).

## Grok Routing (adapter candidate)

| Harness tier | Grok model (router default) | Effort label | Use cases |
| --- | --- | --- | --- |
| `lite` | `grok-composer-2.5-fast` | `low` | read-only exploration, cheap fan-out |
| `standard` | `grok-composer-2.5-fast` | `medium` | normal worker implementation |
| `deep` | `grok-4.5` | `high` | architecture, security, recovery |
| `review` | `grok-4.5` | `high` | harness-review / reviewer path |
| `advisor` | `grok-4.5` | `high` | advisor-request decisions |
| `release` | `grok-4.5` | `high` | release preflight wording checks |
| `long-context` | `grok-4.5` | `high` | large repo reads (500k context window observed) |

Adapter surfaces:

- Grok CLI `--model`
- `scripts/model-routing.sh --host grok --format json|args|env`
- Skill frontmatter `model` when a skill pins a model (prefer routed default)

Notes:

- Grok remains `candidate`; routing defaults are contract fixtures, not a
  public support claim.
- Observed catalog (2026-07-09, CLI 0.2.93): `grok-4.5`, `grok-composer-2.5-fast`.
- Account catalogs may differ; treat missing models as residual risk, not a
  silent fallback in the router.
- `HARNESS_BRAIN_MODEL` is claude-host only and never changes the Grok catalog.

## Harness Role Defaults

| Harness surface | Claude default | Codex default | Cursor default | Grok default | Why |
| --- | --- | --- | --- | --- | --- |
| Interactive operator session | `opusplan`, `high` | `gpt-5.6-sol`, `high` | `composer-2.5-fast`, `medium` | `grok-composer-2.5-fast`, `medium` | strong default without forcing max spend |
| `/harness-plan` | `opusplan` or Opus 5 for non-trivial planning | `gpt-5.6-sol`, `xhigh` | `claude-fable-5`, `xhigh` | `grok-4.5`, `high` | planning quality affects all downstream work |
| `worker` | Sonnet 5, `medium` to `high` | `gpt-5.6-sol`, `xhigh` | `composer-2.5-fast`, `medium` | `grok-composer-2.5-fast`, `medium` | implementation benefits from iteration and tests |
| `explorer` / read-only fan-out | Haiku 4.5, `low` | `gpt-5.4-mini`, `low` | `composer-2-fast`, `low` | `grok-composer-2.5-fast`, `low` | cheap context isolation |
| `reviewer` | Fable 5, `xhigh` (primary verdict tier) | `gpt-5.6-sol`, `xhigh` | `composer-2.5-fast`, `xhigh` (fresh-context pre-review only; primary verdict on brain) | `grok-4.5`, `high` | review is where deeper reasoning pays |
| `advisor` | Opus 5, `xhigh` (Fable 5 via `HARNESS_BRAIN_MODEL=fable`) | `gpt-5.6-sol`, `xhigh` | `claude-fable-5`, `xhigh` | `grok-4.5`, `high` | blocked-loop decisions need high confidence |
| `release` | Sonnet 5, `high` | `gpt-5.6-sol`, `high` | `composer-2.5-fast`, `high` | `grok-4.5`, `high` | procedural but public-facing |

## Non-Goals

- Do not update global user config automatically.
- Do not force every subagent to the most expensive model.
- Do not route by vague prompt words.
- Do not use model routing to bypass sandbox, approval, or review gates.
- Do not treat availability of a model in one account type as guaranteed for
  every Harness user.

## Implementation Surface

Harness implements the routing contract through `scripts/model-routing.sh`.
The router maps:

```text
tier -> claude model/effort
tier -> codex --model / -c model_reasoning_effort
tier -> cursor model (+ effort label for docs/tests)
role -> tier
```

The router should be tested independently from the current user-level
`~/.codex/config.toml` or `~/.claude/settings.json`, because those files are
operator preferences, not repository truth.

`scripts/codex-companion.sh` uses the Codex route for `task` invocations and
translates companion-level `--effort` into Codex CLI
`-c model_reasoning_effort=...` when structured `codex exec` mode is used.
