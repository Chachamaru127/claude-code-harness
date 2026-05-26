# Scripts Directory

A collection of scripts for JSON Schema auto-generation and validation.

## Available Scripts

### generate-schemas.js

Automatically generates Zod schemas from JSON Schemas.

**Usage:**
```bash
npm run generate:schemas
```

**Input:**
- `schemas/*.schema.json` - JSON Schema files

**Output:**
- `src/schemas/*.ts` - Zod schema definitions
- `src/schemas/index.ts` - Barrel export

**Example:**
```bash
# Generate all schemas
node scripts/generate-schemas.js

# Or via npm script (recommended)
npm run generate:schemas
```

**Dependencies:**
- `json-schema-to-zod` - JSON Schema → Zod conversion
- `zod` - Runtime validation

---

## Setup

### Install Dependencies

Install the packages required for schema generation:

```bash
npm install --save-dev json-schema-to-zod
npm install zod
```

### Add npm Script

Add the following to `package.json`:

```json
{
  "scripts": {
    "generate:schemas": "node scripts/generate-schemas.js"
  }
}
```

### Pre-commit Hook (Optional)

Auto-generate on schema changes:

```bash
# .husky/pre-commit
npm run generate:schemas
git add src/schemas/
```

---

## Schema Development Workflow

1. **Create schema**: Create `schemas/*.schema.json`
2. **Run generation**: `npm run generate:schemas`
3. **Verify type inference**: Check TypeScript types in `src/schemas/*.ts`
4. **Validate**: Verify with the generated Zod schemas

### Example

```typescript
// src/example.ts
import { AssetManifestSchema, type AssetManifest } from './schemas';

// Runtime validation
const data: unknown = { /* ... */ };
const result = AssetManifestSchema.safeParse(data);

if (result.success) {
  const manifest: AssetManifest = result.data;
  console.log('Valid manifest:', manifest);
} else {
  console.error('Validation errors:', result.error.errors);
}
```

---

## Schema Versioning

### Version Format

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "version": "1.0.0",
  "title": "SchemaName",
  ...
}
```

### Breaking Changes

Changes that require a major version bump:
- Adding required fields
- Removing fields
- Changing types

Changes possible in a minor version:
- Adding optional fields
- Adding enum values
- Changing descriptions

---

## Troubleshooting

### Schema Generation Errors

**Error**: `Cannot find module 'json-schema-to-zod'`
```bash
npm install --save-dev json-schema-to-zod
```

**Error**: `No .schema.json files found`
- Verify `*.schema.json` files exist in the `schemas/` directory

**Error**: `Invalid JSON`
- Check JSON Schema syntax errors
- Validate with [JSONLint](https://jsonlint.com/)

### Zod Schema Issues

**Type inference not working**
```typescript
// ❌ Bad
const schema = AssetManifestSchema;

// ✅ Good
import { type AssetManifest } from './schemas';
const manifest: AssetManifest = { /* ... */ };
```

---

## Validation Scripts (Phase 2)

### validate-scene.js

Validates individual scene JSON against `scene.schema.json`.

**Usage:**
```bash
node scripts/validate-scene.js <scene-file.json>
```

**Example:**
```bash
node scripts/validate-scene.js schemas/examples/scene-example.json
```

**Output:**
```json
{
  "valid": true,
  "errors": []
}
```

**Exit Codes:**
- `0` - Validation successful
- `1` - Validation failed (schema errors)
- `2` - File not found or invalid JSON

---

### validate-scenario.js

Validates scenario JSON against `scenario.schema.json`.
Also runs semantic checks:
- Section ID uniqueness
- Section order correctness
- Duration validity

**Usage:**
```bash
node scripts/validate-scenario.js <scenario-file.json>
```

**Example:**
```bash
node scripts/validate-scenario.js schemas/examples/scenario-example.json
```

**Semantic Checks:**
- ✅ Section ID uniqueness
- ✅ Section order sequence (0, 1, 2, ...)
- ✅ Duration estimates (negative, excessive values)

**Exit Codes:**
- `0` - Validation successful
- `1` - Validation failed (schema or semantic errors)
- `2` - File not found or invalid JSON

---

### validate-video.js

End-to-end validation of a complete video script JSON.
Critical errors halt execution; warnings are logged and processing continues.

**Usage:**
```bash
node scripts/validate-video.js <video-script-file.json>
```

**Example:**
```bash
node scripts/validate-video.js schemas/examples/video-script-example.json
```

**E2E Validation Checks:**
- ✅ Scene ID uniqueness (across all scenes)
- ✅ Scene order sequence (within each section)
- ✅ Total duration calculation
- ⚠️ Asset file existence
- ⚠️ Audio sync validation
- ⚠️ Resolution/aspect ratio

**Severity Levels:**
| Level | Behavior | Examples |
|-------|----------|----------|
| **Critical** | Stops validation, exit code 1 | Duplicate IDs, invalid schema |
| **Warning** | Logs warning, continues | Missing assets, unusual aspect ratio |

**Output:**
```json
{
  "valid": true,
  "errors": [],
  "warnings": [
    {
      "severity": "warning",
      "path": "/scenes/0/assets/0/source",
      "message": "Asset not found: \"assets/intro.png\"",
      "keyword": "asset-missing"
    }
  ]
}
```

**Exit Codes:**
- `0` - Validation successful (warnings are ok)
- `1` - Validation failed (critical errors)
- `2` - File not found or invalid JSON

---

## Asset Management (Phase 7)

### load-assets.js

Loads assets (backgrounds, sound effects, fonts, images) with user override support.

**Priority System:**
1. User assets: `~/.harness/video/assets/`
2. Skill defaults: `skills/generate-video/assets/`
3. Built-in defaults: Hardcoded fallbacks

**Usage:**
```bash
# Load backgrounds configuration
node scripts/load-assets.js backgrounds

# Load sounds configuration
node scripts/load-assets.js sounds

# Show asset search paths
node scripts/load-assets.js paths

# Initialize user asset directory
node scripts/load-assets.js init

# Test all loading functions
node scripts/load-assets.js test
```

**Programmatic Usage:**
```javascript
const { loadBackgrounds, loadSounds, loadAssetFile } = require('./scripts/load-assets.js');

// Load configurations
const backgrounds = loadBackgrounds();
// → { version: "1.0.0", backgrounds: [...] }

const sounds = loadSounds();
// → { version: "1.0.0", sounds: [...] }

// Load specific asset file
const assetPath = loadAssetFile('sounds', 'impact.mp3');
// → "/path/to/impact.mp3" or null
```

**Functions:**
- `loadBackgrounds()` - Load background configurations
- `loadSounds()` - Load sound effect configurations
- `loadAssetFile(category, filename)` - Load specific asset file
- `updateManifest(manifestPath, assets)` - Update asset manifest
- `getAssetPaths()` - Get asset search paths (debug)
- `initUserAssetDir()` - Initialize `~/.harness/video/assets/`

**Asset Types:**
- **backgrounds** - 5 types: neutral, highlight, dramatic, tech, warm
- **sounds** - 4 types: impact, pop, transition, subtle
- **fonts** - Custom font files (TTF, OTF, WOFF)
- **images** - Custom images (PNG, JPG, SVG, WebP)

**Customization:**
See [references/asset-customization.md](../references/asset-customization.md) for detailed customization guide.

**Test:**
```bash
npm test -- asset-loader.test.js
```

---

## Future Scripts (Phase 3+)

Scripts planned for future addition:

- `merge-scenes.js` - Scene JSON merge
- `optimize-assets.js` - Asset optimization
- `generate-thumbnails.js` - Automatic thumbnail generation
- `render-video.js` - Video rendering (Phase 8)

---

## References

- [JSON Schema](https://json-schema.org/)
- [Zod Documentation](https://zod.dev/)
- [json-schema-to-zod](https://github.com/StefanTerdell/json-schema-to-zod)
- [Asset Customization Guide](../references/asset-customization.md)
