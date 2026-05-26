---
name: generate-video
description: "Auto-generate product demo videos. Internal/manual workflow only; use from an explicit /generate-video command or a parent media workflow. Requires Remotion setup."
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash", "Task", "AskUserQuestion", "WebFetch"]
disable-model-invocation: true
user-invocable: false
argument-hint: "[demo|arch|release]"
context: fork
---

# Generate Video Skill

Skills responsible for automatic generation of product demo videos.

## Invocation Contract

This skill has `user-invocable: false` and `disable-model-invocation: true`.
It is not intended to be auto-selected by Claude from ordinary user speech (e.g., "make a video").

- Only invoked explicitly via a `/generate-video` command or internally from a parent media workflow.
- `allowed-tools` is for Claude Code. Claude can use `AskUserQuestion` for user confirmation.
- In Codex mirrors, the equivalent confirmation maps to plan-mode input for `request_user_input`. When that tool is unavailable in normal execution, present defaults and proceed without halting — only confirm critical unknowns with the user.
- `disable-model-invocation: true` means the model will not auto-invoke this skill just from reading the description. When explicitly invoked via a slash command or parent workflow, follow the steps in this document.

---

## Overview

This skill is used internally by the `/generate-video` command.
It executes the codebase analysis → scenario proposal → parallel generation flow.

## Feature Details

| Feature | Details |
|---------|---------|
| **Best practices** | See [references/best-practices.md](${CLAUDE_SKILL_DIR}/references/best-practices.md) |
| **Codebase analysis** | See [references/analyzer.md](${CLAUDE_SKILL_DIR}/references/analyzer.md) |
| **Scenario planning** | See [references/planner.md](${CLAUDE_SKILL_DIR}/references/planner.md) |
| **Parallel scene generation** | See [references/generator.md](${CLAUDE_SKILL_DIR}/references/generator.md) |
| **Visual effects library** | See [references/visual-effects.md](${CLAUDE_SKILL_DIR}/references/visual-effects.md) |
| **AI image generation** | See [references/image-generator.md](${CLAUDE_SKILL_DIR}/references/image-generator.md) |
| **Image quality assessment** | See [references/image-quality-check.md](${CLAUDE_SKILL_DIR}/references/image-quality-check.md) |

## Prerequisites

- Remotion is set up (`/remotion-setup`)
- Node.js 18+
- (Optional) `GOOGLE_AI_API_KEY` — for AI image generation

## `/generate-video` Flow

```
/generate-video
    │
    ├─[Step 1] Analysis (analyzer.md)
    │   ├─ Framework detection
    │   ├─ Key feature detection
    │   ├─ UI component detection
    │   └─ Project asset analysis (Plans.md, CHANGELOG, etc.)
    │
    ├─[Step 2] Scenario proposal (planner.md)
    │   ├─ Auto-detect video type
    │   ├─ Propose scene structure
    │   └─ User confirmation
    │
    ├─[Step 2.5] Asset generation (image-generator.md) ← NEW
    │   ├─ Determine if assets are needed (intro, CTA, etc.)
    │   ├─ Generate 2 images with Nano Banana Pro
    │   ├─ Claude quality-checks (image-quality-check.md)
    │   └─ OK → adopt / NG → regenerate (max 3 times)
    │
    └─[Step 3] Parallel generation (generator.md)
        ├─ Parallel scene generation (Task tool)
        ├─ Integration + transitions
        └─ Final rendering
```

## Execution Steps

1. User runs `/generate-video`
2. Verify Remotion setup
3. Analyze codebase with `analyzer.md`
4. Propose scenario with `planner.md` + user confirmation
5. Generate in parallel with `generator.md`
6. Report completion

## Video Types (by funnel stage)

| Type | Funnel | Length | Auto-detect condition | Core structure |
|------|--------|--------|-----------------------|----------------|
| **LP/Ad teaser** | Awareness → Interest | 30-90s | New project | Pain → Result → CTA |
| **Intro demo** | Interest → Consideration | 2-3min | UI changes detected | 1 use case end-to-end |
| **Release notes** | Consideration → Conviction | 1-3min | CHANGELOG updated | Before/After focus |
| **Architecture overview** | Conviction → Decision | 5-30min | Large structural changes | Real usage + evidence |
| **Onboarding** | Retention / adoption | 30s-several min | First-time setup | Shortest path to Aha moment |

> Details: [references/best-practices.md](${CLAUDE_SKILL_DIR}/references/best-practices.md)

## Scene Templates

### 90-second teaser (LP/ad)

| Time | Scene | Content |
|------|-------|---------|
| 0-5s | Hook | Pain or desired outcome |
| 5-15s | Problem+Promise | Target user and promise |
| 15-55s | Workflow | Signature workflow |
| 55-70s | Differentiator | Evidence of differentiation |
| 70-90s | CTA | Next step |

### 3-minute intro demo (consideration)

| Time | Scene | Content |
|------|-------|---------|
| 0-10s | Hook | Conclusion + pain |
| 10-30s | UseCase | Use case declaration |
| 30-140s | Demo | Live screen end-to-end |
| 140-170s | Objection | Address 1 common concern |
| 170-180s | CTA | Call to action |

### Common scenes

| Scene | Recommended time | Content |
|-------|-----------------|---------|
| Intro | 3-5s | Logo + tagline |
| Feature demo | 10-30s | Playwright capture |
| Architecture diagram | 10-20s | Mermaid → animation |
| CTA | 3-5s | URL + contact |

> Detailed templates: [${CLAUDE_SKILL_DIR}/references/best-practices.md](${CLAUDE_SKILL_DIR}/references/best-practices.md#templates)

## Audio Sync Rules (Important)

For narrated videos, strictly follow these rules:

| Rule | Value |
|------|-------|
| Audio start | Scene start + 30f (1 second delay) |
| Scene length | 30f + audio length + 20f buffer |
| Transition | 15f (overlap with adjacent scenes) |
| Scene start calculation | Previous scene start + previous scene length - 15f |

**Pre-check**: Confirm audio length with `ffprobe` before designing scenes

> Details: [${CLAUDE_SKILL_DIR}/references/generator.md](${CLAUDE_SKILL_DIR}/references/generator.md#audio-sync-rules-important)

## BGM Support

| Item | Recommended value |
|------|-------------------|
| With narration | bgmVolume: 0.20 - 0.30 |
| Without narration | bgmVolume: 0.50 - 0.80 |
| File location | `public/BGM/` |

> Details: [${CLAUDE_SKILL_DIR}/references/generator.md](${CLAUDE_SKILL_DIR}/references/generator.md#bgm-support)

## Subtitle Support

| Rule | Value |
|------|-------|
| Subtitle start | Same as audio start |
| Subtitle duration | Audio length + 10f |
| Font | Base64 embedding recommended |

> Details: [${CLAUDE_SKILL_DIR}/references/generator.md](${CLAUDE_SKILL_DIR}/references/generator.md#subtitle-support)

## Visual Effects Library

A collection of effects for high-impact videos:

| Effect | Use case |
|--------|---------|
| GlitchText | Hook, titles |
| Particles | Background, CTA convergence |
| ScanLine | Analysis in progress |
| ProgressBar | Parallel processing display |
| 3D Parallax | Card display |

> Details: [references/visual-effects.md](${CLAUDE_SKILL_DIR}/references/visual-effects.md)

## Notes

- Guide to `/remotion-setup` if Remotion is not set up
- Parallel generation count is auto-adjusted based on number of scenes (max 5)
- Generated videos are output to the `out/` directory
- AI-generated images are saved to `out/assets/generated/`
- When `GOOGLE_AI_API_KEY` is not set, image generation is skipped (use existing assets or placeholders)
