# Public Claims Audit — 2026-07-10

This audit rechecked the legacy concerns cited in external coverage against the
current repository. It records observed local facts; it is not a general claim
about every host, platform binary, or third-party post.

| Concern | Result | Evidence observed on 2026-07-10 | Action |
|---|---|---|---|
| Version and bundled binary | NOT REPRODUCED | `VERSION`, `.claude-plugin/plugin.json`, and `harness.toml` report `5.0.0`; `./bin/harness-darwin-arm64 version` reports `5.0.0 (Hokage)`. | No version or binary change. |
| Global TDD enforcement | NOT REPRODUCED | README says “TDD required when the task says so.” The local-trial `[tdd.enforce]` default remains `enabled = false` and `level = "off"`. | Preserve task-scoped TDD; do not make it globally mandatory. |
| Compatibility documentation | REPRODUCED | The prior document still named plugin `3.10.2`, Node.js `18+`, the removed TypeScript `core/` runtime, and obsolete validation commands. | Rewrite `docs/CLAUDE_CODE_COMPATIBILITY.md` for the Go-native `5.0.0` runtime and current commands. |
| Host tier drift | NOT REPRODUCED | `hosts/registry.json` records Claude Code as `supported` and Codex CLI, Cursor, and Grok as `internal-compatible`; existing host and wording tests pin those rows. | Keep tiers registry-derived; do not duplicate them in marketing data. |

## Public Claim Boundary

The accompanying [Public Claims Contract](../public-claims-contract.md) and
shipped `scripts/validate-publication-records.py` gate make publication fail
closed. Only direct-public, fully evidenced `verified` testimonials are
publishable. Login-required, rejected, unavailable, incomplete, oversized, or
overbroad speed/safety records exit nonzero. Independent articles remain
separate coverage links rather than testimonials.

## Verification Commands

```bash
./bin/harness-darwin-arm64 version
bash tests/test-public-claims-contract.sh
bash tests/test-host-registry.sh
bash tests/test-support-claim-wording.sh
```

The binary execution above covers macOS arm64 only. No external testimonial was
retrieved or approved by this repository audit; source verification belongs to
the private marketing evidence archive before any public-site build.
