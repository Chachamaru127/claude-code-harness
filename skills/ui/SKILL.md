---
name: ui
description: "Explicit helper for UI components, hero sections, forms, feedback, and contact surfaces. Do NOT load for: authentication, backend implementation, database work, or business logic."
allowed-tools: ["Read", "Write", "Edit", "Bash"]
user-invocable: false
disable-model-invocation: true
---

# UI Skills

Skills for generating UI components and forms.

## Constraint Priority and Conditions

1. Apply the constraints from `${CLAUDE_SKILL_DIR}/references/ui-skills.md` as the highest priority by default.
2. Apply `${CLAUDE_SKILL_DIR}/references/frontend-design.md` only when something like "bold / distinctive / expressive / brand-forward" is **explicitly** requested.
3. The MUST/NEVER rules in UI Skills apply in principle. However, the following exceptions are permitted **only when the user explicitly requests them**:
   - Gradients, glows, heavy decoration
   - Animations (adding or extending)
   - Custom easing

## Feature Details

| Feature | Details |
|---------|---------|
| **Constraint set** | See [references/ui-skills.md](${CLAUDE_SKILL_DIR}/references/ui-skills.md) / [references/frontend-design.md](${CLAUDE_SKILL_DIR}/references/frontend-design.md) |
| **Component generation** | See [references/component-generation.md](${CLAUDE_SKILL_DIR}/references/component-generation.md) |
| **Feedback forms** | See [references/feedback-forms.md](${CLAUDE_SKILL_DIR}/references/feedback-forms.md) |

## Execution Steps

1. **Apply the constraint set** (follow priority order)
2. **Quality gate** (Step 0)
3. Classify the user's request
4. Read the appropriate reference file from "Feature Details" above
5. Generate according to that reference

### Step 0: Quality Gate (a11y checklist)

When generating UI components, ensure accessibility:

```markdown
♿ Accessibility Checklist

The generated UI should satisfy the following:

### Required
- [ ] Images have alt attributes
- [ ] Form elements are associated with labels
- [ ] Keyboard-operable (Tab key moves focus)
- [ ] Focus state is visually apparent

### Recommended
- [ ] Information is not conveyed by color alone
- [ ] Contrast ratio at least 4.5:1 (text)
- [ ] Appropriate use of aria-label / aria-describedby
- [ ] Heading structure (h1 → h2 → h3) is logical

### Interactive Elements
- [ ] Buttons have descriptive labels (e.g. "View Product Details" not just "Details")
- [ ] Focus trap in modals/dialogs
- [ ] Error messages are announced by screen readers
```

### For VibeCoder Users

```markdown
♿ Making a Design Usable for Everyone

1. **Add descriptions to images**
   - Use "Red sneakers, front view" instead of "Product image"

2. **Make clickable areas keyboard-operable**
   - Tab to navigate, Enter to activate

3. **Don't rely on color alone**
   - Use icon + text alongside red = error
```
