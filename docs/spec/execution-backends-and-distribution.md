# Spec Sub-Spec: execution-backends-and-distribution

This sub-spec is part of the `spec.md` product contract. SSOT order is `spec.md` core > `docs/spec/*` sub-specs > `Plans.md`.

## Execution Backend Contract

Harness adopts the **Kernel + Prompt Pack** model. `harness work` assembles the
embedded prompt pack plus the resolved task and emits it for the host to
execute; the binary does not call an LLM and is not a self-built agent loop or a
direct-API driver. A self-driving agent loop was evaluated and rejected: native
hooks already give per-action gating, so the kernel adjudicates while the host
runs the model. ACP is not adopted — the three hosts' native pre-action hooks
provide per-action enforcement, so no cross-host protocol is required.

The three execution backends are Claude (the native host), Codex, and Cursor.
All three converge on the **same** `harness hook pre-tool` entrypoint through
their native pre-action hook:

| Backend | Native pre-action event | Deny mechanism |
|---------|-------------------------|----------------|
| Claude | `PreToolUse` | exit code 2 |
| Codex | `PreToolUse` | exit code 2 |
| Cursor | `preToolUse` | exit code 2 |

Deny is exit code 2 across all three hosts; that is the universal enforcement
contract. The kernel does not duplicate a rule engine per host — every host's
generated hook routes to one `bin/harness hook pre-tool`, which runs the R01-R13
`go/internal/policy` engine. `go/internal/hookcodec` normalizes each host's
stdin shape (`session_id` vs `conversation_id`, `tool_input` vs
`command`/`file_path`, event-name casing) into one rule-engine input, and emits
each host's deny shape (`permissionDecision` for Claude/Codex, `permission` for
Cursor) so the rule table itself never changes per host.

Non-Claude backends are driven through companions. When `harness` drives Codex
or Cursor as an execution engine (the harness-drives-the-tool direction), the
companion returns a normalized `companion-result.v1` envelope
(`go/internal/companionresult`). Those companion-produced changes are untrusted
until they pass the **FLOOR** (`go/internal/floor`): a universal pre-merge gate
that re-evaluates the candidate diff with `harness policy check` (the same
R01-R13 surface the hook calls) plus the contract greps, before any take-in.
The FLOOR is the backstop for paths a native hook cannot see (nested subagents,
in-process shells), so it runs for every backend regardless of which native
hook already fired.

Backend selection precedence (highest first): a per-command flag (e.g.
`--backend cursor`) > the `HARNESS_IMPL_BACKEND` env var > the project
`env.local` entry > the user-scope `~/.config/claude-harness/impl-backend.env`
entry > the call-site default. The global call-site default remains `claude`,
and shipped workflow skills must not hard-code Cursor as their call-site
fallback. A project or user can opt in to Cursor by setting
`HARNESS_IMPL_BACKEND=cursor`; that default must affect all Cursor-capable
surfaces, not only Breezing. Project scope overrides user scope.

**Resolver-only entry**: The sole canonical entry for choosing a backend is
`scripts/resolve-impl-backend.sh`. Direct env reads in implementations or skill
prose are forbidden; the resolver resolves precedence across env, per-run flags,
project file, and user file in one pass.

Backend is role-scoped: the implementation (worker) role uses the selected
backend. The primary review and advisor roles stay on the brain (the `claude`
host); per-role models resolve via `scripts/model-routing.sh`, and the
`HARNESS_BRAIN_MODEL` opt-in described below affects only the `deep`/`advisor`
tiers — the primary `review` tier is not changed by it. The self-review
prohibition is scoped to the producing
context, not the model family: the session that produced a diff must never
review its own output, but a fresh-context reviewer session on the same
backend (for example the cursor `review` tier, `composer-2.5-fast`) may run
an advisory pre-review pass before the brain's primary review. A pre-review
session qualifies as fresh-context only when it shares no conversation state
with the producing worker session and starts from the diff plus the task
brief. Pre-review findings are advisory input to the brain; the primary
verdict always remains with the brain reviewer, and Cursor never owns the
primary verdict.

Cursor-capable host packages must expose the Cursor namespace as first-class
commands. This surface is pre-release, so Harness does not provide legacy
aliases for the earlier `cursor-do` / `cursor-ask` naming:

- `cursor:setup`: configure or verify the Cursor package, `cursor-agent`, and
  local/project backend defaults.
- `cursor:do`: write delegation through an isolated worktree, Lead diff review,
  and cherry-pick.
- `cursor:ask`: read-only delegation through `cursor-companion.sh task` without
  `--write`, worktree, or cherry-pick.
- `cursor:review`: read-only advisory Cursor review; primary verdict remains
  on the host brain.
- `cursor:rescue`: diagnose Cursor backend setup, resolution, and companion
  failure paths.

Skill frontmatter `name` fields remain validator-safe lowercase hyphen ids
(`cursor-do`, `cursor-ask`, `cursor-setup`, `cursor-review`, `cursor-rescue`).
Codex defaultPrompt uses those registered `$cursor-<verb>` skill ids for
name-based invocation; descriptions and prose retain the `cursor:<verb>`
namespace as the user-facing mental model.

The concrete model for any host+role is resolved by
`scripts/model-routing.sh --host <backend> --role <role>`. This contract does
not reimplement model selection. The claude-host brain tiers (`deep`,
`advisor`) default to `claude-opus-5` (Opus 4.8 was retired from the catalog
on 2026-07-25; the claude lineup is brain = Opus 5, review = Fable 5,
worker = Sonnet 5). Unset, empty, `opus`, or `opus5` keeps the default;
setting `HARNESS_BRAIN_MODEL=fable` opts those two tiers into
`claude-fable-5`; any other value fails with exit 2 instead of falling back
silently. The opt-in never changes the worker or review tiers and never
touches the codex/cursor catalogs.

Cursor remains `internal-compatible`, not a public `supported` claim. The
shipped `harness` CLI keeps Cursor opt-in by default; individual
local environments may set `HARNESS_IMPL_BACKEND=cursor` in env, project
`env.local`, or user-scope config to make Cursor the resolved default. If Cursor
is selected but not configured, the workflow must fail with setup guidance
rather than silently claiming Claude/Codex parity.

Containment for cursor write delegation relies on a dedicated-`.git` worktree
plus Lead diff review and cherry-pick as the real boundary. Per Cursor's
official security docs (cursor.com/docs/agent/security), file writes have no
project-folder confinement and command allowlists are "best-effort, not a
security guarantee", so containment cannot be delegated to Cursor.

## Orchestration Visibility Contract

Backend selection is invisible at runtime: a user cannot tell whether work was
delegated to Codex, Cursor, or kept on Claude. The harness must make the
session's actual backend mix observable, so a user can answer "am I really
orchestrating, or did everything fall back to Claude?" and can show the result
to others.

The contract separates recording from display. Recording is always on; display
is on demand. The harness keeps two scopes: a per-session ledger of the current
session's delegations, and a lifetime accumulator that persists cumulative
per-backend totals across sessions in `.claude/state/orchestration-totals.json`
(project-scoped). Session delegations roll up into the accumulator when the session's tasks are
all complete, and again at session end as a safety net; the rollup always runs
and is never gated behind display. The rollup must
be idempotent per `session_id` so a session counted once is never
double-counted. A user-scope total across all projects is an optional extension,
not required here.

Per-task completion never triggers display; that would spam a multi-task
session. The one allowed automatic surface is a single compact terminal summary,
emitted once when the session's tasks are all complete (the rollup runs first,
so the summary reflects the updated lifetime totals). The HTML scorecard is
never emitted automatically. Surfaces report both the current session mix and
the lifetime totals; the lifetime totals are the primary shareable figure.

The authoritative record is a companion-written ledger. `codex-companion.sh` and
`cursor-companion.sh` append one structured line per delegation to
`.claude/state/orchestration-ledger.jsonl`. Each entry carries only
non-sensitive fields: timestamp, backend, subcommand, write flag, exit code,
duration, session id, and a `counts` flag. The ledger must never contain prompt
text, file contents, or secrets. Only delegation subcommands (`task`, `review`,
`adversarial-review`) set `counts: true`; status/setup/result/cancel calls are
recorded with `counts: false` so polling does not inflate the score.

Claude-side work is not companion-driven, so the scorecard derives Claude
delegation counts from the existing worker spawn trace
(`.claude/state/agent-trace.jsonl`, role `worker`) and merges them with the
ledger. The merged result is an `orchestration-scorecard.v1` snapshot reporting,
per backend: the used count, and a tri-state status — `used` (count > 0),
`available` (backend resolves/configures but unused this session), or
`not-configured` (companion setup fails or binary absent). `not-configured` is a
neutral state, never a failure or warning. The snapshot also reports backend
diversity (how many distinct backends were actually used) and a multi-backend
utilization ratio (non-Claude delegations over total delegations) with a one-line
note stating what the ratio measures.

Two surfaces consume the snapshot: a standalone HTML scorecard rendered through
`scripts/render-html.sh` (redaction layers applied as defense-in-depth, so it is
shareable), produced only on demand; and a compact terminal summary, produced on
demand and additionally emitted once at full-session completion. Neither is
emitted on every task completion. Both report session mix plus lifetime totals.

If the ledger or trace is missing or unreadable, the scorecard degrades to
"no delegations observed" rather than erroring; absent observation is not the
same as absence of work.

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

## Host Distribution Contract

Distribution is a single `harness` CLI binary plus the manifests and mirrors that
hosts read directly. Per-host shims — the hooks.json configs, the skill/agent
mirrors, the manifest, and the catalog docs — are generated from one source
(`hosts.toml`, `skills/`, and the embedded prompt pack), never hand-maintained,
and are committed-and-drift-checked rather than gitignored. The reason they stay
committed: the Claude plugin marketplace clones the repo and reads
`.claude-plugin/*` directly, and `scripts/setup-codex.sh` / `setup-opencode.sh`
copy the committed mirror into the host — there is no install-time generation
step, so the generated artifacts must be present in the distributed tree. Drift is
prevented by CI gates (`harness gen --check`, `sync-skill-mirrors.sh --check`),
not by regenerating on the target. There is one version: a single git tag.
Manifests and mirrors do not carry independently bumped versions, and there is no
separate per-host package to release.

Rules:

- The release unit is the `harness` binary plus `hosts.toml` and the embedded
  prompt pack. Host shims are regenerated from those by `harness gen`; they are
  never the source of truth.
- `harness gen` writes each host's native hook config to its `hook_path` from
  `hosts.toml` (`.claude-plugin/hooks.json`, `.codex/hooks.json`,
  `.cursor/hooks.json`), each routing to `bin/harness hook pre-tool`. `harness
  gen --check` diffs the generated output against golden fixtures in CI so the
  generator cannot drift. The generator writes the Codex and Cursor hook configs;
  the Claude `.claude-plugin/hooks.json` is hand-maintained across its full event
  set and is not overwritten, but `harness gen --check` verifies its PreToolUse
  guardrail group still matches `hosts.toml`, so the pre-action route shared by
  all three hosts cannot drift even though the rest of that file is not generated.
- A host's generated shim must not cross-contaminate another host: the Codex
  artifact contains only Codex hook config and the Codex skill/agent mirror, the
  Cursor artifact only Cursor's, and so on. Cross-host manifests never appear in
  a single host's generated tree.
- Generated component paths must stay inside the install package and must not use
  `..` relative paths. The generator normalizes to in-package locations
  (`./skills/`, `./agents/`, or equivalent).
- The generator normalizes component metadata so each target host actually
  surfaces it. Skills authored for the Claude slash-only convention
  (`user-invocable: true`) are dropped by Cursor, so the Cursor artifact is
  generated with `user-invocable: false` to register them as Agent-Decides
  skills invokable via `/skill-name`; the Claude artifact keeps the original
  `user-invocable: true` slash contract.
- A Cursor local install lives under `~/.cursor/plugins/local/<name>`. Cursor's
  plugins doc supports symlinking an external plugin repo into that directory
  (`ln -s`); install tooling nonetheless real-copies the generated package so the
  install is self-contained and idempotent and does not depend on an external
  build path staying present (symlinks are also unreliable on Windows).
- Codex and Cursor remain below Claude in support tier until their own workflow
  smoke and release gates pass. Generating their shims does not by itself promote
  a host to `supported`.

Two layers, not one. The `hook_path` configs above (`.codex/hooks.json`,
`.cursor/hooks.json`) are the enforcement-wiring layer `harness gen` emits to
route each host's native pre-action hook to `bin/harness hook pre-tool`; each is a
first-class standalone hook location on its host and needs no plugin to run (Codex
discovers `~/.codex/hooks.json` and `<repo>/.codex/hooks.json` next to its config
layers when trusted; Cursor reads project `.cursor/hooks.json`). The
install-delivery layer is separate: `scripts/build-host-plugin-dist.sh` packages
each host's native plugin bundle (`.claude-plugin/` / `.codex-plugin/` /
`.cursor-plugin/`) carrying the generated skills/agents, which setup installs into
the host (`~/.cursor/plugins/local/<name>`, the Claude marketplace clone,
`~/.codex/plugins/<name>` + `~/.agents/plugins/marketplace.json`). Using a host's
native plugin as the install envelope does not contradict "single `harness` CLI,
not a host plugin": the binary plus `hosts.toml` and the embedded prompt pack stay
the sole source of truth and the release unit; the plugin is only the generated,
committed-and-drift-checked envelope that carries the shims to the host.

Cutover status (Phase 91.8(b), landed as generated-and-committed): the manifests
and mirrors are generated from one source and kept committed under CI drift gates,
not untracked. Investigation of the real distribution paths settled this: both
paths consume committed files with no install-time generation — the Claude
marketplace clones the repo and reads `.claude-plugin/*`, and `setup-codex.sh` /
`setup-opencode.sh` copy the committed `codex/.codex/skills` and `opencode/skills`
mirrors — so untracking and gitignoring them (the originally sketched
"generated-on-install" model) would break installation at the distribution target.
Instead the SSOT is `skills/` + `hosts.toml` + the prompt pack: `sync-skill-mirrors.sh
--check` pins the mirrors to `skills/`, `harness gen --check` pins the Codex/Cursor
hooks.json to `hosts.toml` and verifies the committed Claude PreToolUse guardrail
group matches the descriptor, and `harness gen docs --check` pins the catalog. The
artifacts stay committed so distribution keeps working, and the gates make them as
drift-proof as gitignored build output would be. A future pure-CLI install that
regenerates on the target could revisit untracking; it is out of scope while
marketplace and setup-copy distribution is the supported path.

## Clean Mode And Compatibility Mode

Harness defines two user-facing environment profiles. These are Harness
diagnostic and guidance profiles, not host-native global toggles. Cursor may
still load Claude/Codex skill directories when the user enables host
compatibility import in the Desktop app.

| Profile | Meaning | Expected UX |
|---------|---------|-------------|
| `clean` (default) | One host, one Harness route. Cursor users should see Cursor package skills only after cleanup. | Fewer duplicate skills/plugins; explicit host-specific invocation. |
| `compatibility` | Cross-host skill import remains enabled. Harness warns about duplicates but does not force-disable host import settings. | More skills visible; Harness recommends namespaced or explicit invocation. |

Harness must not delete user home configuration by default. Environment cleanup
uses dry-run inventory first, then user-confirmed archive or disable actions.
Compatibility import in Cursor Desktop can reintroduce duplicate skills even
after clean distribution packages are installed; Harness documents that limit
and detects duplicate origins before suggesting fixes.

