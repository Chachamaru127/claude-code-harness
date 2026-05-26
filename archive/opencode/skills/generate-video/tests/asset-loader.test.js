/**
 * Asset Loader Tests
 *
 * Tests for scripts/load-assets.js functionality
 */

const {
  loadBackgrounds,
  loadSounds,
  loadAssetFile,
  updateManifest,
  getAssetPaths,
  initUserAssetDir
} = require('../scripts/load-assets.js');
const fs = require('fs');
const path = require('path');
const os = require('os');

// Test data paths
const SKILL_ROOT = path.join(__dirname, '..');
const ASSETS_DIR = path.join(SKILL_ROOT, 'assets');
const TEST_USER_DIR = path.join(os.tmpdir(), 'test-harness-assets-' + Date.now());

describe('Asset Loader', () => {
  // Mock USER_ASSETS_DIR for testing
  beforeAll(() => {
    // Create test user asset directory
    if (!fs.existsSync(TEST_USER_DIR)) {
      fs.mkdirSync(TEST_USER_DIR, { recursive: true });
    }
  });

  afterAll(() => {
    // Clean up test directory
    if (fs.existsSync(TEST_USER_DIR)) {
      fs.rmSync(TEST_USER_DIR, { recursive: true, force: true });
    }
  });

  describe('loadBackgrounds()', () => {
    test('loads skill default backgrounds', () => {
      const backgrounds = loadBackgrounds();

      expect(backgrounds).toBeDefined();
      expect(backgrounds.version).toBe('1.0.0');
      expect(backgrounds.backgrounds).toBeInstanceOf(Array);
      expect(backgrounds.backgrounds.length).toBeGreaterThan(0);
    });

    test('contains all 5 background types', () => {
      const backgrounds = loadBackgrounds();
      const ids = backgrounds.backgrounds.map(bg => bg.id);

      expect(ids).toContain('neutral');
      expect(ids).toContain('highlight');
      expect(ids).toContain('dramatic');
      expect(ids).toContain('tech');
      expect(ids).toContain('warm');
    });

    test('each background has required fields', () => {
      const backgrounds = loadBackgrounds();

      backgrounds.backgrounds.forEach(bg => {
        expect(bg.id).toBeDefined();
        expect(bg.name).toBeDefined();
        expect(bg.description).toBeDefined();
        expect(bg.type).toBeDefined();
        expect(bg.colors).toBeDefined();
        expect(bg.colors.primary).toBeDefined();
        expect(bg.colors.secondary).toBeDefined();
        expect(bg.usage).toBeDefined();
        expect(bg.usage.scenes).toBeInstanceOf(Array);
      });
    });

    test('neutral background has correct properties', () => {
      const backgrounds = loadBackgrounds();
      const neutral = backgrounds.backgrounds.find(bg => bg.id === 'neutral');

      expect(neutral).toBeDefined();
      expect(neutral.type).toBe('gradient');
      expect(neutral.colors.primary).toMatch(/^#[0-9a-fA-F]{6}$/);
      expect(neutral.gradient).toBeDefined();
      expect(neutral.gradient.type).toBe('linear');
      expect(neutral.gradient.stops).toBeInstanceOf(Array);
    });

    test('tech background has pattern definition', () => {
      const backgrounds = loadBackgrounds();
      const tech = backgrounds.backgrounds.find(bg => bg.id === 'tech');

      expect(tech).toBeDefined();
      expect(tech.type).toBe('pattern');
      expect(tech.pattern).toBeDefined();
      expect(tech.pattern.type).toBe('grid');
      expect(tech.pattern.size).toBeGreaterThan(0);
    });
  });

  describe('loadSounds()', () => {
    test('loads skill default sounds', () => {
      const sounds = loadSounds();

      expect(sounds).toBeDefined();
      expect(sounds.version).toBe('1.0.0');
      expect(sounds.sounds).toBeInstanceOf(Array);
      expect(sounds.sounds.length).toBeGreaterThan(0);
    });

    test('contains all 4 sound types', () => {
      const sounds = loadSounds();
      const ids = sounds.sounds.map(s => s.id);

      expect(ids).toContain('impact');
      expect(ids).toContain('pop');
      expect(ids).toContain('transition');
      expect(ids).toContain('subtle');
    });

    test('each sound has required fields', () => {
      const sounds = loadSounds();

      sounds.sounds.forEach(sound => {
        expect(sound.id).toBeDefined();
        expect(sound.name).toBeDefined();
        expect(sound.description).toBeDefined();
        expect(sound.type).toBe('effect');
        expect(sound.category).toBeDefined();
        expect(sound.emphasis_level).toBeDefined();
        expect(sound.volume).toBeDefined();
        expect(sound.volume.default).toBeGreaterThan(0);
        expect(sound.volume.with_narration).toBeGreaterThan(0);
        expect(sound.usage).toBeDefined();
      });
    });

    test('emphasis levels are correctly assigned', () => {
      const sounds = loadSounds();
      const impact = sounds.sounds.find(s => s.id === 'impact');
      const pop = sounds.sounds.find(s => s.id === 'pop');
      const subtle = sounds.sounds.find(s => s.id === 'subtle');

      expect(impact.emphasis_level).toBe('high');
      expect(pop.emphasis_level).toBe('medium');
      expect(subtle.emphasis_level).toBe('low');
    });

    test('volume with narration is lower than default', () => {
      const sounds = loadSounds();

      sounds.sounds.forEach(sound => {
        expect(sound.volume.with_narration).toBeLessThan(sound.volume.default);
      });
    });
  });

  describe('loadAssetFile()', () => {
    test('returns null for non-existent file', () => {
      const result = loadAssetFile('backgrounds', 'nonexistent.json');
      expect(result).toBeNull();
    });

    test('finds skill default backgrounds.json', () => {
      const result = loadAssetFile('backgrounds', 'backgrounds.json');
      expect(result).toBeDefined();
      expect(result).toContain('backgrounds.json');
      expect(fs.existsSync(result)).toBe(true);
    });

    test('finds skill default sounds.json', () => {
      const result = loadAssetFile('sounds', 'sounds.json');
      expect(result).toBeDefined();
      expect(result).toContain('sounds.json');
      expect(fs.existsSync(result)).toBe(true);
    });
  });

  describe('updateManifest()', () => {
    test('creates new manifest if not exists', () => {
      const manifestPath = path.join(TEST_USER_DIR, 'manifest.json');
      const asset = {
        id: 'test-asset',
        path: 'test.png',
        type: 'image',
        hash: 'abc123',
        size: 1000
      };

      const success = updateManifest(manifestPath, asset);
      expect(success).toBe(true);
      expect(fs.existsSync(manifestPath)).toBe(true);

      const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf-8'));
      expect(manifest.version).toBe('1.0.0');
      expect(manifest.assets).toBeInstanceOf(Array);
      expect(manifest.assets.length).toBe(1);
      expect(manifest.assets[0].id).toBe('test-asset');
    });

    test('appends to existing manifest', () => {
      const manifestPath = path.join(TEST_USER_DIR, 'manifest2.json');
      const asset1 = { id: 'asset1', path: 'a.png', type: 'image', hash: 'aaa', size: 100 };
      const asset2 = { id: 'asset2', path: 'b.png', type: 'image', hash: 'bbb', size: 200 };

      updateManifest(manifestPath, asset1);
      updateManifest(manifestPath, asset2);

      const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf-8'));
      expect(manifest.assets.length).toBe(2);
      expect(manifest.assets[0].id).toBe('asset1');
      expect(manifest.assets[1].id).toBe('asset2');
    });

    test('updates generated_at timestamp', () => {
      const manifestPath = path.join(TEST_USER_DIR, 'manifest3.json');
      const asset = { id: 'test', path: 'test.png', type: 'image', hash: 'xyz', size: 500 };

      updateManifest(manifestPath, asset);
      const manifest1 = JSON.parse(fs.readFileSync(manifestPath, 'utf-8'));
      const timestamp1 = manifest1.generated_at;

      // Wait a bit
      setTimeout(() => {
        updateManifest(manifestPath, { id: 'test2', path: 'test2.png', type: 'image', hash: 'xyz2', size: 600 });
        const manifest2 = JSON.parse(fs.readFileSync(manifestPath, 'utf-8'));
        const timestamp2 = manifest2.generated_at;

        expect(timestamp2).not.toBe(timestamp1);
      }, 100);
    });
  });

  describe('getAssetPaths()', () => {
    test('returns asset search paths', () => {
      const paths = getAssetPaths();

      expect(paths).toBeDefined();
      expect(paths.user).toBeDefined();
      expect(paths.skill).toBeDefined();
      expect(paths.backgrounds).toBeDefined();
      expect(paths.backgrounds.user).toBeDefined();
      expect(paths.backgrounds.skill).toBeDefined();
      expect(paths.sounds).toBeDefined();
      expect(paths.sounds.user).toBeDefined();
      expect(paths.sounds.skill).toBeDefined();
    });

    test('skill path points to correct directory', () => {
      const paths = getAssetPaths();
      expect(paths.skill).toContain('generate-video/assets');
      expect(fs.existsSync(paths.skill)).toBe(true);
    });
  });

  describe('Integration: Background structure', () => {
    test('all backgrounds have valid color hex codes', () => {
      const backgrounds = loadBackgrounds();
      const hexPattern = /^#[0-9a-fA-F]{6}$/;

      backgrounds.backgrounds.forEach(bg => {
        expect(bg.colors.primary).toMatch(hexPattern);
        expect(bg.colors.secondary).toMatch(hexPattern);
        if (bg.colors.accent) {
          expect(bg.colors.accent).toMatch(hexPattern);
        }
        if (bg.colors.grid) {
          expect(bg.colors.grid).toMatch(hexPattern);
        }
      });
    });

    test('gradient stops are in ascending order', () => {
      const backgrounds = loadBackgrounds();

      backgrounds.backgrounds.forEach(bg => {
        if (bg.gradient && bg.gradient.stops) {
          for (let i = 1; i < bg.gradient.stops.length; i++) {
            expect(bg.gradient.stops[i].position).toBeGreaterThanOrEqual(
              bg.gradient.stops[i - 1].position
            );
          }
        }
      });
    });

    test('usage.scenes is not empty', () => {
      const backgrounds = loadBackgrounds();

      backgrounds.backgrounds.forEach(bg => {
        expect(bg.usage.scenes).toBeDefined();
        expect(bg.usage.scenes.length).toBeGreaterThan(0);
      });
    });
  });

  describe('Integration: Sound structure', () => {
    test('volume ranges are valid', () => {
      const sounds = loadSounds();

      sounds.sounds.forEach(sound => {
        expect(sound.volume.default).toBeGreaterThanOrEqual(0);
        expect(sound.volume.default).toBeLessThanOrEqual(1);
        expect(sound.volume.with_narration).toBeGreaterThanOrEqual(0);
        expect(sound.volume.with_narration).toBeLessThanOrEqual(1);
        expect(sound.volume.with_bgm).toBeGreaterThanOrEqual(0);
        expect(sound.volume.with_bgm).toBeLessThanOrEqual(1);
      });
    });

    test('timing offsets are reasonable', () => {
      const sounds = loadSounds();

      sounds.sounds.forEach(sound => {
        if (sound.timing) {
          expect(sound.timing.offset_before_visual).toBeGreaterThanOrEqual(-0.5);
          expect(sound.timing.offset_before_visual).toBeLessThanOrEqual(0.5);
        }
      });
    });

    test('expected duration is reasonable', () => {
      const sounds = loadSounds();

      sounds.sounds.forEach(sound => {
        if (sound.file && sound.file.expected_duration) {
          expect(sound.file.expected_duration).toBeGreaterThan(0);
          expect(sound.file.expected_duration).toBeLessThan(5); // Max 5 seconds
        }
      });
    });
  });

  describe('Metadata', () => {
    test('backgrounds.json has metadata', () => {
      const backgrounds = loadBackgrounds();
      expect(backgrounds.metadata).toBeDefined();
      expect(backgrounds.metadata.created_at).toBeDefined();
      expect(backgrounds.metadata.author).toBeDefined();
    });

    test('sounds.json has metadata', () => {
      const sounds = loadSounds();
      expect(sounds.metadata).toBeDefined();
      expect(sounds.metadata.created_at).toBeDefined();
      expect(sounds.metadata.author).toBeDefined();
    });

    test('sounds.json has guidelines', () => {
      const sounds = loadSounds();
      expect(sounds.guidelines).toBeDefined();
      expect(sounds.guidelines.frequency).toBeDefined();
      expect(sounds.guidelines.combinations).toBeDefined();
    });

    test('sounds.json has fallback configuration', () => {
      const sounds = loadSounds();
      expect(sounds.fallback).toBeDefined();
      expect(sounds.fallback.if_file_missing).toBeDefined();
      expect(sounds.fallback.placeholder_sources).toBeInstanceOf(Array);
    });
  });
});
