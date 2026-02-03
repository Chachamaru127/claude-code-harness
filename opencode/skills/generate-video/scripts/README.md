# Scripts Directory

JSON Schema 自動生成とバリデーションのためのスクリプト集。

## Available Scripts

### generate-schemas.js

JSON Schema から Zod スキーマを自動生成します。

**Usage:**
```bash
npm run generate:schemas
```

**Input:**
- `schemas/*.schema.json` - JSON Schema ファイル

**Output:**
- `src/schemas/*.ts` - Zod スキーマ定義
- `src/schemas/index.ts` - バレル export

**Example:**
```bash
# Generate all schemas
node scripts/generate-schemas.js

# Or via npm script (recommended)
npm run generate:schemas
```

**Dependencies:**
- `json-schema-to-zod` - JSON Schema → Zod 変換
- `zod` - Runtime validation

---

## Setup

### Install Dependencies

スキーマ生成に必要なパッケージをインストール：

```bash
npm install --save-dev json-schema-to-zod
npm install zod
```

### Add npm Script

`package.json` に以下を追加：

```json
{
  "scripts": {
    "generate:schemas": "node scripts/generate-schemas.js"
  }
}
```

### Pre-commit Hook (Optional)

スキーマ変更時に自動生成：

```bash
# .husky/pre-commit
npm run generate:schemas
git add src/schemas/
```

---

## Schema Development Workflow

1. **Schema 作成**: `schemas/*.schema.json` を作成
2. **生成実行**: `npm run generate:schemas`
3. **型推論確認**: `src/schemas/*.ts` で TypeScript 型を確認
4. **バリデーション**: 生成された Zod スキーマで検証

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

メジャーバージョンを上げる必要がある変更：
- Required フィールドの追加
- フィールドの削除
- 型の変更

マイナーバージョンで可能な変更：
- Optional フィールドの追加
- Enum 値の追加
- Description の変更

---

## Troubleshooting

### Schema Generation Errors

**Error**: `Cannot find module 'json-schema-to-zod'`
```bash
npm install --save-dev json-schema-to-zod
```

**Error**: `No .schema.json files found`
- `schemas/` ディレクトリに `*.schema.json` ファイルがあるか確認

**Error**: `Invalid JSON`
- JSON Schema の構文エラーをチェック
- [JSONLint](https://jsonlint.com/) で検証

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

個別シーン JSON を `scene.schema.json` に対してバリデーションします。

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

シナリオ JSON を `scenario.schema.json` に対してバリデーションします。
セマンティックチェックも実行：
- セクション ID の一意性
- セクション順序の正しさ
- Duration の妥当性

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

完全なビデオスクリプト JSON を E2E でバリデーションします。
Critical エラーは停止、Warning はログ出力して続行。

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

アセット（背景、効果音、フォント、画像）の読み込みとユーザー上書き対応。

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

今後追加予定のスクリプト：

- `merge-scenes.js` - シーン JSON マージ
- `optimize-assets.js` - アセット最適化
- `generate-thumbnails.js` - サムネイル自動生成
- `render-video.js` - ビデオレンダリング (Phase 8)

---

## References

- [JSON Schema](https://json-schema.org/)
- [Zod Documentation](https://zod.dev/)
- [json-schema-to-zod](https://github.com/StefanTerdell/json-schema-to-zod)
- [Asset Customization Guide](../references/asset-customization.md)
