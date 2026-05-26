# cross-project-group.v1 Schema

Introduced in Phase 65.3 (Cross-Project Group + 3-Layer Redaction).
Schema specification for `.claude/rules/cross-project-groups.yaml`.

## Purpose

This is the SSOT for group definitions that allow client-side skills like
Plan Brief / Acceptance Demo / Progress Tracker to **opt-in to cross-project search**.

Cross-project search is disabled by default. Only when a group name is explicitly specified
with `--cross-project-group <name>` will `mcp__harness__harness_mem_search` be issued
against the member projects of that group.

## Schema

```yaml
schema_version: cross-project-group.v1

groups:
  - name: <string>            # Group identifier
    description: <string?>    # Optional (description of group's purpose)
    members:                  # Array, elements unique, empty OK
      - <string>              # Member project name
      - <string>
```

## Constraints

| Field | Type | Required | Constraints |
|---|---|---|---|
| `schema_version` | string | ✓ | Fixed to `cross-project-group.v1` |
| `groups` | array | ✓ | Empty array `[]` allowed |
| `groups[].name` | string | ✓ | Unique within `groups`, cannot be empty |
| `groups[].description` | string | optional | Optional |
| `groups[].members` | array | ✓ | Array, elements unique, empty OK |
| `groups[].members[]` | string | - | Cannot be empty, no duplicates |

## Validation

`scripts/load-cross-project-groups.sh` parses the yaml and stops with **exit 1** if an invalid schema is detected.

Detected errors:

1. `schema_version` mismatch (anything other than `cross-project-group.v1`)
2. `groups` is not an array
3. `groups[].name` is missing / empty / duplicated
4. `groups[].members` is not an array / has duplicate elements / contains empty strings
5. `groups[].members[]` is not a string

## Usage Examples

### CLI (direct call to loader script)

```bash
# Output all groups as JSON
bash scripts/load-cross-project-groups.sh

# Output members of a specific group as a JSON array
bash scripts/load-cross-project-groups.sh --group "Personal Tools"
# → ["my-cli","my-dotfiles","my-scripts"]

# Nonexistent group exits with 1
bash scripts/load-cross-project-groups.sh --group "Unknown"
# → stderr: "group not found: Unknown" / exit 1
```

### Via skill (implemented in Phase 65.3.5)

```bash
# No cross-project search (default, current project only)
/harness-plan-brief "I want to introduce new CI"

# Cross-project search opt-in (search all members of Personal Tools group)
/harness-plan-brief "I want to introduce new CI" --cross-project-group "Personal Tools"
```

## Cross-Project Search Implementation (D43 Option α)

```
client skill (Plan Brief / Accept / Progress)
   │
   │ --cross-project-group <name>
   ▼
load-cross-project-groups.sh --group <name>
   │
   │ JSON array of member projects
   ▼
For each member in members:
   mcp__harness__harness_mem_search(project=member, ...)
   │
   ▼
Merge and dedupe on client side (sorted by relevance_score)
   │
   ▼
Layer 2 (dict + NER) redacts proper nouns
   │
   ▼
Layer 3 (final scan) detects residue → if 0: generate HTML, if detected: exit 1
```

For detailed responsibility boundaries, see `.claude/rules/cross-repo-handoff.md`
"3-Layer Redaction Responsibility Boundaries" and "Phase 65.3 Implementation Decisions (D43)".

## Related

- `.claude/rules/cross-project-groups.yaml` — SSOT for this schema (default `groups: []`)
- `scripts/load-cross-project-groups.sh` — yaml → JSON parser + validator
- `tests/test-cross-project-groups-schema.sh` — 4-case automated verification
- `.claude/rules/cross-repo-handoff.md` — Phase 65.3 implementation decisions (D43)
- `.claude/rules/client-redaction.yaml` — Layer 2a dictionary (introduced in Phase 65.3.2)
- Plans.md §65.3.1-65.3.7 — Phase C all tasks
