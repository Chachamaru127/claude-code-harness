# Cross-Repo Handoff Workflow (claude-code-harness ↔ harness-mem)

The SSOT for recording, in a reproducible form, the adjustments to responsibility boundaries, contract changes, and implementation transfers that occur between claude-code-harness and the sibling repo `harness-mem`.

This document extracts the codifiable policy portion of decisions.md D42 (`claude-code-harness ↔ harness-mem responsibility boundary + Cross-repo Handoff Workflow`). Because decisions.md is a per-developer local SSOT (gitignored), policies that need to be shared are placed in this file.

## Why This Rule Is Necessary

During the review at the end of Phase 65 Phase A of claude-code-harness, the user expressed the expectation that "if something that should have been implemented on the harness-mem side was implemented on the claude-code-harness side, then (i) remove it from claude-code-harness and (ii) raise a clearly described Issue on the harness-mem side."

In practice, (i) was already done (managed companion migration in Phase 60, dead default cleanup in Phase 63), but (ii) was being operated not as a GitHub Issue but via the sibling-repo Plans SSOT method using `Plans.md §NNN` in the harness-mem repo. Only one GitHub Issue existed: #70 (Phase 49.1.2 follow-up).

The gap between user expectation (GitHub Issue) and actual practice (Plans.md SSOT) was caused by "policy not being documented." This rule fixes that as the official process and prevents recurrence.

## 3-Layer Redaction Responsibility Boundary (Phase 65 cross-project safety)

| Layer | Content | Implementation layer | Reason |
|---|---|---|---|
| Layer 1 | privacy filter (`<private>` strip) + project scope (`strict_project: true`) | **harness-mem server side** | Guards all clients (CC / Codex / opencode) uniformly at the mem output. `include_private=false` default |
| Layer 2a | Dictionary-based proper noun redaction (`client-redaction.yaml`) | **claude-code-harness client side** | Interpreting project-local config is the responsibility of the presentation layer. Pushing schema interpretation to the server would leak per-company redaction policies into server configuration |
| Layer 2b | NER (Japanese tokenizer such as kuromoji) | **claude-code-harness client side** | Avoid server dependency bloat: ONNX embedding (multilingual-e5) is already heavy; adding a JP tokenizer would hurt cold start (~5ms) and memory footprint |
| Layer 3 | Final scan immediately before HTML generation | **claude-code-harness client side** | render-html.sh exists only on the client (it can only be placed on the rendering pipeline) |

If server-side PII redaction flags are desired in the future, there is room to reconsider with an opt-in design via a `redact_profile` parameter, as harness-mem §111 or later.

### Phase 65.3 Implementation Decisions (D43)

Implementation constraints confirmed through coordination with the mem side before starting Phase 65.3:

| Constraint | Content | Basis |
|---|---|---|
| MCP cross-project requires N-calls | The MCP schema of `mcp__harness__harness_mem_search` exposes only a single `project: string` value (neither `projects: [array]` nor `strict_project: boolean` is exposed via MCP). For cross-project search, the client issues one MCP call per member and merges/deduplicates results on the client side | Confirmed from mem-side mcp-server schema (`mcp-server/src/tools/memory.ts:297-341`) |
| client-redaction.yaml is PiiRule-compatible | The client-side dict schema (`client-redaction.v1`) is made field-name-compatible with the mem-side existing `pii-filter.ts` `PiiRule[]` schema (`rule_id`, `pattern`, `replace_with`, etc.). Full consolidation (npm package) is a future follow-up | Prevents duplicate implementation + preserves upgrade path to Cross-client Consistency section |
| `[REDACTED_*]` double-replacement guard | The server-side `event-recorder.ts:redactContent` has already replaced email / API key / hex with `[REDACTED_*]`. Client Layer 2 redact **must not re-replace** existing marks — sentinel guard is required | Prevents information corruption from double replacement |
| applied_filters annotation policy | The mem-side `applied_filters` meta is not implemented (internal audit only). The Phase 65.3.6 audit log records only Layer 2/3 (client), and Layer 1 (server) is explicitly noted as "depends on server default + internal audit" | Confirmed as not implemented on mem side, not a blocker for this phase |

If the latency of cross-project N-calls becomes a problem in actual operation, file it as **XR-005** (add `projects: [array]` + `strict_project: boolean` to MCP schema) under harness-mem §111.

### Phase 65.3 Completion Report (2026-05-09)

All 7 Phase C tasks completed within a single session, entirely within claude-code-harness with zero Cross-Contract changes.

| Phase | task | commit | Key deliverables | Tests |
|---|---|---|---|---|
| C-1 | 65.3.1 | `4a014137` | `.claude/rules/cross-project-groups.yaml` SSOT + `scripts/load-cross-project-groups.sh` (yaml → JSON validator) + `docs/cross-project-groups-schema.md` | 21 PASS |
| C-2 | 65.3.2 | `5152bed2` | `.claude/rules/client-redaction.yaml` (PiiRule-compatible schema) + `scripts/redact-by-dictionary.sh` Layer 2a + double-replacement guard | 26 PASS |
| C-3 | 65.3.3 | `20a4478f` | `scripts/redact-by-ner.sh` Layer 2b (fugashi tokenizer + fail-open) | 22 PASS |
| C-4 | 65.3.4 | `0ae3f40a` | `scripts/render-html.sh --with-redaction` Layer 3 final scan + `scripts/final-scan-redaction.py` | 16 PASS |
| C-5 | 65.3.5 | `09377eb9` | `harness-plan-brief` / `harness-accept` SKILL.md with `--cross-project-group <name>` flag opt-in (D43 Option alpha: MCP N-call) | 18 PASS |
| C-6 | 65.3.6 | `272a8f33` | `cross-project-audit.v1` audit log + `scripts/cross-project-audit-log.sh` + HTML audit summary display | 21 PASS |
| C-7 | 65.3.7 | `c05d6ef8` | e2e validation (3-member group + all-layer pass-through + envelope + sentinel guard) | 21 PASS |

**Total**: 7 feat commits + 7 chore commits = 14 commits, 145 assertions all PASS, `./tests/validate-plugin.sh` 51 → 58 (+7), `bash scripts/ci/check-consistency.sh` all passing.

All 4 D43 decision packages functioned as initially designed; no unexpected constraints or rework occurred.

**Pending follow-up triggers** (file under harness-mem §111 only when trigger condition is reached):
- XR-005: Add `projects: [array]` + `strict_project: boolean` to MCP schema — if N-call latency becomes a problem in actual operation
- (formerly §110-S110-006): Implement `applied_filters` meta — if demand emerges to make server-side filter application visible from the client ※actual §110 S110-006 has been consumed as the Phase C closure record (see below)
- PiiRule shared npm package: When cross-client consistency is truly needed (see below for mem-side PiiRule schema reference)

### Phase 65.3 Closure Ack (received by harness-mem side, 2026-05-10)

The harness-mem session received the Phase C completion report as **§110 S110-006** (confirmed zero Cross-Contract changes). No new §111 was needed; the SSOT policy became to consolidate it under §110.

| Item | mem-side commit | Content |
|---|---|---|
| content commit | `8b34ecb` | S110-006 Phase C closure record + 6 invariant conflict review (0 conflicts) + PiiRule reference list |
| hash backfill | `ad4ba56` | S110-006 cc:completed [8b34ecb] |
| (optional follow-up) | (S110-007 candidate) | Document "do not include PII in signals" in envelope contract — within mem-side scope, no need to file from claude-code-harness side |

**6 invariant conflict review results** (confirmed on mem side, 0 conflicts):
- `<private>` strip / Layer 2/3 overlap: no conflict (by design, client cannot see what server deleted)
- `[REDACTED_*]` sentinel format: no conflict (mem side uses uppercase `EMAIL` / `KEY` / `SECRET` / `HEX`; client-side regex `[A-Za-z0-9_]+` covers both cases)
- envelope `validateProseContainsSignals`: no practical conflict (S110-007 candidate: document on the envelope contract side, address on the claude-code-harness side by adding defensive notes to client-redaction.yaml)
- cross-project N-call rate limit: no conflict (mem side has no rate limit configured; N=5-10 expected is not a problem)
- Cross-project privacy tag merge: no conflict (server uses independent filter per project; merge is client's responsibility)
- audit log structure: no conflict (Phase 65.3.6 completed entirely on client side)

### PiiRule Schema Official Reference (shared from mem-side commit `8b34ecb`, reference point for when npm package is filed)

PiiRule specification for `mcp-server/src/pii/pii-filter.ts` (fixed as reference point for when npm packaging is filed in the future):

| Type | Path | Content |
|---|---|---|
| TS SoT | `mcp-server/src/pii/pii-filter.ts:15-20` | `interface PiiRule { name: string; pattern: string; replacement: string }` |
| TS SoT | `mcp-server/src/pii/pii-filter.ts:22-24` | `interface PiiRulesFile { rules?: PiiRule[] }` |
| Function exports | `mcp-server/src/pii/pii-filter.ts:33, 50, 69-85, 92` | `applyPiiFilter` / `loadPiiRules` / `DEFAULT_PII_RULES` / `getActivePiiRules` |
| .d.ts | `mcp-server/dist/pii/pii-filter.d.ts:1-6` | Compiled declaration |
| Environment variables | `docs/environment-variables.md:102-111, 302-303` | `HARNESS_MEM_PII_FILTER` / `HARNESS_MEM_PII_RULES_PATH` |
| Official spec doc | `docs/specs/vps-team-deploy-spec.md:57, 260-285` | TEAM-006 PII filtering (inline JSON example at `:270-275`) |
| Contract test | `mcp-server/tests/unit/pii-filter.test.ts:1-56` | 5 cases (JP phone / email / LINE_ID / compound / empty rules) |
| Usage example | `mcp-server/src/tools/memory.ts:13, 1067-1068` | Applied within `record_checkpoint` |

**Important caveat**: README / OpenAPI has no PiiRule component schema, and there is no independent JSON Schema export.
When filing for npm packaging, **scope schema export and official doc preparation together** (recommended by mem side).

### Cross-Client Consistency Guarantee Policy

The requirement to "make redaction work even when called from other clients like Codex" is addressed by **sharing a library (npm package or sub-module) on the client side**. Reasons for not redacting at the server-side MCP API exit:

- Future team sharing (`harness_mem_share_to_team`) would break the contract of "returning the correct original text," losing reversibility
- Keeping the server "presentation policy free" avoids hindering client diversity (CC / Codex / opencode / future third-party clients)

Instead, harness-mem will optionally provide an extension that includes `applied_filters` (e.g., `privacy_filter` / `project_scope`) in the response meta of `mcp__harness__harness_mem_search` as needed (file under harness-mem §110 follow-up or §111).

## Two Paths for Cross-repo Handoff

Use one of the following two paths for handoffs between claude-code-harness and harness-mem.

### Path A: harness-mem repo's `Plans.md §NNN` (sibling-repo Plans SSOT)

**Use case**: Cross-Contract changes (detailed DoD required, handoffs referenced across multiple sessions)

**Examples**:
- §106 (companion contract handoff, filed in Phase 60, cc:completed)
- §107 (checkpoint cold-start handoff, cc:completed)
- §110 (Cross-repo Handoff Workflow Codification, the counterpart to this rule, codification completed on harness-mem side)

**Procedure**:
1. When the claude-code-harness side determines "this should be moved to the mem side for implementation," add a section to Plans.md (e.g., §111)
2. List the required DoD as bullet points in the section (acceptance criteria, technical constraints, relevant claude-code-harness commit hashes)
3. **Remove the relevant portions from claude-code-harness (skills/scripts/docs) in the same PR** (following the Phase 60 `1f4d9133`, `5373d50d` pattern)
4. If needed, add a new row to the table in this rule file `.claude/rules/cross-repo-handoff.md`

### Path B: GitHub Issue

**Use case**: Cross-Runtime long-running follow-ups (discussions spanning multiple sessions and PRs, or cases requiring exposure to external participants)

**Example**: harness-mem #70 (Phase 49.1.2 follow-up)

**Procedure**:
1. File with `gh issue create --repo Chachamaru127/harness-mem --title "..." --body "..."`
2. From the claude-code-harness side, only leave a comment like `# See harness-mem#NN` at the relevant location (do not implement)
3. When the issue is closed on the harness-mem side, update the reference in this rule file on the claude-code-harness side

## Decision Axis (which path to use)

| Consideration | A: Plans.md §NNN | B: GitHub Issue |
|---|---|---|
| Detailed DoD needed? | ✓ Can write detailed DoD | △ Issue body tends to be fluid |
| Referenced across multiple sessions? | ✓ Plans.md is persistent SSOT | △ Issues become harder to read over time |
| Exposure to external participants needed? | △ Repo collaborators only | ✓ Visible to outsiders on a public repo |
| Harmless closeout-only? | ✓ Lightweight | △ Filing an issue creates closeout overhead |
| Long-running cross-runtime? | △ Plans.md is weak for cross-runtime | ✓ Issues are more appropriate |

When in doubt, default to **Path A (Plans.md §NNN)**. Reason: 3 of the past 4 handoffs (Phases 60, 63, 65) were completed using the Plans.md SSOT, with a track record of success. Only one GitHub Issue (#70) exists.

## Historical Boundary Adjustment Record (no retroactive filing)

The following past handoffs are **confirmed by this rule as "Plans.md §NNN is equivalent to a GitHub Issue"**, so retroactive GitHub Issue filing will not be done:

- Phase 60 (managed companion migration) — harness-mem Plans.md §106
- Phase 63 (dead default cleanup) — harness-mem Plans.md §107
- Phase 65.3 (confirming 3-layer redaction owner) — this rule's table + harness-mem Plans.md §110

For future boundary changes, select from the two paths in this rule.

## Related

- claude-code-harness `.claude/memory/decisions.md` D42 (local SSOT origin of this rule, gitignored)
- claude-code-harness `.claude/rules/migration-policy.md` (procedure for recording Phase 60 deleted-concept handoffs)
- harness-mem `docs/claude-harness-companion-contract.md:84-96` (Cross-repo Handoff Workflow section, counterpart on harness-mem side)
- harness-mem `.claude/memory/patterns.md:230` (P7 Non-Application Conditions with Plans.md SSOT exception added)
- harness-mem Plans.md §110 (Cross-repo Handoff Workflow Codification, counterpart to this rule)

## Revision Conditions

- **Trigger A**: When an API providing opt-in PII redaction on the server side (e.g., `redact_profile` parameter) is implemented in harness-mem §111+ — reconsider the owner of Layer 2
- **Trigger B**: When the shared library for cross-client consistency is npm-packaged — update the Cross-client Consistency section
- **Trigger C**: When `applied_filters` is added to the response meta of harness-mem's `mcp__harness__harness_mem_search` — update the Layer 1 verification path
