# Phase 6: Image Generation Patterns - Implementation Complete

## Summary

Phase 6 の画像生成パターン（comparison, concept, flow, highlight）を完全実装しました。

### Completed Tasks

| Task | Status | File | Description |
|------|--------|------|-------------|
| 6.1 | ✅ | `schemas/visual-patterns.schema.json` | 4パターンのJSON Schema定義 |
| 6.2-6.4 | ✅ | `references/image-patterns.md` | 各パターンの使用ガイド |
| 6.5 | ✅ | `templates/image-prompts/*.txt` | AIプロンプトテンプレート（4種） |
| - | ✅ | `tests/visual-patterns.test.js` | バリデーションテスト（25テスト、全合格） |
| - | ✅ | `schemas/examples/visual-patterns/*.json` | 実装例（4パターン） |

---

## Implementation Details

### Task 6.1: visual-patterns.schema.json

**File**: `schemas/visual-patterns.schema.json`

**Schema Version**: 1.0.0

**Pattern Types**:
1. **comparison** - Before/After、良い例/悪い例の対比
2. **concept** - 抽象概念、階層構造、関係性の視覚化
3. **flow** - 手順、プロセス、ワークフローの図示
4. **highlight** - 重要ポイント、メッセージの強調

**Key Features**:
- ✅ `oneOf` constraint enforcing pattern-specific fields
- ✅ Color scheme validation (hex format)
- ✅ Dimension constraints (256-2048px)
- ✅ Generation settings (seed, quality, retries)
- ✅ Comprehensive metadata support

**Common Fields**:
```json
{
  "type": "comparison|concept|flow|highlight",
  "topic": "string (required)",
  "style": "minimalist|technical|modern|gradient|flat|3d",
  "colorScheme": { "primary": "#...", "secondary": "#...", ... },
  "dimensions": { "width": 1920, "height": 1080, "aspectRatio": "16:9" },
  "generation": { "seed": 42, "quality": "standard|high", "retries": 3 }
}
```

---

### Task 6.2: Comparison Pattern

**Purpose**: Before/After、良い例/悪い例の視覚的対比

**Required Fields**:
- `leftSide`: Label, items (array), icon, sentiment
- `rightSide`: Label, items (array), icon, sentiment
- `divider`: arrow|vs|line|gradient

**Visual Structure**:
```
┌──────────────────────────────────────────┐
│  [Before/Bad]  →  [After/Good]           │
│  ❌ Problem 1     ✅ Solution 1           │
│  ❌ Problem 2     ✅ Solution 2           │
└──────────────────────────────────────────┘
```

**Use Cases**:
- Problem presentation → Solution demonstration
- Old version → New version comparison
- Manual process → Automated process

---

### Task 6.3: Concept Pattern

**Purpose**: 抽象概念、階層構造、要素間の関係性を視覚化

**Required Fields**:
- `elements`: Array of 2-10 elements (id, label, level, icon, emphasis)
- `relationships`: Optional connections between elements
- `layout`: hierarchy|radial|grid|flow|circular

**Layout Types**:
| Layout | Use Case | Visual |
|--------|----------|--------|
| hierarchy | Organizational charts, dependency trees | Top-down tree |
| radial | Ecosystem, relationships | Center + surrounding |
| grid | Category classification | Matrix layout |
| flow | Data pipeline | Left-to-right flow |
| circular | Lifecycle, iterative process | Circular pattern |

**Use Cases**:
- Architecture diagrams
- System component relationships
- Process overview
- Concept explanation

---

### Task 6.4: Flow Pattern

**Purpose**: 手順、プロセス、ワークフローを時系列で視覚化

**Required Fields**:
- `steps`: Array of 2-10 steps (id, label, order, type, icon)
- `direction`: horizontal|vertical|zigzag
- `arrowStyle`: solid|dashed|dotted|thick|animated
- `showNumbers`: boolean

**Step Types**:
| Type | Visual | Color | Use |
|------|--------|-------|-----|
| start | Circle | Green | Flow start |
| process | Square | Blue | Standard step |
| decision | Diamond | Yellow | Branching |
| parallel | Multiple boxes | Purple | Concurrent |
| subprocess | Rounded square | Gray | Sub-flow |
| end | Double circle | Red | Completion |

**Use Cases**:
- Setup instructions
- User journey
- Data pipeline
- Onboarding flow

---

### Task 6.5: Highlight Pattern

**Purpose**: 単一のメッセージ、キーワード、数値を強調表示

**Required Fields**:
- `mainText`: Short, impactful message (max 100 chars)
- `subText`: Optional supporting text (max 150 chars)
- `icon`: star|check|alert|trophy|rocket|fire|bolt|heart|none
- `position`: center|top|bottom|left|right
- `effect`: glow|shadow|gradient|outline|none
- `fontSize`: small|medium|large|xlarge
- `emphasis`: high|medium|low

**Effect Types**:
| Effect | Visual | Use Case |
|--------|--------|----------|
| glow | Radiant aura | CTA, conclusion |
| shadow | Drop shadow | Hook, emphasis |
| gradient | Color gradient | Modern look |
| outline | Bold outline | Sharp, clean |
| none | Minimal | Subtle |

**Use Cases**:
- Hook (opening scene)
- CTA (call to action)
- Key metrics ("95% time saved")
- Conclusions

---

## Prompt Templates

### Task 6.5: Template Files

**Location**: `templates/image-prompts/`

**Files**:
1. `comparison.txt` - Before/After split-screen layout
2. `concept.txt` - Diagram with elements and relationships
3. `flow.txt` - Step-by-step process flow
4. `highlight.txt` - Bold message emphasis

**Template Features**:
- ✅ Mustache-style placeholders ({{topic}}, {{style}}, etc.)
- ✅ Conditional sections ({{#hasStart}}...{{/hasStart}})
- ✅ Style-specific instructions
- ✅ Technical specs (resolution, format)
- ✅ Quality guidelines (avoid patterns)

**Usage**:
```javascript
const template = fs.readFileSync('templates/image-prompts/comparison.txt', 'utf-8');
const prompt = Mustache.render(template, {
  topic: data.topic,
  style: data.style,
  leftLabel: data.comparison.leftSide.label,
  // ... more placeholders
});
```

---

## Testing

### Test Suite: visual-patterns.test.js

**Coverage**: 25 tests, all passing ✅

**Test Categories**:
1. **Schema Structure** (3 tests)
   - Valid JSON Schema
   - Required metadata fields
   - All 4 pattern types defined

2. **Comparison Pattern** (3 tests)
   - Valid pattern validation
   - Missing leftSide rejection
   - Missing rightSide rejection

3. **Concept Pattern** (3 tests)
   - Valid pattern validation
   - Minimum 2 elements enforcement
   - Relationships validation

4. **Flow Pattern** (3 tests)
   - Valid pattern validation
   - Minimum 2 steps enforcement
   - Different directions

5. **Highlight Pattern** (3 tests)
   - Valid pattern validation
   - Missing mainText rejection
   - Icon types validation

6. **Color Scheme** (2 tests)
   - Valid hex codes
   - Invalid format rejection

7. **Dimensions** (2 tests)
   - Valid dimensions
   - Out-of-range rejection

8. **Generation Settings** (2 tests)
   - Settings validation
   - Quality levels

9. **oneOf Enforcement** (4 tests)
   - Pattern type consistency

**Run Tests**:
```bash
npm test -- visual-patterns.test.js
```

---

## Examples

### Example Files

**Location**: `schemas/examples/visual-patterns/`

**Files**:
1. `comparison-example.json` - Task management Before/After
2. `concept-example.json` - Microservices architecture
3. `flow-example.json` - Video generation workflow
4. `highlight-example.json` - 95% time saved value prop

**Validation**:
All examples pass schema validation ✅

---

## Integration

### With Existing Systems

**Schema Generation**:
```bash
npm run generate:schemas
# → src/schemas/visual-patterns.ts created
```

**Zod Export**:
```typescript
import { VisualPatternsSchema, type VisualPatterns } from './src/schemas';

const pattern: VisualPatterns = {
  type: 'comparison',
  topic: 'Test',
  // ...
};

const result = VisualPatternsSchema.safeParse(pattern);
```

**Image Generator Integration**:
- Referenced by `references/image-generator.md`
- Prompt templates used in AI generation
- Quality check via `references/image-quality-check.md`

**Asset Management**:
- Output to `out/video-{id}/assets/generated/`
- Tracked in `assets.manifest.schema.json`
- SHA-256 hash for determinism

---

## File Structure

```
skills/generate-video/
├── schemas/
│   ├── visual-patterns.schema.json          # ✅ NEW (Task 6.1)
│   └── examples/
│       └── visual-patterns/                 # ✅ NEW
│           ├── comparison-example.json
│           ├── concept-example.json
│           ├── flow-example.json
│           └── highlight-example.json
├── templates/
│   └── image-prompts/                       # ✅ NEW (Task 6.5)
│       ├── comparison.txt
│       ├── concept.txt
│       ├── flow.txt
│       └── highlight.txt
├── references/
│   └── image-patterns.md                    # ✅ NEW (Task 6.2-6.4)
├── tests/
│   └── visual-patterns.test.js              # ✅ NEW
└── src/
    └── schemas/
        └── visual-patterns.ts               # ✅ Generated
```

---

## Usage Guide

### Pattern Selection

**By Scene Type**:
| Scene | Pattern | Purpose |
|-------|---------|---------|
| Hook | highlight | Grab attention |
| Problem | comparison | Show pain points |
| Solution | concept | Explain approach |
| Demo | flow | Show steps |
| Differentiator | comparison | Highlight advantages |
| CTA | highlight | Call to action |

**By Funnel Stage**:
| Stage | Recommended Patterns |
|-------|---------------------|
| Awareness | highlight, comparison |
| Consideration | concept, flow |
| Decision | comparison, concept |
| Retention | flow, highlight |

### Implementation Example

```javascript
// 1. Define pattern
const comparisonPattern = {
  type: 'comparison',
  topic: 'Development Speed',
  style: 'modern',
  comparison: {
    leftSide: {
      label: 'Manual Process',
      items: ['30 min setup', 'Frequent errors', 'Hard to reproduce'],
      icon: 'x',
      sentiment: 'negative'
    },
    rightSide: {
      label: 'Automated',
      items: ['10 sec setup', 'Zero errors', 'Always reproducible'],
      icon: 'check',
      sentiment: 'positive'
    }
  }
};

// 2. Validate
const result = VisualPatternsSchema.safeParse(comparisonPattern);

// 3. Generate prompt
const template = readTemplate('comparison.txt');
const prompt = renderPrompt(template, comparisonPattern);

// 4. Generate image
const image = await generateImage(prompt, {
  seed: comparisonPattern.generation?.seed,
  quality: comparisonPattern.generation?.quality
});

// 5. Quality check
const qualityResult = await checkImageQuality(image);

// 6. Save to manifest
addToAssetManifest(image, comparisonPattern);
```

---

## Quality Checks

### Self-Review

- [x] **Generality**: Works for any topic, not hardcoded
- [x] **Edge Cases**: Validates required fields, rejects invalid data
- [x] **Logic**: Meaningful constraints (min 2 elements, max 10 steps)
- [x] **Error Handling**: Clear validation errors via AJV

### No Hardcoding

- [x] No test-specific values
- [x] Generic templates with placeholders
- [x] Configurable dimensions, colors, styles
- [x] Extensible metadata

### Documentation

- [x] Comprehensive reference: `image-patterns.md`
- [x] Usage examples for all 4 patterns
- [x] Integration guide
- [x] Selection criteria by scene/funnel

---

## Next Steps

### Phase 6 Complete → Phase 7: Asset Foundation

**Next Tasks**:
- Task 7.1: Background set (`assets/backgrounds/`)
- Task 7.2: Sound effect set (`assets/sounds/`)
- Task 7.3: Asset loader (`scripts/load-assets.js`)
- Task 7.4: User override (`~/.harness/video/assets/`)

**Integration Points**:
- Visual patterns will use background assets
- Image generation will reference prompt templates
- Asset manifest will track generated images

---

## Acceptance Criteria

| Task | Criteria | Status |
|------|----------|--------|
| 6.1 | Schema defines 4 patterns | ✅ Complete |
| 6.1 | oneOf constraint enforces pattern fields | ✅ Complete |
| 6.2-6.4 | Reference doc covers all patterns | ✅ Complete |
| 6.2-6.4 | Usage guidelines by scene type | ✅ Complete |
| 6.5 | 4 prompt templates with placeholders | ✅ Complete |
| 6.5 | Templates include technical specs | ✅ Complete |
| - | All tests pass | ✅ 25/25 passing |
| - | Schema generates valid Zod types | ✅ Complete |

---

## References

- **Plans.md**: [/Users/tachibanashuuta/Desktop/Code/CC-harness/claude-code-harness-video-hybrid/Plans.md](../../Plans.md)
- **Schema**: [schemas/visual-patterns.schema.json](../../schemas/visual-patterns.schema.json)
- **Reference**: [references/image-patterns.md](../../references/image-patterns.md)
- **Templates**: [templates/image-prompts/](../../templates/image-prompts/)
- **Tests**: [tests/visual-patterns.test.js](../../tests/visual-patterns.test.js)

---

**Implementation Date**: 2026-02-02
**Implemented By**: Claude Code (Task Worker)
**Verification Status**: ✅ Ready for Phase 7
