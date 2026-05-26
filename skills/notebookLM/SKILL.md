---
name: notebookLM
description: "Generate NotebookLM YAML and slides. Document craftsman shows skill. Use when user mentions NotebookLM, YAML, slides, or presentations. Do NOT load for: implementation work, code fixes, reviews, or deployments."
description-en: "Generate NotebookLM YAML and slides. Document craftsman shows skill. Use when user mentions NotebookLM, YAML, slides, or presentations. Do NOT load for: implementation work, code fixes, reviews, or deployments."
allowed-tools: ["Read", "Write", "Edit"]
disable-model-invocation: true
user-invocable: false
argument-hint: "[yaml|slides]"
---

# NotebookLM Skill

A set of skills responsible for document generation.

## Feature Details

| Feature | Details |
|------|------|
| **NotebookLM YAML** | See [references/notebooklm-yaml.md](${CLAUDE_SKILL_DIR}/references/notebooklm-yaml.md) |
| **Slide YAML** | See [references/notebooklm-slides.md](${CLAUDE_SKILL_DIR}/references/notebooklm-slides.md) |

## Execution Steps

1. Classify the user's request
2. Read the appropriate reference file from "Feature Details" above
3. Generate according to its contents

---

## PDF Page Range Reading (Claude Code 2.1.49+)

A feature for efficiently handling large PDFs.

### Reading with page range specification

```javascript
// Read with page range
Read({ file_path: "docs/spec.pdf", pages: "1-10" })

// Check table of contents only
Read({ file_path: "docs/manual.pdf", pages: "1-3" })

// Specific section only
Read({ file_path: "docs/api-reference.pdf", pages: "25-45" })
```

### Recommended approach by use case

| Case | Recommended reading method | Reason |
|--------|----------------|------|
| **PDFs over 100 pages** | Table of contents (1-3) → relevant chapters only | Minimize token consumption |
| **Specification review** | Specify range per section | Read only the necessary parts in detail |
| **API documentation** | Start from endpoint list (table of contents) | Understand overall structure before diving into details |
| **Academic papers** | Abstract + conclusion → body | Grasp key points first |
| **Technical manuals** | Table of contents + troubleshooting chapter | Prioritize practical sections |

### Example usage when generating NotebookLM YAML

```markdown
When generating YAML from a large PDF (300-page technical specification):

1. **Read the table of contents** (pages 1-5)
   Read({ file_path: "spec.pdf", pages: "1-5" })
   → Understand the chapter structure

2. **Read the opening of each chapter** (first 2 pages of each chapter)
   Read({ file_path: "spec.pdf", pages: "10-11" })  // Chapter 1
   Read({ file_path: "spec.pdf", pages: "45-46" })  // Chapter 2
   → Grasp the overview of each chapter

3. **Read important sections in detail**
   Read({ file_path: "spec.pdf", pages: "78-95" })  // API reference
   → Extract detailed content

With this approach, you can efficiently generate YAML without reading all 300 pages.
```

### Best practices

| Principle | Description |
|------|------|
| **Progressive loading** | Read in order: table of contents → overview → details |
| **Relevant pages only** | Specify only the pages needed for the task |
| **Token savings** | Reading all pages is a last resort |
| **Structure-first understanding** | Grasp the overall picture from the table of contents before going into details |

### Comparison with the traditional approach

| Method | Token consumption | Processing time | Accuracy |
|------|------------|---------|------|
| **Read all pages** (300 pages) | ~150,000 | Long | High |
| **Page range specification** (30 necessary pages) | ~15,000 | Short | High |

→ **90% token reduction and faster processing is achievable**
