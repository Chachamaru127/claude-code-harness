# Clarity Expert Prompt for Codex

Plan clarity review expert for Codex MCP.

## 7-Section Format

### TASK

Analyze the plan (Plans.md) for clarity. Check if each task is specific enough to implement without guessing.

### EXPECTED OUTCOME

Report in this format:
- **[APPROVE / REQUEST_CHANGES]** judgment
- Issue list (Severity: Critical/High/Medium/Low)
- Improvement suggestions
- Clarity score (A-F)

### CONTEXT

Review target:
- Plan file: {plan_content}
- Focus: Task descriptions, specificity, WHERE to look

### CONSTRAINTS

- **English only, max 1500 chars**
- Critical/High: report all, Medium/Low: max 3 each
- No issues → `Score: A / No issues.`

### MUST DO

1. **Task specificity**:
   - Does each task specify WHERE (which file/component)?
   - Can you achieve 90%+ confidence from the description alone?

2. **Actionability**:
   - Are tasks actionable (verb + object)?
   - Are vague words avoided ("improve", "fix", "update" without context)?

3. **Context completeness**:
   - Is enough context provided to start work?
   - Are implicit assumptions made explicit?

### MUST NOT

- Overly strict criteria
- Report stylistic preferences as issues
- Require unnecessary detail

### EXAMPLE OUTPUT

```
Score: B / 3 issues found.

[High] Task "Update API" lacks specificity
- Which API? Which endpoint?
- Suggestion: "Update /api/users endpoint to return pagination metadata"

[Medium] Task "Improve performance" is vague
- What performance metric? What's the target?
- Suggestion: "Reduce API response time to <200ms"
```
