# TDD Adoption

## Purpose

Strict TDD = accurately understanding user intent. Tests are "specification documentation", agreeing before implementation.

## TDD Adoption Judgment

**Adopt TDD if any of the following conditions apply**:

| Judgment Condition | Reason |
|-------------------|--------|
| Contains business logic | Calculation, judgment, state transition require specification documentation |
| Has data transformation/processing | Many boundary conditions in input→output conversion |
| Has external API integration | Clarify specifications through mock design |
| Has multiple branches/conditions | Need to identify edge cases |
| Involves money/auth/permissions | No room for error (security + TDD) |
| User's words are vague | Align understanding through test cases |

**Record judgment result**:
```
Feature "{{feature name}}" → TDD adoption reason: {{matching condition}}
```

## Deep Intent Questions

For features with TDD adoption decision, **always ask the following**:

> 🎯 **Let me confirm about "{{feature name}}" before writing tests**
>
> 1. **Normal case**: What's the most common usage? (specific scenario)
> 2. **Boundary conditions**: Where's the line between "barely OK" and "barely NG"?
> 3. **On error**: How do you want to show errors to users?
> 4. **Implicit expectations**: What do you consider "obvious"? (unspoken rules)

**Additional questions to draw out tacit knowledge** (as needed):

| Situation | Additional Question |
|-----------|---------------------|
| Handling numbers | "Allow 0 or negative?" "Decimal places?" |
| Handling dates | "Timezone?" "Allow past dates?" |
| Handling strings | "Empty string?" "Max length?" "Emojis?" |
| Handling lists | "Empty list?" "Upper limit?" "Duplicates?" |
| State transitions | "Can go back?" "Cancel midway?" "Timeout?" |
| User operations | "What if spammed?" "What if they leave midway?" |

## Test Case Design (Include in Plans.md)

**TDD-adopted features include test design before implementation tasks**:

```markdown
### {{Feature Name}} `[feature:tdd]`

#### Test Case Design (Agree before implementation)

| Test Case | Input | Expected Output | Notes |
|-----------|-------|-----------------|-------|
| Normal: basic | {{example}} | {{expected}} | Most common case |
| Normal: boundary lower | {{barely OK}} | {{success}} | Lower limit test |
| Normal: boundary upper | {{barely OK}} | {{success}} | Upper limit test |
| Error: boundary exceeded | {{barely NG}} | {{error}} | Validation check |
| Error: null/empty | null, "", [] | {{error}} | Defensive programming |
| Edge case | {{special case}} | {{expected behavior}} | Tacit knowledge documentation |

#### Implementation Tasks
- [ ] Create test file (implement above cases)
- [ ] Create implementation code (until tests pass)
- [ ] Refactor (while maintaining tests)
```

## When TDD Not Adopted

Simple features not matching TDD judgment conditions (static UI, config file generation, etc.) proceed with normal implementation flow. However, if user requests "also write tests", adopt TDD.
