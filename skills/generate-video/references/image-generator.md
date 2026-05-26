# Image Generator - Nano Banana Pro Automated Image Generation

Uses Nano Banana Pro (Google DeepMind) to automatically generate high-quality images for video scenes.

---

## Overview

Automatically executed during the scene generation phase of `/generate-video` when asset images are determined to be needed.
Implements a quality assurance loop: generate 2 images → Claude quality-checks → regenerate if NG.

## Prerequisites

- `GOOGLE_AI_API_KEY` environment variable is set
- Nano Banana Pro (Gemini 3 Pro Image Preview) is enabled in Google AI Studio

---

## API Specification

> **Official documentation**: [Nano Banana image generation | Gemini API](https://ai.google.dev/gemini-api/docs/image-generation)

### Endpoint

```
POST https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent
```

### Model Selection

| Model | Use | Max Resolution |
|--------|------|-----------|
| `gemini-3-pro-image-preview` | Professional quality (recommended) | 4K |
| `gemini-2.5-flash-image` | Fast, low-cost | 1024px |

### Authentication

```bash
# x-goog-api-key header (Gemini API standard)
x-goog-api-key: ${GOOGLE_AI_API_KEY}
```

> **Note**: The Gemini API uses the `x-goog-api-key` header. The query parameter method (`?key=...`) is also available, but the header method is recommended.

### Request Format

```json
{
  "contents": [{
    "parts": [
      {"text": "A modern SaaS dashboard interface with clean design, showing analytics charts and user metrics, professional UI mockup, light theme"}
    ]
  }],
  "generationConfig": {
    "responseModalities": ["TEXT", "IMAGE"],
    "imageConfig": {
      "aspectRatio": "16:9",
      "imageSize": "2K"
    }
  }
}
```

> **Note**: `responseModalities` can be set to `["TEXT", "IMAGE"]` or `["IMAGE"]`. This flow specifies both to also obtain a text description for quality checking.

### Response Format

```json
{
  "candidates": [{
    "content": {
      "parts": [
        {"text": "Here is the generated image of a modern SaaS dashboard..."},
        {
          "inline_data": {
            "mime_type": "image/png",
            "data": "iVBORw0KGgoAAAANS..."
          }
        }
      ]
    }
  }]
}
```

> **Note**: The REST API uses snake_case (`inline_data`, `mime_type`). The SDK uses camelCase (`inlineData`, `mimeType`).

---

## Resolution Options

| Setting | Resolution | Use | Estimated Cost |
|------|--------|------|-----------|
| `1K` | 1024×1024 | Preview, testing | ~$0.02/image |
| `2K` | 2048×2048 | Standard quality | ~$0.06/image |
| `4K` | 4096×4096 | High quality, professional | ~$0.12/image |

### Aspect Ratios

| Ratio | Use |
|------|------|
| `16:9` | Video scenes (recommended) |
| `1:1` | Icons, logos |
| `9:16` | Vertical videos |
| `4:3` | Presentation materials |

---

## Prompt Design Guidelines

### Basic Structure

```
[Subject] + [Style] + [Quality specification] + [Constraints]
```

### Prompt Templates by Scene Type

#### Intro / Title Scene

```
Professional product logo and title card for "{product_name}",
modern minimalist design, clean typography,
{brand_color} accent color, dark background,
cinematic quality, 4K render
```

#### UI Demo Scene (Supplementary Image)

```
Modern web application interface showing {feature_description},
clean UI design, light theme, subtle shadows,
professional SaaS aesthetic, mockup style,
no text labels, focus on visual hierarchy
```

#### CTA Scene

```
Call-to-action banner for {product_name},
action-oriented design, prominent button,
{brand_color} gradient, professional marketing style,
clear visual hierarchy, engaging composition
```

#### Architecture / Concept Diagram

```
Technical architecture diagram showing {concept},
isometric illustration style, modern tech aesthetic,
clear visual flow, connected components,
professional documentation quality, clean lines
```

### Tips for Better Prompts

| Addition | Effect |
|---------|------|
| `professional quality` | Overall quality improvement |
| `clean design` | Reduce unwanted elements |
| `modern aesthetic` | Contemporary design |
| `cinematic lighting` | Dramatic lighting |
| `4K render` | High resolution |
| `no text` | No text (when text will be added later) |

### Patterns to Avoid

| NG Pattern | Reason |
|------------|------|
| Vague instructions | "A nice image" → Unstable results |
| Overly complex | Too many elements degrades quality |
| Text specification | AI-generated text quality is unstable |
| Copyrighted material | Brand logos, etc. cannot be generated |

---

## Execution Flow

```
Scene generation phase
    │
    ├── [Step 1] Determine if asset is needed
    │   └─ Check scene type and existing assets
    │       ├── Asset exists → Skip
    │       └── No asset → Proceed to Step 2
    │
    ├── [Step 2] Generate prompt
    │   ├─ Build prompt from scene information
    │   ├─ Incorporate brand information (colors, style)
    │   └─ Apply template
    │
    ├── [Step 3] Generate images (2 in parallel)
    │   └─ Nano Banana Pro API call (2 parallel requests)
    │       generateContent × 2 (simultaneous requests to reduce latency)
    │
    ├── [Step 4] Quality check
    │   └─ → See image-quality-check.md
    │
    ├── [Step 5] Process result
    │   ├── Success → Save image, incorporate into scene
    │   └── Failure → Proceed to Step 6
    │
    └── [Step 6] Regeneration loop (max 3 times)
        ├─ Improve prompt (Claude suggests)
        └─ Return to Step 3
```

---

## Bash Execution Examples

### API Call with curl

```bash
# Check environment variable (verify key is set)
test -n "$GOOGLE_AI_API_KEY" && echo "GOOGLE_AI_API_KEY is set" || echo "GOOGLE_AI_API_KEY is not set"

# Image generation request
curl -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent" \
  -H "x-goog-api-key: ${GOOGLE_AI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "contents": [{
      "parts": [
        {"text": "Modern SaaS dashboard interface, clean design, light theme, professional UI"}
      ]
    }],
    "generationConfig": {
      "responseModalities": ["TEXT", "IMAGE"],
      "imageConfig": {
        "aspectRatio": "16:9",
        "imageSize": "2K"
      }
    }
  }' \
  -o response.json

# Decode Base64 and save (extract image data from parts array)
cat response.json | jq -r '.candidates[0].content.parts[] | select(.inline_data) | .inline_data.data' | head -1 | base64 -d > out/assets/generated/image_1.png
```

> **Note**: One request generates one image. Run 2 requests to get 2 images.

### Image Save Location

```
out/
└── assets/
    └── generated/
        ├── intro_1.png
        ├── intro_2.png
        ├── cta_1.png
        └── cta_2.png
```

---

## Regeneration Loop Control

### Maximum Attempts

```
max_attempts = 3
```

### Prompt Improvement During Regeneration

Claude improves the prompt each attempt:

| Attempt | Improvement Strategy |
|------|---------|
| 1st | Generate with initial prompt |
| 2nd | Adjust prompt based on quality feedback |
| 3rd | Add more specific instructions, change style |

### Improved Prompt Generation

```
The previous image was rejected for the following reason:
- {rejection_reason}

Improvements:
1. {improvement_1}
2. {improvement_2}

New prompt:
{improved_prompt}
```

### Fallback After 3 Failures

```
⚠️ Image generation failed 3 times

Scene: {scene_name}
Last error: {last_error}

Options:
1. "Continue" → Proceed with placeholder image
2. "Skip" → Generate this scene without an image
3. "Manual" → User provides image
```

---

## Error Handling

### API Errors

| Error Code | Cause | Action |
|-------------|------|------|
| `400` | Invalid prompt | Check prompt content |
| `401` | Authentication failure | Verify API key |
| `429` | Rate limit | Wait 60 seconds and retry |
| `500` | Server error | Wait 30 seconds and retry |

### Content Policy Violation

```
⚠️ Content policy violation

The prompt violates Google's policy.
Please remove/change the following:
- {violation_reason}

Would you like to attempt automatic correction? (y/n)
```

### Missing Environment Variable

```
⚠️ GOOGLE_AI_API_KEY is not set

How to set it:
1. Get an API key from Google AI Studio
   https://ai.google.dev/aistudio

2. Set the environment variable
   export GOOGLE_AI_API_KEY="your-api-key"

3. Or add to .env.local
   GOOGLE_AI_API_KEY=your-api-key
```

---

## Cost Estimate

### Cost Per Scene

```
Basic: 2 images × $0.12 = $0.24
Maximum (3 regenerations): 6 images × $0.12 = $0.72
```

### Estimated Cost Per Video

| Video Type | Scenes | Image Generation Scenes | Estimated Cost |
|-----------|---------|---------------|-----------|
| 90-second teaser | 5 | 2-3 | $0.48-$0.72 |
| 3-minute demo | 8 | 3-4 | $0.72-$0.96 |
| 5-minute architecture | 12 | 4-6 | $0.96-$1.44 |

---

## Related Documentation

- [image-quality-check.md](./image-quality-check.md) - Quality check logic
- [generator.md](./generator.md) - Parallel scene generation engine
- [planner.md](./planner.md) - Scenario planner
