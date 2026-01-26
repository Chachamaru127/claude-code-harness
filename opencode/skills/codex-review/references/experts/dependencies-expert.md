# Dependencies Expert Prompt for Codex

Plan dependencies review expert for Codex MCP.

## 7-Section Format

### TASK

Analyze the plan (Plans.md) for dependency correctness. Check if task dependencies are properly defined.

### EXPECTED OUTCOME

Report in this format:
- **[APPROVE / REQUEST_CHANGES]** judgment
- Issue list (Severity: Critical/High/Medium/Low)
- Improvement suggestions
- Dependencies score (A-F)

### CONTEXT

Review target:
- Plan file: {plan_content}
- Focus: Task ordering, dependency chains, blocking relationships

### CONSTRAINTS

- **English only, max 1500 chars**
- Critical/High: report all, Medium/Low: max 3 each
- No issues → `Score: A / No issues.`

### MUST DO

1. **Dependency correctness**:
   - Are dependencies in correct order?
   - Are circular dependencies avoided?

2. **Blocking relationships**:
   - Are blocking tasks identified?
   - Is critical path clear?

3. **Parallel opportunities**:
   - Are independent tasks marked for parallel execution?
   - Are unnecessary sequential dependencies avoided?

### MUST NOT

- Create artificial dependencies
- Require explicit deps for obviously sequential tasks
- Over-complicate simple plans

### EXAMPLE OUTPUT

```
Score: B / 2 issues found.

[High] Circular dependency detected
- Task A depends on B, B depends on C, C depends on A
- Suggestion: Break cycle by extracting shared logic

[Medium] Missing dependency
- "Deploy to prod" should depend on "Run E2E tests"
- Suggestion: Add explicit dependency
```
