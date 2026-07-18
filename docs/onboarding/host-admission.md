# Host Admission (N+1)

Last updated: 2026-07-09 (Phase 111.1)

This page is the **checklist for adding a new agent host** to Claude Code Harness.
It pairs with the multi-host bar **H1–H8** in
`docs/spec/planning-and-host-adapter.md` and the machine SSOT
`hosts/registry.json`.

## Why a registry

Without a registry, each new host copies case statements in:

- `scripts/build-host-plugin-dist.sh`
- `scripts/model-routing.sh`
- `scripts/release-preflight.sh`
- README / matrix / onboarding tier tables

That snowflake cost does not scale. New hosts start as **one registry row** plus
thin setup/smoke scripts.

## SSOT layout

| File | Role |
|------|------|
| `hosts/registry.json` | Machine SSOT: id, tier, setup, dist, routing, floor_member, smoke paths |
| `hosts.toml` | Hook generation descriptors for `harness gen` (event/deny/codec) — separate concern |
| `scripts/lib/host-registry.sh` | Bash/node helpers to read the registry |
| `tests/test-host-registry.sh` | Tier tables and script paths must match the registry |

## Admission checklist (12 items)

Complete **before** raising public tier above `future/unsupported`.

1. **Native intercept or explicit none**
   Can the host stop an action before it runs? If no, set
   `safety_model: none` and **max** public tier is packaging / candidate until a
   documented post-gate model exists.

2. **Deny semantics**
   Document fail-closed vs fail-open (e.g. Cursor non-exit-2 fail-open).

3. **Event coverage**
   Shell only? File write? MCP? Read? Record Bash-only gaps honestly.

4. **Install unit test**
   Isolated HOME / install root; no writes to the operator's live config in CI.

5. **Static smoke in CI**
   Package shape, no `..` in dist manifests, core skills present.

6. **Optional runtime flag**
   `HARNESS_<HOST>_*_SMOKE_REQUIRED=1` for hard fail when CLI is expected.

7. **Bootstrap route named**
   Entry in `docs/bootstrap-routing-contract.md` (not false SessionStart parity).

8. **support-claim wording**
   Block EN `supported` and JP 正式対応 / 対応済み for this host until H1–H8 green
   (`tests/test-support-claim-wording.sh`).

9. **Evidence research note**
   `docs/research/<host>-adapter-candidate.md` with observed / missing / commands.

10. **Floor join or explicit exclusion**
    `floor_member: true` only after `harness hook pre-tool --host <id>` live deny;
    otherwise `false` and never claim 3cli parity.

11. **Public wording template**
    Allowed vs blocked phrases in registry `blocked_public_phrases` + onboarding.

12. **Capability matrix row**
    Every capability cell has strength language; same name ≠ same enforcement.

## How to add host `example`

1. Implement thin `scripts/setup-example.sh` (`--check` + isolated install).
2. Add dist profile in `build-host-plugin-dist.sh` **or** generic copy profile driven by registry fields (prefer generic).
3. Add routing catalog in `model-routing.sh` if the host is an execution/routing surface.
4. Append a row to `hosts/registry.json`.
5. Add `tests/test-example-adapter-*.sh` and point `smoke.adapter` at it.
6. Update README / matrix / onboarding tier tables (or generate from registry later).
7. Run:

```bash
bash tests/test-host-registry.sh
bash tests/test-host-plugin-dist.sh
bash tests/test-model-routing.sh
bash tests/test-support-claim-wording.sh
```

8. Do **not** set `tier: supported` until H1–H8 pass on one claim path (Phase 111).

## Registry field contract

| Field | Meaning |
|-------|---------|
| `id` | Stable slug (`grok`, `cursor`) |
| `display_name` | Public table label (`Grok`, `Claude Code`) |
| `tier` | `supported` \| `internal-compatible` \| `candidate` \| `future/unsupported` |
| `setup_script` | Path or null |
| `dist_host` | Value for `build-host-plugin-dist.sh --host` |
| `routing_host` | Value for `model-routing.sh --host` |
| `safety_model` | Free-form enum string for docs/tests |
| `floor_member` | boolean — shared pre-tool floor |
| `smoke.adapter` / `smoke.setup_check` | Commands/paths for preflight |
| `blocked_public_phrases` | Patterns that must not appear as public claims |

## Related

- `docs/bootstrap-routing-contract.md`
- `docs/tool-capability-matrix.md`
- `docs/plans/phase-111-multi-host-supported.md`
- `docs/spec/planning-and-host-adapter.md` (H1–H8)
