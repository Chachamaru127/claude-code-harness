# Asset Customization Guide

How to override user custom assets (backgrounds, sound effects, fonts, images) and best practices.

---

## Overview

Assets used during video generation are loaded in the following priority order:

```
1. User assets (~/.harness/video/assets/)    ← Highest priority
2. Skill defaults (skills/generate-video/assets/) ← Fallback
3. Built-in defaults (hardcoded)              ← Last resort
```

This system lets you use your own assets without modifying the skill itself.

---

## Directory Structure

### User Asset Directory

```
~/.harness/video/assets/
├── README.md                    # Usage guide (auto-generated)
├── backgrounds/
│   ├── backgrounds.json         # Custom background definitions
│   └── my-custom-bg.png         # Custom background image (optional)
├── sounds/
│   ├── sounds.json              # Custom sound effect definitions
│   ├── impact.mp3               # High-emphasis sound
│   ├── pop.mp3                  # Medium-emphasis sound
│   ├── transition.mp3           # Scene transition sound
│   └── subtle.mp3               # Low-emphasis sound
├── fonts/
│   ├── MyBrand-Bold.ttf
│   └── MyBrand-Regular.ttf
└── images/
    ├── logo.png
    └── icon.png
```

### Initialization

Create the user asset directory:

```bash
node scripts/load-assets.js init
```

Or create manually:

```bash
mkdir -p ~/.harness/video/assets/{backgrounds,sounds,fonts,images}
```

---

## Customization Methods

### 1. Background Customization

#### Steps

1. **Copy the default configuration**:

```bash
cp skills/generate-video/assets/backgrounds/backgrounds.json \
   ~/.harness/video/assets/backgrounds/
```

2. **Edit the configuration**:

```json
{
  "version": "1.0.0",
  "backgrounds": [
    {
      "id": "my-brand",
      "name": "My Brand Background",
      "description": "Company brand colors",
      "type": "gradient",
      "colors": {
        "primary": "#1e3a8a",
        "secondary": "#3b82f6",
        "accent": "#60a5fa"
      },
      "gradient": {
        "type": "linear",
        "angle": 135,
        "stops": [
          { "color": "#1e3a8a", "position": 0 },
          { "color": "#3b82f6", "position": 50 },
          { "color": "#60a5fa", "position": 100 }
        ]
      },
      "usage": {
        "scenes": ["intro", "cta"],
        "recommended_for": "Brand-focused content"
      }
    }
  ]
}
```

3. **Use in video generation**:

```json
{
  "scene": {
    "background": "my-brand"
  }
}
```

#### Background Types

| Type | Description | Fields |
|------|-------------|--------|
| `gradient` | Gradient background | `colors`, `gradient` |
| `pattern` | Pattern background (grid, etc.) | `colors`, `gradient`, `pattern` |
| `solid` | Solid color background | `colors.primary` |
| `image` | Image background | `file` (path to image) |

#### Gradient Types

```json
// Linear gradient
"gradient": {
  "type": "linear",
  "angle": 135,
  "stops": [...]
}

// Radial gradient
"gradient": {
  "type": "radial",
  "stops": [...]
}
```

---

### 2. Sound Effect Customization

#### Steps

1. **Copy the default configuration**:

```bash
cp skills/generate-video/assets/sounds/sounds.json \
   ~/.harness/video/assets/sounds/
```

2. **Place sound effect files**:

```bash
# Download from FreeSound (CC0 license recommended)
cp ~/Downloads/my-impact.mp3 ~/.harness/video/assets/sounds/impact.mp3
cp ~/Downloads/my-pop.mp3 ~/.harness/video/assets/sounds/pop.mp3
```

3. **Edit the configuration**:

```json
{
  "version": "1.0.0",
  "sounds": [
    {
      "id": "impact",
      "name": "Custom Impact",
      "type": "effect",
      "category": "emphasis",
      "emphasis_level": "high",
      "file": {
        "placeholder": "impact.mp3",
        "expected_duration": 0.5,
        "format": "mp3"
      },
      "volume": {
        "default": 0.7,
        "with_narration": 0.4,
        "with_bgm": 0.6
      }
    }
  ]
}
```

#### Recommended Formats

| Format | Sample Rate | Bit Depth | Notes |
|--------|-------------|-----------|-------|
| MP3 | 44100 Hz | 16-bit | Recommended (best compatibility) |
| WAV | 44100 Hz | 16-bit | High quality (large file size) |
| OGG | 44100 Hz | - | Lightweight (watch for browser compatibility) |

#### Recommended Volume Values

| Context | Volume Range | Notes |
|---------|--------------|-------|
| With narration | 0.15 - 0.4 | Don't drown out the voice |
| With BGM | 0.25 - 0.6 | Duck under BGM |
| No audio | 0.3 - 1.0 | Full volume OK |

---

### 3. Font Customization

#### Steps

1. **Place font files**:

```bash
cp ~/Downloads/MyFont-Bold.ttf ~/.harness/video/assets/fonts/
cp ~/Downloads/MyFont-Regular.ttf ~/.harness/video/assets/fonts/
```

2. **Reference in scene configuration**:

```json
{
  "scene": {
    "text": {
      "content": "My Message",
      "font": {
        "family": "MyFont",
        "weight": "bold",
        "file": "~/.harness/video/assets/fonts/MyFont-Bold.ttf"
      }
    }
  }
}
```

#### Using in Remotion

```typescript
import { loadFont } from '@remotion/google-fonts/Inter';

// Load custom font
const fontFamily = loadFont({
  src: '~/.harness/video/assets/fonts/MyFont-Bold.ttf',
  fontFamily: 'MyFont',
  fontWeight: 'bold',
});
```

#### Recommended Formats

| Format | Web Safe | Notes |
|--------|----------|-------|
| TTF | ✅ Yes | Recommended (highest compatibility) |
| OTF | ✅ Yes | Supports OpenType features |
| WOFF/WOFF2 | ✅ Yes | Web-optimized (lightweight) |

---

### 4. Image Customization

#### Steps

1. **Place image files**:

```bash
cp ~/Downloads/logo.png ~/.harness/video/assets/images/
cp ~/Downloads/icon.png ~/.harness/video/assets/images/
```

2. **Reference in scene configuration**:

```json
{
  "scene": {
    "image": {
      "src": "~/.harness/video/assets/images/logo.png",
      "width": 200,
      "height": 100
    }
  }
}
```

#### Recommended Formats

| Format | Use Case | Notes |
|--------|----------|-------|
| PNG | Logos, icons | Transparency support |
| JPG | Photos, backgrounds | High compression ratio |
| SVG | Vector graphics | Scales without quality loss |
| WebP | Modern environments | Lightweight, high quality |

#### Size Guidelines

| Asset Type | Recommended Size | Max Size |
|------------|------------------|----------|
| Logo | 500x500 px | 1000x1000 px |
| Icon | 128x128 px | 512x512 px |
| Background | 1920x1080 px | 3840x2160 px |
| Screenshot | 1920x1080 px | 2560x1440 px |

---

## Priority Details

### Load Order

`scripts/load-assets.js` searches for assets in the following order:

```javascript
// 1. User assets
const userPath = '~/.harness/video/assets/{category}/{file}';
if (exists(userPath)) return userPath;

// 2. Skill defaults
const skillPath = 'skills/generate-video/assets/{category}/{file}';
if (exists(skillPath)) return skillPath;

// 3. Built-in defaults
return getBuiltInDefault();
```

### Partial Override

You can override only some assets:

```bash
# Customize only backgrounds (use default sound effects)
cp my-backgrounds.json ~/.harness/video/assets/backgrounds/backgrounds.json
```

### Partial Override Within JSON

```json
// ~/.harness/video/assets/backgrounds/backgrounds.json
{
  "version": "1.0.0",
  "backgrounds": [
    {
      "id": "my-brand",
      "name": "My Brand"
      // ... custom settings
    }
    // "neutral", "highlight", etc. are omitted → loaded from defaults
  ]
}
```

**Note**: When the same `id` exists, the user setting takes priority.

---

## Verification

### Test Commands

```bash
# Test asset loading
node scripts/load-assets.js test

# Show background configuration
node scripts/load-assets.js backgrounds

# Show sound effect configuration
node scripts/load-assets.js sounds

# Show search paths
node scripts/load-assets.js paths
```

### Expected Output

```
🧪 Testing asset loader...

🎨 Loading backgrounds...
  ✅ Loaded user backgrounds from: ~/.harness/video/assets/backgrounds/backgrounds.json

🔊 Loading sounds...
  ✅ Loaded skill sounds from: skills/generate-video/assets/sounds/sounds.json

📂 Asset paths:
{
  "user": "~/.harness/video/assets",
  "skill": "skills/generate-video/assets"
}
```

---

## Troubleshooting

### Problem: Asset Not Loading

**Cause**: Incorrect file path

**Solution**:
```bash
# Check path
node scripts/load-assets.js paths

# Verify file exists
ls -la ~/.harness/video/assets/backgrounds/
```

### Problem: JSON Parse Error

**Cause**: Invalid JSON format

**Solution**:
```bash
# Validate JSON
cat ~/.harness/video/assets/backgrounds/backgrounds.json | jq .

# Check error message
node scripts/load-assets.js test
```

### Problem: Sound Effect Not Playing

**Cause**: Unsupported file format

**Solution**:
```bash
# Convert to MP3
ffmpeg -i input.wav -codec:a libmp3lame -b:a 192k output.mp3

# Check file info
ffprobe output.mp3
```

### Problem: Font Not Displaying

**Cause**: Font file path cannot be resolved

**Solution**:
```typescript
// Use absolute path
const fontPath = path.join(os.homedir(), '.harness/video/assets/fonts/MyFont.ttf');
```

---

## Best Practices

### 1. Version Control

To manage custom assets with Git:

```bash
# Place at project root
project-root/
├── .video-assets/
│   ├── backgrounds/
│   ├── sounds/
│   └── fonts/
└── .gitignore  # Exclude .harness/

# Create symlink
ln -s $(pwd)/.video-assets ~/.harness/video/assets
```

### 2. Team Sharing

Use shared assets across the team:

```bash
# Shared repository
git clone https://github.com/company/video-assets.git ~/.harness/video/assets
```

### 3. Per-Project Assets

Use different assets per project:

```bash
# Switch via environment variable
export VIDEO_ASSETS_DIR=/path/to/project-specific/assets

# Reference environment variable in load-assets.js
const assetsDir = process.env.VIDEO_ASSETS_DIR || defaultPath;
```

### 4. License Management

```
~/.harness/video/assets/
└── LICENSES.md    # License information for each asset
```

```markdown
# Asset Licenses

## Sounds

- impact.mp3: CC0, from freesound.org/s/12345
- pop.mp3: CC BY 3.0, by Author Name

## Fonts

- MyFont-Bold.ttf: SIL Open Font License
```

---

## Sample Collection

### Brand Color Background

```json
{
  "id": "brand-primary",
  "name": "Brand Primary",
  "type": "gradient",
  "colors": {
    "primary": "#your-brand-color",
    "secondary": "#your-secondary-color"
  },
  "gradient": {
    "type": "linear",
    "angle": 135,
    "stops": [
      { "color": "#your-brand-color", "position": 0 },
      { "color": "#your-secondary-color", "position": 100 }
    ]
  },
  "usage": {
    "scenes": ["intro", "outro", "cta"]
  }
}
```

### Custom Sound Effect Set

```json
{
  "id": "whoosh",
  "name": "Whoosh Transition",
  "type": "effect",
  "category": "transition",
  "file": {
    "placeholder": "whoosh.mp3",
    "expected_duration": 0.6
  },
  "volume": {
    "default": 0.5,
    "with_narration": 0.3
  },
  "timing": {
    "offset_before_visual": -0.1
  }
}
```

### Company Logo

```json
{
  "scene": {
    "image": {
      "src": "~/.harness/video/assets/images/company-logo.png",
      "width": 300,
      "height": 150,
      "position": "top-right"
    }
  }
}
```

---

## References

- **Asset Loader**: `scripts/load-assets.js`
- **Default Backgrounds**: `assets/backgrounds/backgrounds.json`
- **Default Sounds**: `assets/sounds/sounds.json`
- **BackgroundLayer Component**: `remotion/src/components/BackgroundLayer.tsx`
- **Plans.md**: Phase 7 - Asset Foundation

---

## Changelog

- **2026-02-02**: Initial release (Phase 7 implementation)
