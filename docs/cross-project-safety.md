# 3-Layer Defense for Cross-Project Search (Phase 65.3)

When pulling in past decisions and knowledge from other projects, you may not want
**proper nouns — client names, personal names, company names — to leak in**.
To address this, a 3-layer system redacts proper nouns before rendering HTML.

## Goal

By default, Claude harness search is **limited to the current project** (safe default).

When you want to bring in knowledge from similar projects, specify the
`--cross-project-group <name>` flag to enable cross-project search.
At that point, 3 layers of defense ensure that **proper nouns from other projects
do not leak into the current project's HTML**.

## How to Use

### Group definition (prerequisite)

List member projects in `.claude/rules/cross-project-groups.yaml`:

```yaml
schema_version: cross-project-group.v1
groups:
  - name: PersonalTools
    members:
      - my-cli
      - my-dotfiles
      - my-scripts
```

Details: [cross-project-groups-schema.md](cross-project-groups-schema.md)

### Enabling cross-project search

```bash
# Use cross-project search in Plan Brief
/harness-plan-brief --cross-project-group "PersonalTools"
```

Or use the MCP N-call flow described in Step 2 (alt) of the skill's SKILL.md, which is applied automatically.

### How the 3-layer redaction works

When cross-project search is enabled, the following are applied automatically during HTML generation:

#### Layer 1: harness-mem server side (Cross-Contract, separate repo)

- Strip `<private>` blocks (always applied at server exit, cannot be opted out)
- `strict_project: true` is default (currently immutable via MCP; N-call support added in Phase 65.3.5)
- Implementation: `harness-mem/memory-server/src/core/privacy-tags.ts`

#### Layer 2a: Dictionary-based proper noun redaction (client side)

- Literal string matching from the dict in `.claude/rules/client-redaction.yaml`
- Example: `NoraiCorp` → `[Client_A]`, `John Smith` → `[Person_A]`
- Implementation: `scripts/redact-by-dictionary.sh` (PiiRule-compatible schema)

#### Layer 2b: NER (Named Entity Recognition) redaction (client side)

- Morphological analysis using Japanese tokenizer (fugashi + UniDic-lite)
- Tokens where pos2 == "proper noun" are replaced with `[Entity]`
- Consecutive proper noun tokens are merged into a single `[Entity]`
- If the tokenizer is absent: **fail-open** (original text + stderr warning)
- Implementation: `scripts/redact-by-ner.sh`

#### Layer 3: Final sanity scan (client side)

- Scan before HTML generation, excluding template chrome (CSS/HTML comments)
- Detect 5 or more consecutive katakana characters as "residue"
- On detection: **HTML is not generated and exits with 1** (fail-safe)
- Implementation: `scripts/render-html.sh --with-redaction` + `scripts/final-scan-redaction.py`

### Audit log

Every time a cross-project search runs, one line is appended to `.claude/state/audit/cross-project-search.jsonl`:

```json
{
  "schema_version": "cross-project-audit.v1",
  "timestamp": "2026-05-09T12:00:00Z",
  "group_name": "PersonalTools",
  "member_projects": ["my-cli", "my-dotfiles"],
  "query_hash": "<sha256 64 chars>",
  "redaction_count": {"dict": 2, "ner": 1},
  "output_passed_final_scan": true
}
```

The actual query string is **not recorded** (for privacy) — only the sha256 hash.

The generated HTML footer shows "redacted: dict X items + NER Y items."

## Things to be aware of

### 1. Layer 1 is on the server side (separate repo) — do not touch it from claude-code-harness

Per the cross-repo handoff workflow (D42) boundary, Layer 1 is fully handled by harness-mem.
Even if a new fixture containing `<private>` is created on the client side, it will always be stripped
via the server (cannot be opted out).

### 2. NER tokenizer is an opt-in dependency

`scripts/redact-by-ner.sh` uses fugashi (Python tokenizer).
Installation status:
- Automatically used if available (check: `python3 -c "from fugashi import Tagger"`)
- Fail-open if absent (only Layer 2a + Layer 3 operate)

For full NER coverage, run `pip install fugashi unidic-lite`.

### 3. Layer 3 final scan is fail-safe

If 5 or more consecutive katakana characters are detected, HTML is **not generated and exits with 1**.
Not generating is safer than "generated HTML with leaks going public."

Intentional branding by the template author (e.g., `harness-orange` in a CSS comment) is excluded
(template chrome strip excludes `<!-- -->` `/* */` `<style>` `<script>` from the scan scope).

### 4. Double-replacement guard for existing server-side sentinel `[REDACTED_*]`

The `[REDACTED_EMAIL]` `[REDACTED_KEY]` `[REDACTED_SECRET]` `[REDACTED_HEX]` output
by `event-recorder.ts:redactContent` on the mem side must not be re-redacted by client Layer 2.
This is implemented in 3 stages: sentinel escape → redact → restore.
The regex `[A-Za-z0-9_]+` handles both upper and lower case.

### 5. Cross-project default is OFF

Unless the `--cross-project-group` flag is specified, search is limited to the current project
(Phase 65.1.x behavior). Cross-project search only runs with an explicit opt-in.

### 6. Raw queries are not stored in the audit log

Only `query_hash` (sha256, 64-char hex) is recorded.
Since it cannot be reversed, the actual query content is protected even in the event of a leak.

## Related

- [cross-project-groups-schema.md](cross-project-groups-schema.md) — Group configuration
- [cognitive-load-surfaces.md](cognitive-load-surfaces.md) — Role of the 3 surfaces
- `.claude/rules/cross-repo-handoff.md` — D42 (claude-code-harness ↔ harness-mem boundary)
- `.claude/memory/decisions.md` D43 (design decisions for this feature, 4-decision package)

## Related scripts

| Script | Role |
|----------|------|
| `scripts/load-cross-project-groups.sh` | Read yaml SSOT and resolve member projects |
| `scripts/redact-by-dictionary.sh` | Layer 2a dictionary redaction |
| `scripts/redact-by-ner.sh` | Layer 2b NER redaction |
| `scripts/final-scan-redaction.py` | Layer 3 final scan |
| `scripts/render-html.sh --with-redaction` | Apply all 3 layers sequentially and generate HTML |
| `scripts/cross-project-audit-log.sh` | Append to audit log |
