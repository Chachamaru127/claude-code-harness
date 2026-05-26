---
name: docs-notebooklm-slide-yaml
description: "Generate two design-instruction YAML variations (from different angles) for use in NotebookLM's [Customize slide deck] feature."
allowed-tools: ["Read", "Write"]
---

# NotebookLM Slide Design YAML (2 Variations)

## Purpose

In NotebookLM's "Slides" generation, **specify the design direction via YAML to improve quality and reproducibility**.

This skill outputs **two YAML variations with different interpretations of the intent**
so that the same source material can have visually distinct presentations.

References (usage/examples):
- `https://note.com/yoshifujidesign/n/nd9c8db0b55b8`
- `https://note.com/yoshifujidesign/n/n7412bccb5762`

---

## How to use (NotebookLM side)

After loading the source material in NotebookLM,
go to [Slides] → [Customize slide deck] → [Describe the slides to create]
and **paste the full YAML output from this skill**, then click [Generate].

---

## Input (confirm with the user)

If possible, ask up to 5 questions upfront; if no answer is given, proceed with the defaults shown in parentheses.

1. Purpose (e.g., internal sharing / sales / recruiting / investor-facing) (internal sharing)
2. Target audience (e.g., management / engineering / non-engineers) (mixed non-engineers)
3. Tone (e.g., trustworthy / innovative / approachable) (trustworthy)
4. Brand elements (logo / brand colors / font specification) (none specified)
5. Photo-to-chart ratio (photo-heavy / data-heavy) (data-heavy)

---

## Output (required format)

Always output the following **2 variations**.

- Variation A: **Readability, trustworthiness, and data communication as top priorities** (minimal / corporate)
- Variation B: **Emphasizes emotion, storytelling, and the aesthetics of whitespace** (editorial / lifestyle)

Both should be in **Japanese YAML** that can be pasted directly into NotebookLM.

Output format:

- One YAML (code block) directly below `### Variation A`
- One YAML (code block) directly below `### Variation B`

---

## Generation Rules

- Include specific colors as **HEX values** (e.g., `#FFFFFF`)
- Include a few "don'ts" (e.g., avoid excessive borders, avoid heavy shadows, limit color count)
- Explicitly state **constraints that improve reproducibility** such as chapter structure, navigation, whitespace, and grid
- Write as a **structural template** that works even when the source content is unknown

---

## Output Template (generation example skeleton)

### Variation A (Minimal / Corporate)

(Adjust as needed to fit purpose, audience, and brand colors)

```yaml
# presentation_design_spec_minimal_corporate.yaml
# Style: Modern Minimal / Corporate
# Purpose: Prioritize readability and data communication (trustworthy)

overall_design:
  tone: "Trustworthy, professional, clean, logical"
  color_palette:
    base: "#FFFFFF (white) or #F5F5F7 (very light gray)"
    text: "#111111 (near black) or #333333 (charcoal)"
    accent: "Use brand color if available; otherwise #0052CC (blue)"
    highlight: "#FFB020 (amber) — limited to key figures and warnings"
    color_limit: "Max 3 colors + gray gradations"
  typography:
    heading: "Bold sans-serif. Short, strong words."
    body: "Highly readable sans-serif. Generous line spacing."
    numbers: "Large, bold sans-serif. Units (% etc.) slightly smaller."
  layout_rules:
    grid: "Align to 12-column equivalent. Wide left/right margins."
    navigation: "Show small section number + chapter title in top-left, e.g. '01. SECTION'."
    whitespace: "No cramming. One message per slide."
    charts: "Minimize grid lines. Use accent color only on emphasis points."
  dont:
    - "Avoid excessive drop shadows"
    - "Avoid overuse of decorative borders"
    - "Avoid heavy use of gradients"

layout_catalog:
  - type: "Cover"
    design: "Wide margins. Title large and left-aligned, subtitle small. One thin horizontal rule."
  - type: "Chapter divider"
    design: "Chapter title large. Background solid color, minimal."
  - type: "Conclusion (TL;DR)"
    design: "3 key takeaways + one large number/metric."
  - type: "2-column (problem vs. solution)"
    design: "Vertical line divides in two. Left: problem, Right: solution. Heading bold, body light."
  - type: "Data / chart"
    design: "Simple bar/line representation. Annotations short."
  - type: "Process"
    design: "Horizontal steps (01–05). Circle icons minimal."
  - type: "Timeline"
    design: "Vertical line + large year + small description."
  - type: "Summary"
    design: "Next actions in 3 points. Concise checklist style."
```

### Variation B (Editorial / Story)

(Adjust as needed to fit purpose, audience, and photo ratio)

```yaml
# presentation_design_spec_editorial_story.yaml
# Style: Modern Editorial / Lifestyle magazine
# Purpose: Tell a story through whitespace and photography (emotion / persuasion)

overall_design:
  tone: "Calm, intellectual, emotional, organic, refined"
  visual_identity:
    background: "#F3F0EB (sand beige) or #EBEBEB (warm gray)"
    text: "#333333 (charcoal) — avoid pure black"
    accent: "#E07A5F (terracotta) or #708D81 (olive)"
    image_style:
      characteristics: "Natural light, film grain, low saturation"
      shape: "Rounded rectangle or arch shape"
  typography:
    heading: "Elegant serif. Emphasize key words subtly."
    body: "Readable sans-serif, kept small."
    numbers: "Serif numerals for a composed feel."
  layout_rules:
    whitespace: "Whitespace is the top priority. Keep text density low."
    photos: "One large photo per slide as the default."
    borders: "No frames. Use only whitespace or hairlines as dividers."
  design_rules:
    - "No cool colors or neons (keep a warm tone throughout)"
    - "No excessive icons (let photos and typography do the talking)"

layout_catalog:
  - type: "Cover (magazine cover)"
    design: "Full-bleed photo on the right, title on the left. Thin horizontal rule as divider."
  - type: "Quote"
    design: "Short message centered. Large faint quotation marks in background."
  - type: "Story (1→2→3)"
    design: "Vertical steps. Connected by dotted lines. Small circular photo beside each step."
  - type: "Comparison"
    design: "Two photos side by side + individual captions. Colors subdued."
  - type: "Data"
    design: "Ultra-thin line chart + explanatory text paragraph as a narrative supplement."
  - type: "Summary"
    design: "3 next actions. Close with whitespace preserved."
```
