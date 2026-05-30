# Cursor Adapter Candidate

Status: candidate evidence boundary
Checked at: 2026-05-28 JST
Phase: `Plans.md` 81.1

## Conclusion

Cursor remains `candidate`.

Harness now has a Cursor adapter skeleton (`.cursor-plugin/`, `.cursor/AGENTS.md`,
`.cursor/agents/`, hooks/MCP config shape) and static smoke tests, but it does not
have verified workflow smoke that proves Plan → Work → Review from Cursor alone.
The existing `docs/CURSOR_INTEGRATION.md` PM handoff path is separate from adapter
support.

## Evidence Boundary

`not_observed != absent`: missing Cursor runtime smoke is not proof that Cursor
cannot support Harness. It is proof that Harness must not claim support yet.

Do not promote Cursor beyond the `candidate` tier until:

- host-specific bootstrap smoke passes,
- release preflight consumes the adapter route,
- README/onboarding wording still separates handoff integration from adapter
  support.

## Harness Evidence (This Repository)

| Artifact | What it proves | What it does not prove |
|---|---|---|
| `docs/CURSOR_INTEGRATION.md` | Cursor PM ↔ Claude Code Harness handoff workflow | Cursor adapter support |
| `.cursor-plugin/plugin.json` | Plugin manifest points at core `skills/` | Marketplace install or runtime skill loading |
| `.cursor/AGENTS.md` | Bootstrap routing guidance for plan/work/review | Automatic runtime routing |
| `.cursor/agents/*.md` | Subagent shape for worker/reviewer/advisor roles | Team execution parity with Claude Agent Teams |
| `.cursor/hooks.json` | Config shape for optional session hooks | Hook enforcement parity with Claude Code |
| `.cursor/mcp.json` | MCP config shape placeholder | MCP trust or runtime wiring |
| `tests/test-cursor-adapter-candidate.sh` | Static adapter contract + optional CLI smoke | Full Breezing multitask proof |
| `scripts/model-routing.sh --host cursor` | Role-tier → Cursor model mapping contract | Account-specific model availability |

Superpowers reference shape (external, not Harness proof):

- `.cursor-plugin/plugin.json` may reference `skills`, `agents`, `commands`, and
  `hooks` in other repositories.
- That shape informed the Harness skeleton but does not upgrade Harness support
  tier by itself.

## Official Cursor Surfaces (Observed 2026-05-28)

Sources checked:

- https://cursor.com/docs/context/rules — project rules (`.cursor/rules`, `AGENTS.md`)
- https://cursor.com/docs/context/skills — Agent Skills discovery and invocation
- https://cursor.com/docs/context/subagents — subagent frontmatter (`model`, `readonly`, background)
- https://cursor.com/docs/agent/hooks — lifecycle hooks (session/tool events)
- https://cursor.com/docs/context/mcp — MCP server configuration
- https://cursor.com/docs/cloud-agent/api — Cloud Agent API (`mode`, `model.id`, `model.params`)
- https://cursor.com/docs/cli/overview — CLI agent with `--model` and mode flags

Observed adapter-relevant mechanics:

| Surface | Harness mapping | Notes |
|---|---|---|
| Rules / `AGENTS.md` | Bootstrap notice + prompt routing | Same conceptual layer as Codex `AGENTS.md`, different enforcement |
| Skills | Core workflow skills via plugin `skills/` path | Skill tool / `$skill` style invocation varies by host |
| Subagents | Worker / Reviewer / Advisor adapter roles | `model: inherit` or explicit model slug; `readonly` for review |
| Task / background agents | Breezing parallel worker smoke target only | Core keeps review + cherry-pick serial |
| Hooks | Optional sessionStart / preflight gate | Secret-free config-shape validation only in static smoke |
| MCP | Optional harness-mem / tool bridge | Trust policy applies; no secret reads in smoke |
| Cloud Agent API | Optional paid/auth evidence | Not required for local Desktop/CLI static gate |
| CLI `--model` | Explicit override surface | Outranks routed default when caller sets it |

Not observed in this repo's smoke (2026-05-28):

- Cursor Desktop plugin marketplace install transcript for this manifest
- Cloud Agent API workflow smoke with auth
- Multitask mode proof for full Breezing cherry-pick loop
- Hook runtime block parity with Claude PreToolUse

## Separation: PM Handoff vs Adapter Support

| Concern | PM handoff (`CURSOR_INTEGRATION.md`) | Adapter candidate (this doc) |
|---|---|---|
| Primary user | Cursor plans/reviews, Claude implements | Operator stays in Cursor for Plan → Work → Review |
| Bootstrap | Shared `Plans.md` + Cursor command templates | `.cursor-plugin/` + `.cursor/AGENTS.md` + skills/agents |
| Parallelism | Out of scope | Maps to subagents / background agents / multitask (smoke target) |
| Support claim | Never implies Cursor adapter support | Remains `candidate` until smoke + preflight pass |
| Verification | Branch + marker sanity | `bash tests/test-cursor-adapter-candidate.sh` |

## cursor-agent CLI fact-check (local, no network)

Local inspection of the `cursor-agent` CLI at `~/.local/bin/cursor-agent`
(version `2026.05.28-a70ca7c`). Confirmed facts come from `cursor-agent --help`
and the model router contract; nothing here was exercised against the Cursor
cloud, so model-call behavior stays `⏳ needs-network`.

| Claim | Status | Source |
|---|---|---|
| `cursor-agent` binary present at `~/.local/bin/cursor-agent` | ✅ confirmed-local | `command -v cursor-agent` |
| Version is `2026.05.28-a70ca7c` | ✅ confirmed-local | `cursor-agent --version` |
| Flags `-p/--print`, `--output-format text\|json\|stream-json`, `--model` exist | ✅ confirmed-local | `cursor-agent --help` |
| Flags `-f/--force`, `--yolo`, `--mode plan\|ask`, `--resume`, `--continue` exist | ✅ confirmed-local | `cursor-agent --help` |
| Flags `--list-models`, `--sandbox enabled\|disabled`, `--trust`, `--workspace`, `-w/--worktree` exist | ✅ confirmed-local | `cursor-agent --help` |
| Auth via `--api-key` / `CURSOR_API_KEY`; headers via `-H/--header`; `--approve-mcps`, `--plugin-dir` exist | ✅ confirmed-local | `cursor-agent --help` |
| macOS has no `timeout` / `gtimeout` (probe wrappers cannot rely on them) | ✅ confirmed-local | local shell environment |
| Model router exposes cursor tiers `composer-2.5-fast` and `composer-2-fast` but **no bare `composer-2.5` slug** | ✅ confirmed-local | `scripts/model-routing.sh --host cursor` |
| `composer-2.5` / `composer-2.5-fast` are actually callable end-to-end | ⏳ needs-network | requires a live `cursor-agent` model invocation |
| The `.result` JSON schema (shape of `--output-format json`) | ⏳ needs-network | requires a live model run |
| Whether a chat-completions style API is exposed | ⏳ needs-network | see Route B note — unfalsifiable negative, not relied upon |
| Latency numbers for model calls | ⏳ needs-network | requires timed live runs |
| Cursor cloud egress hostnames | ⏳ needs-network | requires observing a live run's network traffic |

### Route B: out of verification scope

Route B (a local OpenAI-compatible bridge wrapping `cursor-agent`) is out of
verification scope because of the double-agent problem: `cursor-agent` is itself
a full agent, so a host's tool-calling protocol cannot pass through it. Only the
final `.result` text returns, which effectively kills the host agent loop.
Verifying Route B would therefore prove nothing that Route A does not already
establish.

Keeping `not_observed != absent` discipline: the absence of an observed
chat-completions API is an unfalsifiable negative and is **not** relied upon as
proof. No claim here asserts "no chat-completions API" as proven.

This fact-check inspects the local CLI only. It does **not** promote Cursor
beyond the `candidate` tier and adds no support claim; the candidate boundary in
the Conclusion and Evidence Boundary sections is unchanged.

## cursor-agent CLI network smoke (verified 2026-05-29)

Contained Route A go/no-go run, executed in a throwaway `mktemp -d` directory
with `--mode ask` (read-only), no `--force`/`--yolo`, and cursor-agent's own
`--sandbox enabled`. The Claude Code Bash sandbox was disabled for this run
because cursor-agent reaches Cursor cloud hosts outside the sandbox allowlist
(under the sandbox the call hangs on blocked egress — confirming the network
dependency). This run did not change the support tier; Cursor stays `candidate`.

| Observation | Result |
| --- | --- |
| Model slugs available (`--list-models`) | `composer-2.5` (current) and `composer-2.5-fast` (default) both present ✅ |
| Route A go/no-go (`-p --output-format json --model composer-2.5 --mode ask "Reply with PONG"`) | `is_error:false`, `result:"PONG"` ✅ |
| Success JSON top-level keys | `type, subtype, is_error, duration_ms, duration_api_ms, result, session_id, request_id, usage` (superset of the originally documented `{type,is_error,result,session_id,usage}`) |
| Latency | API `duration_ms` ≈ 9.85s; wall `real` ≈ 17.4s (includes CLI startup); `inputTokens` ≈ 69k per call |
| **Error shape (bad model name)** | exit `1`, **no JSON on stdout** — error text goes to stderr (`Cannot use this model: ...`). A Route A wrapper must check the exit code, not only parse `.result` (a bare `jq -r .result` prints nothing/`null` on error). |
| Egress destinations | `52.6.48.235:443`, `54.82.32.244:443` (AWS us-east-1 range, no PTR records). Process owner is `node` (cursor-agent is a Node app). The TLS SNI hostname was not captured locally; resolving the allowlist hostname is a Phase 83 (distribution) follow-up. |

Verdict: **Route A verified (go)**. Route B remains out of scope (double-agent
problem above). Distribution to consumers is out of scope for this phase and is
gated by the Phase 83 prerequisites (manual sandbox allowlist recipe,
cursor-agent governance rule, support-tier promotion).

### Write-capability spike (Phase 83.3a, 2026-05-29)

Make-or-break check for the "brain Opus / body composer" execution backend: can
`cursor-agent --force` write files while its OWN sandbox stays enabled (the
Codex `workspace-write` equivalent), or is `--sandbox disabled` required?

| cursor-agent sandbox | `--force` write of `foo.txt` in throwaway workspace | is_error | wall |
| --- | --- | --- | --- |
| `--sandbox enabled` | ✅ wrote `PONG` | false | ~32.6s (cold start) |
| `--sandbox disabled` | ✅ wrote `PONG` | false | ~18.3s |

Result: `--sandbox enabled --force --workspace <dir>` **does perform writes**, so
the recommended path keeps cursor-agent's own jail enabled (Codex-equivalent
containment) and does not require disabling it. Only the Claude Code outer Bash
sandbox needs the egress path (allowlist preferred over disable). Implication:
the recommended gatsuri path needs no per-task Risk Gate ack; the bare
`--sandbox disabled` fallback is the only ack-gated path.

### Containment / "can it be stopped?" spike (Phase 83.3a follow-up, 2026-05-29)

Verified whether cursor-agent can be *blocked*, with the CC outer Bash sandbox
disabled (so only cursor-agent's own controls are under test):

| Test | Setup | Result |
| --- | --- | --- |
| Write OUTSIDE `--workspace` | `--sandbox enabled --force --workspace W` → write to a path outside `W` | ❌ **NOT blocked** — the file was written. `--sandbox enabled` does **not** confine writes to the workspace. |
| Write OUTSIDE `--workspace` | `--sandbox disabled --force` → same | Written (no jail, expected). |
| Write under read-only mode | `--mode ask --force` → create a file inside `W` | ✅ **Blocked** — "Ask モードのため作成できません". `--force` does **not** override `--mode ask`. |

Corrected conclusions (supersedes the assumption that `--sandbox enabled`
equals Codex `workspace-write`):

1. cursor-agent's `--sandbox enabled` is **not** a filesystem confinement boundary;
   `--workspace` only sets the cwd, not a write jail.
2. The reliable hard "stop" is `--mode ask` / `--mode plan` (read-only, not
   overridable by `--force`) — use it for read-only/plan delegation.
3. For WRITE delegation, confinement must come from the **CC outer Bash sandbox**
   (network = allowlist Cursor egress, filesystem write = restrict to the
   worktree), not from cursor-agent's own sandbox. Whether cursor-agent functions
   while FS-confined by the outer sandbox is a follow-up verification (Phase 83.3b).
4. Worktree (dedicated `.git`) + Lead diff review + cherry-pick remain mandatory
   regardless, because cursor-agent self-confinement cannot be relied on.

### Official security model (cursor.com/docs/agent/security, observed 2026-05-29)

Cursor's own security docs confirm and refine the spike findings:

- **"No traditional sandbox."** File writes are auto-approved and have **"no
  confinement to project folder"** — exactly matching the 83.3a-follow-up result.
  cursor-agent's `--sandbox` confines shell *commands*, not the file-edit tool.
- **Command controls live in `~/.cursor/permissions.json`** with three levels:
  `Ask Every Time` (default), `Allowlist` / **`Allowlist (with Sandbox)`**
  (pre-approved commands auto-run, sandboxed), and `Run Everything`
  (Cursor's docs say **"Never use"** — this is the `--force`/`--yolo` equivalent).
- **`.cursorignore`** blocks the agent from *reading* listed files (e.g. secrets) —
  an exfiltration control to add to the governance rule.
- **Network default**: agents cannot make arbitrary requests; only GitHub, direct
  link retrieval, and web-search providers are permitted, with no documented
  expansion allowlist.
- **Workspace trust**: `"security.workspace.trust.enabled": true` enables a
  restricted mode for untrusted repos.

Design consequences (supersede the `--force` recommendation):

1. Do **not** drive cursor-agent with `--force` / Run Everything (Cursor says
   never). Prefer `~/.cursor/permissions.json` `Allowlist (with Sandbox)` so only
   curated commands auto-run; `--mode ask` for read-only delegation.
2. Write confinement cannot come from Cursor; it comes from a dedicated-`.git`
   worktree + the CC outer sandbox / OS + Lead review (Phase 83.3b).
3. Add a recommended `.cursorignore` (secrets, `.env`, keys, `.git`) so the
   network-enabled agent cannot read secrets to exfiltrate.

#### `~/.cursor/permissions.json` schema (cursor.com/docs/reference/permissions)

Two optional top-level arrays. Global per-user (no per-project override), JSONC,
hot-reloaded:

```jsonc
{
  // terminal commands that auto-run without approval (prefix match, case-sensitive)
  "terminalAllowlist": ["git status", "git diff", "go test", "npm:test*"],
  // MCP tools that auto-run without approval ("server:tool", wildcards ok)
  "mcpAllowlist": ["harness:*"]
}
```

- `terminalAllowlist`: command-prefix strings. `"git"` matches every `git ...`;
  `"npm:install*"` = base command `npm` + argument glob.
- Precedence: team admin (dashboard) > `permissions.json` > IDE settings UI. A
  defined key **fully replaces** the in-app allowlist for that type (no merge).
- **CRITICAL (Cursor's exact words): "Allowlists are best-effort convenience.
  They are not a security guarantee."** So `permissions.json` only removes
  approval friction for headless auto-run — it is **not** a containment boundary
  and is bypassable. The real boundary remains: dedicated-`.git` worktree + Lead
  diff review + cherry-pick through R01-R13, and treating cursor output as
  untrusted. This is why write containment cannot be delegated to Cursor at all.

### Egress + memory findings (2026-05-29)

- **Cursor egress hosts** (from `~/.cursor/cli-config.json`): `api2.cursor.sh` and
  `agentn.global.api5.cursor.sh`. A CC sandbox `network.allowedDomains` entry of
  `*.cursor.sh` covers both, letting cursor-agent reach the cloud WITHOUT
  per-run `dangerouslyDisableSandbox` (ergonomic win; sandbox's other guards stay on).
  (TLS SAN capture by bare IP failed — the ALB requires SNI — so the hostnames
  come from the CLI config, not a cert probe.)
- **harness-mem already wired globally**: `~/.cursor/mcp.json` contains a
  `harness-mem` server entry. cursor-agent (CLI) loads global `~/.cursor/mcp.json`,
  so the body (composer) already shares memory with the brain (Opus). The
  repo-level `.cursor/mcp.json` is empty and **redundant** for this user — Phase
  83.6 reduces to "confirm cursor-agent loads global mcp at runtime + document";
  no repo wiring required.
- **83.3b reality**: the CC sandbox filesystem-write rule is a GLOBAL setting;
  restricting writes to a single worktree would also block normal local dev, so
  outer-sandbox write-confinement is not a clean per-run control. Recommendation:
  do the `*.cursor.sh` network allowlist (keeps sandbox on), but keep write-mode
  containment as worktree + Lead review + per-session consent (same posture as
  Codex). Strict write-confinement via the sandbox is optional global hardening,
  not a blocker.

## Cursor ACP — Not adopted (2026-05-29)

Cursor's Agent Client Protocol (ACP) is recorded here as NOT ADOPTED for the
harness execution backend; Cursor stays `candidate` and no support tier changes.

### What ACP is

- Bidirectional JSON-RPC over stdio for "custom clients and integrations",
  activated via `agent acp`.
- Streaming via `session/update` notifications (live token / event feed).
- Permission gating via `session/request_permission` (per-action approval).
- Blocking methods such as `cursor/ask_question` and `cursor/create_plan`, plus
  persistent `sessionId` for multi-turn continuity.
- IDE integration path for editors other than Cursor desktop to embed composer.
- No separate server and no special tier; auth reuses `agent login` /
  `--api-key` / `--auth-token`.
- Official guidance from cursor.com/docs/ja/cli/acp: "ACP is intended for
  building custom clients or integrations. For normal terminal workflows, use
  the interactive CLI with `agent`."

### Why not adopt now

- Harness delegation pattern is whole-task: send a task, wait, receive a final
  `.result`. ACP's strengths (streaming, permission gating, blocking dialogs,
  sessionId continuity) are unused.
- Implementing ACP would require streaming consumers, permission-gating
  handlers, and JSON-RPC plumbing on the harness side without adding capability
  the wrapper does not already deliver.
- `cursor-agent -p --output-format json --trust` (the current wrapper) already
  returns the final `.result` deterministically with exit-code semantics that
  the wrapper's exit-code-first check (Phase 82 evidence) requires.

### Re-evaluate ACP when ANY of the following hold

- Streaming UX is required (live progress feed inside Lead, not just
  task-completed events).
- An IDE other than Cursor desktop must embed composer as a worker backend.
- Per-action permission gating (rather than per-session) becomes a harness
  contract.

Support tier is unchanged (cursor=`candidate`); no consumer distribution claim
is added by this entry.

## Promotion Conditions

Cursor can move beyond `candidate` only after all of the following in the same
claim path:

1. Current official docs captured with extractable evidence (this doc + tests).
2. Harness-specific Cursor bootstrap route consumed by setup or release preflight.
3. Workflow smoke proves at least one of `harness-plan`, `harness-work`, or
   `harness-review` routing from Cursor with transcript or CI artifact.
4. Breezing Cursor mapping recorded as smoke target, not as public parity claim.
5. `tests/test-support-claim-wording.sh` still passes (no public Cursor tier
   claim beyond `candidate`).
6. Optional Cloud Agent API smoke recorded separately; failure does not block
   local Desktop/CLI candidate evidence if tier wording stays honest.

Residual risks after Phase 81:

- Explicit subagent `model` override wins; team/admin/plan unavailable models
  fall back silently unless smoke catches them.
- Multitask / background agent behavior may differ from Claude Agent Teams.
- MCP and hooks can affect external sends; config-shape tests do not prove runtime
  policy enforcement.

## Verification Commands

```bash
bash tests/test-cursor-adapter-candidate.sh
bash tests/test-bootstrap-routing-contract.sh
bash tests/test-tool-capability-matrix.sh
bash tests/test-model-routing.sh
bash tests/test-support-claim-wording.sh
```

Optional runtime smoke when Cursor CLI is installed:

```bash
HARNESS_CURSOR_ADAPTER_SMOKE_REQUIRED=1 bash tests/test-cursor-adapter-candidate.sh
```
