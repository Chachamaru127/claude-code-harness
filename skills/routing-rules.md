# Skill Routing Rules (Reference)

Reference document for routing rules between skills.

> **SSOT location**: The `description` field of each skill is the SSOT for routing.
> This file is a reference providing detailed explanations and examples; actual routing depends on each skill's description.
>
> **Important**: The description of each skill and the "Do NOT Load For" table in the body must be in exact agreement.

## Codex-Related Routing

### harness-review (includes Codex review functionality)

**Purpose**: Provides a second-opinion review via Codex CLI (`codex exec`) (integrated from `codex-review` in v3)

**Trigger keywords** (quoted from description):
- "review", "code review", "plan review"
- "scope analysis", "security", "performance"
- "quality checks", "PRs", "diffs"
- "/harness-review"

**Exclusion keywords** (quoted from description):
- "implementation", "new features", "bug fixes"
- "setup", "release"

### harness-work --codex (includes Codex implementation functionality)

**Purpose**: Uses Codex as the implementation engine (integrated in v3)

**Trigger keywords**:
- "implement", "execute", "/work"
- "breezing", "team run"
- "--codex", "--parallel"

**Exclusion keywords** (quoted from description):
- "planning", "code review", "release"
- "setup", "initialization"

**Invocation**: Run with `/harness-work --codex`

## Routing Decision Flow (Reference)

> This section describes Claude Code's internal behavior and does not define additional keywords.
> Actual routing is determined solely by the keywords listed in each skill's description.

```
User input
    │
    ├── Matches trigger keyword in description → load the skill
    ├── Matches exclusion keyword in description → exclude the skill
    └── Neither → standard skill matching
```

## Priority Rules (Reference)

Priority when a keyword matches multiple skills:

1. **Exclusions take highest priority**: A skill that matches an exclusion keyword is never loaded
2. **More specific keywords win**: Exact match > partial match

> **Note**: "Context-based judgment" is not used as it introduces ambiguity. Routing is determined decisively by keywords in descriptions.

## Update Rules

1. **description = SSOT**: The `description` field of each skill is the authoritative routing definition
2. **Body must match**: Each skill's "Do NOT Load For" table must exactly match its description
3. **Role of this file**: Reference for detailed explanations and decision flow (not the SSOT)
4. **Maintain a complete list**: Use specific keywords, not generic expressions (e.g., "anything related to X")
