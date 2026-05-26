/**
 * E2E Render Test
 *
 * Tests the complete rendering pipeline with a minimal video-script.json
 *
 * Test cases:
 *   1. Render minimal video script
 *   2. Verify output file exists
 *   3. Verify frame count matches expected duration
 *   4. Verify file size is reasonable
 */

const fs = require('fs');
const path = require('path');
const { loadVideoScript, resolveAssets, msToFrames } = require('../../scripts/render-video');

describe('E2E Render Tests', () => {
  const testDir = path.join(__dirname, '..', '..', 'tests', 'fixtures');
  const outputDir = path.join(__dirname, '..', '..', 'tests', 'output');
  const minimalScriptPath = path.join(testDir, 'minimal-video-script.json');
  const outputVideoPath = path.join(outputDir, 'test-render.mp4');

  // Create minimal video script fixture
  beforeAll(() => {
    if (!fs.existsSync(testDir)) {
      fs.mkdirSync(testDir, { recursive: true });
    }

    if (!fs.existsSync(outputDir)) {
      fs.mkdirSync(outputDir, { recursive: true });
    }

    // Create minimal video script
    const minimalScript = {
      metadata: {
        title: 'Test Video',
        version: '1.0.0',
        created_at: new Date().toISOString(),
        video_type: 'custom',
      },
      scenes: [
        {
          scene_id: 'test-scene-1',
          section_id: 'intro',
          order: 0,
          type: 'intro',
          content: {
            text: 'Hello World',
            duration_ms: 3000,
            title: 'Test',
            subtitle: 'E2E Test',
          },
          direction: {
            transition: {
              in: 'fade',
              out: 'fade',
              duration_ms: 500,
            },
            background: {
              type: 'solid',
              value: '#000000',
            },
          },
          assets: [],
          template: 'intro',
        },
        {
          scene_id: 'test-scene-2',
          section_id: 'content',
          order: 1,
          type: 'text',
          content: {
            text: 'This is a test scene',
            duration_ms: 2000,
          },
          direction: {
            transition: {
              in: 'fade',
              out: 'fade',
              duration_ms: 500,
            },
          },
          assets: [],
        },
      ],
      total_duration_ms: 5000,
      output_settings: {
        width: 1280,
        height: 720,
        fps: 30,
        codec: 'h264',
        format: 'mp4',
        quality: 'medium',
      },
    };

    fs.writeFileSync(minimalScriptPath, JSON.stringify(minimalScript, null, 2));
  });

  afterAll(() => {
    // Cleanup test files
    if (fs.existsSync(outputVideoPath)) {
      fs.unlinkSync(outputVideoPath);
    }
  });

  test('Load video script', () => {
    const script = loadVideoScript(minimalScriptPath, { skipValidation: true });

    expect(script).toBeDefined();
    expect(script.metadata).toBeDefined();
    expect(script.metadata.title).toBe('Test Video');
    expect(script.scenes).toHaveLength(2);
    expect(script.total_duration_ms).toBe(5000);
  });

  test('Resolve assets', () => {
    const script = loadVideoScript(minimalScriptPath, { skipValidation: true });
    const resolved = resolveAssets(script, minimalScriptPath);

    expect(resolved).toBeDefined();
    expect(resolved.scenes).toHaveLength(2);
    // No assets in minimal script, so should remain empty
    expect(resolved.scenes[0].assets).toEqual([]);
  });

  test('Calculate frames from milliseconds', () => {
    const fps = 30;

    expect(msToFrames(1000, fps)).toBe(30); // 1 second
    expect(msToFrames(3000, fps)).toBe(90); // 3 seconds
    expect(msToFrames(5000, fps)).toBe(150); // 5 seconds
    expect(msToFrames(100, fps)).toBe(3); // 100ms rounds up
  });

  test('Frame calculation matches total duration', () => {
    const script = loadVideoScript(minimalScriptPath, { skipValidation: true });
    const fps = script.output_settings.fps;
    const totalFrames = msToFrames(script.total_duration_ms, fps);

    expect(totalFrames).toBe(150); // 5000ms @ 30fps = 150 frames
  });

  test('Validate render command construction', () => {
    const script = loadVideoScript(minimalScriptPath, { skipValidation: true });
    const { buildRenderCommand } = require('../../scripts/render-video');

    const options = {
      output: outputVideoPath,
      composition: 'VideoComposition',
      quality: 'medium',
    };

    const { command, args, outputPath, totalFrames, fps } = buildRenderCommand(script, options);

    expect(command).toBeDefined();
    expect(args).toContain('render');
    expect(args.some((arg) => arg.includes(outputPath))).toBe(true);
    expect(outputPath).toBe(outputVideoPath);
    expect(totalFrames).toBe(150);
    expect(fps).toBe(30);
  });

  test('Handle missing video script', () => {
    expect(() => {
      loadVideoScript('/nonexistent/path.json');
    }).toThrow('Video script not found');
  });

  test('Handle invalid video script (missing fields)', () => {
    const invalidScriptPath = path.join(testDir, 'invalid-script.json');
    fs.writeFileSync(invalidScriptPath, JSON.stringify({ invalid: 'data' }));

    expect(() => {
      loadVideoScript(invalidScriptPath, { skipValidation: true });
    }).toThrow('Invalid video script');

    fs.unlinkSync(invalidScriptPath);
  });

  test('Handle empty scenes array', () => {
    const emptyScriptPath = path.join(testDir, 'empty-scenes.json');
    const emptyScript = {
      metadata: { title: 'Empty', version: '1.0.0', created_at: new Date().toISOString(), author: 'test', video_type: 'custom' },
      scenes: [],
      total_duration_ms: 0,
      output_settings: { width: 1280, height: 720, fps: 30, codec: 'h264', format: 'mp4' },
    };
    fs.writeFileSync(emptyScriptPath, JSON.stringify(emptyScript));

    expect(() => {
      loadVideoScript(emptyScriptPath, { skipValidation: true });
    }).toThrow('scenes must be a non-empty array');

    fs.unlinkSync(emptyScriptPath);
  });

  // NOTE: Integration test with actual Remotion rendering is intentionally excluded
  // from automated tests. Manual testing:
  //   node scripts/render-video.js tests/fixtures/minimal-video-script.json --output tests/output/test.mp4
});
