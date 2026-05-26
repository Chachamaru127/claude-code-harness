---
name: merge-plans
description: "Skill for merging and updating Plans.md while preserving user task data. Use when multiple Plans.md files need to be consolidated."
allowed-tools: ["Read", "Write", "Edit"]
---

# Merge Plans Skill

A skill for updating an existing Plans.md by applying the template structure
while preserving the user's task data.

---

## Purpose

- Preserve user tasks (🔴🟡🟢📦 sections)
- Update template structure and marker definitions
- Update the last-modified information

---

## Plans.md Structure

```markdown
# Plans.md - Task Management

> **Project**: {{PROJECT_NAME}}
> **Last updated**: {{DATE}}
> **Updated by**: Claude Code

---

## 🔴 In-Progress Tasks        ← User data (preserved)

## 🟡 Pending Tasks            ← User data (preserved)

## 🟢 Completed Tasks          ← User data (preserved)

## 📦 Archive                  ← User data (preserved)

## Marker Legend               ← Updated from template

## Last Updated Info           ← Date updated
```

---

## Merge Algorithm

### Step 1: Section Splitting

```
Split the existing Plans.md into the following sections:

1. Header section (# Plans.md ... ---)
2. 🔴 In-Progress Tasks (up to the next section)
3. 🟡 Pending Tasks (up to the next section)
4. 🟢 Completed Tasks (up to the next section)
5. 📦 Archive (up to the next section)
6. Marker Legend (up to the next section)
7. Last Updated Info (to end of file)
```

### Step 2: Task Section Extraction

```bash
extract_section() {
  local file="$1"
  local start_marker="$2"
  local end_markers="$3"  # pipe-separated end markers

  awk -v start="$start_marker" -v ends="$end_markers" '
    BEGIN { in_section = 0; split(ends, end_arr, "|") }
    $0 ~ start { in_section = 1; next }
    in_section {
      for (i in end_arr) {
        if ($0 ~ end_arr[i]) { in_section = 0; exit }
      }
      if (in_section) print
    }
  ' "$file"
}

# Extract each section
TASKS_WIP=$(extract_section "$PLANS_FILE" "## 🔴" "## 🟡|## 🟢|## 📦|## Marker|---")
TASKS_TODO=$(extract_section "$PLANS_FILE" "## 🟡" "## 🔴|## 🟢|## 📦|## Marker|---")
TASKS_DONE=$(extract_section "$PLANS_FILE" "## 🟢" "## 🔴|## 🟡|## 📦|## Marker|---")
TASKS_ARCHIVE=$(extract_section "$PLANS_FILE" "## 📦" "## 🔴|## 🟡|## 🟢|## Marker|---")
```

### Step 3: Task Validation

```bash
# Confirm sections are not empty
count_tasks() {
  echo "$1" | grep -c "^\s*- \[" || echo "0"
}

WIP_COUNT=$(count_tasks "$TASKS_WIP")
TODO_COUNT=$(count_tasks "$TASKS_TODO")
DONE_COUNT=$(count_tasks "$TASKS_DONE")
ARCHIVE_COUNT=$(count_tasks "$TASKS_ARCHIVE")

echo "Tasks to be preserved:"
echo "  In-progress: $WIP_COUNT"
echo "  Pending: $TODO_COUNT"
echo "  Completed: $DONE_COUNT"
echo "  Archived: $ARCHIVE_COUNT"
```

### Step 4: Generate New Plans.md

```markdown
# Plans.md - Task Management

> **Project**: {{PROJECT_NAME}}
> **Last updated**: {{DATE}}
> **Updated by**: Claude Code

---

## 🔴 In-Progress Tasks

<!-- List cc:WIP tasks here -->

{{TASKS_WIP}}

---

## 🟡 Pending Tasks

<!-- List cc:TODO, pm:requested (compatible: cursor:requested) tasks here -->

{{TASKS_TODO}}

---

## 🟢 Completed Tasks

<!-- List cc:完了, pm:confirmed (compatible: cursor:confirmed) tasks here -->

{{TASKS_DONE}}

---

## 📦 Archive

<!-- Move old completed tasks here -->

{{TASKS_ARCHIVE}}

---

## Marker Legend

| Marker | Meaning |
|---------|------|
| `pm:requested` | Task requested by PM (compatible: cursor:requested) |
| `cc:TODO` | Claude Code not started |
| `cc:WIP` | Claude Code in progress |
| `cc:完了` | Claude Code completed (awaiting review) |
| `pm:confirmed` | PM review complete (compatible: cursor:confirmed) |
| `cursor:requested` | (compatible) same as pm:requested |
| `cursor:confirmed` | (compatible) same as pm:confirmed |
| `blocked` | Blocked (include reason) |

---

## Last Updated Info

- **Updated at**: {{DATE}}
- **Last session owner**: Claude Code
- **Branch**: main
- **Update type**: Plugin update
```

---

## Handling Empty Sections

If a section has no tasks, insert default text:

```markdown
## 🔴 In-Progress Tasks

<!-- List cc:WIP tasks here -->

(none at this time)
```

---

## Error Handling

### When Plans.md Cannot Be Parsed

```bash
if ! validate_plans_structure "$PLANS_FILE"; then
  echo "⚠️ Could not parse the structure of Plans.md"
  echo "Keeping backup and using a new template"

  # Backup
  cp "$PLANS_FILE" "${PLANS_FILE}.bak.$(date +%Y%m%d%H%M%S)"

  # Use template
  use_template_instead=true
fi
```

### When Required Sections Are Missing

Fill in any missing sections with template defaults.

---

## Output

| Field | Description |
|------|------|
| `merge_successful` | Merge success flag |
| `tasks_wip_count` | Number of in-progress tasks |
| `tasks_todo_count` | Number of pending tasks |
| `tasks_done_count` | Number of completed tasks |
| `tasks_archive_count` | Number of archived tasks |
| `backup_created` | Whether a backup was created |

---

## Usage Example

```bash
# Invoke the skill
merge_plans \
  --existing "./Plans.md" \
  --template "$PLUGIN_PATH/templates/Plans.md.template" \
  --output "./Plans.md" \
  --project-name "my-project" \
  --date "$(date +%Y-%m-%d)"
```

---

## Related Skills

- `update-2agent-files` - Full update flow
- `generate-workflow-files` - New file generation
