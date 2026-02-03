# Video Generation JSON Schemas

JSON Schema definitions for the video generation workflow. These schemas define the structure of scenarios, scenes, and complete video scripts.

## Schema Files

| Schema | Purpose | Version |
|--------|---------|---------|
| **scenario.schema.json** | High-level scenario structure with sections | 1.0.0 |
| **scene.schema.json** | Individual scene definition with content and direction | 1.0.0 |
| **video-script.schema.json** | Complete video script with metadata and settings | 1.0.0 |

## Schema Overview

```
Scenario (高レベル構造)
    │
    ├── Section 1 (イントロ)
    │   ├── Scene 1.1
    │   └── Scene 1.2
    │
    ├── Section 2 (デモ)
    │   ├── Scene 2.1
    │   ├── Scene 2.2
    │   └── Scene 2.3
    │
    └── Section 3 (CTA)
        └── Scene 3.1

Video Script = Metadata + Scenes + Output Settings
```

## Usage

### 1. Basic Validation (No Dependencies)

```bash
node validate-schemas-basic.js
```

This performs basic JSON and structure validation without external dependencies.

### 2. Full Validation with ajv

```bash
# Install dependencies first
npm install ajv ajv-formats

# Run full validation
node validate-schemas.js
```

### 3. Programmatic Usage

```javascript
const Ajv = require('ajv');
const addFormats = require('ajv-formats');
const fs = require('fs');

// Initialize ajv
const ajv = new Ajv({ strict: false });
addFormats(ajv);

// Load schemas
const sceneSchema = JSON.parse(fs.readFileSync('scene.schema.json'));
const videoScriptSchema = JSON.parse(fs.readFileSync('video-script.schema.json'));

// Add schemas
ajv.addSchema(sceneSchema);
ajv.addSchema(videoScriptSchema);

// Validate data
const validate = ajv.compile(videoScriptSchema);
const valid = validate(myVideoScriptData);

if (!valid) {
  console.error(validate.errors);
}
```

## Schema Details

### scenario.schema.json

Defines the high-level structure of a video scenario.

**Key Fields**:
- `title`: Scenario title
- `description`: Purpose and content overview
- `sections[]`: Ordered list of sections
  - `id`: Unique section identifier
  - `title`: Section name
  - `description`: Section purpose
  - `order`: Display order (0-indexed)
  - `duration_estimate_ms`: Estimated duration
- `metadata`: Generation metadata
  - `version`: Schema version
  - `generated_at`: ISO 8601 timestamp
  - `video_type`: Type enum (lp-teaser, intro-demo, etc.)
  - `target_funnel`: Marketing funnel stage

**Example**: See [examples/scenario-example.json](examples/scenario-example.json)

### scene.schema.json

Defines an individual video scene with content, visual direction, and assets.

**Key Fields**:
- `scene_id`: Unique scene identifier
- `section_id`: Parent section reference
- `order`: Order within section
- `type`: Scene type enum (intro, ui-demo, cta, etc.)
- `content`: Scene content
  - `text`: Primary text
  - `image`: Image asset path
  - `duration_ms`: Scene duration
  - `url`: For Playwright captures
  - `actions[]`: UI automation actions
  - `mermaid`: Diagram definition
  - `code`: Code snippet with highlights
- `direction`: Visual effects
  - `transition`: In/out transitions
  - `emphasis`: Visual emphasis effects
  - `background`: Background configuration
  - `camera`: Camera movement (3D)
- `assets[]`: Scene assets
  - `type`: Asset type (image, video, audio, font)
  - `source`: Path or URL
  - `generated`: AI-generated flag
- `audio`: Audio configuration
  - `narration`: Voice-over
  - `sfx[]`: Sound effects

**Example**: See [examples/scene-example.json](examples/scene-example.json)

### video-script.schema.json

Complete video script with all scenes, metadata, and output settings.

**Key Fields**:
- `metadata`: Video metadata
  - `title`: Video title
  - `version`: Script version
  - `created_at`: Creation timestamp
  - `video_type`: Type enum
  - `scenario_id`: Reference to source scenario
- `scenes[]`: Array of scene objects (references scene.schema.json)
- `total_duration_ms`: Total video duration
- `output_settings`: Rendering configuration
  - `width`, `height`: Resolution
  - `fps`: Frame rate (24, 30, 60)
  - `codec`: Video codec (h264, h265, vp9, av1)
  - `format`: Output format (mp4, webm, mov, gif)
  - `quality`: Quality preset
  - `preset`: Resolution preset (1080p, 4k, etc.)
- `audio_settings`: Global audio
  - `bgm`: Background music configuration
  - `master_volume`: Master volume control
- `branding`: Brand configuration
  - `logo`: Logo path
  - `colors`: Brand colors
  - `fonts`: Font configuration
- `transitions`: Global transition settings

**Example**: See [examples/video-script-example.json](examples/video-script-example.json)

## Scene Types

| Type | Description | Use Case |
|------|-------------|----------|
| `intro` | Opening title/logo | First scene, brand introduction |
| `ui-demo` | UI walkthrough with Playwright | Feature demonstrations |
| `architecture` | System architecture diagram | Technical explanations |
| `code-highlight` | Code snippet with highlights | Developer-focused content |
| `changelog` | Release notes display | Version updates |
| `cta` | Call to action | Final scene, conversions |
| `feature-highlight` | Specific feature focus | Feature marketing |
| `problem-promise` | Problem + solution statement | Value proposition |
| `workflow` | Multi-step workflow demo | Process explanations |
| `objection` | Address common objections | Objection handling |
| `custom` | Custom scene type | Flexible usage |

## Video Types (video_type)

| Type | Duration | Funnel Stage | Purpose |
|------|----------|--------------|---------|
| `lp-teaser` | 30-90s | Awareness | Landing page, social ads |
| `intro-demo` | 2-3min | Interest | Product introduction |
| `release-notes` | 1-3min | Consideration | Feature updates |
| `architecture` | 5-30min | Decision | Technical deep-dive |
| `onboarding` | 30s-3min | Retention | User onboarding |
| `custom` | Variable | Any | Custom purpose |

## Audio Sync Rules

When using narration, follow these timing rules:

| Rule | Value | Reason |
|------|-------|--------|
| **Audio start** | Scene start + 1000ms | 1-second breathing room |
| **Scene length** | 1000ms + audio length + 500ms | Padding for transitions |
| **Transition** | 450-500ms overlap | Smooth cross-fade |
| **Scene start calc** | Previous scene start + duration - 450ms | Overlap handling |

**Always check audio duration first**:
```bash
ffprobe -v error -show_entries format=duration \
  -of default=noprint_wrappers=1:nokey=1 audio.mp3
```

## Validation

### Required Fields by Schema

**scenario.schema.json**:
- ✅ title, description, sections, metadata

**scene.schema.json**:
- ✅ scene_id, section_id, order, type, content
- ✅ content.duration_ms

**video-script.schema.json**:
- ✅ metadata, scenes, total_duration_ms, output_settings
- ✅ output_settings: width, height, fps
- ✅ metadata: title, version, created_at

### Common Validation Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `Missing required property` | Required field not provided | Add the missing field |
| `Invalid enum value` | Invalid type/format value | Use allowed enum values |
| `Pattern mismatch` | ID format incorrect | Use lowercase-with-hyphens |
| `Invalid date-time` | Timestamp format wrong | Use ISO 8601 format |
| `Invalid $ref` | Schema reference broken | Ensure scene.schema.json is loaded |

## Examples

All example files are located in the `examples/` directory:

1. **scenario-example.json** - 90-second teaser scenario
2. **scene-example.json** - Intro scene with effects
3. **video-script-example.json** - Complete video script

## Integration

These schemas are used by:

1. **Planner** (planner.md) - Generates scenario and scene structures
2. **Generator** (generator.md) - Reads video-script.json and renders video
3. **Validation** - Ensures generated data conforms to expected structure

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-02-02 | Initial release with core schemas |

## References

- [JSON Schema Draft-07](https://json-schema.org/draft-07/json-schema-release-notes.html)
- [ajv Documentation](https://ajv.js.org/)
- [Best Practices Guide](../references/best-practices.md)
- [Planner Reference](../references/planner.md)
- [Generator Reference](../references/generator.md)
