# Image Patterns Reference

Usage guide for the 4 image generation patterns (comparison, concept, flow, highlight).

---

## Overview

Defines image patterns optimized for video scenes. Each pattern is optimized for a specific purpose and integrates with AI image generation prompt templates.

### Pattern List

| Pattern | Use | Best Scenes | Prompt Template |
|---------|------|-----------|---------------------|
| **comparison** | Before/After, good/bad example contrasts | Problem statement, demonstrating improvement | `templates/image-prompts/comparison.txt` |
| **concept** | Visualizing abstract concepts, hierarchies, relationships | Architecture explanations, concept walkthroughs | `templates/image-prompts/concept.txt` |
| **flow** | Illustrating steps, processes, workflows | Demo steps, processing flows | `templates/image-prompts/flow.txt` |
| **highlight** | Emphasizing important points, key messages | Hook, CTA, conclusion | `templates/image-prompts/highlight.txt` |

---

## 1. Comparison Pattern {#comparison}

### Purpose

Visually contrast two states or options, such as Before/After or good vs. bad examples.

### Use Cases

| Scene | Example |
|--------|-----|
| **Problem statement** | Complexity of existing tools vs. simplicity of this product |
| **Improvement effect** | Before adoption (manual, slow) vs. After (automated, fast) |
| **Feature comparison** | Old method vs. new feature |
| **Release notes** | Old version vs. new version |

### Visual Layout

```
┌──────────────────────────────────────────┐
│                                          │
│  [Bad/Before]  🠖  [Good/After]          │
│                                          │
│  ❌ Problem 1         ✅ Improvement 1   │
│  ❌ Problem 2         ✅ Improvement 2   │
│  ❌ Problem 3         ✅ Improvement 3   │
│                                          │
└──────────────────────────────────────────┘
```

### JSON Example

```json
{
  "type": "comparison",
  "topic": "Task management improvement",
  "style": "modern",
  "colorScheme": {
    "primary": "#3B82F6",
    "secondary": "#10B981",
    "background": "#1F2937"
  },
  "comparison": {
    "leftSide": {
      "label": "Before",
      "items": [
        "Manual spreadsheet management",
        "Frequent missed updates",
        "30 minutes to check status"
      ],
      "icon": "x",
      "sentiment": "negative"
    },
    "rightSide": {
      "label": "After",
      "items": [
        "Dashboard updates automatically",
        "Real-time sync",
        "Status visible at a glance"
      ],
      "icon": "check",
      "sentiment": "positive"
    },
    "divider": "arrow"
  }
}
```

### Prompt Generation Tips

- **Left side (Before/Bad)**: Red tones, warning icons, cluttered impression
- **Right side (After/Good)**: Green tones, check icons, organized impression
- **Divider**: Clear arrow or "VS" for visual separation
- **Text**: Short and specific (recommended 20 characters or fewer per item)

### Patterns to Avoid

| ❌ Avoid | ✅ Recommended |
|----------|---------|
| Long text lists | Short keywords |
| Abstract descriptions | Specific numbers and results |
| Nuanced evaluation | Clear contrast |
| Same icon on both sides | Different emotional icons |

---

## 2. Concept Pattern {#concept}

### Purpose

Visually represent abstract concepts, hierarchies, and relationships between elements.

### Use Cases

| Scene | Example |
|--------|-----|
| **Architecture explanation** | System architecture diagram, layer structure |
| **Concept walkthrough** | Philosophy, design principles, value delivery diagram |
| **Relationships** | Dependencies between components |
| **Big picture** | Ecosystem, overall workflow |

### Visual Layout (Hierarchy Example)

```
        ┌───────────┐
        │   Top     │
        └─────┬─────┘
              │
     ┌────────┴────────┐
     │                 │
┌────▼────┐       ┌────▼────┐
│ Level 1 │       │ Level 1 │
└─────────┘       └────┬────┘
                       │
                  ┌────▼────┐
                  │ Level 2 │
                  └─────────┘
```

### JSON Example

```json
{
  "type": "concept",
  "topic": "Microservices architecture",
  "style": "technical",
  "colorScheme": {
    "primary": "#6366F1",
    "secondary": "#8B5CF6",
    "background": "#0F172A"
  },
  "concept": {
    "elements": [
      {
        "id": "api-gateway",
        "label": "API Gateway",
        "description": "Entry point for all requests",
        "level": 0,
        "icon": "cloud",
        "emphasis": "high"
      },
      {
        "id": "auth-service",
        "label": "Auth Service",
        "level": 1,
        "parentId": "api-gateway",
        "icon": "server",
        "emphasis": "medium"
      },
      {
        "id": "data-service",
        "label": "Data Service",
        "level": 1,
        "parentId": "api-gateway",
        "icon": "database",
        "emphasis": "medium"
      }
    ],
    "relationships": [
      {
        "from": "api-gateway",
        "to": "auth-service",
        "label": "Auth check",
        "type": "flow"
      },
      {
        "from": "api-gateway",
        "to": "data-service",
        "label": "Data fetch",
        "type": "flow"
      }
    ],
    "layout": "hierarchy"
  }
}
```

### Layout Types

| Layout | Use | Visual Image |
|-----------|------|------------|
| **hierarchy** | Hierarchical structure (org charts, dependencies) | Tree flowing top to bottom |
| **radial** | Radiating from center (ecosystem) | Main element in center, related elements around it |
| **grid** | Parallel arrangement (category classification) | Matrix layout |
| **flow** | Processing flow (pipeline) | Flow left to right |
| **circular** | Circular process (lifecycle) | Circular ring |

### Prompt Generation Tips

- **Element count**: 2-10 (too many becomes unreadable)
- **Hierarchy**: Maximum 3-4 levels
- **Icons**: Represent the nature of elements intuitively
- **Relationships**: Express importance with arrow thickness or color

### Patterns to Avoid

| ❌ Avoid | ✅ Recommended |
|----------|---------|
| 10+ elements | Narrow down to 7 or fewer |
| Complex connecting lines | Only the main relationships |
| Long descriptions | Short labels + icons |
| Elements that all look the same | Differentiate with emphasis level |

---

## 3. Flow Pattern {#flow}

### Purpose

Visualize steps, processes, and workflows in chronological or step order.

### Use Cases

| Scene | Example |
|--------|-----|
| **Demo steps** | Steps from setup to execution |
| **User flow** | Login → operation → completion |
| **Processing flow** | Data pipeline, CI/CD flow |
| **Onboarding** | First-use guidance |

### Visual Layout (Horizontal Example)

```
[1. Start] ──▶ [2. Input] ──▶ [3. Process] ──▶ [4. Complete]
   ⏱2 min         ⏱1 min         ⏱3 sec          Instant
```

### JSON Example

```json
{
  "type": "flow",
  "topic": "Video generation flow",
  "style": "modern",
  "colorScheme": {
    "primary": "#F59E0B",
    "secondary": "#EF4444",
    "background": "#111827"
  },
  "flow": {
    "steps": [
      {
        "id": "analyze",
        "label": "Codebase analysis",
        "description": "Auto-detect project structure",
        "order": 1,
        "type": "start",
        "icon": "circle",
        "duration": "10 sec"
      },
      {
        "id": "plan",
        "label": "Scenario generation",
        "description": "Propose optimal video structure",
        "order": 2,
        "type": "process",
        "icon": "square",
        "duration": "20 sec"
      },
      {
        "id": "generate",
        "label": "Parallel generation",
        "description": "Create all scenes simultaneously",
        "order": 3,
        "type": "parallel",
        "icon": "rounded",
        "duration": "2 min"
      },
      {
        "id": "render",
        "label": "Rendering",
        "description": "Output final video",
        "order": 4,
        "type": "end",
        "icon": "hexagon",
        "duration": "30 sec"
      }
    ],
    "direction": "horizontal",
    "arrowStyle": "solid",
    "showNumbers": true
  }
}
```

### Step Types

| Type | Use | Visual |
|--------|------|---------|
| **start** | Flow start point | Circle icon, green |
| **process** | Normal processing step | Square, blue |
| **decision** | Conditional branch | Diamond, yellow |
| **parallel** | Parallel processing | Multiple icons, purple |
| **subprocess** | Sub-flow | Rounded rectangle |
| **end** | Flow end point | Double circle, red |

### Prompt Generation Tips

- **Direction**: Horizontal reads easier (for English audiences)
- **Step count**: 2-10 steps (too many becomes complex)
- **Duration**: Displaying time per step adds practicality
- **Numbers**: Make order explicit (showNumbers: true)

### Patterns to Avoid

| ❌ Avoid | ✅ Recommended |
|----------|---------|
| 10+ steps | Consolidate to 7 steps or fewer |
| Complex branching | Simplify to a linear flow |
| Long step names | Verb + noun, concise |
| Unclear order | Make explicit with order field |

---

## 4. Highlight Pattern {#highlight}

### Purpose

Emphasize a single message, keyword, or number prominently.

### Use Cases

| Scene | Example |
|--------|-----|
| **Hook (opening)** | "Still burning out on manual work?" |
| **CTA (call to action)** | "Try it now" |
| **Conclusion** | "3x faster, 10x easier" |
| **Key metrics** | "95% time reduction" |

### Visual Layout

```
┌────────────────────────────────────────┐
│                                        │
│                                        │
│          ⚡ 3x faster, 10x easier ⚡    │
│                                        │
│    A development experience transformed │
│           through automation           │
│                                        │
└────────────────────────────────────────┘
```

### JSON Example

```json
{
  "type": "highlight",
  "topic": "Product value emphasis",
  "style": "gradient",
  "colorScheme": {
    "primary": "#EC4899",
    "accent": "#8B5CF6",
    "background": "#18181B"
  },
  "highlight": {
    "mainText": "95% time reduction",
    "subText": "A dev team freed from manual work",
    "icon": "rocket",
    "position": "center",
    "effect": "glow",
    "fontSize": "xlarge",
    "emphasis": "high"
  }
}
```

### Effect Types

| Effect | Use | Visual |
|-----------|------|---------|
| **glow** | Glowing emphasis (CTA, conclusion) | Glow effect |
| **shadow** | Calm emphasis (Hook) | Drop shadow |
| **gradient** | Modern impression | Gradient background |
| **outline** | Sharp impression | Outline only |
| **none** | Minimal | No decoration |

### Icons and Emotions

| Icon | Emotion/Meaning | Use Case |
|---------|-----------|---------|
| **star** | Excellence, quality | Feature introductions, ratings |
| **check** | Done, success | Adoption effects, results |
| **alert** | Draw attention | Problem statement, warning |
| **trophy** | Achievement, victory | Results, accomplishments |
| **rocket** | Speed, innovation | Performance, new features |
| **fire** | Popular, trending | Trends, attention |
| **bolt** | Instant, power | Speed, efficiency |

### Prompt Generation Tips

- **Brevity is key**: Main text ideally 10 words or fewer
- **Numbers**: Specific numbers are persuasive ("95%", "3x")
- **Contrast**: Pair two values like "faster, easier"
- **Emotion**: Amplify emotion with icon + effect

### Patterns to Avoid

| ❌ Avoid | ✅ Recommended |
|----------|---------|
| Long text (20+ words) | Short catchphrase |
| Multiple claims | Focus on one |
| Plain design | Make it stand out with effects |
| Small font | xlarge recommended |

---

## Pattern Selection Guide

### Recommended Patterns by Scene Type

| Scene Type | 1st Choice | 2nd Choice | Use |
|------------|---------|---------|------|
| **Hook** | highlight | comparison | Strong first impression |
| **Problem** | comparison | concept | Clearly show the current issue |
| **Solution** | concept | flow | Show how the solution works |
| **Demo** | flow | comparison | Visualize the steps |
| **Differentiator** | comparison | concept | Differentiation points |
| **CTA** | highlight | - | Call to action |

### Usage Frequency by Funnel Stage

| Pattern | Awareness/Interest | Consideration | Conviction | Retention |
|---------|-----------|------|------|------|
| **comparison** | ★★★ | ★★★ | ★★☆ | ★☆☆ |
| **concept** | ★☆☆ | ★★★ | ★★★ | ★★☆ |
| **flow** | ★★☆ | ★★★ | ★★☆ | ★★★ |
| **highlight** | ★★★ | ★★☆ | ★★★ | ★☆☆ |

### Combining Multiple Patterns

**90-second teaser (for LP/ad) example**:

| Seconds | Scene | Pattern | Content |
|------|--------|---------|------|
| 0-5s | Hook | **highlight** | "Still burning out on manual work?" |
| 5-15s | Problem | **comparison** | Before (manual) vs After (automated) |
| 15-55s | Solution | **flow** | Setup → Run → Done in 3 steps |
| 55-70s | Proof | **concept** | Robustness of architecture |
| 70-90s | CTA | **highlight** | "Start free now" |

---

## Implementation Notes

### 1. JSON Schema Validation

- **Required**: `type` and `topic` fields are mandatory
- **oneOf**: Pattern-specific fields are required (e.g., type="comparison" requires the comparison field)
- **Validation**: Verify with `scripts/validate-visual-pattern.js`

### 2. Integration with Prompt Templates

- **Template**: Use `templates/image-prompts/{type}.txt`
- **Placeholders**: Replace `{{topic}}`, `{{items}}`, `{{style}}`, etc. with JSON values
- **Generation**: `references/image-generator.md` handles the actual generation

### 3. Image Quality Check

- **Automated check**: Quality evaluation via `references/image-quality-check.md`
- **Retry**: Regenerate up to 3 times if quality check fails
- **Determinism**: Save seed values to ensure reproducibility

### 4. Asset Management

- **Output location**: `out/video-{id}/assets/generated/`
- **Manifest**: Record in `assets.manifest.schema.json`
- **Hash**: SHA-256 tamper detection

---

## Related Documentation

- [visual-patterns.schema.json](../schemas/visual-patterns.schema.json) - JSON Schema definition
- [image-generator.md](./image-generator.md) - AI image generation implementation
- [image-quality-check.md](./image-quality-check.md) - Quality check logic
- [templates/image-prompts/](../templates/image-prompts/) - Prompt templates
- [best-practices.md](./best-practices.md) - Video production best practices

---

**Created**: 2026-02-02
**Target Phase**: Phase 6 - Image Generation Patterns
**Maintenance**: Update when schema changes
