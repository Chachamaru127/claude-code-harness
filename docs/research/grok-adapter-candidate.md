# Grok Adapter Evidence Boundary

Status: internal-compatible evidence boundary
Checked at: 2026-07-09 JST
Phase: Grok host completion (goal plan)

## Conclusion

Grok is an **internal-compatible** Harness host.

Harness has a Grok adapter surface (`.grok-plugin/`, `.grok/AGENTS.md`,
`scripts/setup-grok.sh`, host dist build, model routing, static smoke tests).
Package install and skill discovery via `grok plugin install` + `grok inspect`
are observed. It does **not** have CI-gated Plan → Work → Review workflow smoke
or Claude SessionStart / PreToolUse hook parity. Do not claim public `supported`.

## Evidence Boundary

`not_observed != absent`: missing Grok workflow smoke is not proof that Grok
cannot support Harness. It is proof that Harness must not overclaim support.

Do not promote Grok to public `supported` until:

- host-specific bootstrap smoke stays green in release preflight,
- CI-gated workflow smoke proves Plan/Work/Review from Grok alone (or an
  equivalent operator-accepted bar),
- README/onboarding wording still separates install discovery from Claude-tier
  support.

## Observed Runtime Evidence (2026-07-09)

Operator-local / CLI observation (Grok CLI `0.2.93`):

| Observation | Evidence | Limit |
|---|---|---|
| Plugin manifest validate | `grok plugin validate` accepts `.grok-plugin/plugin.json` packages with `skills: "./skills/"` | Shape only |
| Isolated HOME install | `HOME=<tmp> grok plugin install <dist> --trust` writes `~/.grok/installed-plugins/` + registry | Depends on CLI |
| Skill discovery in other project | `HOME=<tmp> grok inspect --json` from a temp cwd lists `harness-plan`, `harness-work`, `harness-review`, `breezing` with `source.type=plugin` | Single-environment proof |
| Model IDs | Catalog includes `grok-4.5` and `grok-composer-2.5-fast` | Account catalog may differ |

## Harness Evidence (This Repository)

| Artifact | What it proves | What it does not prove |
|---|---|---|
| `.grok-plugin/plugin.json` | Plugin manifest points at core `skills/` | Marketplace publish or every-account install |
| `.grok/AGENTS.md` | Bootstrap routing guidance for plan/work/review | Automatic runtime routing |
| `scripts/setup-grok.sh` | Isolated build/check + install entrypoint | Live operator HOME install as CI proof |
| `scripts/build-host-plugin-dist.sh --host grok` | Package-local `./skills/` paths (no `..`) | Host runtime beyond package shape |
| `scripts/model-routing.sh --host grok` | Role-tier → Grok model mapping contract | Account-specific model availability |
| `tests/test-grok-adapter-candidate.sh` | Static adapter contract + isolated setup smoke | Full Breezing multitask proof |

## Official Grok Surfaces (Observed 2026-07-09)

Sources checked (local user-guide + CLI help):

- `~/.grok/docs/user-guide/08-skills.md` — skill discovery roots
- `~/.grok/docs/user-guide/09-plugins.md` — plugin install / validate / inspect
- `~/.grok/docs/user-guide/12-project-rules.md` — AGENTS.md project rules
- `grok plugin validate|install|list|details`, `grok inspect --json`

Observed adapter-relevant mechanics:

| Surface | Harness mapping | Notes |
|---|---|---|
| Project rules / `AGENTS.md` | Bootstrap notice + prompt routing | Same conceptual layer as Codex/Cursor AGENTS |
| Skills | Core workflow skills via plugin `skills/` | Slash commands when `user-invocable: true` |
| Plugins | `.grok-plugin/plugin.json` + `skills/` | User install under `~/.grok/installed-plugins/` |
| CLI `--model` | Explicit override surface | Outranks routed default when caller sets it |
| Hooks | Optional future mapping | Not claimed as Claude PreToolUse parity |

## Verification Commands

```bash
bash tests/test-grok-adapter-candidate.sh
bash scripts/setup-grok.sh --check
bash scripts/build-host-plugin-dist.sh --host grok --out /tmp/cch-grok-dist
bash scripts/model-routing.sh --host grok --role worker --format json
# Optional when CLI available:
grok plugin validate /tmp/cch-grok-dist
```

## Blocked Wording

| Allowed | Blocked |
|---|---|
| internal-compatible Grok adapter | public top-tier product claim for this host |
| setup-grok install / package smoke | Claude SessionStart parity |
| skill discovery via inspect | PreToolUse deny parity |
| model-routing host `grok` | Breezing multitask public support claim |
