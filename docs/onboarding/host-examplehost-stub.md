# N+1 dry-run: `examplehost` (stub)

Phase 111.6.2 — **do not implement a real ExampleHost**. This page proves the
admission path fits in one PR without new case-statement snowflakes.

## Checklist (complete without shipping code)

1. [ ] Native intercept? → if no, `safety_model: none`, max tier packaging/candidate
2. [ ] Deny fail-open/closed documented
3. [ ] Event coverage table (shell/file/MCP)
4. [ ] `scripts/setup-examplehost.sh` with `--check` + isolated HOME
5. [ ] Static smoke test path registered
6. [ ] `HARNESS_EXAMPLEHOST_*_SMOKE_REQUIRED` documented
7. [ ] Bootstrap route named in bootstrap-routing-contract
8. [ ] support-claim wording patterns added
9. [ ] `docs/research/examplehost-adapter-candidate.md`
10. [ ] `floor_member` true only after live deny
11. [ ] Allowed/blocked public phrases
12. [ ] Capability matrix row

## Registry row (illustrative only)

```json
{
  "id": "examplehost",
  "display_name": "ExampleHost",
  "tier": "future/unsupported",
  "setup_script": "scripts/setup-examplehost.sh",
  "dist_host": "examplehost",
  "routing_host": "examplehost",
  "safety_model": "none",
  "floor_member": false,
  "smoke": {
    "static": ["tests/test-examplehost-adapter.sh"],
    "setup_check": "scripts/setup-examplehost.sh --check",
    "adapter": "tests/test-examplehost-adapter.sh"
  },
  "blocked_public_phrases": ["supported ExampleHost", "正式対応.*ExampleHost"]
}
```

## What must NOT grow

- New hard-coded `case "$HOST" in ... examplehost)` blocks in release-preflight
  (use `hosts/registry.json` smoke loop instead)
- Duplicate skill trees under `skills-examplehost/`

## Verification of dry-run (this PR)

```bash
test -f docs/onboarding/host-admission.md
test -f hosts/registry.json
bash tests/test-host-registry.sh
```

Adding a real host is: copy this stub → fill checklist → append registry row →
add setup/smoke scripts → update public tier tables once evidence exists.
