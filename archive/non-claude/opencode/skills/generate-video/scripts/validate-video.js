#!/usr/bin/env node

/**
 * Video Script Validator (E2E)
 *
 * Validates a complete video-script.json file against video-script.schema.json
 * Also performs E2E semantic validation:
 * - Scene ordering and consistency
 * - Total duration calculation
 * - Asset reference validation
 * - Audio sync validation
 * - Section/scene relationship validation
 *
 * Severity Levels:
 * - Critical: Stops validation, must be fixed
 * - Warning: Logs warning, continues validation
 *
 * Usage:
 *   node scripts/validate-video.js <video-script-file.json>
 *
 * Exit codes:
 *   0 - Validation successful (no critical errors)
 *   1 - Validation failed (critical errors found)
 *   2 - File not found or invalid JSON
 */

const fs = require('fs');
const path = require('path');
const Ajv = require('ajv');
const addFormats = require('ajv-formats');

// Initialize AJV with formats
const ajv = new Ajv({
  strict: false,
  allErrors: true,
  verbose: true,
});
addFormats(ajv);

/**
 * Load JSON file safely
 */
function loadJsonFile(filePath) {
  try {
    const content = fs.readFileSync(filePath, 'utf-8');
    return JSON.parse(content);
  } catch (error) {
    if (error.code === 'ENOENT') {
      console.error(`Error: File not found: ${filePath}`);
    } else if (error instanceof SyntaxError) {
      console.error(`Error: Invalid JSON in ${filePath}`);
      console.error(`  ${error.message}`);
    } else {
      console.error(`Error reading file: ${error.message}`);
    }
    return null;
  }
}

/**
 * Format validation errors for human-readable output
 */
function formatErrors(errors, severity = 'error') {
  if (!errors || errors.length === 0) {
    return [];
  }

  return errors.map((error) => {
    const errorPath = error.instancePath || error.path || 'root';
    const message = error.message || 'Unknown error';
    const params = error.params ? JSON.stringify(error.params) : '';

    return {
      severity: severity,
      path: errorPath,
      message: message,
      keyword: error.keyword || 'semantic',
      params: params,
      details: `${errorPath}: ${message}${params ? ` (${params})` : ''}`,
    };
  });
}

/**
 * Perform E2E semantic validation on video script
 */
function validateE2ESemantics(videoData) {
  const errors = [];
  const warnings = [];
  const scenes = videoData.scenes || [];

  // 1. Scene ID uniqueness
  const sceneIds = new Set();
  scenes.forEach((scene, index) => {
    if (sceneIds.has(scene.scene_id)) {
      errors.push({
        path: `/scenes/${index}/scene_id`,
        message: `Duplicate scene ID: "${scene.scene_id}"`,
        keyword: 'uniqueness',
      });
    } else {
      sceneIds.add(scene.scene_id);
    }
  });

  // 2. Scene order validation (per section)
  // Relaxed: only require monotonic increasing + no duplicates (not strict 0..n-1 sequence)
  // This aligns with schema which only requires minimum value, not strict sequence
  const sectionScenes = {};
  scenes.forEach((scene) => {
    if (!sectionScenes[scene.section_id]) {
      sectionScenes[scene.section_id] = [];
    }
    sectionScenes[scene.section_id].push(scene);
  });

  Object.entries(sectionScenes).forEach(([sectionId, sectionSceneList]) => {
    const orders = sectionSceneList.map((s) => s.order).sort((a, b) => a - b);

    // Check for duplicate orders (critical error)
    const orderSet = new Set(orders);
    if (orderSet.size !== orders.length) {
      const duplicates = orders.filter((o, i) => orders.indexOf(o) !== i);
      errors.push({
        path: `/scenes (section: ${sectionId})`,
        message: `Duplicate order values in section "${sectionId}": ${[...new Set(duplicates)].join(', ')}`,
        keyword: 'order-duplicate',
      });
    }

    // Check for monotonic increasing (warning only for gaps)
    for (let i = 1; i < orders.length; i++) {
      if (orders[i] <= orders[i - 1]) {
        errors.push({
          path: `/scenes (section: ${sectionId})`,
          message: `Scene order not monotonic in section "${sectionId}": ${orders[i - 1]} followed by ${orders[i]}`,
          keyword: 'order-sequence',
        });
        break;
      }
    }
  });

  // 3. Total duration validation
  const calculatedDuration = scenes.reduce(
    (sum, scene) => sum + (scene.content.duration_ms || 0),
    0
  );
  const declaredDuration = videoData.total_duration_ms;

  // Allow 5% tolerance for transitions
  const tolerance = calculatedDuration * 0.05;
  if (Math.abs(calculatedDuration - declaredDuration) > tolerance) {
    warnings.push({
      path: '/total_duration_ms',
      message: `Total duration mismatch: declared ${declaredDuration}ms, calculated ${calculatedDuration}ms (tolerance: ±${tolerance.toFixed(0)}ms)`,
      keyword: 'duration-mismatch',
    });
  }

  // 4. Asset reference validation (check if files exist)
  const assetWarnings = [];
  scenes.forEach((scene, sceneIndex) => {
    // Check content images
    if (scene.content.image) {
      const imagePath = path.resolve(scene.content.image);
      if (!fs.existsSync(imagePath)) {
        assetWarnings.push({
          path: `/scenes/${sceneIndex}/content/image`,
          message: `Image asset not found: "${scene.content.image}"`,
          keyword: 'asset-missing',
        });
      }
    }

    // Check scene assets
    if (scene.assets) {
      scene.assets.forEach((asset, assetIndex) => {
        if (!asset.source.startsWith('http')) {
          const assetPath = path.resolve(asset.source);
          if (!fs.existsSync(assetPath)) {
            assetWarnings.push({
              path: `/scenes/${sceneIndex}/assets/${assetIndex}/source`,
              message: `Asset not found: "${asset.source}"`,
              keyword: 'asset-missing',
            });
          }
        }
      });
    }

    // Check audio files
    if (scene.audio?.narration?.file) {
      const audioPath = path.resolve(scene.audio.narration.file);
      if (!fs.existsSync(audioPath)) {
        assetWarnings.push({
          path: `/scenes/${sceneIndex}/audio/narration/file`,
          message: `Narration audio not found: "${scene.audio.narration.file}"`,
          keyword: 'asset-missing',
        });
      }
    }
  });

  // Only add asset warnings if there are any (don't fail on missing assets)
  warnings.push(...assetWarnings);

  // 5. Audio sync validation
  scenes.forEach((scene, index) => {
    if (scene.audio?.narration?.file) {
      const startOffset = scene.audio.narration.start_offset_ms || 1000;
      const sceneDuration = scene.content.duration_ms;

      // Check if narration start offset is reasonable
      if (startOffset > sceneDuration / 2) {
        warnings.push({
          path: `/scenes/${index}/audio/narration/start_offset_ms`,
          message: `Narration starts too late (${startOffset}ms in ${sceneDuration}ms scene)`,
          keyword: 'audio-sync',
        });
      }

      // Recommend checking audio duration
      warnings.push({
        path: `/scenes/${index}/audio`,
        message: `Audio sync should be verified with ffprobe for scene "${scene.scene_id}"`,
        keyword: 'audio-verify',
      });
    }
  });

  // 6. Resolution validation
  const { width, height } = videoData.output_settings;
  const aspectRatio = width / height;
  const commonRatios = {
    '16:9': 16 / 9,
    '4:3': 4 / 3,
    '1:1': 1,
    '9:16': 9 / 16,
  };

  let matchedRatio = null;
  for (const [name, ratio] of Object.entries(commonRatios)) {
    if (Math.abs(aspectRatio - ratio) < 0.01) {
      matchedRatio = name;
      break;
    }
  }

  if (!matchedRatio) {
    warnings.push({
      path: '/output_settings',
      message: `Unusual aspect ratio: ${width}x${height} (${aspectRatio.toFixed(2)}:1)`,
      keyword: 'resolution-unusual',
    });
  }

  return { errors, warnings };
}

/**
 * Validate video script against schema
 */
function validateVideoScript(videoData, schemaPath, sceneSchemaPath) {
  // Load schemas
  const videoSchema = loadJsonFile(schemaPath);
  if (!videoSchema) {
    return {
      valid: false,
      errors: [{ message: 'Failed to load video script schema', path: 'schema' }],
      warnings: [],
    };
  }

  const sceneSchema = loadJsonFile(sceneSchemaPath);
  if (!sceneSchema) {
    return {
      valid: false,
      errors: [{ message: 'Failed to load scene schema', path: 'schema' }],
      warnings: [],
    };
  }

  // Add scene schema to ajv (guard against duplicate registration)
  if (!ajv.getSchema('scene.schema.json')) {
    ajv.addSchema(sceneSchema, 'scene.schema.json');
  }

  // Compile video schema
  let validate;
  try {
    validate = ajv.compile(videoSchema);
  } catch (error) {
    return {
      valid: false,
      errors: [
        {
          message: `Schema compilation error: ${error.message}`,
          path: 'schema',
        },
      ],
      warnings: [],
    };
  }

  // Validate against schema
  const valid = validate(videoData);
  let schemaErrors = [];

  if (!valid) {
    schemaErrors = formatErrors(validate.errors, 'error');
    // Return early if schema validation fails - don't run semantic validation
    // on structurally invalid data as it may cause runtime errors
    return {
      valid: false,
      errors: schemaErrors,
      warnings: [],
    };
  }

  // Perform E2E semantic validation (only if schema is valid)
  const { errors: semanticErrors, warnings: semanticWarnings } =
    validateE2ESemantics(videoData);

  // Combine errors and warnings
  const allErrors = formatErrors(semanticErrors, 'error');
  const allWarnings = formatErrors(semanticWarnings, 'warning');

  // Critical errors prevent success
  if (allErrors.length > 0) {
    return {
      valid: false,
      errors: allErrors,
      warnings: allWarnings,
    };
  }

  return {
    valid: true,
    errors: [],
    warnings: allWarnings,
  };
}

/**
 * Main validation function
 */
function main() {
  const args = process.argv.slice(2);

  if (args.length === 0) {
    console.error('Usage: node scripts/validate-video.js <video-script-file.json>');
    console.error('');
    console.error('Example:');
    console.error('  node scripts/validate-video.js examples/video-script-example.json');
    process.exit(2);
  }

  const videoFile = args[0];
  const schemaPath = path.join(__dirname, '../schemas/video-script.schema.json');
  const sceneSchemaPath = path.join(__dirname, '../schemas/scene.schema.json');

  console.log('Video Script Validator (E2E)');
  console.log('============================');
  console.log(`Input: ${videoFile}`);
  console.log(`Schema: ${schemaPath}`);
  console.log('');

  // Load video script file
  const videoData = loadJsonFile(videoFile);
  if (!videoData) {
    process.exit(2);
  }

  // Validate
  const result = validateVideoScript(videoData, schemaPath, sceneSchemaPath);

  // Display warnings first (if any)
  if (result.warnings.length > 0) {
    console.log('⚠️  Warnings:');
    console.log('');
    result.warnings.forEach((warning, index) => {
      console.log(`${index + 1}. ${warning.details}`);
    });
    console.log('');
  }

  // Output results
  if (result.valid) {
    console.log('✅ Validation successful');
    console.log('');
    console.log('Video details:');
    console.log(`  Title: ${videoData.metadata.title}`);
    console.log(`  Version: ${videoData.metadata.version}`);
    console.log(`  Scenes: ${videoData.scenes.length}`);
    console.log(`  Duration: ${(videoData.total_duration_ms / 1000).toFixed(1)}s`);
    console.log(
      `  Resolution: ${videoData.output_settings.width}x${videoData.output_settings.height} @ ${videoData.output_settings.fps}fps`
    );
    if (videoData.metadata.video_type) {
      console.log(`  Type: ${videoData.metadata.video_type}`);
    }

    // Display scene breakdown by section
    const sectionScenes = {};
    videoData.scenes.forEach((scene) => {
      if (!sectionScenes[scene.section_id]) {
        sectionScenes[scene.section_id] = [];
      }
      sectionScenes[scene.section_id].push(scene);
    });

    console.log('');
    console.log('Scenes by section:');
    Object.entries(sectionScenes).forEach(([sectionId, scenes]) => {
      console.log(`  ${sectionId}: ${scenes.length} scene(s)`);
      scenes.forEach((scene) => {
        const duration = (scene.content.duration_ms / 1000).toFixed(1);
        console.log(`    - ${scene.scene_id} (${duration}s, ${scene.type})`);
      });
    });

    console.log('');
    console.log(
      JSON.stringify(
        {
          valid: true,
          errors: [],
          warnings: result.warnings,
        },
        null,
        2
      )
    );
    process.exit(0);
  } else {
    console.error('❌ Validation failed');
    console.error('');
    console.error(`Found ${result.errors.length} critical error(s):`);
    console.error('');

    result.errors.forEach((error, index) => {
      console.error(`${index + 1}. ${error.details}`);
    });

    console.error('');
    console.error(
      JSON.stringify(
        {
          valid: false,
          errors: result.errors,
          warnings: result.warnings,
        },
        null,
        2
      )
    );
    process.exit(1);
  }
}

// Run if executed directly
if (require.main === module) {
  main();
}

// Export for testing
module.exports = { validateVideoScript, validateE2ESemantics, formatErrors };
