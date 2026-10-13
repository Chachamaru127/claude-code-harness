<p align="center"><img src="docs/images/claude-harness-logo-with-text.png" alt="Claude Harness" width="220"></p>



<h1 align="center">The AI writes the code.<br>You still manage the work.</h1>

<p align="center"><a href="docs/images/readme/hero-motion-en.svg"><picture><source media="(prefers-reduced-motion: reduce)" srcset="docs/images/readme/hero-motion-en-poster.svg"><img src="docs/images/readme/hero-motion-en.gif" alt="Scattered work becomes a plan, implementation and tests, and a separate review before your final decision" width="880"></picture></a></p>

<p align="center"><strong>Delegate the plan, checks, and review.<br>Judge the result.</strong></p>

Use your existing Claude Code, Codex CLI, Cursor, or Grok account.
[Choose your tool](#install-by-tool) · [Try one small request](#your-first-request)

English | [日本語](README_ja.md)
[![Latest release](https://img.shields.io/github/v/release/Chachamaru127/claude-code-harness?display_name=tag&sort=semver)](https://github.com/Chachamaru127/claude-code-harness/releases/latest)

## Install and start

You need an installed, signed-in coding assistant and a project folder you can
write to. For an existing Harness setup, read the [migration guide](docs/onboarding/migration.md)
before reinstalling or cleaning up files.

For Claude Code, open a terminal (the app where you type system commands) and run:

```bash
claude
```

Then enter these commands **inside Claude Code**, one at a time:

```text
/plugin marketplace add Chachamaru127/claude-code-harness
/plugin install claude-code-harness@claude-code-harness-marketplace
/harness-setup
```

`/harness-setup` prepares the project's instructions and checks. Review any
proposed project changes before accepting them. Installation time depends on
your existing setup and connection.

**Current Claude Code limitation:** newer builds can reject the name
`claude-code-harness` as reserved for Anthropic. If installation reports that
error, this route is blocked on that build. Our local check reproduced it with
Claude Code 2.1.296 on 2026-10-13. Keep the exact error and
[report it](https://github.com/Chachamaru127/claude-code-harness/issues); repeating
setup does not resolve the reserved-name rejection. The tool table describes verified paths, not every future
assistant version.

For other tools, choose the route in [Install by tool](#install-by-tool).
The [onboarding guide](docs/onboarding/index.md) covers the same starting point
with more detail.

## Your first request

You decide the outcome, the completion criteria, and the actions you authorize.
Review means checking the change separately from its implementation.


Start with one small change whose result you can check:

```text
/harness-plan Stop the contact form from sending twice. When I click Send twice quickly, only one message should be created. Keep the existing fields and appearance.
```

Harness drafts `spec.md` and `Plans.md` for you. Read the proposed behavior,
what it will change, how it will test the result, and anything still unknown.
Approve the plan or correct it before work starts.

Then run:

```text
/harness-work all
/harness-review
```

The first command works through the approved tasks. The second requests a
separate review. On Codex, use `$harness-plan`, `$harness-work all`, and
`$harness-review` instead of the slash form.

At the end, check the actual result: try the form, read which tests passed,
and look for unresolved problems. A review-ready change can still need a
real service connection or your acceptance before it is ready to publish.

## What you can delegate

| Re-explaining the work | Tracking what is done | Checking “it works” |
|---|---|---|
| Keep the specification and plan in files | See task status and pending decisions | Get actual test results and a separate review |

## The work steps

<p align="center"><img src="docs/images/readme/loop-en.svg" alt="Plan, work, review, and release" width="880"></p>

Harness keeps the specification in `spec.md` and tasks in `Plans.md`.
Think of them as a shared job sheet and checklist. In practice, the assistant
writes the drafts and updates the records; you approve the intended result.

A **skill** is a reusable set of instructions for the assistant. The 5 verb skills
cover planning, work, review, checking status, and release. Setup is separate.

| Request or command | What you receive | Your decision |
|---|---|---|
| `/harness-plan` | A specification, tasks, completion criteria, unknowns, and operations that need permission | Approve or correct the scope and criteria |
| `/harness-work 3` | Changes and required checks for task 3 | Resolve a new permission or product decision if one is needed |
| `/harness-work all` | Work on all approved tasks, with checks and corrections | Judge the result against the criteria |
| `/harness-review` | Findings from a reviewer separate from the implementation | Serious findings block completion; minor suggestions can remain |
| `/harness-sync` | Differences between the recorded plan and observed project state | Decide what to correct when they disagree |
| `/harness-release` | A release plan, version changes, and publication checks | Approve the complete publication plan before it runs |

When a task requires test-first development, the assistant demonstrates a
failing test before implementing the fix, then runs it again. Other tasks use
the checks their plan requires. A wording change need not use the same tests
as a payment feature.

The assistant continues reversible work inside the approved scope. It stops
the affected operation when a new authorization or material product decision
is needed. Failed checks and exhausted correction limits are reported as
unfinished work, with evidence and a next step.

## What you can see during work

| View | When to use it | What it tells you |
|---|---|---|
| Plan Brief | Before approving a plan | Intended result, choices, risks, and completion criteria |
| Progress (`/harness-progress`) | During work | Task status and pending decisions recorded in `Plans.md` |
| Acceptance | Before publication | Which completion criteria passed, failed, or remain unverified |

The progress percentage counts recorded tasks. It is not the percentage of
features proven to work. For example, “8 of 10 tasks complete” can coexist
with a failed end-to-end test. Claude Code refreshes the progress page after
edits or commands, at most once every 60 seconds; other tools have different
update behavior.

To continue after an interruption, use:

```text
/harness-work --resume latest
```

This recovers the recorded plan, changes, check results, and remaining work.
Ask the assistant to show what was recovered before relying on it. Optional
[harness-mem](https://github.com/Chachamaru127/harness-mem) adds memory and search
across sessions; the basic workflow does not require it.

## Permissions and limits

Harness checks operations connected to its execution hooks (checks run before
or after an assistant action). The **Go-native guardrail engine** is the bundled
program that applies those rules; it does not require Node.js to run.

| Check layer | What it checks | What you control |
|---|---|---|
| Runtime floor | Billing, external sends, secret reads, production deployment, and destruction outside the task's working copy | Named permissions under the category's rules; there is no global off switch |
| Guardrails | Protected files, direct pushes to the shared main branch, forced pushes, and changes to recorded history | Some rules are configurable for the project |

Known permissions can be scoped and collected with the plan where the
operation supports it. The permission details depend on the operation and its configured rules. The assistant must not rewrite protected settings to pass its own check.
Stop reasons identify the rule and action so you can inspect the cause.

These checks do not guarantee every command is contained. Coverage depends
on the tool and how the operation is launched. Cursor has no traditional
filesystem isolation; its restrictions are applied by Harness. Native Codex
child agents can inherit their parent's permissions. A reviewer role alone
is not read-only isolation; the companion review route explicitly requests
read-only execution. Read the [differences between tools](docs/hardening-parity.md)
and [Cursor limits](docs/CURSOR_INTEGRATION.md) before delegating sensitive work.

## Cost and project data

Harness is free to use and modify under the MIT license. Your coding assistant, model
provider, and any connected services have their own fees and terms. More
workers, reviews, and repeated attempts can use more of those services.
Harness does not provide an account or a universal spending cap.

Project plans and task records are files in your project. Execution state is
kept under `.claude/state/`. Setup also adds project guidance and check files. Content read by the
coding assistant is still subject to that assistant's data handling. Installing
Harness does not make model requests local or prevent the assistant from
sending project content to its provider. Optional memory and external
connections have their own configuration and data boundaries.

## Install by tool

The tier describes the checked Harness integration path. `supported` means a
verified path; `internal-compatible` means limited integration; `candidate`
means experimental work; `future/unsupported` means no current user route.
These labels do not promise identical permissions or features across tools.

| Tool | Tier | How to start or what is missing |
|---|---|---|
| Claude Code | `supported` | Use the marketplace commands above, then `/harness-setup` |
| Codex CLI | `supported` | [Run `scripts/setup-codex.sh --user`](codex/README.md#option-1-script-recommended-user-based), then restart Codex |
| Cursor | `supported` | Run `scripts/setup-cursor.sh`, then reload Cursor; read its permission limits above |
| Grok | `supported` | Run `scripts/setup-grok.sh`, then start a new session |
| OpenCode | `internal-compatible` | Run `scripts/setup-opencode.sh` for instructions and skills; the full execution behavior is not verified as equivalent |
| Codex app | `candidate` | The Codex CLI installation does not establish an app installation path |
| Hermes Agent | `candidate` | Experimental manual skill loading; automatic guardrail enforcement is not connected |
| GitHub Copilot CLI | `candidate` | Experimental manual instructions; no verified Harness installation route |
| Antigravity CLI | `future/unsupported` | No end-user installation route |

For setup scripts, first download this repository with Git (the program that
manages project versions):

```bash
git clone https://github.com/Chachamaru127/claude-code-harness.git
cd claude-code-harness
```

Then run the script for your tool. The Codex `--user` route writes user-level
skills, rules, and managed profiles, so it applies across projects. Existing
`worker.toml` and `reviewer.toml` are backed up and replaced, even if you created
them yourself. Read the [installation details](docs/onboarding/install.md) for
project-local alternatives, update steps, and removal.

## Larger jobs and model choices

`/breezing` divides larger approved work between agents. `/harness-loop`
repeats work within a limit and can ask an advisor for help. It defaults to
eight cycles. Reaching the limit is not completion. Use `/harness-loop status`
to inspect it and `/harness-loop stop` to stop further execution.

Your explicit model and reasoning-effort choices take priority in their
execution path. Reasoning effort is the amount of processing a model uses to
think. Changing the main conversation does not change every child agent's
settings. See [model choices](docs/model-routing-policy.md) and
[Codex Breezing role routing](codex/README.md#codex-breezing-role-routing) before
changing defaults.

The experimental `HARNESS_AUTO_APPROVE=on` option only records an eligibility
check. It is off by default and does not skip approval prompts.

## Update or troubleshoot

For Claude Code, run these inside the assistant:

```text
/plugin update claude-code-harness
/harness-setup
```

For a script installation, update your repository copy with `git pull --ff-only`,
rerun the same setup script, and restart or reload the assistant.
Check the [English changelog](CHANGELOG.md) or [Japanese changelog](CHANGELOG_ja.md)
for behavior changes and required action before updating.

If commands are missing, check that installation targeted the tool you are
using and that you restarted it. The [installation check](docs/onboarding/skill-trigger-acceptance.md)
shows what a successful first invocation looks like.
From your Harness repository copy, `bin/harness doctor --migration-report`
inspects old setup files and memory state without deleting them.

If a check blocks work, keep the exact error and ask the assistant to explain
the rule, target, and required permission. Do not treat a failed check as a
completed task. Report reproducible installation or execution problems in
[GitHub Issues](https://github.com/Chachamaru127/claude-code-harness/issues).

## Requirements

CLI means the edition you run from a terminal. A repository is a project folder
whose changes are tracked with Git.


- An installed coding assistant and access to its account or model provider.
- Claude Code v2.1+ for the Claude path; check [compatibility notes](docs/CLAUDE_CODE_COMPATIBILITY.md) for dated observations and platform limits.
- A project repository with write access. Setup scripts require Git and a shell that can run them.
- No Go installation is needed for bundled binaries. Building the current source requires Go 1.26.0 or later; optional skills can have additional requirements.

## Documentation

- [Start with your tool](docs/onboarding/index.md), [installation and removal](docs/onboarding/install.md), and [existing-user migration](docs/onboarding/migration.md).
- [Language settings](docs/i18n.md): English is the default. Ask “Please respond in Japanese” to switch the conversation; project settings and environment variables are also available.
- [What gets installed](docs/distribution-scope.md) and [checks for a whole plan](docs/evidence/work-all.md).
- [Product guide in Japanese](docs/reports/2026-09-06-cch-product-guide-v5.15.0.html).

For a project without a pinned language setting, you can also choose Japanese
when starting Claude Code:

```bash
CLAUDE_CODE_HARNESS_LANG=ja claude
```

A project language setting takes priority over this environment variable.
An explicit instruction in the conversation takes priority over both.

## Contributing

Describe what you expected, what happened, and how to reproduce it in an Issue.
For changes, see [CONTRIBUTING.md](CONTRIBUTING.md).

## Acknowledgments

[AI Masao](https://note.com/masa_wunder) contributed ideas on organizing skills;
[Beagle](https://github.com/beagleworks) contributed test integrity patterns.

## License

[MIT](LICENSE.md).
