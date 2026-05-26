#!/usr/bin/env node

/**
 * Asset Loader Utility
 *
 * Loads backgrounds, sounds, and other assets with user override support.
 * Provides fallback defaults when files are missing.
 *
 * Usage:
 *   const { loadBackgrounds, loadSounds, updateManifest } = require('./load-assets.js');
 *   const backgrounds = await loadBackgrounds();
 *   const sounds = await loadSounds();
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

// Asset directories
const SKILL_ROOT = path.join(__dirname, '..');
const ASSETS_DIR = path.join(SKILL_ROOT, 'assets');
const USER_ASSETS_DIR = path.join(os.homedir(), '.harness', 'video', 'assets');

/**
 * Load JSON file with error handling
 * @param {string} filePath - Path to JSON file
 * @returns {Object|null} Parsed JSON or null if not found
 */
function loadJSON(filePath) {
  try {
    if (!fs.existsSync(filePath)) {
      return null;
    }
    const content = fs.readFileSync(filePath, 'utf-8');
    return JSON.parse(content);
  } catch (error) {
    console.warn(`Warning: Failed to load ${filePath}: ${error.message}`);
    return null;
  }
}

/**
 * Load backgrounds with user override support
 *
 * Priority:
 * 1. ~/.harness/video/assets/backgrounds/backgrounds.json
 * 2. {skill}/assets/backgrounds/backgrounds.json
 * 3. Built-in defaults
 *
 * @returns {Object} Backgrounds configuration
 */
function loadBackgrounds() {
  console.log('🎨 Loading backgrounds...');

  // Try user override
  const userBackgroundsPath = path.join(USER_ASSETS_DIR, 'backgrounds', 'backgrounds.json');
  const userBackgrounds = loadJSON(userBackgroundsPath);
  if (userBackgrounds) {
    console.log('  ✅ Loaded user backgrounds from:', userBackgroundsPath);
    return userBackgrounds;
  }

  // Try skill defaults
  const skillBackgroundsPath = path.join(ASSETS_DIR, 'backgrounds', 'backgrounds.json');
  const skillBackgrounds = loadJSON(skillBackgroundsPath);
  if (skillBackgrounds) {
    console.log('  ✅ Loaded skill backgrounds from:', skillBackgroundsPath);
    return skillBackgrounds;
  }

  // Fallback to built-in defaults
  console.log('  ⚠️  No backgrounds.json found, using built-in defaults');
  return getDefaultBackgrounds();
}

/**
 * Load sounds with user override support
 *
 * Priority:
 * 1. ~/.harness/video/assets/sounds/sounds.json
 * 2. {skill}/assets/sounds/sounds.json
 * 3. Built-in defaults
 *
 * @returns {Object} Sounds configuration
 */
function loadSounds() {
  console.log('🔊 Loading sounds...');

  // Try user override
  const userSoundsPath = path.join(USER_ASSETS_DIR, 'sounds', 'sounds.json');
  const userSounds = loadJSON(userSoundsPath);
  if (userSounds) {
    console.log('  ✅ Loaded user sounds from:', userSoundsPath);
    return userSounds;
  }

  // Try skill defaults
  const skillSoundsPath = path.join(ASSETS_DIR, 'sounds', 'sounds.json');
  const skillSounds = loadJSON(skillSoundsPath);
  if (skillSounds) {
    console.log('  ✅ Loaded skill sounds from:', skillSoundsPath);
    return skillSounds;
  }

  // Fallback to built-in defaults
  console.log('  ⚠️  No sounds.json found, using built-in defaults');
  return getDefaultSounds();
}

/**
 * Load specific asset file (image, audio, etc.) with user override
 *
 * Priority:
 * 1. ~/.harness/video/assets/{category}/{filename}
 * 2. {skill}/assets/{category}/{filename}
 * 3. null (file not found)
 *
 * @param {string} category - Asset category (backgrounds, sounds, fonts, etc.)
 * @param {string} filename - Asset filename
 * @returns {string|null} Absolute path to asset file or null
 */
function loadAssetFile(category, filename) {
  // Path traversal protection
  if (path.isAbsolute(category) || path.isAbsolute(filename)) {
    console.warn('⚠️ Rejecting absolute path in loadAssetFile');
    return null;
  }
  const normalizedPath = path.normalize(path.join(category, filename));
  if (normalizedPath.includes('..') || normalizedPath.startsWith('/')) {
    console.warn('⚠️ Rejecting path traversal attempt in loadAssetFile');
    return null;
  }

  // Try user override
  const userAssetPath = path.join(USER_ASSETS_DIR, category, filename);
  if (fs.existsSync(userAssetPath)) {
    console.log(`  ✅ Found user asset: ${category}/${filename}`);
    return userAssetPath;
  }

  // Try skill defaults
  const skillAssetPath = path.join(ASSETS_DIR, category, filename);
  if (fs.existsSync(skillAssetPath)) {
    console.log(`  ✅ Found skill asset: ${category}/${filename}`);
    return skillAssetPath;
  }

  // Not found
  console.warn(`  ⚠️  Asset not found: ${category}/${filename}`);
  return null;
}

/**
 * Get default backgrounds (fallback)
 * @returns {Object} Default backgrounds configuration
 */
function getDefaultBackgrounds() {
  return {
    version: '1.0.0',
    backgrounds: [
      {
        id: 'neutral',
        name: 'Neutral',
        type: 'gradient',
        colors: { primary: '#f5f5f5', secondary: '#e0e0e0', accent: '#ffffff' },
        gradient: {
          type: 'linear',
          angle: 135,
          stops: [
            { color: '#ffffff', position: 0 },
            { color: '#f5f5f5', position: 50 },
            { color: '#e8e8e8', position: 100 }
          ]
        }
      },
      {
        id: 'highlight',
        name: 'Highlight',
        type: 'gradient',
        colors: { primary: '#fff9e6', secondary: '#ffe699', accent: '#ffd966' },
        gradient: {
          type: 'radial',
          stops: [
            { color: '#fffef5', position: 0 },
            { color: '#fff9e6', position: 40 },
            { color: '#ffe699', position: 100 }
          ]
        }
      },
      {
        id: 'dramatic',
        name: 'Dramatic',
        type: 'gradient',
        colors: { primary: '#1a1a2e', secondary: '#16213e', accent: '#0f3460' },
        gradient: {
          type: 'linear',
          angle: 225,
          stops: [
            { color: '#0a0a14', position: 0 },
            { color: '#1a1a2e', position: 30 },
            { color: '#16213e', position: 70 },
            { color: '#0f3460', position: 100 }
          ]
        }
      },
      {
        id: 'tech',
        name: 'Tech',
        type: 'pattern',
        colors: { primary: '#0d1b2a', secondary: '#1b263b', accent: '#415a77', grid: '#2d3e50' },
        gradient: {
          type: 'linear',
          angle: 180,
          stops: [
            { color: '#0d1b2a', position: 0 },
            { color: '#1b263b', position: 100 }
          ]
        },
        pattern: { type: 'grid', size: 40, lineWidth: 1, opacity: 0.15 }
      },
      {
        id: 'warm',
        name: 'Warm',
        type: 'gradient',
        colors: { primary: '#fff5eb', secondary: '#ffe6cc', accent: '#ffd9b3' },
        gradient: {
          type: 'radial',
          stops: [
            { color: '#fffaf5', position: 0 },
            { color: '#fff5eb', position: 30 },
            { color: '#ffe6cc', position: 100 }
          ]
        }
      }
    ]
  };
}

/**
 * Get default sounds (fallback)
 * @returns {Object} Default sounds configuration
 */
function getDefaultSounds() {
  return {
    version: '1.0.0',
    sounds: [
      {
        id: 'impact',
        name: 'Impact',
        category: 'emphasis',
        emphasis_level: 'high',
        volume: { default: 0.7, with_narration: 0.4, with_bgm: 0.6 }
      },
      {
        id: 'pop',
        name: 'Pop',
        category: 'emphasis',
        emphasis_level: 'medium',
        volume: { default: 0.5, with_narration: 0.25, with_bgm: 0.4 }
      },
      {
        id: 'transition',
        name: 'Transition',
        category: 'transition',
        emphasis_level: 'low',
        volume: { default: 0.4, with_narration: 0.2, with_bgm: 0.3 }
      },
      {
        id: 'subtle',
        name: 'Subtle',
        category: 'emphasis',
        emphasis_level: 'low',
        volume: { default: 0.3, with_narration: 0.15, with_bgm: 0.25 }
      }
    ]
  };
}

/**
 * Update asset manifest with loaded assets
 *
 * @param {string} manifestPath - Path to assets.manifest.json
 * @param {Object} assets - Assets to add to manifest
 * @returns {boolean} Success status
 */
function updateManifest(manifestPath, assets) {
  try {
    console.log('📝 Updating asset manifest...');

    // Load existing manifest or create new
    let manifest = loadJSON(manifestPath) || {
      version: '1.0.0',
      generated_at: new Date().toISOString(),
      project: {
        name: 'Unknown',
        video_id: 'video-' + Date.now()
      },
      assets: []
    };

    // Add new assets
    if (Array.isArray(assets)) {
      manifest.assets.push(...assets);
    } else {
      manifest.assets.push(assets);
    }

    // Update timestamp
    manifest.generated_at = new Date().toISOString();

    // Write manifest
    const manifestDir = path.dirname(manifestPath);
    if (!fs.existsSync(manifestDir)) {
      fs.mkdirSync(manifestDir, { recursive: true });
    }
    fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));

    console.log('  ✅ Manifest updated:', manifestPath);
    return true;
  } catch (error) {
    console.error('  ❌ Failed to update manifest:', error.message);
    return false;
  }
}

/**
 * Get asset search paths (for debugging)
 *
 * @returns {Object} Asset search paths
 */
function getAssetPaths() {
  return {
    user: USER_ASSETS_DIR,
    skill: ASSETS_DIR,
    backgrounds: {
      user: path.join(USER_ASSETS_DIR, 'backgrounds'),
      skill: path.join(ASSETS_DIR, 'backgrounds')
    },
    sounds: {
      user: path.join(USER_ASSETS_DIR, 'sounds'),
      skill: path.join(ASSETS_DIR, 'sounds')
    }
  };
}

/**
 * Initialize user asset directory
 * Creates ~/.harness/video/assets/ structure
 *
 * @returns {boolean} Success status
 */
function initUserAssetDir() {
  try {
    console.log('🔧 Initializing user asset directory...');

    const dirs = [
      USER_ASSETS_DIR,
      path.join(USER_ASSETS_DIR, 'backgrounds'),
      path.join(USER_ASSETS_DIR, 'sounds'),
      path.join(USER_ASSETS_DIR, 'fonts'),
      path.join(USER_ASSETS_DIR, 'images')
    ];

    for (const dir of dirs) {
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
        console.log(`  ✅ Created: ${dir}`);
      } else {
        console.log(`  ℹ️  Already exists: ${dir}`);
      }
    }

    // Create README
    const readmePath = path.join(USER_ASSETS_DIR, 'README.md');
    if (!fs.existsSync(readmePath)) {
      fs.writeFileSync(readmePath, getUserAssetReadme());
      console.log(`  ✅ Created: ${readmePath}`);
    }

    console.log('  ✅ User asset directory initialized');
    return true;
  } catch (error) {
    console.error('  ❌ Failed to initialize user asset directory:', error.message);
    return false;
  }
}

/**
 * Get README content for user asset directory
 * @returns {string} README content
 */
function getUserAssetReadme() {
  return `# User Video Assets

This directory contains custom assets for video generation.

## Directory Structure

\`\`\`
~/.harness/video/assets/
├── backgrounds/
│   └── backgrounds.json    # Custom background definitions
├── sounds/
│   └── sounds.json         # Custom sound effect definitions
├── fonts/
│   └── *.ttf, *.otf        # Custom fonts
└── images/
    └── *.png, *.jpg        # Custom images
\`\`\`

## Asset Priority

Assets in this directory override skill defaults:

1. **User assets** (~/.harness/video/assets/) - Highest priority
2. **Skill defaults** (skills/generate-video/assets/) - Fallback
3. **Built-in defaults** (hardcoded) - Last resort

## Customization

### Backgrounds

Copy and modify \`backgrounds.json\` from skill defaults:

\`\`\`bash
cp {skill}/assets/backgrounds/backgrounds.json ~/.harness/video/assets/backgrounds/
\`\`\`

Edit colors, gradients, and usage settings.

### Sounds

Copy and modify \`sounds.json\` from skill defaults:

\`\`\`bash
cp {skill}/assets/sounds/sounds.json ~/.harness/video/assets/sounds/
\`\`\`

Add your own audio files and update file paths.

### Fonts

Place custom font files in \`fonts/\` directory:

\`\`\`bash
cp MyFont-Bold.ttf ~/.harness/video/assets/fonts/
\`\`\`

Reference in scene configurations.

### Images

Place custom images (logos, icons) in \`images/\` directory:

\`\`\`bash
cp logo.png ~/.harness/video/assets/images/
\`\`\`

Reference in scene configurations.

## Example

\`\`\`json
// backgrounds.json
{
  "version": "1.0.0",
  "backgrounds": [
    {
      "id": "my-brand",
      "name": "My Brand",
      "type": "gradient",
      "colors": {
        "primary": "#your-color",
        "secondary": "#another-color"
      }
    }
  ]
}
\`\`\`

## Notes

- JSON files must be valid JSON
- Audio files should be MP3 or WAV format
- Image files should be PNG or JPG format
- Font files should be TTF or OTF format

For more information, see: skills/generate-video/references/asset-customization.md
`;
}

// CLI usage
if (require.main === module) {
  const command = process.argv[2];

  switch (command) {
    case 'backgrounds':
      console.log(JSON.stringify(loadBackgrounds(), null, 2));
      break;
    case 'sounds':
      console.log(JSON.stringify(loadSounds(), null, 2));
      break;
    case 'paths':
      console.log(JSON.stringify(getAssetPaths(), null, 2));
      break;
    case 'init':
      initUserAssetDir();
      break;
    case 'test':
      console.log('🧪 Testing asset loader...\n');
      loadBackgrounds();
      console.log('');
      loadSounds();
      console.log('');
      console.log('📂 Asset paths:');
      console.log(JSON.stringify(getAssetPaths(), null, 2));
      break;
    default:
      console.log(`
Asset Loader Utility

Usage:
  node load-assets.js backgrounds   # Load backgrounds configuration
  node load-assets.js sounds        # Load sounds configuration
  node load-assets.js paths         # Show asset search paths
  node load-assets.js init          # Initialize user asset directory
  node load-assets.js test          # Test all loading functions

Programmatic Usage:
  const { loadBackgrounds, loadSounds } = require('./load-assets.js');
  const backgrounds = loadBackgrounds();
  const sounds = loadSounds();
`);
  }
}

// Export functions
module.exports = {
  loadBackgrounds,
  loadSounds,
  loadAssetFile,
  updateManifest,
  getAssetPaths,
  initUserAssetDir
};
