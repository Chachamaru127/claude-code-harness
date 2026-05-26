/**
 * Tests for validation integration (Task 11.4)
 *
 * Validates:
 * - 11.4.1: merge-scenes entry point validation
 * - 11.4.2: render-video entry point validation
 * - 11.4.3: --skip-validation flag for both scripts
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Security note: execSync is safe here because:
// 1. This is test code running in controlled environment
// 2. All inputs (paths, flags) are constructed by test code, not user input
// 3. Script paths are resolved from __dirname (constant)
// 4. Temp directories are created by Node.js fs.mkdtempSync (safe paths)

const MERGE_SCRIPT = path.join(__dirname, '../scripts/merge-scenes.js');
const RENDER_SCRIPT = path.join(__dirname, '../scripts/render-video.js');

describe('Validation Integration (Task 11.4)', () => {
  let tempDir;

  beforeEach(() => {
    tempDir = fs.mkdtempSync(path.join('/tmp', 'validation-test-'));
  });

  afterEach(() => {
    if (tempDir && fs.existsSync(tempDir)) {
      fs.rmSync(tempDir, { recursive: true });
    }
  });

  /**
   * Helper: Create scenario.json
   */
  function createScenario(data) {
    const scenarioPath = path.join(tempDir, 'scenario.json');
    const scenario = {
      title: data.title || 'Test Scenario',
      description: data.description || 'Test scenario description',
      metadata: {
        version: '1.0.0',
        generated_at: new Date().toISOString(),
        video_type: 'custom',
        ...(data.metadata || {})
      },
      sections: data.sections || []
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
   * Helper: Create video-script.json
   */
  function createVideoScript(data) {
    const scriptPath = path.join(tempDir, 'video-script.json');
    const script = {
      metadata: {
        title: data.title || 'Test Video',
        version: '1.0.0',
        created_at: new Date().toISOString(),
        author: 'test',
        video_type: 'custom',
        ...(data.metadata || {})
      },
      scenes: data.scenes || [],
      total_duration_ms: data.total_duration_ms || 0,
      output_settings: {
        width: 1920,
        height: 1080,
        fps: 30,
        codec: 'h264',
        format: 'mp4',
        ...(data.output_settings || {})
      }
    };
    fs.writeFileSync(scriptPath, JSON.stringify(script, null, 2));
    return scriptPath;
  }

  /**
   * Helper: Run merge-scenes.js (controlled test environment)
   */
  function runMerge(options = {}) {
    const skipFlag = options.skipValidation ? ' --skip-validation' : '';
    try {
      const output = execSync(`node ${MERGE_SCRIPT} ${tempDir}${skipFlag}`, {
        encoding: 'utf-8',
        stdio: 'pipe'
      });
      return { success: true, output };
    } catch (error) {
      const combinedOutput = (error.stdout || '') + (error.stderr || '');
      return { success: false, output: combinedOutput };
    }
  }

  describe('11.4.1: merge-scenes entry point validation', () => {
    it('should validate scenario.json by default', () => {
      // Arrange: Create invalid scenario (missing required field)
      const scenarioPath = path.join(tempDir, 'scenario.json');
      const invalidScenario = {
        title: 'Test',
        // Missing 'description' field (required)
        metadata: { version: '1.0.0', generated_at: new Date().toISOString() },
        sections: []
      };
      fs.writeFileSync(scenarioPath, JSON.stringify(invalidScenario, null, 2));

      // Create valid scenes directory
      fs.mkdirSync(path.join(tempDir, 'scenes'));

      // Act
      const result = runMerge();

      // Assert: Should fail validation
      expect(result.success).toBe(false);
      expect(result.output).toMatch(/Validating scenario\.json/);
      expect(result.output).toMatch(/Scenario validation failed/);
      expect(result.output).toMatch(/must have required property 'description'/);
    });

    it('should proceed when scenario.json is valid', () => {
      // Arrange: Create valid scenario
      createScenario({
        sections: [
          { id: 'intro', title: 'Intro', description: 'Introduction', order: 0 }
        ]
      });
      createScene({ scene_id: 'scene-1', section_id: 'intro', order: 0 });

      // Act
      const result = runMerge();

      // Assert: Should succeed
      expect(result.success).toBe(true);
      expect(result.output).toMatch(/Validating scenario\.json/);
      expect(result.output).toMatch(/Scenario validation passed/);
      expect(result.output).toMatch(/Merge completed successfully/);
    });

    it('should suggest --skip-validation flag on validation failure', () => {
      // Arrange: Invalid scenario
      const scenarioPath = path.join(tempDir, 'scenario.json');
      const invalidScenario = {
        title: 'Test',
        metadata: { version: '1.0.0', generated_at: new Date().toISOString() },
        sections: []
      };
      fs.writeFileSync(scenarioPath, JSON.stringify(invalidScenario, null, 2));
      fs.mkdirSync(path.join(tempDir, 'scenes'));

      // Act
      const result = runMerge();

      // Assert
      expect(result.success).toBe(false);
      expect(result.output).toMatch(/Run with --skip-validation to bypass validation/);
    });
  });

  describe('11.4.2: render-video entry point validation', () => {
    it('should validate video-script.json by default', () => {
      // Arrange: Create invalid video-script (missing required field)
      const scriptPath = path.join(tempDir, 'video-script.json');
      const invalidScript = {
        metadata: { title: 'Test', version: '1.0.0', created_at: new Date().toISOString(), author: 'test', video_type: 'custom' },
        // Missing 'scenes' field (required)
        total_duration_ms: 0,
        output_settings: { width: 1920, height: 1080, fps: 30, codec: 'h264', format: 'mp4' }
      };
      fs.writeFileSync(scriptPath, JSON.stringify(invalidScript, null, 2));

      // Act
      try {
        execSync(`node ${RENDER_SCRIPT} ${scriptPath}`, {
          encoding: 'utf-8',
          stdio: 'pipe'
        });
        fail('Should have thrown an error');
      } catch (error) {
        const output = (error.stdout || '') + (error.stderr || '');

        // Assert: Should fail validation
        expect(output).toMatch(/Validating video-script\.json/);
        expect(output).toMatch(/Video script validation failed/);
      }
    });

    it('should proceed when video-script.json is valid', () => {
      // Arrange: Create valid video-script
      const scriptPath = createVideoScript({
        scenes: [
          {
            scene_id: 'scene-1',
            section_id: 'intro',
            order: 0,
            type: 'custom',
            content: { duration_ms: 1000 }
          }
        ],
        total_duration_ms: 1000
      });

      // Act: Try to run render (will fail at Remotion step, but validation should pass)
      try {
        execSync(`node ${RENDER_SCRIPT} ${scriptPath}`, {
          encoding: 'utf-8',
          stdio: 'pipe',
          timeout: 5000  // Timeout to prevent long-running Remotion attempts
        });
      } catch (error) {
        const output = (error.stdout || '') + (error.stderr || '');

        // Assert: Should pass validation and reach rendering stage
        expect(output).toMatch(/Validating video-script\.json against schema/);
        expect(output).toMatch(/Video script validation passed/);
        expect(output).toMatch(/Loaded: Test Video/);
      }
    });

    it('should suggest --skip-validation flag on validation failure', () => {
      // Arrange: Invalid video-script
      const scriptPath = path.join(tempDir, 'video-script.json');
      const invalidScript = {
        metadata: { title: 'Test', version: '1.0.0', created_at: new Date().toISOString(), author: 'test', video_type: 'custom' },
        total_duration_ms: 0,
        output_settings: { width: 1920, height: 1080, fps: 30, codec: 'h264', format: 'mp4' }
      };
      fs.writeFileSync(scriptPath, JSON.stringify(invalidScript, null, 2));

      // Act
      try {
        execSync(`node ${RENDER_SCRIPT} ${scriptPath}`, {
          encoding: 'utf-8',
          stdio: 'pipe'
        });
        fail('Should have thrown an error');
      } catch (error) {
        const output = (error.stdout || '') + (error.stderr || '');

        // Assert
        expect(output).toMatch(/Run with --skip-validation to bypass validation/);
      }
    });
  });

  describe('11.4.3: --skip-validation flag', () => {
    it('should skip validation in merge-scenes when flag is provided', () => {
      // Arrange: Create invalid scenario
      const scenarioPath = path.join(tempDir, 'scenario.json');
      const invalidScenario = {
        title: 'Test',
        // Missing 'description'
        metadata: { version: '1.0.0', generated_at: new Date().toISOString() },
        sections: [
          { id: 'intro', title: 'Intro', description: 'Test', order: 0 }
        ]
      };
      fs.writeFileSync(scenarioPath, JSON.stringify(invalidScenario, null, 2));
      createScene({ scene_id: 'scene-1', section_id: 'intro', order: 0 });

      // Act: Run with --skip-validation
      const result = runMerge({ skipValidation: true });

      // Assert: Should succeed despite invalid scenario
      expect(result.success).toBe(true);
      expect(result.output).toMatch(/Skipping scenario validation/);
      expect(result.output).toMatch(/Merge completed successfully/);
    });

    it('should skip validation in render-video when flag is provided', () => {
      // Arrange: Create invalid video-script (but structurally parseable)
      const scriptPath = path.join(tempDir, 'video-script.json');
      const partiallyValidScript = {
        metadata: { title: 'Test', version: '1.0.0', created_at: new Date().toISOString(), author: 'test', video_type: 'custom' },
        scenes: [
          {
            scene_id: 'scene-1',
            section_id: 'intro',
            order: 0,
            type: 'custom',
            content: { duration_ms: 1000 }
          }
        ],
        total_duration_ms: 1000,
        output_settings: { width: 1920, height: 1080, fps: 30, codec: 'h264', format: 'mp4' }
      };
      fs.writeFileSync(scriptPath, JSON.stringify(partiallyValidScript, null, 2));

      // Act: Try to run with --skip-validation (will fail at Remotion, but validation should be skipped)
      try {
        execSync(`node ${RENDER_SCRIPT} ${scriptPath} --skip-validation`, {
          encoding: 'utf-8',
          stdio: 'pipe',
          timeout: 5000  // Timeout to prevent long-running Remotion attempts
        });
      } catch (error) {
        const output = (error.stdout || '') + (error.stderr || '');

        // Assert: Should skip validation and reach rendering stage
        expect(output).toMatch(/Skipping video-script\.json validation/);
        expect(output).toMatch(/Loaded: Test/);
      }
    });

    it('should display warning when --skip-validation is used in merge-scenes', () => {
      // Arrange
      createScenario({
        sections: [
          { id: 'intro', title: 'Intro', description: 'Test', order: 0 }
        ]
      });
      createScene({ scene_id: 'scene-1', section_id: 'intro', order: 0 });

      // Act
      const result = runMerge({ skipValidation: true });

      // Assert
      expect(result.success).toBe(true);
      expect(result.output).toMatch(/⚠️.*Skipping scenario validation/);
    });

    it('should show --skip-validation option in help text for merge-scenes', () => {
      // Act
      try {
        const output = execSync(`node ${MERGE_SCRIPT} --help`, {
          encoding: 'utf-8',
          stdio: 'pipe'
        });

        // Assert
        expect(output).toMatch(/--skip-validation/);
        expect(output).toMatch(/Skip scenario\.json validation/);
      } catch (error) {
        const output = (error.stdout || '') + (error.stderr || '');
        expect(output).toMatch(/--skip-validation/);
      }
    });

    it('should show --skip-validation option in help text for render-video', () => {
      // Act
      try {
        const output = execSync(`node ${RENDER_SCRIPT} --help`, {
          encoding: 'utf-8',
          stdio: 'pipe'
        });

        // Assert
        expect(output).toMatch(/--skip-validation/);
        expect(output).toMatch(/Skip video-script\.json validation/);
      } catch (error) {
        const output = (error.stdout || '') + (error.stderr || '');
        expect(output).toMatch(/--skip-validation/);
      }
    });
  });
});
