---
name: core-diff-aware-editing
description: "Edit files with minimal diffs to minimize impact on existing code."
allowed-tools: ["Read", "Edit"]
---

# Diff-Aware Editing

A skill for making changes to files with minimal diffs.
Prevents unintended destruction of existing code and produces changes that are easy to review.

---

## Core Principles

### 1. Read Before Edit

**Always read the target file before editing it**

```
❌ Bad: Overwrite the entire file using the Write tool
✅ Good: Read → review contents → use Edit to change only the necessary parts
```

### 2. Prefer Minimal Diffs

Keep changes to the absolute minimum necessary:

- Preserve existing indentation and formatting
- Keep existing comments
- Match the style already in use

### 3. Change One Meaningful Unit at a Time

```typescript
// ❌ Bad: Mix unrelated changes
// Adding a function + changing formatting + reorganizing imports

// ✅ Good: Focus on a single change
// Add the function only
```

---

## How to Use the Edit Tool

### Pattern 1: Simple substitution

```
old_string: "const value = 1"
new_string: "const value = 2"
```

### Pattern 2: Adding a code block

```
old_string: "// TODO: implement feature"
new_string: "// Feature implemented
const feature = () => {
  // implementation
}"
```

### Pattern 3: Modifying a function

```
old_string: "function getData() {
  return []
}"
new_string: "function getData() {
  const data = fetchData()
  return data
}"
```

---

## Patterns to Avoid

### 1. Rewriting the entire file

```
❌ Rewriting all 100 lines of a file with the Write tool
✅ Using the Edit tool to fix only the 5 lines that need changing
```

### 2. Mixing in formatting changes

```
❌ Changing indentation at the same time as adding a feature
✅ Feature addition only. Handle formatting in a separate commit.
```

### 3. Adding unnecessary blank lines or comments

```
❌ Imposing your own style
✅ Follow the existing style
```

---

## Pre-edit Checklist

1. [ ] Confirmed the target file with Read
2. [ ] Identified the locations that need changing
3. [ ] Understood the existing style (indentation, naming conventions)
4. [ ] Confirmed the change is within paths.allowed_modify
5. [ ] Can visualize how the code will behave after the change

---

## Post-edit Verification

```bash
# Review the diff
git diff

# Check the line count of changes (is it too large?)
git diff --stat

# Check for syntax errors
npm run build 2>&1 | head -20
# or
npx tsc --noEmit
```

---

## Editing Multiple Files

When editing multiple files:

1. **Dependency order**: type definitions → implementation → tests
2. **Ensure consistency**: make related changes together
3. **Keep working at each intermediate state**: maintain a buildable state after each edit

---

## Handling Errors

If an error occurs during editing:

1. **Re-check the original code**: use Read to see the current state
2. **Verify old_string match**: check whitespace and newlines exactly
3. **Split and retry**: break large changes into smaller ones
