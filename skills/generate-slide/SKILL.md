---
name: generate-slide
description: "Generate project intro slides with Nano Banana Pro. Internal/manual workflow only; use from an explicit /generate-slide command or a parent media workflow."
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep", "AskUserQuestion"]
disable-model-invocation: true
user-invocable: false
argument-hint: "[project-path|description]"
---

# Generate Slide Skill

Automatically generates a single-slide project introduction image using the Nano Banana Pro (Gemini 3 Pro Image Preview) API.

## Invocation Contract

This skill has `user-invocable: false` and `disable-model-invocation: true`.
It is not intended to be auto-selected by Claude from ordinary user speech (e.g., "make a slide").

- Only invoked explicitly via a `/generate-slide` command or internally from a parent media workflow.
- `allowed-tools` is for Claude Code. Claude can use `AskUserQuestion` for user confirmation.
- In Codex mirrors, the equivalent confirmation maps to plan-mode input for `request_user_input`. When that tool is unavailable in normal execution, present defaults and proceed without halting — only confirm critical unknowns with the user.
- `disable-model-invocation: true` means the model will not auto-invoke this skill just from reading the description. When explicitly invoked via a slash command or parent workflow, follow the steps in this document.

---

## Overview

Generate 3 patterns × 2 candidates each = 6 total → quality-check each pattern → retry if NG → output the best 1 of each pattern, 3 images total.

## Prerequisites

- `GOOGLE_AI_API_KEY` environment variable is set
- Nano Banana Pro (Gemini 3 Pro Image Preview) is enabled in Google AI Studio

## Feature Details

| Feature | Details |
|---------|---------|
| **Slide image generation** | See [references/slide-generator.md](${CLAUDE_SKILL_DIR}/references/slide-generator.md) |
| **Quality assessment** | See [references/slide-quality-check.md](${CLAUDE_SKILL_DIR}/references/slide-quality-check.md) |

---

## Execution Flow

```
/generate-slide
    |
    +--[Step 1] Information gathering
    |   +-- User-supplied text or automated codebase analysis (README, package.json, etc.)
    |   +-- Extract project name, summary, key features, tech stack
    |
    +--[Step 2] Spec confirmation (AskUserQuestion)
    |   +-- Size / aspect ratio (default: 16:9 / 2K)
    |   +-- Tone (tech, casual, corporate, etc.)
    |   +-- Points to emphasize (only ask if unclear)
    |
    +--[Step 3] Generate 3 patterns × 2 images (Nano Banana Pro API × 6 calls)
    |   +-- Pattern A: Minimalist (2 images)
    |   +-- Pattern B: Infographic (2 images)
    |   +-- Pattern C: Hero Visual (2 images)
    |
    +--[Step 4] Quality-check per pattern
    |   +-- Claude reads both candidates per pattern with Read
    |   +-- 5-criterion scoring → adopt the higher-scoring candidate
    |   +-- Both score 2 or below → improve prompt and retry (max 3 times)
    |   +-- Retry limit reached → report to user, choose continue or skip
    |
    +--[Step 5] Output the 3 best images
        +-- Copy the best of each pattern to selected/
        +-- Present results list (path + score + evaluation comment) to the user
```

---

## Design Patterns

| Pattern | Concept | Characteristics |
|---------|---------|----------------|
| **Minimalist** | Whitespace and typography-driven | clean, whitespace, typography-driven, elegant |
| **Infographic** | Data/flow visualization | data visualization, metrics, flow diagram, structured |
| **Hero Visual** | Bold visual + tagline | bold visual, impactful, hero image, catchy headline |

---

## Output Location

```
out/slides/
+-- minimalist_1.png       # Pattern A candidate 1
+-- minimalist_2.png       # Pattern A candidate 2
+-- infographic_1.png      # Pattern B candidate 1
+-- infographic_2.png      # Pattern B candidate 2
+-- hero_1.png             # Pattern C candidate 1
+-- hero_2.png             # Pattern C candidate 2
+-- selected/
|   +-- minimalist.png     # Pattern A best
|   +-- infographic.png    # Pattern B best
|   +-- hero.png           # Pattern C best
+-- quality-report.md      # Quality check results report
```

---

## Execution Steps

### Step 1: Information gathering

Collect project information in the following priority order:

1. **User-supplied text**: If a project description is passed as an argument, use it
2. **Automated codebase analysis**: If no argument, automatically analyze the following:
   - `README.md` — project overview
   - `package.json` / `Cargo.toml` / `pyproject.toml` — project name, description, dependencies
   - `CLAUDE.md` — project structure and purpose
   - `Plans.md` — active tasks (if exists)

Information to extract:

| Item | Example |
|------|---------|
| Project name | Claude Code Harness |
| Summary (1-2 sentences) | A plugin for autonomous operation of Claude Code in a Plan-Work-Review workflow |
| Key features (3-5) | Skill management, quality checks, parallel execution |
| Tech stack | TypeScript, Node.js, Claude Code Plugin |
| Colors (if any) | Brand color or inferred |

### Step 2: Spec confirmation

Confirm with AskUserQuestion (only ask if unclear, as defaults are provided):

```
Question 1: Slide size / aspect ratio?
  - 16:9 / 2K (recommended)
  - 4:3 / 2K
  - 1:1 / 2K
  - Custom

Question 2: Tone?
  - Tech (dark theme, code-inspired)
  - Casual (bright, friendly)
  - Corporate (formal, trustworthy)
  - Creative (bold, artistic)
```

### Step 3: Image generation

Following the steps in `slide-generator.md`, generate 3 patterns × 2 images = 6 images.

Each pattern is independent, so run curl calls in parallel where possible:

```bash
# Parallel generation example (3 patterns × 2 images)
for pattern in minimalist infographic hero; do
  for i in 1 2; do
    # Execute curl patterns from slide-generator.md
    # → save to out/slides/${pattern}_${i}.png
  done
done
```

### Step 4: Quality check

Following the criteria in `slide-quality-check.md`, evaluate both candidates per pattern:

1. Read each image with Read
2. 5-criterion scoring (information delivery, layout, text readability, professionalism, brand consistency)
3. Adopt the higher-scoring candidate within each pattern
4. Both score 2 or below → improve prompt and regenerate (max 3 times)

### Step 5: Output results

```bash
# Copy best images to selected/
mkdir -p out/slides/selected
cp out/slides/minimalist_best.png out/slides/selected/minimalist.png
cp out/slides/infographic_best.png out/slides/selected/infographic.png
cp out/slides/hero_best.png out/slides/selected/hero.png
```

Generate quality report (`out/slides/quality-report.md`):

```markdown
# Slide Quality Report

## Generation Info
- Project: {project_name}
- Generated at: {datetime}
- Aspect ratio: {aspect_ratio}
- Tone: {tone}

## Results Summary

| Pattern | Candidate 1 | Candidate 2 | Selected | Score |
|---------|-------------|-------------|----------|-------|
| Minimalist | 3/5 | 4/5 | Candidate 2 | 4/5 |
| Infographic | 4/5 | 3/5 | Candidate 1 | 4/5 |
| Hero Visual | 5/5 | 4/5 | Candidate 1 | 5/5 |

## Detailed Evaluation
...
```

---

## Error Handling

### GOOGLE_AI_API_KEY not set

```
GOOGLE_AI_API_KEY is not set.

How to set it:
1. Get an API key from Google AI Studio: https://ai.google.dev/aistudio
2. export GOOGLE_AI_API_KEY="your-api-key"
```

### Retry limit reached for all patterns

Present options via AskUserQuestion:

```
Pattern {pattern} images did not meet quality criteria after 3 retries.

Options:
1. Accept the highest-scoring image and continue
2. Skip this pattern
3. Specify a prompt manually and regenerate
```

---

## Related Skills

- `generate-video` — Product demo video generation (shares the image generation engine)
- `notebookLM` — Document and slide generation (different approach)
