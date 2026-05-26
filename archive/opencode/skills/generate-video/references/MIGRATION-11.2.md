# Migration Guide: Schema Naming & Unit Standardization (11.2)

**Date**: 2026-02-03
**Phase**: 11.2 - Naming & Unit Standardization
**Status**: ✅ Complete

---

## Overview

This migration standardizes naming conventions and time units across all video generation schemas.

### Key Changes

1. **Time units**: All `duration_frames` → `duration_ms` (milliseconds)
2. **Transition enum**: `"slideIn"` → `"slide_in"` (snake_case)
3. **Property naming**: All camelCase → snake_case
4. **Enum values**: Standardized to lowercase with underscores

---

## Files Modified

### 1. direction.schema.json

| Before | After | Reason |
|--------|-------|--------|
| `duration_frames` | `duration_ms` | Time unit standardization |
| `"slideIn"` enum | `"slide_in"` | Enum naming convention |
| `primaryColor` | `primary_color` | Property naming convention |
| `secondaryColor` | `secondary_color` | Property naming convention |
| `delay_before` (frames) | `delay_before_ms` | Time unit standardization |
| `delay_after` (frames) | `delay_after_ms` | Time unit standardization |
| `audio_start_offset` (frames) | `audio_start_offset_ms` | Time unit standardization |

**Default value changes**:
- `duration_ms`: 15 frames @ 30fps → 500ms
- `audio_start_offset_ms`: 30 frames @ 30fps → 1000ms

### 2. animation.schema.json

| Before | After | Reason |
|--------|-------|--------|
| `duration_frames` | `duration_ms` | Time unit standardization |
| `"slideIn"` enum | `"slide_in"` | Enum naming convention |
| `delay` | `delay_ms` | Time unit standardization |
| `overshootClamping` | `overshoot_clamping` | Property naming convention |
| `inputRange` | `input_range` | Property naming convention |
| `outputRange` | `output_range` | Property naming convention |
| `extrapolateLeft` | `extrapolate_left` | Property naming convention |
| `extrapolateRight` | `extrapolate_right` | Property naming convention |

**Maximum duration**: 300 frames → 10000ms (10 seconds)

### 3. emphasis.schema.json

| Before | After | Reason |
|--------|-------|--------|
| `start_frame` | `start_ms` | Time unit standardization |
| `duration_frames` | `duration_ms` | Time unit standardization |
| `trigger_frame` | `trigger_ms` | Time unit standardization |
| `glowIntensity` | `glow_intensity` | Property naming convention |
| `borderRadius` | `border_radius` | Property naming convention |
| `fontSize` | `font_size` | Property naming convention |
| `fontWeight` | `font_weight` | Property naming convention |
| `fontFamily` | `font_family` | Property naming convention |
| `lineHeight` | `line_height` | Property naming convention |
| `letterSpacing` | `letter_spacing` | Property naming convention |
| `textTransform` | `text_transform` | Property naming convention |
| `pulseSpeed` | `pulse_speed` | Property naming convention |
| `"fadeIn"` enum | `"fade_in"` | Enum naming convention |
| `"slideIn"` enum | `"slide_in"` | Enum naming convention |
| `"zoomIn"` enum | `"zoom_in"` | Enum naming convention |
| `"fadeOut"` enum | `"fade_out"` | Enum naming convention |
| `"slideOut"` enum | `"slide_out"` | Enum naming convention |
| `"zoomOut"` enum | `"zoom_out"` | Enum naming convention |

**Default value changes**:
- `duration_ms`: 30 frames @ 30fps → 1000ms
- `animation.duration_ms`: 15 frames @ 30fps → 500ms
- `pulse_speed`: 0.1 (per-frame) → 1.0 (per-second, 1 cycle/sec)

### 4. scene.schema.json

| Before | After | Reason |
|--------|-------|--------|
| `"slideIn"` enum (transition.in) | `"slide_in"` | Enum naming convention |
| `"slideIn"` enum (transition.out) | `"slide_in"` | Enum naming convention |

### 5. video-script.schema.json

| Before | After | Reason |
|--------|-------|--------|
| `"slide"` enum | `"slide_in"` | Enum naming convention |
| `"none"` enum | `"cut"` | Enum standardization |

### 6. visual-patterns.schema.json

| Before | After | Reason |
|--------|-------|--------|
| `colorScheme` | `color_scheme` | Property naming convention |
| `leftSide` | `left_side` | Property naming convention |
| `rightSide` | `right_side` | Property naming convention |
| `arrowStyle` | `arrow_style` | Property naming convention |
| `showNumbers` | `show_numbers` | Property naming convention |
| `mainText` | `main_text` | Property naming convention |
| `subText` | `sub_text` | Property naming convention |
| `fontSize` | `font_size` | Property naming convention |
| `aspectRatio` | `aspect_ratio` | Property naming convention |

---

## Breaking Changes

### For JSON Authors

If you have existing JSON files that use the old naming:

```json
// ❌ Old format (no longer valid)
{
  "transition": {
    "type": "slideIn",
    "duration_frames": 15
  },
  "emphasis": {
    "text": [{
      "start_frame": 0,
      "duration_frames": 30
    }]
  }
}

// ✅ New format (required)
{
  "transition": {
    "type": "slide_in",
    "duration_ms": 500
  },
  "emphasis": {
    "text": [{
      "start_ms": 0,
      "duration_ms": 1000
    }]
  }
}
```

### For Code

If you have TypeScript/JavaScript code that accesses these properties:

```typescript
// ❌ Old code (will break)
const duration = scene.transition.duration_frames;
const color = scene.background.primaryColor;

// ✅ New code
const duration = scene.transition.duration_ms;
const color = scene.background.primary_color;
```

### For Validators

JSON Schema validators will reject old property names. Update all references.

---

## Conversion Formulas

### Frames to Milliseconds

```javascript
// Assuming 30 FPS (standard for video generation)
const fps = 30;
const durationMs = Math.floor((durationFrames / fps) * 1000);

// Examples:
// 15 frames → 500ms
// 30 frames → 1000ms
// 60 frames → 2000ms
```

### Milliseconds to Frames (Runtime)

```javascript
// When rendering with Remotion
const fps = outputSettings.fps; // from video-script.schema.json
const durationFrames = Math.floor((durationMs / 1000) * fps);
```

---

## Validation

All schemas have been validated with the following checks:

- ✅ No `duration_frames` properties remain
- ✅ All transition enums use `slide_in` (not `slideIn`)
- ✅ All properties use `snake_case` (not camelCase)
- ✅ All enum values use lowercase with underscores

### Run Validation Yourself

```bash
node -e "
const fs = require('fs');
const schemas = fs.readdirSync('./skills/generate-video/schemas')
  .filter(f => f.endsWith('.schema.json'))
  .map(f => './skills/generate-video/schemas/' + f);

schemas.forEach(file => {
  const content = fs.readFileSync(file, 'utf8');
  const issues = [];

  if (content.includes('duration_frames')) issues.push('duration_frames found');
  if (content.includes('\"slideIn\"')) issues.push('slideIn found');

  if (issues.length) {
    console.log(file, '❌', issues.join(', '));
  } else {
    console.log(file, '✅');
  }
});
"
```

---

## Rollback Instructions

If you need to rollback these changes:

```bash
# Rollback all schemas to previous commit
git checkout HEAD~1 skills/generate-video/schemas/

# Remove naming conventions document
rm skills/generate-video/references/naming-conventions.md

# Remove this migration guide
rm skills/generate-video/references/MIGRATION-11.2.md
```

---

## Next Steps

1. **Update any existing test data** to use the new naming conventions
2. **Update code generators** (if any) to output the new format
3. **Update documentation** that references old property names
4. **Consider versioning** if backward compatibility is needed

---

## Related Documentation

- [Naming Conventions](./naming-conventions.md) - Comprehensive naming rules
- [Schema Phase Plan](../PLANS.md) - Phase 11.2 task details
- [All Schemas](../schemas/) - Updated schema files

---

## Checklist

Migration is complete when:

- [x] All schemas use `duration_ms` instead of `duration_frames`
- [x] All transition enums standardized to `["fade", "slide_in", "zoom", "cut"]`
- [x] All properties use `snake_case`
- [x] All enum values use lowercase with underscores
- [x] Naming conventions document created
- [x] Migration guide created
- [x] All schemas pass validation

**Status**: ✅ Complete (2026-02-03)
