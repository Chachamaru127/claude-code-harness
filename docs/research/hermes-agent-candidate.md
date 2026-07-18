# Hermes Agent Candidate

Status: candidate evidence boundary
Checked at: 2026-07-12 JST

## Conclusion

Hermes Agent is a **candidate** Harness host path.

Operator-local evidence shows that Hermes can expose Harness workflow skills by
symlinking the CCH `skills/` source-of-truth into a local Hermes skill directory.
Hermes then discovers the canonical skill names as dynamic slash commands such as
`/harness-plan`, `/harness-work`, `/harness-review`, `/harness-sync`, and
`/breezing`.

This is not a public `supported` claim. Harness has not added a Hermes setup
script, host-specific distribution package, routing model, runtime floor parity,
or CI-gated workflow smoke.

## Evidence Boundary

`not_observed != absent`: missing Hermes workflow smoke is not proof that Hermes
cannot support Harness. It is proof that Harness must not overclaim support.

Do not promote Hermes Agent above `candidate` until Harness has its own:

- bootstrap evidence from a clean Hermes profile,
- trigger evidence for canonical `/harness-*` and `/breezing` commands,
- runtime workflow evidence for Plan → Work → Review or an accepted equivalent,
- release/preflight evidence that stays green in CI or an operator-accepted gate,
- support wording that still separates candidate use from public `supported`.

## Observed Local Evidence (2026-07-12)

Operator-local observation on a user-controlled checkout:

| Observation | Evidence | Limit |
|---|---|---|
| Skill source | CCH `skills/` is the SSOT; `.agents/skills` is an optional read-only mirror (`not-configured` when absent) | Local checkout only |
| Hermes exposure | Directory symlinks under `~/.hermes/skills/cch/<skill>` point to CCH `skills/<skill>` | Manual operator setup; no setup script |
| Skill discovery | `hermes skills list` showed the pilot skills as enabled | Single local profile |
| Dynamic slash commands | Hermes command registry built invocations for `/breezing`, `/harness-plan`, `/harness-work`, `/harness-review`, `/harness-sync`, `/harness-setup`, `/harness-loop`, and `/harness-release` | Invocation parsing only, not full workflow execution |
| Duplicate aliases | Temporary `cch-*` aliases were removed; canonical names match CCH source names | Local cleanup only |
| Security warning | Hermes warns when symlinks resolve outside `~/.hermes/skills` | Expected for external checkout symlinks |

## Harness Evidence (This Repository)

| Artifact | What it proves | What it does not prove |
|---|---|---|
| `skills/` | Canonical skill names and source content | Hermes install or runtime behavior |
| `docs/research/hermes-agent-candidate.md` | Candidate boundary and observed evidence | Public support |
| `docs/tool-capability-matrix.md` | Support-tier wording includes Hermes as candidate | Workflow parity |
| `tests/test-hermes-agent-candidate.sh` | Static doc contract stays present | Live Hermes execution |

## Candidate Manual Setup Shape

This is a research shape, not an end-user install script:

```bash
CCH_SRC="$HOME/path/to/claude-code-harness/skills"
HERMES_CCH_DIR="$HOME/.hermes/skills/cch"
mkdir -p "$HERMES_CCH_DIR"
for skill in harness-plan harness-work harness-review harness-setup harness-sync harness-loop harness-release breezing; do
  ln -sfn "$CCH_SRC/$skill" "$HERMES_CCH_DIR/$skill"
done
hermes skills list | grep -E 'breezing|harness-(plan|work|review|setup|sync|loop|release)'
```

Required boundaries:

- link from CCH `skills/`, not `.agents/skills`,
- keep command names canonical (`/harness-*`, `/breezing`),
- do not create `cch-*` command aliases,
- treat Hermes security warnings for external symlinks as a documented residual
  risk unless a future packaged install path removes them.

## Verification Commands

Static repository contract:

```bash
bash tests/test-hermes-agent-candidate.sh
bash tests/test-tool-capability-matrix.sh
bash tests/test-support-claim-wording.sh
```

Optional operator-local smoke when Hermes is available:

```bash
hermes skills list | grep -E 'breezing|harness-(plan|work|review|setup|sync|loop|release)'
```

## Blocked Wording

| Allowed | Blocked |
|---|---|
| candidate Hermes Agent path | blocked: supported Hermes adapter |
| manual symlink research route | blocked: Hermes 正式対応 |
| dynamic slash invocation observed locally | Claude SessionStart parity |
| candidate skill discovery | runtime floor / PreToolUse parity |
