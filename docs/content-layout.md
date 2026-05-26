# Content Layout

This repository distinguishes between `docs/` and `out/` according to the following rules.

## Basic Rules

- `docs/`: The authoritative source for human readers. Place hand-edited prose, publication-ready drafts, prompts, design notes, and reference material here.
- `out/`: Output destination for tools and generation processes. Place images, candidate drafts, exports, and derived artifacts here.

When in doubt, use these criteria:

1. Is this text that a person will read and reuse later?
   - Yes: `docs/`
2. Is this a regenerable artifact?
   - Yes: `out/`

## Social / X Operations

- `docs/social/`
  - Canonical post text
  - Image generation prompts
  - Alt text
  - Posting notes and outlines
- `out/social/`
  - Generated images
  - Candidate cards
  - Tool-generated drafts
  - Temporary comparison artifacts

In short: `docs/social/` is "what to post," and `out/social/` is "what was generated."

Legacy paths `out/x-post/`, `out/x-posts/`, `out/x-promo/`, and `out/x-release/` also exist from past operations. These will remain for now, but **all new social output going forward should go into `out/social/`**.

## Slides / Media Operations

- `docs/slides/`
  - Slide scripts, specifications, YAML sources
- `out/slides/`
  - Exported images, selected images, quality reports

## Rules When Adding Content

- When saving new post text, save it to `docs/social/` first
- Results from image generation or export runs go into `out/social/`
- Do not add generated images to `docs/`
- Do not add canonical prose to `out/`

## Cleanup Policy for This Round

- Consolidate X post source drafts into `docs/social/`
- Preserve existing `out/social/` content as already-generated artifacts
- Follow the same rules for future additions
