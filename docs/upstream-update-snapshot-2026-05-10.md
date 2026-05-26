# Codex upstream snapshot - 2026-05-10

This snapshot tracks Codex `0.130.0` stable for the claude-harness.
Phase 67.1.1 fixes upstream facts; Phase 67.1.2 onward splits targets
for implementation into provider / app-server / plugin workflow docs.

Confirmed on:

- 2026-05-10 (Asia/Tokyo)

Target release:

- tag: `rust-v0.130.0`
- name: `0.130.0`
- prerelease: `false`
- published_at: `2026-05-08T23:09:55Z`
- release URL: <https://github.com/openai/codex/releases/tag/rust-v0.130.0>
- compare: <https://github.com/openai/codex/compare/rust-v0.129.0...rust-v0.130.0>

Existing Harness tracking baseline:

- Codex `0.124.0` stable (Phase 56)
- Codex `0.125.0` / `0.128.0` stable (Phase 58)
- Claude Code `2.1.112`-`2.1.132` follow-up (Phase 62)

Classifications:

- `A: Validation strengthening`: Fix upstream tracking in the current snapshot / Feature Table / CHANGELOG / tests.
- `C: Automatic inheritance`: Receive Codex core fixes as-is. Do not overlay Harness wrappers.
- `P: Plans`: Has value for Harness, but do not implement at runtime in this snapshot; cut into Phase 67 tasks.
- `B: Documentation-only 0 items`: Do not create explanation-only items not connected to implementation / tests / follow-up Plans.

## Version-by-version breakdown

| Version | Upstream item | How it improves | Category | Harness surface | Harness action |
|---------|---------------|-----------------|----------|-----------------|----------------|
| Codex `0.130.0` stable | plugin details show bundled hooks | Easier to determine whether a plugin has bundled hooks | P | Codex plugin workflow docs / setup review | In Phase 67.1.2, connect plugin-bundled hooks display to docs and maintain the policy of not speculatively generating inline hooks in Harness |
| Codex `0.130.0` stable | plugin sharing exposes link metadata/discoverability controls | Easier to handle shared plugin link information and discoverability | P | plugin sharing policy | In Phase 67.1.2, document the responsibility boundary for marketplace / private sharing |
| Codex `0.130.0` stable | top-level `codex remote-control` | Entry point for remote control becomes clearer | P | Codex workflow docs | In Phase 67.1.2, add `codex remote-control` as an official top-level command |
| Codex `0.130.0` stable | app-server Thread pagination APIs | Better scalability for large thread lists | P | app-server / session docs | In Phase 67.1.2, connect Thread pagination APIs to the app-server policy |
| Codex `0.130.0` stable | Bedrock `aws login` profile credentials | Credential retrieval path for Bedrock profiles becomes clearer | P | provider setup docs | In Phase 67.1.2, add boundary notes for `aws login` / `amazon-bedrock` / console-login credentials |
| Codex `0.130.0` stable | `view_image` through selected environments | Can verify images through selected environments | P | multi-environment review docs | In Phase 67.1.2, make selected-environment `view_image` consistent with read-only first / one primary write environment |
| Codex `0.130.0` stable | live app-server threads refresh latest config snapshot | Live threads more easily reflect the latest config snapshot | P | app-server config lifecycle | In Phase 67.1.2, document expected behavior for live threads from latest config snapshot |
| Codex `0.130.0` stable | turn diff accuracy after `apply_patch` including partial failures | Turn diffs after `apply_patch` become accurate | C | review / diff UX | Auto-inherit core fix. Do not add turn diffs workaround on Harness side |
| Codex `0.130.0` stable | ThreadStore summaries/resume/fork improvements | Summary / resume / fork become stable | C | session runtime | Auto-inherit core fix. Do not duplicate Plans SSOT or harness-loop state |
| Codex `0.130.0` stable | remote compaction emits `response.processed` and omits `service_tier` under API auth | Remote compaction event / auth behavior becomes stable | C | remote compaction telemetry | Auto-inherit core fix. Harness telemetry keeps `response.processed` as observation target and does not treat `service_tier` absence as an error |
| Codex `0.130.0` stable | Windows sandbox runtime bin cache | Runtime bin resolution speeds up and stabilizes during Windows sandbox startup | C | Windows sandbox runtime | Auto-inherit core fix. Harness does not add Windows workarounds |
| Codex `0.130.0` stable | docs use `cargo install --locked` | Better reproducibility for install steps | P | setup docs | In Phase 67.1.3, review Codex install guidance and align old cargo install examples to `cargo install --locked` if any |
| Codex `0.130.0` stable | configurable OTel trace metadata | Easier to attach trace metadata to match the environment | P | telemetry policy | In Phase 67.1.3, evaluate OTel trace metadata in a form that doesn't conflict with privacy-first / local-first policy |
| Codex `0.130.0` stable | built-in MCPs first-class runtime servers | Easier to treat built-in MCPs as runtime servers | P | MCP setup docs | In Phase 67.1.3, document the boundary between built-in MCPs and plugin-provided MCP |
| Codex `0.130.0` stable | `CODEX_HOME` environments TOML provider | Can handle environments TOML provider under `CODEX_HOME` | P | Codex setup / environment policy | In Phase 67.1.3, fix the priority order between `CODEX_HOME` environments TOML provider and repo-local config |
| Codex `0.130.0` stable | remove skills list extra roots | Reduces duplicate and unnecessary skill root searches | C | skill runtime | Auto-inherit core fix. Harness skill manifest generator unchanged |

## Phase 67 follow-up plan

| Task | Scope |
|------|-------|
| 67.1.1 | Add this snapshot, Feature Table, CHANGELOG, and upstream integration tests |
| 67.1.2 | Update Codex provider / app-server / multi-environment policy to `0.130.0` stable |
| 67.1.3 | Update Codex setup / telemetry / MCP / environment docs to `0.130.0` stable |
| 67.1.4 | Perform Phase 67 integration validation and Plans marker updates |

## Why B: Documentation-only is 0 items

- `A` is fixed as validation strengthening via this snapshot and `tests/test-claude-upstream-integration.sh`.
- `P` is connected to docs / policy work in Phase 67.1.2 / 67.1.3.
- For each `C`, the reason for automatically inheriting the Codex core runtime fix is stated in one line.
- No items are left that only appear in the Feature Table and CHANGELOG.

## No-op adaptation decision for this snapshot

This snapshot itself is a no-op adaptation.

Reasons:

- `codex remote-control`, app-server Thread pagination APIs, selected-environment `view_image`,
  Bedrock `aws login`, plugin hooks are docs / policy boundary updates first;
  they are not grounds for immediately changing runtime wrappers.
- `apply_patch` turn diffs, ThreadStore summaries/resume/fork improvements, Windows sandbox runtime bin cache
  are Codex core fixes; creating double workarounds on the Harness side would conflict with future behavior.
- OTel trace metadata, built-in MCPs, `CODEX_HOME` environments TOML provider are convenient but
  adopt after fixing the privacy / setup precedence / MCP ownership boundary in Phase 67.1.3.
