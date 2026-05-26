/**
 * @file merge-e2e.test.js
 * @description Task 11.6.3: E2E tests for merge-scenes.js
 *
 * Validates:
 * - End-to-end determinism (same input → same output)
 * - Real file system operations
 * - Multiple execution rounds produce identical results
 *
 * Note: Uses execSync with controlled inputs in test environment (safe)
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { execSync } = require('child_process'); // Safe in tests with controlled inputs

const MERGE_SCRIPT = path.join(__dirname, '../../scripts/merge-scenes.js');

/**
 * Helper: Generate SHA-256 hash of file content
 */
function hashFile(filePath) {
  const content = fs.readFileSync(filePath, 'utf-8');
  return crypto.createHash('sha256').update(content).digest('hex');
}

/**
 * Helper: Generate SHA-256 hash of JSON object
 */
function hashJson(obj) {
  return crypto.createHash('sha256').update(JSON.stringify(obj)).digest('hex');
}

describe('E2E: merge-scenes.js determinism', () => {
  let tempDir;

  beforeEach(() => {
    tempDir = fs.mkdtempSync(path.join('/tmp', 'merge-e2e-'));
  });

  afterEach(() => {
    if (tempDir && fs.existsSync(tempDir)) {
      fs.rmSync(tempDir, { recursive: true });
    }
  });

  /**
   * Helper: Create test scenario and scenes
   */
  function setupTestData() {
    // Create scenario.json
    const scenario = {
      id: 'e2e-test-scenario',
      title: 'E2E Test Video',
      description: 'End-to-end determinism test',
      metadata: {
        version: '1.0.0',
        generated_at: '2026-02-02T00:00:00Z',
        video_type: 'custom'
      },
      sections: [
        {
          id: 'opening',
          title: 'Opening',
          description: 'Opening section',
          order: 0
        },
        {
          id: 'main',
          title: 'Main',
          description: 'Main content',
          order: 1
        },
        {
          id: 'closing',
          title: 'Closing',
          description: 'Closing section',
          order: 2
        }
      ]
    };

    fs.writeFileSync(
      path.join(tempDir, 'scenario.json'),
      JSON.stringify(scenario, null, 2)
    );

    // Create scenes directory
    const scenesDir = path.join(tempDir, 'scenes');
    fs.mkdirSync(scenesDir);

    // Create scene files
    const scenes = [
      { scene_id: 'intro-1', section_id: 'opening', order: 0 },
      { scene_id: 'intro-2', section_id: 'opening', order: 1 },
      { scene_id: 'hook', section_id: 'opening', order: 2 },
      { scene_id: 'demo-1', section_id: 'main', order: 0 },
      { scene_id: 'demo-2', section_id: 'main', order: 1 },
      { scene_id: 'demo-3', section_id: 'main', order: 1 }, // Duplicate order (tiebreaker test)
      { scene_id: 'cta', section_id: 'closing', order: 0 },
      { scene_id: 'outro', section_id: 'closing', order: 1 }
    ];

    scenes.forEach(sceneData => {
      const scene = {
        scene_id: sceneData.scene_id,
        section_id: sceneData.section_id,
        order: sceneData.order,
        type: 'custom',
        content: {
          title: `Scene ${sceneData.scene_id}`,
          duration_ms: 3000
        },
        direction: {
          transition: {
            in: 'fade',
            out: 'fade',
            duration_ms: 500
          }
        }
      };

      fs.writeFileSync(
        path.join(scenesDir, `${sceneData.scene_id}.json`),
        JSON.stringify(scene, null, 2)
      );
    });
  }

  /**
   * Helper: Run merge-scenes.js
   */
  function runMerge() {
    try {
      execSync(`node ${MERGE_SCRIPT} ${tempDir}`, {
        encoding: 'utf-8',
        stdio: 'pipe'
      });
      return true;
    } catch (error) {
      console.error('Merge failed:', error.message);
      return false;
    }
  }

  /**
   * Helper: Load video-script.json
   */
  function loadVideoScript() {
    const scriptPath = path.join(tempDir, 'video-script.json');
    if (!fs.existsSync(scriptPath)) {
      return null;
    }
    return JSON.parse(fs.readFileSync(scriptPath, 'utf-8'));
  }

  describe('Same input → Same output (deterministic scenes)', () => {
    it('should produce identical scene order across multiple runs', () => {
      setupTestData();

      // Run 1
      expect(runMerge()).toBe(true);
      const script1 = loadVideoScript();

      // Delete output
      fs.unlinkSync(path.join(tempDir, 'video-script.json'));

      // Run 2
      expect(runMerge()).toBe(true);
      const script2 = loadVideoScript();

      // Delete output
      fs.unlinkSync(path.join(tempDir, 'video-script.json'));

      // Run 3
      expect(runMerge()).toBe(true);
      const script3 = loadVideoScript();

      // Scene order and content should be identical (excluding created_at)
      const scenes1 = script1.scenes.map(s => s.scene_id);
      const scenes2 = script2.scenes.map(s => s.scene_id);
      const scenes3 = script3.scenes.map(s => s.scene_id);

      expect(scenes1).toEqual(scenes2);
      expect(scenes2).toEqual(scenes3);

      // Scene content should be identical
      expect(script1.scenes).toEqual(script2.scenes);
      expect(script2.scenes).toEqual(script3.scenes);

      // Total duration should be consistent
      expect(script1.total_duration_ms).toBe(script2.total_duration_ms);
      expect(script2.total_duration_ms).toBe(script3.total_duration_ms);
    });

    it('should produce consistent structure (metadata may have timestamps)', () => {
      setupTestData();

      // Run 1
      expect(runMerge()).toBe(true);
      const script1 = loadVideoScript();

      // Delete output
      fs.unlinkSync(path.join(tempDir, 'video-script.json'));

      // Run 2
      expect(runMerge()).toBe(true);
      const script2 = loadVideoScript();

      // Structure should be consistent
      expect(script1).toHaveProperty('metadata');
      expect(script1).toHaveProperty('scenes');
      expect(script1).toHaveProperty('total_duration_ms');
      expect(script1).toHaveProperty('output_settings');

      expect(script2).toHaveProperty('metadata');
      expect(script2).toHaveProperty('scenes');
      expect(script2).toHaveProperty('total_duration_ms');
      expect(script2).toHaveProperty('output_settings');

      // Metadata fields (except created_at) should match
      expect(script1.metadata.title).toBe(script2.metadata.title);
      expect(script1.metadata.version).toBe(script2.metadata.version);
      expect(script1.metadata.scenario_id).toBe(script2.metadata.scenario_id);

      // Output settings should be identical
      expect(script1.output_settings).toEqual(script2.output_settings);
    });
  });

  describe('Scene order determinism', () => {
    it('should consistently order scenes with tiebreaker', () => {
      setupTestData();

      // Run merge multiple times
      const runs = [];
      for (let i = 0; i < 5; i++) {
        expect(runMerge()).toBe(true);
        const script = loadVideoScript();
        runs.push(script.scenes.map(s => s.scene_id));

        // Delete output for next run
        fs.unlinkSync(path.join(tempDir, 'video-script.json'));
      }

      // All runs should produce the same scene order
      for (let i = 1; i < runs.length; i++) {
        expect(runs[i]).toEqual(runs[0]);
      }

      // Verify correct order (with tiebreaker applied)
      const expectedOrder = [
        'intro-1',  // opening, order 0
        'intro-2',  // opening, order 1
        'hook',     // opening, order 2
        'demo-1',   // main, order 0
        'demo-2',   // main, order 1 (demo-2 < demo-3 by tiebreaker)
        'demo-3',   // main, order 1
        'cta',      // closing, order 0
        'outro'     // closing, order 1
      ];

      expect(runs[0]).toEqual(expectedOrder);
    });
  });

  describe('Metadata consistency', () => {
    it('should generate consistent metadata (excluding timestamps)', () => {
      setupTestData();

      // Run 1
      expect(runMerge()).toBe(true);
      const script1 = loadVideoScript();

      // Delete output
      fs.unlinkSync(path.join(tempDir, 'video-script.json'));

      // Run 2
      expect(runMerge()).toBe(true);
      const script2 = loadVideoScript();

      // Metadata should be consistent (except created_at)
      expect(script1.metadata.title).toBe(script2.metadata.title);
      expect(script1.metadata.version).toBe(script2.metadata.version);
      expect(script1.metadata.scenario_id).toBe(script2.metadata.scenario_id);

      // Output settings should be identical
      expect(script1.output_settings).toEqual(script2.output_settings);

      // Total duration should be identical
      expect(script1.total_duration_ms).toBe(script2.total_duration_ms);
    });
  });

  describe('Real-world scenario simulation', () => {
    it('should handle complex scenario with 20+ scenes', () => {
      // Create larger scenario
      const scenario = {
        id: 'large-test',
        title: 'Large Test Video',
        description: 'Testing with many scenes',
        metadata: {
          version: '1.0.0',
          generated_at: '2026-02-02T00:00:00Z',
          video_type: 'custom'
        },
        sections: [
          { id: 'section-1', title: 'Section 1', description: 'Section 1', order: 0 },
          { id: 'section-2', title: 'Section 2', description: 'Section 2', order: 1 },
          { id: 'section-3', title: 'Section 3', description: 'Section 3', order: 2 },
          { id: 'section-4', title: 'Section 4', description: 'Section 4', order: 3 }
        ]
      };

      fs.writeFileSync(
        path.join(tempDir, 'scenario.json'),
        JSON.stringify(scenario, null, 2)
      );

      const scenesDir = path.join(tempDir, 'scenes');
      fs.mkdirSync(scenesDir);

      // Create 24 scenes (6 per section)
      for (let section = 1; section <= 4; section++) {
        for (let scene = 1; scene <= 6; scene++) {
          const sceneData = {
            scene_id: `s${section}-scene-${scene}`,
            section_id: `section-${section}`,
            order: scene,
            type: 'custom',
            content: {
              duration_ms: 2000
            }
          };

          fs.writeFileSync(
            path.join(scenesDir, `${sceneData.scene_id}.json`),
            JSON.stringify(sceneData, null, 2)
          );
        }
      }

      // Run merge twice
      expect(runMerge()).toBe(true);
      const script1 = loadVideoScript();

      fs.unlinkSync(path.join(tempDir, 'video-script.json'));

      expect(runMerge()).toBe(true);
      const script2 = loadVideoScript();

      // Should produce identical results
      expect(script1.scenes.length).toBe(24);
      expect(script2.scenes.length).toBe(24);

      const order1 = script1.scenes.map(s => s.scene_id);
      const order2 = script2.scenes.map(s => s.scene_id);

      expect(order1).toEqual(order2);
    });
  });

  describe('Error recovery determinism', () => {
    it('should produce consistent warnings for duplicate orders', () => {
      setupTestData();

      // Run merge multiple times and capture output
      const outputs = [];
      for (let i = 0; i < 3; i++) {
        try {
          const output = execSync(`node ${MERGE_SCRIPT} ${tempDir}`, {
            encoding: 'utf-8',
            stdio: 'pipe'
          });
          outputs.push(output);
        } catch (error) {
          outputs.push(error.stdout || '');
        }

        // Delete output for next run
        if (fs.existsSync(path.join(tempDir, 'video-script.json'))) {
          fs.unlinkSync(path.join(tempDir, 'video-script.json'));
        }
      }

      // All outputs should mention duplicate orders
      outputs.forEach(output => {
        expect(output).toMatch(/WARNING: Duplicate orders detected/);
        expect(output).toMatch(/demo-2/);
        expect(output).toMatch(/demo-3/);
      });
    });
  });

  describe('File system operations determinism', () => {
    it('should produce consistent output regardless of file creation order', () => {
      // Create scenario
      const scenario = {
        id: 'order-test',
        title: 'Order Test',
        description: 'Testing file order independence',
        metadata: {
          version: '1.0.0',
          generated_at: '2026-02-02T00:00:00Z',
          video_type: 'custom'
        },
        sections: [
          { id: 'section', title: 'Section', description: 'Test section', order: 0 }
        ]
      };

      fs.writeFileSync(
        path.join(tempDir, 'scenario.json'),
        JSON.stringify(scenario, null, 2)
      );

      const scenesDir = path.join(tempDir, 'scenes');
      fs.mkdirSync(scenesDir);

      // Create scenes in reverse alphabetical order
      const sceneIds = ['scene-c', 'scene-b', 'scene-a'];
      sceneIds.forEach((sceneId, index) => {
        const scene = {
          scene_id: sceneId,
          section_id: 'section',
          order: 1, // Same order for all
          type: 'custom',
          content: { duration_ms: 1000 }
        };

        fs.writeFileSync(
          path.join(scenesDir, `${sceneId}.json`),
          JSON.stringify(scene, null, 2)
        );

        // Add small delay to ensure different mtime
        if (index < sceneIds.length - 1) {
          const start = Date.now();
          while (Date.now() - start < 10) {
            // Busy wait
          }
        }
      });

      // Run merge
      expect(runMerge()).toBe(true);
      const script = loadVideoScript();

      // Should be sorted by scene_id (lexicographic), not file creation order
      const order = script.scenes.map(s => s.scene_id);
      expect(order).toEqual(['scene-a', 'scene-b', 'scene-c']);
    });
  });
});
