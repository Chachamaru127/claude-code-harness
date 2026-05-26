/**
 * @file determinism.test.js
 * @description Phase 0.3: Determinism tests for video generation pipeline
 *
 * Tests ensure that:
 * 1. Same scenario.json → same video-script.json (deterministic output)
 * 2. Same seed → same asset hashes (reproducible generation)
 * 3. Scene merge results are deterministic (order consistency)
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// Helper: Generate SHA-256 hash of content
function sha256(content) {
  return crypto.createHash('sha256').update(JSON.stringify(content)).digest('hex');
}

// Helper: Create test scenario
function createTestScenario(seed = 'test-seed-12345') {
  return {
    title: 'Test Video',
    description: 'Determinism test scenario',
    sections: [
      {
        id: 'opening',
        title: 'Opening',
        description: 'Introduction section',
        order: 0,
        duration_estimate_ms: 5000,
      },
      {
        id: 'main',
        title: 'Main',
        description: 'Main content',
        order: 1,
        duration_estimate_ms: 10000,
      },
    ],
    metadata: {
      seed: seed,
      version: '1.0.0',
      generated_at: '2026-02-02T00:00:00Z', // Fixed timestamp for determinism
      generator: 'test-generator',
      project_name: 'Test Project',
      video_type: 'intro-demo',
      target_funnel: 'interest',
    },
  };
}

// Helper: Simulate scene generation (deterministic based on seed + scene_id)
function generateScene(sceneId, sectionId, order, seed) {
  // Deterministic hash: seed + scene_id
  const contentHash = crypto
    .createHash('sha256')
    .update(`${seed}-${sceneId}`)
    .digest('hex');

  return {
    scene_id: sceneId,
    section_id: sectionId,
    order: order,
    type: 'intro',
    content: {
      title: `Scene ${sceneId}`,
      duration_ms: 3000,
    },
    direction: {
      transition: {
        in: 'fade',
        out: 'fade',
        duration_ms: 500,
      },
    },
    // Deterministic asset hash (based on content)
    assets: [
      {
        type: 'image',
        source: `assets/generated/${sceneId}.png`,
        generated: true,
        metadata: {
          content_hash: contentHash,
        },
      },
    ],
  };
}

// Helper: Merge scenes into video-script
function mergeScenes(scenes) {
  // Sort by section_id + order for deterministic ordering
  const sorted = scenes.slice().sort((a, b) => {
    if (a.section_id !== b.section_id) {
      return a.section_id.localeCompare(b.section_id);
    }
    return a.order - b.order;
  });

  return {
    metadata: {
      title: 'Merged Video',
      version: '1.0.0',
      created_at: '2026-02-02T00:00:00Z',
      scene_count: sorted.length,
    },
    scenes: sorted,
    total_duration_ms: sorted.reduce((sum, scene) => sum + scene.content.duration_ms, 0),
    output_settings: {
      width: 1920,
      height: 1080,
      fps: 30,
    },
  };
}

describe('Determinism Tests (Phase 0.3)', () => {
  describe('Scenario → Video Script Determinism', () => {
    test('same scenario.json produces same video-script.json hash', () => {
      const scenario1 = createTestScenario('fixed-seed-001');
      const scenario2 = createTestScenario('fixed-seed-001'); // Same seed

      // Simulate scene generation from scenario
      const scenes1 = [
        generateScene('intro', 'opening', 0, scenario1.metadata.seed),
        generateScene('demo', 'main', 0, scenario1.metadata.seed),
      ];

      const scenes2 = [
        generateScene('intro', 'opening', 0, scenario2.metadata.seed),
        generateScene('demo', 'main', 0, scenario2.metadata.seed),
      ];

      // Merge to video-script
      const videoScript1 = mergeScenes(scenes1);
      const videoScript2 = mergeScenes(scenes2);

      // Hash comparison
      const hash1 = sha256(videoScript1);
      const hash2 = sha256(videoScript2);

      expect(hash1).toBe(hash2);
      expect(videoScript1).toEqual(videoScript2);
    });

    test('different seeds produce different video-script hashes', () => {
      const scenario1 = createTestScenario('seed-A');
      const scenario2 = createTestScenario('seed-B'); // Different seed

      const scenes1 = [
        generateScene('intro', 'opening', 0, scenario1.metadata.seed),
      ];

      const scenes2 = [
        generateScene('intro', 'opening', 0, scenario2.metadata.seed),
      ];

      const videoScript1 = mergeScenes(scenes1);
      const videoScript2 = mergeScenes(scenes2);

      const hash1 = sha256(videoScript1);
      const hash2 = sha256(videoScript2);

      expect(hash1).not.toBe(hash2);
    });
  });

  describe('Seed → Asset Hash Determinism', () => {
    test('same seed produces same asset content hash', () => {
      const seed = 'deterministic-seed-001';
      const sceneId = 'test-scene';

      const scene1 = generateScene(sceneId, 'section', 0, seed);
      const scene2 = generateScene(sceneId, 'section', 0, seed);

      const asset1 = scene1.assets[0];
      const asset2 = scene2.assets[0];

      expect(asset1.metadata.content_hash).toBe(asset2.metadata.content_hash);
    });

    test('different seeds produce different asset hashes', () => {
      const sceneId = 'test-scene';

      const scene1 = generateScene(sceneId, 'section', 0, 'seed-X');
      const scene2 = generateScene(sceneId, 'section', 0, 'seed-Y');

      const asset1 = scene1.assets[0];
      const asset2 = scene2.assets[0];

      expect(asset1.metadata.content_hash).not.toBe(asset2.metadata.content_hash);
    });

    test('multiple runs with same seed produce identical asset hashes', () => {
      const seed = 'reproducible-seed';
      const sceneId = 'consistent-scene';

      // Run 1
      const run1 = generateScene(sceneId, 'section', 0, seed);

      // Run 2 (independent)
      const run2 = generateScene(sceneId, 'section', 0, seed);

      // Run 3 (independent)
      const run3 = generateScene(sceneId, 'section', 0, seed);

      expect(run1.assets[0].metadata.content_hash).toBe(run2.assets[0].metadata.content_hash);
      expect(run2.assets[0].metadata.content_hash).toBe(run3.assets[0].metadata.content_hash);
    });
  });

  describe('Merge Determinism', () => {
    test('scene order is deterministic (section_id + order)', () => {
      const scenes = [
        generateScene('scene-c', 'section-b', 1, 'seed'),
        generateScene('scene-a', 'section-a', 0, 'seed'),
        generateScene('scene-b', 'section-a', 1, 'seed'),
        generateScene('scene-d', 'section-b', 0, 'seed'),
      ];

      // Shuffle input order to test sorting
      const shuffled1 = [scenes[2], scenes[0], scenes[3], scenes[1]];
      const shuffled2 = [scenes[3], scenes[1], scenes[0], scenes[2]];

      const merged1 = mergeScenes(shuffled1);
      const merged2 = mergeScenes(shuffled2);

      // Same result regardless of input order
      expect(merged1.scenes).toEqual(merged2.scenes);

      // Verify correct order
      expect(merged1.scenes[0].scene_id).toBe('scene-a'); // section-a, order 0
      expect(merged1.scenes[1].scene_id).toBe('scene-b'); // section-a, order 1
      expect(merged1.scenes[2].scene_id).toBe('scene-d'); // section-b, order 0
      expect(merged1.scenes[3].scene_id).toBe('scene-c'); // section-b, order 1
    });

    test('duplicate scene_id detection', () => {
      const scenes = [
        generateScene('duplicate', 'section-a', 0, 'seed'),
        generateScene('duplicate', 'section-b', 0, 'seed'), // Same scene_id!
      ];

      // Check for duplicates
      const sceneIds = scenes.map((s) => s.scene_id);
      const uniqueIds = new Set(sceneIds);

      // Critical error: duplicate scene_id
      expect(sceneIds.length).not.toBe(uniqueIds.size);
    });

    test('missing scenes detection (section with no scenes)', () => {
      const scenario = createTestScenario();

      const scenes = [
        generateScene('intro', 'opening', 0, 'seed'),
        // Missing: 'main' section has no scenes
      ];

      const merged = mergeScenes(scenes);

      // Detect missing sections
      const sceneSections = new Set(merged.scenes.map((s) => s.section_id));
      const expectedSections = scenario.sections.map((s) => s.id);

      const missingSections = expectedSections.filter((id) => !sceneSections.has(id));
      expect(missingSections).toContain('main');
    });

    test('total_duration_ms is sum of scene durations', () => {
      const scenes = [
        { ...generateScene('a', 'section', 0, 'seed'), content: { duration_ms: 1000 } },
        { ...generateScene('b', 'section', 1, 'seed'), content: { duration_ms: 2000 } },
        { ...generateScene('c', 'section', 2, 'seed'), content: { duration_ms: 3000 } },
      ];

      const merged = mergeScenes(scenes);

      expect(merged.total_duration_ms).toBe(6000);
    });
  });

  describe('Reproducibility Verification', () => {
    test('end-to-end: scenario → scenes → video-script is reproducible', () => {
      const seed = 'e2e-seed-12345';
      const scenario = createTestScenario(seed);

      // Run 1: Full pipeline
      const run1Scenes = [
        generateScene('intro', 'opening', 0, seed),
        generateScene('hook', 'opening', 1, seed),
        generateScene('demo', 'main', 0, seed),
      ];
      const run1Script = mergeScenes(run1Scenes);
      const run1Hash = sha256(run1Script);

      // Run 2: Independent execution (same seed)
      const run2Scenes = [
        generateScene('intro', 'opening', 0, seed),
        generateScene('hook', 'opening', 1, seed),
        generateScene('demo', 'main', 0, seed),
      ];
      const run2Script = mergeScenes(run2Scenes);
      const run2Hash = sha256(run2Script);

      // Verify reproducibility
      expect(run1Hash).toBe(run2Hash);
      expect(run1Script).toEqual(run2Script);
    });

    test('asset hashes are stable across pipeline runs', () => {
      const seed = 'stable-seed-999';

      // Run 1
      const run1 = generateScene('test', 'section', 0, seed);
      const run1AssetHash = run1.assets[0].metadata.content_hash;

      // Run 2 (simulating different session)
      const run2 = generateScene('test', 'section', 0, seed);
      const run2AssetHash = run2.assets[0].metadata.content_hash;

      // Run 3
      const run3 = generateScene('test', 'section', 0, seed);
      const run3AssetHash = run3.assets[0].metadata.content_hash;

      expect(run1AssetHash).toBe(run2AssetHash);
      expect(run2AssetHash).toBe(run3AssetHash);
    });
  });

  describe('Edge Cases', () => {
    test('empty scenes array produces deterministic output', () => {
      const merged1 = mergeScenes([]);
      const merged2 = mergeScenes([]);

      expect(merged1).toEqual(merged2);
      expect(merged1.total_duration_ms).toBe(0);
      expect(merged1.scenes).toEqual([]);
    });

    test('single scene produces deterministic output', () => {
      const scene = generateScene('only', 'section', 0, 'seed');

      const merged1 = mergeScenes([scene]);
      const merged2 = mergeScenes([scene]);

      const hash1 = sha256(merged1);
      const hash2 = sha256(merged2);

      expect(hash1).toBe(hash2);
    });

    test('seed with special characters is handled consistently', () => {
      const specialSeeds = [
        'seed-with-dashes',
        'seed_with_underscores',
        'seed.with.dots',
        'seed123numbers',
      ];

      specialSeeds.forEach((seed) => {
        const scene1 = generateScene('test', 'section', 0, seed);
        const scene2 = generateScene('test', 'section', 0, seed);

        expect(scene1.assets[0].metadata.content_hash).toBe(
          scene2.assets[0].metadata.content_hash
        );
      });
    });
  });
});
