# Phase 7: Asset Foundation - Implementation Complete

## Summary

Phase 7 のアセット基盤（背景セット、効果音セット、asset-loader、ユーザー上書き）を完全実装しました。

### Completed Tasks

| Task | Status | File | Description |
|------|--------|------|-------------|
| 7.1 | ✅ | `assets/backgrounds/backgrounds.json` | 5種類の背景定義 |
| 7.2 | ✅ | `assets/sounds/sounds.json` | 4種類の効果音定義 |
| 7.3 | ✅ | `scripts/load-assets.js` | アセット読み込みユーティリティ |
| 7.4 | ✅ | `references/asset-customization.md` | ユーザー上書きドキュメント |
| - | ✅ | `tests/asset-loader.test.js` | アセットローダーテスト（28テスト、全合格） |

---

## Implementation Details

### Task 7.1: Background Set

**File**: `assets/backgrounds/backgrounds.json`

**Background Types** (5種類):

1. **neutral** - 標準（白/グレー系）
   - 用途: 一般コンテンツ、説明、中立的情報
   - グラデーション: linear, 135度
   - 色: #ffffff → #f5f5f5 → #e8e8e8

2. **highlight** - 強調（黄色系）
   - 用途: CTA、重要メッセージ、価値提案
   - グラデーション: radial
   - 色: #fffef5 → #fff9e6 → #ffe699
   - アニメーション: pulse (2秒、強度0.1)

3. **dramatic** - インパクト（暗め、グラデーション）
   - 用途: オープニングフック、問題提起、差別化
   - グラデーション: linear, 225度
   - 色: #0a0a14 → #1a1a2e → #16213e → #0f3460
   - オーバーレイ: vignette (強度0.3)
   - アニメーション: shift (10秒、強度0.05)

4. **tech** - テック感（青/紫系、グリッド）
   - 用途: アーキテクチャ図、技術解説、システム概要
   - グラデーション: linear, 180度
   - 色: #0d1b2a → #1b263b
   - パターン: grid (40px, lineWidth 1, opacity 0.15)
   - アニメーション: scan (3秒、強度0.2)

5. **warm** - 親しみ（オレンジ/ベージュ系）
   - 用途: オンボーディング、お客様の声、コミュニティ
   - グラデーション: radial
   - 色: #fffaf5 → #fff5eb → #ffe6cc
   - アニメーション: float (4秒、強度0.08)

**Key Features**:
- ✅ 各背景に用途ガイドライン（recommended_for, avoid_for）
- ✅ グラデーション設定（linear/radial, stops, angle）
- ✅ アニメーション設定（type, duration, intensity）
- ✅ オーバーレイ対応（vignette）
- ✅ パターン対応（grid）

**Metadata**:
```json
{
  "version": "1.0.0",
  "created_at": "2026-02-02",
  "author": "Claude Code"
}
```

---

### Task 7.2: Sound Effect Set

**File**: `assets/sounds/sounds.json`

**Sound Types** (4種類):

1. **impact** - 高強調（インパクト音）
   - 用途: 劇的な演出、重要な差別化点、CTA、オープニングフック
   - 強調レベル: high
   - ボリューム: default 0.7, with_narration 0.4, with_bgm 0.6
   - 期待時間: 0.5秒
   - 推奨頻度: 最大2-3回/動画

2. **pop** - 中強調（ポップ音）
   - 用途: 機能リスト、ベネフィット、ステップ完了
   - 強調レベル: medium
   - ボリューム: default 0.5, with_narration 0.25, with_bgm 0.4
   - 期待時間: 0.3秒
   - 推奨頻度: 最大5-8回/動画

3. **transition** - 場面転換（スライド音）
   - 用途: シーン転換、セクション移動、トピックシフト
   - 強調レベル: low
   - ボリューム: default 0.4, with_narration 0.2, with_bgm 0.3
   - 期待時間: 0.4秒
   - タイミング: ビジュアルトランジション中（offset -0.1秒）
   - 推奨頻度: 全シーン転換（有効化時）

4. **subtle** - 低強調（控えめな音）
   - 用途: 補足情報、UI変更、進捗インジケーター
   - 強調レベル: low
   - ボリューム: default 0.3, with_narration 0.15, with_bgm 0.25
   - 期待時間: 0.2秒
   - 推奨頻度: 最大10-15回/動画

**Key Features**:
- ✅ 強調レベル（high/medium/low）
- ✅ コンテキスト別ボリューム（default, with_narration, with_bgm）
- ✅ タイミング設定（offset, fade-in, fade-out）
- ✅ 使用ガイドライン（scenes, timing, recommended_for, avoid_for）
- ✅ 代替案（alternatives: stronger, softer, silent）

**Guidelines**:
```json
{
  "frequency": {
    "impact": "Maximum 2-3 per video",
    "pop": "Up to 5-8 per video",
    "transition": "All scene transitions (if enabled)",
    "subtle": "Up to 10-15 per video"
  },
  "combinations": {
    "with_narration": "Use lower volumes to avoid competing with voice",
    "with_bgm": "Use moderate volumes, BGM should be ducked during effects"
  }
}
```

**Fallback**:
```json
{
  "if_file_missing": "Continue without sound effect (silent)",
  "if_user_disabled": "Respect user preference (no effects)",
  "placeholder_sources": [
    "https://freesound.org/ (CC0 or CC BY licensed)",
    "User-provided sounds in ~/.harness/video/assets/sounds/",
    "Generate procedural sounds with Web Audio API"
  ]
}
```

---

### Task 7.3: Asset Loader Script

**File**: `scripts/load-assets.js`

**Functions**:

1. **loadBackgrounds()** - 背景設定読み込み
   - 優先順位: ユーザー → スキル → ビルトイン
   - 戻り値: `{ version, backgrounds: [...] }`

2. **loadSounds()** - 効果音設定読み込み
   - 優先順位: ユーザー → スキル → ビルトイン
   - 戻り値: `{ version, sounds: [...] }`

3. **loadAssetFile(category, filename)** - 個別ファイル読み込み
   - category: 'backgrounds', 'sounds', 'fonts', 'images'
   - 戻り値: 絶対パス or null

4. **updateManifest(manifestPath, assets)** - マニフェスト更新
   - 既存マニフェストに追加
   - タイムスタンプ更新
   - ディレクトリ自動作成

5. **getAssetPaths()** - アセット検索パス取得
   - デバッグ用
   - 戻り値: `{ user, skill, backgrounds: {...}, sounds: {...} }`

6. **initUserAssetDir()** - ユーザーアセットディレクトリ初期化
   - `~/.harness/video/assets/` 作成
   - サブディレクトリ作成（backgrounds, sounds, fonts, images）
   - README.md 生成

**Priority System**:
```
1. ~/.harness/video/assets/{category}/{file}     ← Highest
2. {skill}/assets/{category}/{file}              ← Fallback
3. Built-in defaults (hardcoded)                 ← Last resort
```

**CLI Usage**:
```bash
node load-assets.js backgrounds   # Load backgrounds
node load-assets.js sounds        # Load sounds
node load-assets.js paths         # Show search paths
node load-assets.js init          # Initialize user directory
node load-assets.js test          # Test all functions
```

**Programmatic Usage**:
```javascript
const { loadBackgrounds, loadSounds } = require('./load-assets.js');

const backgrounds = loadBackgrounds();
// → { version: "1.0.0", backgrounds: [...] }

const sounds = loadSounds();
// → { version: "1.0.0", sounds: [...] }
```

**Key Features**:
- ✅ 3層優先順位システム
- ✅ ファイル存在チェック
- ✅ JSON解析エラーハンドリング
- ✅ ビルトインフォールバック
- ✅ マニフェスト自動更新
- ✅ CLI + プログラム両対応
- ✅ ユーザーアセットディレクトリ初期化

---

### Task 7.4: User Customization Documentation

**File**: `references/asset-customization.md`

**Content**:

1. **Overview** - アセット優先順位の説明
2. **Directory Structure** - ユーザーアセットディレクトリ構造
3. **Customization Methods**
   - 背景のカスタマイズ（gradient, pattern, solid, image）
   - 効果音のカスタマイズ（ファイル配置、設定編集）
   - フォントのカスタマイズ（TTF/OTF配置、Remotion使用）
   - 画像のカスタマイズ（PNG/JPG配置、サイズ推奨値）
4. **Priority Details** - 優先順位の詳細説明
5. **Testing** - 動作確認コマンド
6. **Troubleshooting** - よくある問題と解決策
7. **Best Practices**
   - バージョン管理
   - チーム共有
   - プロジェクト別アセット
   - ライセンス管理
8. **Sample Configurations** - サンプル集

**Key Sections**:

#### Background Customization
```json
{
  "id": "my-brand",
  "name": "My Brand Background",
  "type": "gradient",
  "colors": {
    "primary": "#1e3a8a",
    "secondary": "#3b82f6"
  },
  "gradient": {
    "type": "linear",
    "angle": 135,
    "stops": [...]
  }
}
```

#### Sound Customization
```bash
# Download CC0 sounds
cp my-impact.mp3 ~/.harness/video/assets/sounds/impact.mp3

# Edit configuration
vim ~/.harness/video/assets/sounds/sounds.json
```

#### Font Customization
```bash
# Place font files
cp MyFont-Bold.ttf ~/.harness/video/assets/fonts/

# Reference in scene
{
  "font": {
    "family": "MyFont",
    "file": "~/.harness/video/assets/fonts/MyFont-Bold.ttf"
  }
}
```

#### Testing Commands
```bash
node scripts/load-assets.js test         # Test all
node scripts/load-assets.js backgrounds  # Show backgrounds
node scripts/load-assets.js sounds       # Show sounds
node scripts/load-assets.js paths        # Show paths
```

**Troubleshooting**:
- Asset not loading → Check file paths
- JSON parse error → Validate JSON syntax
- Sound not playing → Check file format (MP3 recommended)
- Font not rendering → Use absolute path

---

## Testing

### Test Suite: asset-loader.test.js

**Coverage**: 28 tests, all passing ✅

**Test Categories**:

1. **loadBackgrounds()** (5 tests)
   - Loads skill default backgrounds
   - Contains all 5 background types
   - Each background has required fields
   - Neutral background properties
   - Tech background pattern definition

2. **loadSounds()** (5 tests)
   - Loads skill default sounds
   - Contains all 4 sound types
   - Each sound has required fields
   - Emphasis levels correctly assigned
   - Volume with narration is lower

3. **loadAssetFile()** (3 tests)
   - Returns null for non-existent file
   - Finds skill backgrounds.json
   - Finds skill sounds.json

4. **updateManifest()** (3 tests)
   - Creates new manifest if not exists
   - Appends to existing manifest
   - Updates generated_at timestamp

5. **getAssetPaths()** (2 tests)
   - Returns asset search paths
   - Skill path points to correct directory

6. **Integration: Background structure** (3 tests)
   - All backgrounds have valid color hex codes
   - Gradient stops in ascending order
   - Usage.scenes not empty

7. **Integration: Sound structure** (3 tests)
   - Volume ranges valid (0-1)
   - Timing offsets reasonable
   - Expected duration reasonable

8. **Metadata** (4 tests)
   - backgrounds.json has metadata
   - sounds.json has metadata
   - sounds.json has guidelines
   - sounds.json has fallback configuration

**Run Tests**:
```bash
npm test -- asset-loader.test.js
```

**Test Results**:
```
Test Suites: 1 passed, 1 total
Tests:       28 passed, 28 total
Time:        0.237 s
```

---

## File Structure

```
skills/generate-video/
├── assets/
│   ├── backgrounds/
│   │   └── backgrounds.json              # ✅ NEW (Task 7.1)
│   └── sounds/
│       └── sounds.json                   # ✅ NEW (Task 7.2)
├── scripts/
│   └── load-assets.js                    # ✅ NEW (Task 7.3)
├── references/
│   └── asset-customization.md            # ✅ NEW (Task 7.4)
├── tests/
│   └── asset-loader.test.js              # ✅ NEW
└── .claude/state/
    └── phase-7-implementation.md         # ✅ NEW (this file)
```

**User Asset Directory** (created by init):
```
~/.harness/video/assets/
├── README.md                             # Auto-generated
├── backgrounds/
│   └── backgrounds.json                  # User override
├── sounds/
│   ├── sounds.json                       # User override
│   ├── impact.mp3                        # User audio
│   ├── pop.mp3
│   ├── transition.mp3
│   └── subtle.mp3
├── fonts/
│   └── *.ttf, *.otf
└── images/
    └── *.png, *.jpg
```

---

## Integration

### With Existing Systems

**Phase 5 Components**:
- `remotion/components/BackgroundLayer.tsx` uses backgrounds from `loadBackgrounds()`
- Background IDs referenced in scene configurations

**Phase 6 Visual Patterns**:
- Generated images saved to `out/video-{id}/assets/generated/`
- Tracked in `assets.manifest.schema.json`

**Scene Configuration**:
```json
{
  "scene": {
    "background": "tech",
    "emphasis": {
      "level": "high",
      "sound": "impact"
    }
  }
}
```

**Asset Loading Flow**:
```
Scene JSON → loadBackgrounds() → Priority check → Load config
                                                    ↓
                                        Background applied to scene
```

---

## Usage Examples

### Example 1: Use Default Assets

```javascript
const { loadBackgrounds, loadSounds } = require('./scripts/load-assets.js');

// Load defaults
const backgrounds = loadBackgrounds();
const sounds = loadSounds();

// Use in scene
const scene = {
  background: 'dramatic',  // From backgrounds.backgrounds[2]
  emphasis: {
    sound: 'impact'        // From sounds.sounds[0]
  }
};
```

### Example 2: Override Backgrounds Only

```bash
# Copy and customize
cp assets/backgrounds/backgrounds.json ~/.harness/video/assets/backgrounds/

# Edit brand colors
vim ~/.harness/video/assets/backgrounds/backgrounds.json
```

```json
{
  "version": "1.0.0",
  "backgrounds": [
    {
      "id": "my-brand",
      "name": "My Brand",
      "colors": {
        "primary": "#your-brand-color"
      }
    }
  ]
}
```

### Example 3: Custom Sound Effects

```bash
# Download CC0 sounds from freesound.org
curl -o ~/.harness/video/assets/sounds/impact.mp3 https://...

# Load in code
const sounds = loadSounds();
// → Now uses your custom impact.mp3
```

### Example 4: Initialize User Directory

```bash
# Create user asset directory
node scripts/load-assets.js init

# Output:
# 🔧 Initializing user asset directory...
#   ✅ Created: ~/.harness/video/assets
#   ✅ Created: ~/.harness/video/assets/backgrounds
#   ✅ Created: ~/.harness/video/assets/sounds
#   ✅ Created: ~/.harness/video/assets/fonts
#   ✅ Created: ~/.harness/video/assets/images
#   ✅ Created: ~/.harness/video/assets/README.md
```

---

## Quality Checks

### Self-Review

- [x] **Generality**: Works for any custom assets, not hardcoded
- [x] **Edge Cases**: Handles missing files (fallback), invalid JSON (warning)
- [x] **Logic**: 3-tier priority system is meaningful and extensible
- [x] **Error Handling**: Clear warnings, graceful fallbacks

### No Hardcoding

- [x] No test-specific values
- [x] Generic priority system
- [x] Configurable paths (user/skill/builtin)
- [x] Extensible structure (easy to add new asset types)

### Documentation

- [x] Comprehensive customization guide: `asset-customization.md`
- [x] CLI usage documented in script comments
- [x] Programmatic usage with code examples
- [x] Troubleshooting section

### Security

- [x] No code execution from JSON files
- [x] File path validation
- [x] Safe JSON parsing with error handling
- [x] User directory creation with proper permissions

---

## Next Steps

### Phase 7 Complete → Phase 8: Rendering

**Next Tasks**:
- Task 8.1: Render video script (`scripts/render-video.js`)
- Task 8.2: Integration tests (`tests/e2e/render.test.ts`)

**Integration Points**:
- Backgrounds/sounds loaded at render time
- Asset manifest generated during render
- User assets automatically applied

---

## Acceptance Criteria

| Task | Criteria | Status |
|------|----------|--------|
| 7.1 | 5 background types defined | ✅ Complete |
| 7.1 | Each background has usage guidelines | ✅ Complete |
| 7.1 | Gradient/pattern/animation support | ✅ Complete |
| 7.2 | 4 sound types defined | ✅ Complete |
| 7.2 | Volume recommendations by context | ✅ Complete |
| 7.2 | Timing/frequency guidelines | ✅ Complete |
| 7.3 | 3-tier priority system | ✅ Complete |
| 7.3 | CLI + programmatic usage | ✅ Complete |
| 7.3 | Fallback to built-in defaults | ✅ Complete |
| 7.4 | Customization guide | ✅ Complete |
| 7.4 | Troubleshooting section | ✅ Complete |
| 7.4 | Sample configurations | ✅ Complete |
| - | All tests pass | ✅ 28/28 passing |

---

## References

- **Plans.md**: [Phase 7 - Asset Foundation](../../Plans.md#phase-7-アセット基盤-cctodo)
- **Backgrounds**: [assets/backgrounds/backgrounds.json](../../assets/backgrounds/backgrounds.json)
- **Sounds**: [assets/sounds/sounds.json](../../assets/sounds/sounds.json)
- **Asset Loader**: [scripts/load-assets.js](../../scripts/load-assets.js)
- **Customization Guide**: [references/asset-customization.md](../../references/asset-customization.md)
- **Tests**: [tests/asset-loader.test.js](../../tests/asset-loader.test.js)

---

**Implementation Date**: 2026-02-02
**Implemented By**: Claude Code (Task Worker)
**Verification Status**: ✅ Ready for Phase 8
