# Naming Conventions for Video Generation Schemas

This document defines the unified naming conventions for all JSON schemas in the video generation system.

## Version
**1.0.0** - 2026-02-03

---

## 1. Time Units

### Rule
**All time durations MUST use milliseconds (`_ms` suffix)**

### Rationale
- Milliseconds provide sufficient precision for video timing
- Frame counts are FPS-dependent and should be calculated at runtime
- Consistency across all schemas

### Examples

```json
// ✅ Correct
{
  "duration_ms": 5000,
  "start_offset_ms": 1000,
  "fade_in_ms": 500
}

// ❌ Incorrect
{
  "duration_frames": 150,
  "duration": 5,
  "durationSec": 5
}
```

### Conversion at Runtime
```javascript
// FPS is provided in output_settings
const fps = 30;
const durationMs = 5000;
const durationFrames = Math.floor((durationMs / 1000) * fps); // 150 frames
```

---

## 2. Transition Types

### Rule
**Transition enums MUST use snake_case values**

### Standard Enum
```json
{
  "enum": ["fade", "slide_in", "zoom", "cut"]
}
```

### Definitions

| Value | Description | Use Case |
|-------|-------------|----------|
| `fade` | Gradual opacity change | Default, subtle transitions |
| `slide_in` | Slide from direction | Dynamic scene changes |
| `zoom` | Scale in/out | Emphasis, dramatic reveals |
| `cut` | Instant cut (no transition) | Fast-paced content |

### Direction Property (for slide_in)
When `transition.type === "slide_in"`, use the `direction` property:

```json
{
  "transition": {
    "type": "slide_in",
    "duration_ms": 500,
    "direction": "left"
  }
}
```

**Valid directions**: `"left"`, `"right"`, `"top"`, `"bottom"`

---

## 3. Property Naming Case

### Rule
**All property names MUST use snake_case**

### Rationale
- Consistency with existing codebase conventions
- Better readability for multi-word properties
- Alignment with JSON Schema best practices

### Examples

```json
// ✅ Correct
{
  "primary_color": "#3B82F6",
  "secondary_color": "#10B981",
  "font_size": 48,
  "font_weight": 700,
  "line_height": 1.5,
  "border_radius": 8,
  "glow_intensity": 20
}

// ❌ Incorrect
{
  "primaryColor": "#3B82F6",
  "fontSize": 48,
  "lineHeight": 1.5,
  "borderRadius": 8
}
```

---

## 4. Enum Values

### Rule
**Enum values MUST use lowercase with hyphens for multi-word values**

### Standard Patterns

#### Scene Types
```json
["intro", "ui-demo", "architecture", "code-highlight", "changelog", "cta"]
```

#### Visual Styles
```json
["minimalist", "technical", "modern", "gradient", "flat", "3d"]
```

#### Animation Easing
```json
["linear", "ease-in", "ease-out", "ease-in-out", "ease-in-quad", "ease-out-quad"]
```

#### Background Types
```json
["cyberpunk", "corporate", "minimal", "gradient", "particles"]
```

---

## 5. ID Patterns

### Rule
**IDs MUST use kebab-case (lowercase with hyphens)**

### Pattern
```regex
^[a-z0-9-]+$
```

### Examples

```json
// ✅ Correct
{
  "scene_id": "intro-hero",
  "section_id": "feature-highlights",
  "character_id": "expert-reviewer"
}

// ❌ Incorrect
{
  "scene_id": "introHero",
  "section_id": "feature_highlights",
  "character_id": "ExpertReviewer"
}
```

---

## 6. Color Format

### Rule
**Colors MUST use uppercase HEX format with `#` prefix**

### Pattern
```regex
^#[0-9A-F]{6}$
```

### Examples

```json
// ✅ Correct
{
  "primary_color": "#3B82F6",
  "accent_color": "#F59E0B"
}

// ❌ Incorrect
{
  "primary_color": "#3b82f6",  // lowercase
  "accent_color": "3B82F6",    // missing #
  "text_color": "rgb(59, 130, 246)"  // not HEX
}
```

### RGBA Exception
For transparency, use `rgba()` format:

```json
{
  "background_color": "rgba(0, 0, 0, 0.8)"
}
```

---

## 7. Reserved Keywords

### Audio Properties
- `fade_in_ms` / `fade_out_ms` - Audio fade durations
- `start_offset_ms` - Delay before audio/narration starts
- `master_volume` - Global volume (0.0 - 1.0)

### Visual Properties
- `duration_ms` - Duration in milliseconds
- `transition` - Transition configuration object
- `emphasis` - Emphasis/highlighting configuration
- `background` - Background configuration

### Metadata Properties
- `created_at` / `updated_at` - ISO 8601 timestamps
- `version` - Semantic version (e.g., "1.0.0")
- `description` - Human-readable description

---

## 8. Migration Guide

### From `duration_frames` to `duration_ms`

**Before:**
```json
{
  "transition": {
    "type": "fade",
    "duration_frames": 15
  }
}
```

**After:**
```json
{
  "transition": {
    "type": "fade",
    "duration_ms": 500
  }
}
```

**Conversion formula** (assuming 30 FPS):
```
duration_ms = (duration_frames / 30) * 1000
```

### From `slideIn` to `slide_in`

**Before:**
```json
{
  "transition": {
    "type": "slideIn",
    "duration_frames": 15
  }
}
```

**After:**
```json
{
  "transition": {
    "type": "slide_in",
    "duration_ms": 500,
    "direction": "left"
  }
}
```

### From camelCase to snake_case

**Before:**
```json
{
  "background": {
    "primaryColor": "#3B82F6",
    "secondaryColor": "#10B981"
  }
}
```

**After:**
```json
{
  "background": {
    "primary_color": "#3B82F6",
    "secondary_color": "#10B981"
  }
}
```

---

## 9. Schema Validation

All schemas MUST validate against these conventions:

### Checklist
- [ ] No `duration_frames` properties (use `duration_ms`)
- [ ] Transition enums: `["fade", "slide_in", "zoom", "cut"]`
- [ ] All properties use `snake_case`
- [ ] All enum values use `lowercase-with-hyphens`
- [ ] All IDs match pattern `^[a-z0-9-]+$`
- [ ] All HEX colors match pattern `^#[0-9A-F]{6}$`

---

## 10. Exceptions

### Character Schema (Phase 10+)
The `character.schema.json` may retain some camelCase properties for compatibility with TTS provider APIs (e.g., `overshootClamping` for spring animations).

### External APIs
When interfacing with external APIs (Remotion, TTS providers), conversion layers should handle naming differences.

---

## Related Documentation

- [Schema Phase Plan](../PLANS.md) - Phase 11.2: Naming & Unit Standardization
- [Animation Schema](../schemas/animation.schema.json)
- [Direction Schema](../schemas/direction.schema.json)
- [Scene Schema](../schemas/scene.schema.json)
