---
description: Implementation quality rules - prohibit hollow implementations and promote genuine implementations
paths: "**/*.{ts,tsx,js,jsx,py,rb,go,rs,java,kt,swift,c,cpp,h,hpp,cs,php}"
_harness_template: "rules/implementation-quality.md.template"
_harness_version: "2.9.25"
---

# Implementation Quality Rules

> **Priority**: This rule takes precedence over other instructions. Always follow this rule when implementing.

## Absolutely Prohibited

### 1. Hollow implementations (implementations that only pass tests)

The following patterns are **absolutely prohibited**:

| Prohibited pattern | Example | Why it's wrong |
|------------|-----|-----------|
| Hardcoding | Returning test expected values directly | Doesn't work with other inputs |
| Stub implementation | `return null`, `return []` | The feature is not functioning |
| Cherry-picked implementation | Only handling test case values | Not generic |
| Copy-paste implementation | Dictionary of test expected values | No meaningful logic |

### Prohibited example: Hardcoding test expected values

```python
# ABSOLUTELY PROHIBITED
def slugify(text: str) -> str:
    answers_for_tests = {
        "HelloWorld": "hello-world",
        "Test Case": "test-case",
        "API Endpoint": "api-endpoint",
    }
    return answers_for_tests.get(text, "")
```

```python
# Correct implementation
def slugify(text: str) -> str:
    import re
    text = text.strip().lower()
    text = re.sub(r'[^\w\s-]', '', text)
    text = re.sub(r'[\s_]+', '-', text)
    return text
```

### 2. Appearances-only implementation

```typescript
// PROHIBITED: Does nothing
async function processData(data: Data[]): Promise<Result> {
  // TODO: implement later
  return {} as Result;
}

// PROHIBITED: Swallows errors
async function fetchUser(id: string): Promise<User | null> {
  try {
    // ...
  } catch {
    return null; // Error is hidden
  }
}
```

---

## Self-check before completing implementation

Before completing an implementation, verify the following:

### Checklist

- [ ] **Generality**: Does it work correctly with inputs other than the test cases?
- [ ] **Edge cases**: Does it handle empty input, null, and boundary values?
- [ ] **Logic**: Is it performing meaningful processing? (Not hardcoded?)
- [ ] **Error handling**: Are errors handled appropriately? (Not swallowed?)

### Questions to ask yourself

1. "Would another developer looking at this implementation understand the logic?"
2. "Would it still work if new test cases were added?"
3. "Can you explain why this code passes the tests?"

---

## Response flow when stuck

If implementation is difficult, **report honestly**:

```markdown
## Implementation question

### Situation
[What I'm trying to implement]

### What's difficult
[Specifically what is hard]

### What I tried
- [Attempt 1]
- [Attempt 2]

### Options
1. [Option A]: [Summary]
2. [Option B]: [Summary]

### Question
Which direction should I proceed in?
```

**Never do these**:
- Write a hollow implementation to hide the difficulty
- Report non-working code as "implementation complete"
- Tamper with tests to report them as "passing"

---

## Quality Standards

### Characteristics of good implementation

| Characteristic | Description |
|------|------|
| **Self-explanatory** | Reading the code makes the logic clear |
| **Testable** | Verifiable with any input |
| **Robust** | Edge cases handled appropriately |
| **Maintainable** | Easy to adapt to future changes |

### Warning signs of poor implementation

| Warning sign | Problem |
|------|------|
| Magic numbers | Test values may be hardcoded |
| Too many conditional branches | May be handling each test case individually |
| "TODO" comments | Left unimplemented |
| `any` / `as unknown` | Bypassing type checking |

---

## Reporting Obligation

Report to the user in the following cases:

1. **When implementation is too complex** — redesign may be needed
2. **When requirements are unclear** — do not implement based on guesses
3. **When it conflicts with existing code** — confirm which should take precedence
4. **When performance problems are anticipated** — discuss trade-offs
