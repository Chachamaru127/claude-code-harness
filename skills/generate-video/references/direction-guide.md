# Direction Guide

Defines the visual direction system for the generate-video skill and best practices for using it.

---

## Overview

The direction system is composed of 4 elements:

| Element | Role | Controls |
|------|------|---------|
| **transition** | Scene switching | Fade, slide, zoom, cut |
| **emphasis** | Element highlighting | 3-level emphasis + sound effects |
| **background** | Background design | 5 background styles |
| **timing** | Timing adjustments | Wait time, audio offset |

---

## Transition

### 4 Transition Types

| Type | Use | Visual Effect | Recommended Duration |
|------|------|---------|--------------|
| **fade** | General-purpose switching | Smooth fade in/out | 500ms (15f) |
| **slideIn** | Moving to the next topic | Directional slide (left/right/top/bottom) | 400ms (12f) |
| **zoom** | Drawing attention to detail | Zoom in/out | 600ms (18f) |
| **cut** | Instant switching | Cut (instantaneous) | 0ms |

### Usage Guidelines

#### fade
- **Recommended scenes**: General, section openings, calm transitions
- **Effect**: Visually gentle, does not over-attract attention
- **Examples**:
  - Intro → main explanation
  - Feature explanation → next feature explanation
  - Settling before CTA

```json
{
  "transition": {
    "type": "fade",
    "duration_ms": 500,
    "easing": "easeInOut"
  }
}
```

#### slideIn
- **Recommended scenes**: Topic changes, comparisons, step progression
- **Effect**: Dynamic, builds anticipation for upcoming content
- **direction**:
  - `right`: Forward motion (next step)
  - `left`: Looking back (Before in a Before/After)
  - `top`: Important information appearing
  - `bottom`: Adding supplementary information

```json
{
  "transition": {
    "type": "slideIn",
    "duration_ms": 400,
    "direction": "right",
    "easing": "easeOut"
  }
}
```

#### zoom
- **Recommended scenes**: Showing detail, emphasis, impactful information
- **Effect**: Draws attention, creates impact
- **Examples**:
  - Displaying an important number
  - Presenting the core of a problem
  - Emphasizing a differentiator

```json
{
  "transition": {
    "type": "zoom",
    "duration_ms": 600,
    "easing": "easeInOut"
  }
}
```

#### cut
- **Recommended scenes**: Demo operations, rapid sequence, tension
- **Effect**: Instantaneous, tempo boost
- **Examples**:
  - Between steps of UI operations
  - High-speed demonstrations
  - Rhythmic feature showcasing

```json
{
  "transition": {
    "type": "cut",
    "duration_ms": 0
  }
}
```

### Recommended Transitions by Funnel Stage

| Funnel Stage | Recommended Transition | Reason |
|-------------|-------------------|------|
| Awareness (LP/Ad) | fade, zoom | Calm, impactful |
| Interest (Intro) | slideIn, fade | Dynamic, builds anticipation |
| Consideration (Feature demo) | cut, slideIn | Pacing, efficiency |
| Conviction (Architecture) | fade, zoom | Detail, trust |
| Retention (Onboarding) | slideIn, cut | Step progression |

---

## Emphasis

### 3 Levels of Emphasis

| Level | Use | Visual Effect | Recommended Sound |
|-------|------|---------|-----------|
| **high** | Most important message | Large animation, bright color | whoosh, chime |
| **medium** | Important points | Medium animation, accent color | pop |
| **low** | Supplementary information | Subtle emphasis, muted color | none, ding |

### Usage Guidelines

#### high
- **Recommended scenes**:
  - Hook (opening impact)
  - CTA (call to action)
  - Differentiator
  - Surprising results or numbers

- **Visual effects**:
  - Text size: Extra large
  - Color: Vivid (default: `#00F5FF` cyan)
  - Animation: scale 1.2, bounce
  - Sound: `whoosh` or `chime`

- **Examples**:
  - "3x faster" → high emphasis
  - "Try it free now" → high emphasis

```json
{
  "emphasis": {
    "level": "high",
    "text": ["3x faster"],
    "sound": "whoosh",
    "color": "#00F5FF",
    "position": "center"
  }
}
```

#### medium
- **Recommended scenes**:
  - Key points in feature explanations
  - Workflow steps
  - Problem statement
  - Solution

- **Visual effects**:
  - Text size: Large
  - Color: Accent (default: `#FFC700` gold)
  - Animation: scale 1.1, fade-in
  - Sound: `pop`

- **Examples**:
  - "Step 1: Configuration" → medium emphasis
  - "Does this sound familiar?" → medium emphasis

```json
{
  "emphasis": {
    "level": "medium",
    "text": ["Step 1: Configuration"],
    "sound": "pop",
    "color": "#FFC700",
    "position": "top"
  }
}
```

#### low
- **Recommended scenes**:
  - Supplementary information
  - Light introduction of additional features
  - Footnotes
  - Links to detailed information

- **Visual effects**:
  - Text size: Normal
  - Color: Muted (default: `#A8DADC` light blue)
  - Animation: fade-in only
  - Sound: `none` or `ding`

- **Examples**:
  - "* See documentation for details" → low emphasis
  - "And many more features" → low emphasis

```json
{
  "emphasis": {
    "level": "low",
    "text": ["* See documentation for details"],
    "sound": "none",
    "color": "#A8DADC",
    "position": "bottom"
  }
}
```

### Choosing Sound Effects

| Sound | Character | Recommended Use |
|-------|---------|---------|
| **whoosh** | Wind sweep, dynamic | high emphasis, screen transitions |
| **chime** | Bell-like, beautiful | CTA, success display |
| **pop** | Poppy, light | medium emphasis, button appearance |
| **ding** | Small bell | low emphasis, light notifications |
| **none** | Silent | Quiet information, consecutive displays |

### Recommended Emphasis Levels by Funnel Stage

| Funnel Stage | Primary Emphasis | Secondary Emphasis |
|-------------|---------|---------|
| Awareness (LP/Ad) | high frequently | medium moderately |
| Interest (Intro) | high 1-2 times | medium frequently |
| Consideration (Feature demo) | medium primarily | low supplementary |
| Conviction (Architecture) | medium moderately | low frequently |
| Retention (Onboarding) | high for goals | medium for steps |

---

## Background

### 5 Background Styles

| Type | Visual Character | Use | Color Example |
|------|---------|------|---------|
| **cyberpunk** | Neon, grid, futuristic | Tech-focused, cutting-edge appeal | `#0a0e27` + `#00f5ff` |
| **corporate** | Refined, trustworthy, professional | B2B, enterprise | `#1a1a2e` + `#16213e` |
| **minimal** | Simple, clean, focused | Content-heavy, documentation | `#ffffff` + `#f0f0f0` |
| **gradient** | Colorful, dynamic, friendly | B2C, casual | `#667eea` → `#764ba2` |
| **particles** | Dynamic particles, energetic | Hook, CTA, high impact | `#000000` + particles |

### Usage Guidelines

#### cyberpunk
- **Recommended scenes**:
  - Emphasizing technological advancement
  - Developer tools
  - AI/ML feature introductions
  - Architecture diagrams

- **Characteristics**:
  - Neon grid
  - Glitch effects
  - Blue and cyan palette

```json
{
  "background": {
    "type": "cyberpunk",
    "primaryColor": "#0a0e27",
    "secondaryColor": "#00f5ff",
    "opacity": 0.9
  }
}
```

#### corporate
- **Recommended scenes**:
  - B2B products
  - Enterprise features
  - Security and reliability appeal
  - Case studies and track record

- **Characteristics**:
  - Dark blue palette
  - Clean gradients
  - Calm atmosphere

```json
{
  "background": {
    "type": "corporate",
    "primaryColor": "#1a1a2e",
    "secondaryColor": "#16213e",
    "opacity": 1
  }
}
```

#### minimal
- **Recommended scenes**:
  - Want the viewer to focus on content
  - Complex diagrams or code displays
  - Onboarding
  - Documentation-style explanations

- **Characteristics**:
  - White and gray palette
  - Simple
  - Readability-first

```json
{
  "background": {
    "type": "minimal",
    "primaryColor": "#ffffff",
    "secondaryColor": "#f0f0f0",
    "opacity": 1
  }
}
```

#### gradient
- **Recommended scenes**:
  - B2C products
  - Approachability appeal
  - Intros and CTAs
  - Casual tone

- **Characteristics**:
  - Colorful gradients
  - Soft impression
  - Visually engaging

```json
{
  "background": {
    "type": "gradient",
    "primaryColor": "#667eea",
    "secondaryColor": "#764ba2",
    "opacity": 0.95
  }
}
```

#### particles
- **Recommended scenes**:
  - Hook (opening impact)
  - CTA (call to action)
  - Important turning points
  - Energetic impression

- **Characteristics**:
  - Dynamic particles
  - Energy
  - Draws attention

```json
{
  "background": {
    "type": "particles",
    "primaryColor": "#000000",
    "secondaryColor": "#00f5ff",
    "opacity": 0.8
  }
}
```

### Recommended Backgrounds by Funnel Stage

| Funnel Stage | Recommended Background | Reason |
|-------------|---------|------|
| Awareness (LP/Ad) | particles, gradient | Visual impact |
| Interest (Intro) | gradient, cyberpunk | Approachability, cutting-edge |
| Consideration (Feature demo) | minimal, corporate | Focus, trust |
| Conviction (Architecture) | corporate, cyberpunk | Professional |
| Retention (Onboarding) | minimal, gradient | Simple, welcoming |

---

## Timing

### Timing Parameters

| Parameter | Use | Recommended Value |
|-----------|------|--------|
| **delay_before** | Wait before scene starts | 0-15f (0-500ms) |
| **delay_after** | Wait after scene ends | 0-30f (0-1000ms) |
| **audio_start_offset** | Audio start offset | 30f (1000ms, standard) |

### Usage Guidelines

#### delay_before
- **Use**:
  - Visual settling after a transition
  - Holding onto the previous scene's feeling
  - A beat to draw attention

- **Recommended values**:
  - `0f`: When the transition provides enough pause
  - `5-10f`: Light pause
  - `15f`: Solid pause

```json
{
  "timing": {
    "delay_before": 10
  }
}
```

#### delay_after
- **Use**:
  - Resonance after audio ends
  - Time to absorb a CTA
  - Time to read content

- **Recommended values**:
  - `0f`: Move immediately to the next
  - `15-20f`: Standard resonance
  - `30f`: Give them time to read

```json
{
  "timing": {
    "delay_after": 20
  }
}
```

#### audio_start_offset
- **Use**:
  - Wait after scene appears before audio starts
  - Audio starts once visuals have settled

- **Recommended values**:
  - `30f` (1000ms): Standard (recommended)
  - `15f` (500ms): Fast-paced
  - `45f` (1500ms): Leisurely

```json
{
  "timing": {
    "audio_start_offset": 30
  }
}
```

### Critical Audio Sync Rules

> **Important**: For narrated videos, strictly follow these rules:

1. **Scene length calculation**:
   ```
   duration_ms = audio_start_offset + audio_length + delay_after
   ```

2. **Pre-check audio length**:
   ```bash
   ffprobe -v error -show_entries format=duration \
     -of default=noprint_wrappers=1:nokey=1 audio/scene.wav
   ```

3. **Adjustment with transitions**:
   ```
   Scene start = previous scene start + previous scene length - transition length
   Audio start = scene start + audio_start_offset
   ```

4. **Ensure buffer**:
   - Audio must finish before the transition begins
   - Always maintain at least `delay_after: 20f`

---

## Best Practices

### 1. Direction Combinations by Funnel Stage

#### 90-second LP/Ad Teaser (Awareness → Interest)
```json
{
  "hook": {
    "transition": { "type": "zoom", "duration_ms": 600 },
    "emphasis": { "level": "high", "sound": "whoosh" },
    "background": { "type": "particles" },
    "timing": { "delay_before": 10, "delay_after": 20 }
  },
  "problem": {
    "transition": { "type": "slideIn", "direction": "right", "duration_ms": 400 },
    "emphasis": { "level": "medium", "sound": "pop" },
    "background": { "type": "gradient" },
    "timing": { "delay_before": 0, "delay_after": 15 }
  },
  "cta": {
    "transition": { "type": "zoom", "duration_ms": 600 },
    "emphasis": { "level": "high", "sound": "chime" },
    "background": { "type": "particles" },
    "timing": { "delay_before": 15, "delay_after": 30 }
  }
}
```

#### 3-minute Intro Demo (Interest → Consideration)
```json
{
  "intro": {
    "transition": { "type": "fade", "duration_ms": 500 },
    "emphasis": { "level": "high", "sound": "whoosh" },
    "background": { "type": "gradient" },
    "timing": { "delay_before": 0, "delay_after": 20 }
  },
  "demo": {
    "transition": { "type": "cut", "duration_ms": 0 },
    "emphasis": { "level": "medium", "sound": "pop" },
    "background": { "type": "minimal" },
    "timing": { "delay_before": 0, "delay_after": 10 }
  },
  "cta": {
    "transition": { "type": "fade", "duration_ms": 500 },
    "emphasis": { "level": "high", "sound": "chime" },
    "background": { "type": "gradient" },
    "timing": { "delay_before": 10, "delay_after": 30 }
  }
}
```

### 2. Appropriate Use of Sound Effects

**Rules**:
- No more than **5-7 sound effects** per video
- Hold back on sound effects in consecutive scenes (diminishing returns from habituation)
- Always include a sound effect for high emphasis
- Sound effects for medium emphasis are optional
- Low emphasis should generally be silent

### 3. Background Consistency

**Rules**:
- No more than **2-3 background types** per video
- Unify within sections (same background within a section)
- Special backgrounds (particles) are only permitted for Hook/CTA

### 4. Transition Rhythm

**Rules**:
- Do not use the same transition 3 times in a row
- Combine fast-paced (cut) with slow-paced (fade/zoom)
- Start sections with fade or zoom

### 5. Emphasis Level Distribution

**Rules (for a 90-second video)**:
- high: 2-3 times (Hook, Differentiator, CTA)
- medium: 5-8 times (main messages)
- low: as needed (supplementary information)

---

## Scene Design Checklist

Check the following when designing scene direction:

### Transition
- [ ] Selected a transition that matches the scene's purpose
- [ ] Not using the same transition consecutively
- [ ] duration_ms is appropriate (fade: 500ms, slideIn: 400ms, zoom: 600ms)

### Emphasis
- [ ] Emphasis level is appropriate (high: most important only)
- [ ] Sound effect count is appropriate (5-7 total)
- [ ] Keywords to emphasize are specified in the text array

### Background
- [ ] Background type matches the funnel stage
- [ ] Background is unified within a section
- [ ] primaryColor and secondaryColor are specified

### Timing
- [ ] audio_start_offset is 30f (standard)
- [ ] Scene length = audio start + audio length + delay_after
- [ ] Audio ends before the transition begins

### Overall Balance
- [ ] Sound effects are 5-7 or fewer
- [ ] Background types are 2-3 or fewer
- [ ] high emphasis is 2-3 times or fewer

---

## Related Documents

- [generator.md](./generator.md) - Parallel generation flow
- [visual-effects.md](./visual-effects.md) - Visual effects library
- [schemas/direction.schema.json](../schemas/direction.schema.json) - Direction schema definition
- [schemas/emphasis.schema.json](../schemas/emphasis.schema.json) - Emphasis schema definition
- [schemas/animation.schema.json](../schemas/animation.schema.json) - Animation schema definition
