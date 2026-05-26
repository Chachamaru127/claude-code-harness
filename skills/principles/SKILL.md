---
name: principles
description: "Explicit helper for development principles, safety guidelines, and diff-aware editing rules. Do NOT load for: implementation, review, workflow coaching, or VibeCoder onboarding."
description-en: "Explicit helper for development principles, safety guidelines, and diff-aware editing rules. Do NOT load for: implementation, review, workflow coaching, or VibeCoder onboarding."
allowed-tools: ["Read"]
user-invocable: false
disable-model-invocation: true
---

# Principles Skills

A set of skills providing development principles and guidelines.

## Feature Details

| Feature | Details |
|------|------|
| **General principles** | See [references/general-principles.md](${CLAUDE_SKILL_DIR}/references/general-principles.md) |
| **Diff-aware editing** | See [references/diff-aware-editing.md](${CLAUDE_SKILL_DIR}/references/diff-aware-editing.md) |
| **Context reading** | See [references/repo-context-reading.md](${CLAUDE_SKILL_DIR}/references/repo-context-reading.md) |
| **VibeCoder** | See [references/vibecoder-guide.md](${CLAUDE_SKILL_DIR}/references/vibecoder-guide.md) |

## Execution Steps

1. Classify the user's request
2. Read the appropriate reference file from "Feature Details" above
3. Reference and apply its contents
