# Versioning Rules

Versioning standards for Harness. Follows SemVer (Semantic Versioning).

## Version Determination Criteria

| Type of change | Version | Example |
|-----------|----------|-----|
| Wording fix or addition in skill definition (SKILL.md) | **patch** (x.y.Z) | Template minor fix, description improvement |
| Updates to documentation or rule files | **patch** (x.y.Z) | CHANGELOG rewrite, rules/ addition |
| Bug fix in hooks/scripts | **patch** (x.y.Z) | Escape fix in task-completed.sh |
| Adding a new flag/subcommand to an existing skill | **minor** (x.Y.0) | `--snapshot`, `--auto-mode` |
| Adding a new skill/agent/hook | **minor** (x.Y.0) | New skill `harness-foo` |
| Changes to the TypeScript guardrail engine | **minor** (x.Y.0) | New rule added, existing rule changed |
| Compatibility update for a new Claude Code version | **minor** (x.Y.0) | CC v2.1.72 support |
| Breaking changes (old skill deprecated, format incompatible) | **major** (X.0.0) | Plans.md v1 support removed |

## Decision Flowchart

```
Does it break existing behavior?
├─ Yes → major
└─ No → Does it enable users to do something new?
    ├─ Yes → minor
    └─ No → patch
```

## Batch Release Recommendation

- **When multiple Phases are completed on the same day**: consolidate into one minor release
- **Phase completion + documentation fix**: include the phase as minor with the documentation fix bundled (do not make it a separate release)
- **CC compatibility update + feature addition**: may be combined into one minor

### Bad Example

```
v3.6.0 (03/08 AM) — Phase 25
v3.7.0 (03/08 PM) — Phase 26    ← avoid 2 minor bumps on the same day
v3.7.1 (03/09)    — Auto Mode
```

### Good Example

```
v3.6.0 (03/08) — Phase 25 + Phase 26    ← consolidated into 1 minor
v3.6.1 (03/09) — Auto Mode prep         ← prep is a patch
```

## Pre-Release Checklist

1. **List all changes since the last release**
2. **Determine the version type against the criteria**
3. **Consider batching multiple changes made on the same day**
4. **Confirm the 4-way sync of VERSION / plugin.json / harness.toml / CHANGELOG**
5. **Confirm that git tags are consecutive without gaps**

## Prohibited Actions

- Deleting or rolling back tags (published versions are immutable)
- More than one minor bump on the same day
- Bumping to minor for patch-level changes
