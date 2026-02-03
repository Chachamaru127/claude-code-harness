/**
 * Tests for merge-scenes.js
 *
 * Validates:
 * - Deterministic sorting (tiebreaker by scene_id)
 * - Duplicate order detection (warning)
 * - Unknown section detection (critical error)
 * - Unit tests for sortScenes function (Task 11.6)
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process'); // Note: Safe in tests with controlled inputs

const MERGE_SCRIPT = path.join(__dirname, '../scripts/merge-scenes.js');
const { sortScenes } = require(MERGE_SCRIPT);

describe('merge-scenes.js', () => {
  let tempDir;

  beforeEach(() => {
    tempDir = fs.mkdtempSync(path.join('/tmp', 'merge-test-'));
  });

  afterEach(() => {
    if (tempDir && fs.existsSync(tempDir)) {
      fs.rmSync(tempDir, { recursive: true });
    }
  });

  /**
   * Helper: Create scenario.json
   */
  function createScenario(sections) {
    const scenarioPath = path.join(tempDir, 'scenario.json');
    const scenario = {
      id: 'test-scenario',
      title: 'Test Scenario',
      description: 'Test scenario for merge-scenes tests',
      metadata: {
        version: '1.0.0',
        generated_at: new Date().toISOString(),
        video_type: 'custom',
        generator: 'merge-scenes-test'
      },
      sections: sections.map((s, i) => ({
        id: s.id,
        title: s.title || s.id,
        description: s.description || `Test section ${s.id}`,
        order: s.order !== undefined ? s.order : i
      }))
    };
    fs.writeFileSync(scenarioPath, JSON.stringify(scenario, null, 2));
  }

  /**
   * Helper: Create scene file
   */
  function createScene(sceneData) {
    const scenesDir = path.join(tempDir, 'scenes');
    if (!fs.existsSync(scenesDir)) {
      fs.mkdirSync(scenesDir);
    }

    const scene = {
      scene_id: sceneData.scene_id,
      section_id: sceneData.section_id,
      order: sceneData.order,
      type: sceneData.type || 'custom',
      content: {
        duration_ms: sceneData.duration_ms || 1000
      }
    };

    const filename = `${sceneData.scene_id}.json`;
    fs.writeFileSync(
      path.join(scenesDir, filename),
      JSON.stringify(scene, null, 2)
    );
  }

  /**
   * Helper: Run merge-scenes.js
   * Note: execSync is safe here - controlled inputs in test environment
   */
  function runMerge() {
    try {
      const output = execSync(`node ${MERGE_SCRIPT} ${tempDir}`, {
        encoding: 'utf-8',
        stdio: 'pipe'
      });
      return { success: true, output };
    } catch (error) {
      // Combine stdout and stderr for error cases
      const combinedOutput = (error.stdout || '') + (error.stderr || '');
      return { success: false, output: combinedOutput };
    }
  }

  /**
   * Helper: Load generated video-script.json
   */
  function loadVideoScript() {
    const scriptPath = path.join(tempDir, 'video-script.json');
    if (!fs.existsSync(scriptPath)) {
      return null;
    }
    return JSON.parse(fs.readFileSync(scriptPath, 'utf-8'));
  }

  describe('11.3.1 Deterministic tiebreaker', () => {
    it('should sort by scene_id (lexicographic) when section_id and order are identical', () => {
      // Arrange: Create scenario with one section
      createScenario([{ id: 'intro', order: 0 }]);

      // Create 3 scenes with same section_id and order (but different scene_id)
      createScene({ scene_id: 'scene-c', section_id: 'intro', order: 1 });
      createScene({ scene_id: 'scene-a', section_id: 'intro', order: 1 });
      createScene({ scene_id: 'scene-b', section_id: 'intro', order: 1 });

      // Act: Run merge
      const result = runMerge();

      // Assert: Should succeed with warning
      expect(result.success).toBe(true);
      expect(result.output).toMatch(/WARNING: Duplicate orders detected/);

      // Check order: scene-a, scene-b, scene-c (lexicographic)
      const videoScript = loadVideoScript();
      expect(videoScript).not.toBeNull();
      expect(videoScript.scenes.length).toBe(3);
      expect(videoScript.scenes[0].scene_id).toBe('scene-a');
      expect(videoScript.scenes[1].scene_id).toBe('scene-b');
      expect(videoScript.scenes[2].scene_id).toBe('scene-c');
    });

    it('should be deterministic across multiple runs', () => {
      // Arrange
      createScenario([{ id: 'intro', order: 0 }]);
      createScene({ scene_id: 'z-last', section_id: 'intro', order: 1 });
      createScene({ scene_id: 'a-first', section_id: 'intro', order: 1 });
      createScene({ scene_id: 'm-middle', section_id: 'intro', order: 1 });

      // Act: Run merge twice
      const result1 = runMerge();
      const script1 = loadVideoScript();

      // Delete video-script.json
      fs.unlinkSync(path.join(tempDir, 'video-script.json'));

      const result2 = runMerge();
      const script2 = loadVideoScript();

      // Assert: Both runs produce identical order
      expect(result1.success).toBe(true);
      expect(result2.success).toBe(true);

      const order1 = script1.scenes.map(s => s.scene_id);
      const order2 = script2.scenes.map(s => s.scene_id);

      expect(order1).toEqual(order2);
      expect(order1).toEqual(['a-first', 'm-middle', 'z-last']);
    });
  });

  describe('11.3.2 Duplicate order detection', () => {
    it('should warn (but not fail) when duplicate orders exist', () => {
      // Arrange
      createScenario([{ id: 'intro', order: 0 }]);
      createScene({ scene_id: 'scene-1', section_id: 'intro', order: 1 });
      createScene({ scene_id: 'scene-2', section_id: 'intro', order: 1 });

      // Act
      const result = runMerge();

      // Assert: Should succeed with warning
      expect(result.success).toBe(true);
      expect(result.output).toMatch(/⚠️.*WARNING: Duplicate orders detected/);
      expect(result.output).toMatch(/section_id: intro, order: 1/);
      expect(result.output).toMatch(/scene-1/);
      expect(result.output).toMatch(/scene-2/);
    });

    it('should not warn when all orders are unique', () => {
      // Arrange
      createScenario([{ id: 'intro', order: 0 }]);
      createScene({ scene_id: 'scene-1', section_id: 'intro', order: 1 });
      createScene({ scene_id: 'scene-2', section_id: 'intro', order: 2 });

      // Act
      const result = runMerge();

      // Assert: No warning
      expect(result.success).toBe(true);
      expect(result.output).toMatch(/✅ No duplicate orders detected/);
      expect(result.output).not.toMatch(/WARNING: Duplicate orders/);
    });

    it('should detect duplicates across multiple sections independently', () => {
      // Arrange
      createScenario([
        { id: 'intro', order: 0 },
        { id: 'main', order: 1 }
      ]);

      // intro has duplicate order 1
      createScene({ scene_id: 'intro-a', section_id: 'intro', order: 1 });
      createScene({ scene_id: 'intro-b', section_id: 'intro', order: 1 });

      // main has duplicate order 2
      createScene({ scene_id: 'main-x', section_id: 'main', order: 2 });
      createScene({ scene_id: 'main-y', section_id: 'main', order: 2 });

      // Act
      const result = runMerge();

      // Assert: Should report both duplicates
      expect(result.success).toBe(true);
      expect(result.output).toMatch(/section_id: intro, order: 1/);
      expect(result.output).toMatch(/section_id: main, order: 2/);
    });
  });

  describe('11.3.3 Unknown section detection', () => {
    it('should fail (critical error) when scene references unknown section_id', () => {
      // Arrange: scenario has only "intro"
      createScenario([{ id: 'intro', order: 0 }]);

      // Scene references "unknown-section"
      createScene({ scene_id: 'scene-1', section_id: 'unknown-section', order: 1 });

      // Act
      const result = runMerge();

      // Assert: Should fail with critical error
      expect(result.success).toBe(false);
      expect(result.output).toMatch(/❌ CRITICAL: Scenes reference section_id not in scenario\.json/);
      expect(result.output).toMatch(/section_id: unknown-section/);
      expect(result.output).toMatch(/scene-1/);
    });

    it('should succeed when all section_id values are valid', () => {
      // Arrange
      createScenario([
        { id: 'intro', order: 0 },
        { id: 'main', order: 1 }
      ]);

      createScene({ scene_id: 'scene-1', section_id: 'intro', order: 1 });
      createScene({ scene_id: 'scene-2', section_id: 'main', order: 1 });

      // Act
      const result = runMerge();

      // Assert: Should succeed
      expect(result.success).toBe(true);
      expect(result.output).toMatch(/✅ All sections are valid/);
    });

    it('should fail with multiple unknown sections', () => {
      // Arrange
      createScenario([{ id: 'intro', order: 0 }]);

      createScene({ scene_id: 'scene-1', section_id: 'unknown-1', order: 1 });
      createScene({ scene_id: 'scene-2', section_id: 'unknown-2', order: 1 });

      // Act
      const result = runMerge();

      // Assert: Should report both unknown sections
      expect(result.success).toBe(false);
      expect(result.output).toMatch(/unknown-1/);
      expect(result.output).toMatch(/unknown-2/);
    });
  });

  describe('Integration: Multiple validations', () => {
    it('should detect unknown sections before duplicate order warnings', () => {
      // Arrange: Create scenario with valid section
      createScenario([{ id: 'intro', order: 0 }]);

      // Create scenes: one valid with duplicate order, one with unknown section
      createScene({ scene_id: 'valid-1', section_id: 'intro', order: 1 });
      createScene({ scene_id: 'valid-2', section_id: 'intro', order: 1 }); // duplicate order
      createScene({ scene_id: 'invalid-1', section_id: 'unknown', order: 1 }); // unknown section

      // Act
      const result = runMerge();

      // Assert: Should fail due to unknown section (before warning about duplicates)
      expect(result.success).toBe(false);
      expect(result.output).toMatch(/❌ CRITICAL: Scenes reference section_id not in scenario\.json/);
      expect(result.output).toMatch(/unknown/);
    });
  });

  // ========================================
  // Task 11.6.2: Unit tests for sortScenes
  // ========================================
  describe('11.6.2 sortScenes unit tests', () => {
    /**
     * Helper: Create scene wrapper
     */
    function createSceneWrapper(sceneId, sectionId, order) {
      return {
        file: `${sceneId}.json`,
        scene: {
          scene_id: sceneId,
          section_id: sectionId,
          order: order,
          type: 'custom',
          content: { duration_ms: 1000 }
        }
      };
    }

    describe('Tiebreaker behavior', () => {
      it('should sort by scene_id (lexicographic) when section_id and order match', () => {
        const scenario = {
          sections: [{ id: 'intro', order: 0 }]
        };

        const scenes = [
          createSceneWrapper('scene-z', 'intro', 1),
          createSceneWrapper('scene-a', 'intro', 1),
          createSceneWrapper('scene-m', 'intro', 1)
        ];

        const sorted = sortScenes(scenes, scenario);

        expect(sorted[0].scene.scene_id).toBe('scene-a');
        expect(sorted[1].scene.scene_id).toBe('scene-m');
        expect(sorted[2].scene.scene_id).toBe('scene-z');
      });

      it('should handle tiebreaker with numbers in scene_id', () => {
        const scenario = {
          sections: [{ id: 'main', order: 0 }]
        };

        const scenes = [
          createSceneWrapper('scene-10', 'main', 1),
          createSceneWrapper('scene-2', 'main', 1),
          createSceneWrapper('scene-1', 'main', 1)
        ];

        const sorted = sortScenes(scenes, scenario);

        // Lexicographic: '1' < '10' < '2'
        expect(sorted[0].scene.scene_id).toBe('scene-1');
        expect(sorted[1].scene.scene_id).toBe('scene-10');
        expect(sorted[2].scene.scene_id).toBe('scene-2');
      });

      it('should handle tiebreaker with special characters', () => {
        const scenario = {
          sections: [{ id: 'section', order: 0 }]
        };

        const scenes = [
          createSceneWrapper('scene_c', 'section', 1),
          createSceneWrapper('scene-b', 'section', 1),
          createSceneWrapper('scene.a', 'section', 1)
        ];

        const sorted = sortScenes(scenes, scenario);

        // Check deterministic ordering (localeCompare uses locale-specific rules)
        // localeCompare treats '_' as space, sorting it before special chars
        expect(sorted.map(s => s.scene.scene_id)).toEqual([
          'scene_c',  // '_' treated as space (comes first)
          'scene-b',  // '-'
          'scene.a'   // '.'
        ]);
      });
    });

    describe('Empty and edge cases', () => {
      it('should handle empty scenes array', () => {
        const scenario = {
          sections: [{ id: 'intro', order: 0 }]
        };

        const sorted = sortScenes([], scenario);

        expect(sorted).toEqual([]);
      });

      it('should handle single scene', () => {
        const scenario = {
          sections: [{ id: 'intro', order: 0 }]
        };

        const scenes = [
          createSceneWrapper('only-scene', 'intro', 1)
        ];

        const sorted = sortScenes(scenes, scenario);

        expect(sorted).toHaveLength(1);
        expect(sorted[0].scene.scene_id).toBe('only-scene');
      });

      it('should handle null/undefined scenario', () => {
        const scenes = [
          createSceneWrapper('scene-b', 'unknown', 1),
          createSceneWrapper('scene-a', 'unknown', 1)
        ];

        // Without scenario, section order defaults to 999
        const sorted = sortScenes(scenes, null);

        // Should still sort by scene_id as tiebreaker
        expect(sorted[0].scene.scene_id).toBe('scene-a');
        expect(sorted[1].scene.scene_id).toBe('scene-b');
      });
    });

    describe('Large-scale determinism', () => {
      it('should handle 100 scenes with deterministic output', () => {
        const scenario = {
          sections: [
            { id: 'section-1', order: 0 },
            { id: 'section-2', order: 1 }
          ]
        };

        // Generate 100 scenes (50 per section, all same order)
        const scenes = [];
        for (let i = 0; i < 50; i++) {
          scenes.push(createSceneWrapper(`scene-${i}`, 'section-1', 1));
          scenes.push(createSceneWrapper(`scene-${i}`, 'section-2', 1));
        }

        // Sort twice
        const sorted1 = sortScenes([...scenes], scenario);
        const sorted2 = sortScenes([...scenes], scenario);

        // Should produce identical order
        const ids1 = sorted1.map(s => s.scene.scene_id);
        const ids2 = sorted2.map(s => s.scene.scene_id);

        expect(ids1).toEqual(ids2);
      });

      it('should sort large array in reasonable time', () => {
        const scenario = {
          sections: [{ id: 'section', order: 0 }]
        };

        // Generate 1000 scenes
        const scenes = [];
        for (let i = 0; i < 1000; i++) {
          scenes.push(createSceneWrapper(`scene-${i}`, 'section', Math.floor(i / 10)));
        }

        const start = Date.now();
        const sorted = sortScenes(scenes, scenario);
        const duration = Date.now() - start;

        expect(sorted).toHaveLength(1000);
        expect(duration).toBeLessThan(1000); // Should complete in < 1 second
      });
    });

    describe('Section order priority', () => {
      it('should prioritize section order over scene order', () => {
        const scenario = {
          sections: [
            { id: 'main', order: 1 },
            { id: 'intro', order: 0 }
          ]
        };

        const scenes = [
          createSceneWrapper('scene-1', 'main', 0),
          createSceneWrapper('scene-2', 'intro', 999)
        ];

        const sorted = sortScenes(scenes, scenario);

        // intro (section order 0) should come before main (section order 1)
        expect(sorted[0].scene.section_id).toBe('intro');
        expect(sorted[1].scene.section_id).toBe('main');
      });

      it('should handle missing section in scenario (defaults to order 999)', () => {
        const scenario = {
          sections: [
            { id: 'intro', order: 0 }
          ]
        };

        const scenes = [
          createSceneWrapper('scene-2', 'unknown-section', 1),
          createSceneWrapper('scene-1', 'intro', 1)
        ];

        const sorted = sortScenes(scenes, scenario);

        // intro (order 0) should come before unknown-section (order 999)
        expect(sorted[0].scene.section_id).toBe('intro');
        expect(sorted[1].scene.section_id).toBe('unknown-section');
      });
    });

    describe('Multi-level sorting', () => {
      it('should sort by section order > scene order > scene_id', () => {
        const scenario = {
          sections: [
            { id: 'section-b', order: 1 },
            { id: 'section-a', order: 0 }
          ]
        };

        const scenes = [
          createSceneWrapper('z', 'section-b', 2),
          createSceneWrapper('a', 'section-b', 2),
          createSceneWrapper('m', 'section-a', 1),
          createSceneWrapper('b', 'section-a', 0),
          createSceneWrapper('c', 'section-a', 1)
        ];

        const sorted = sortScenes(scenes, scenario);

        expect(sorted.map(s => s.scene.scene_id)).toEqual([
          'b',   // section-a, order 0
          'c',   // section-a, order 1 (c < m)
          'm',   // section-a, order 1
          'a',   // section-b, order 2 (a < z)
          'z'    // section-b, order 2
        ]);
      });
    });
  });
});
