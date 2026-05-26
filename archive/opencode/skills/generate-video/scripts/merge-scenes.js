#!/usr/bin/env node

/**
 * Scene Merger
 *
 * Merges individual scene JSON files into a single video-script.json.
 * Validates order, detects conflicts, and generates final video script.
 *
 * Usage:
 *   node scripts/merge-scenes.js <output-dir>
 *
 * Example:
 *   node scripts/merge-scenes.js out/video-20260202-001/
 *
 * Input:
 *   - out/video-{date}-{id}/scenes/*.json (individual scene files)
 *   - out/video-{date}-{id}/scenario.json (scenario definition)
 *
 * Output:
 *   - out/video-{date}-{id}/video-script.json (merged scenes)
 *
 * Exit codes:
 *   0 - Merge successful
 *   1 - Critical error (conflicts or missing scenes)
 *   2 - Invalid arguments or file not found
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
 * Load scene schema
 */
function loadSceneSchema() {
  const schemaPath = path.join(__dirname, '../schemas/scene.schema.json');
  const schema = loadJsonFile(schemaPath);
  if (!schema) {
    console.error('Failed to load scene schema');
    process.exit(2);
  }
  return schema;
}

/**
 * Load all scene files from scenes directory
 */
function loadSceneFiles(scenesDir) {
  if (!fs.existsSync(scenesDir)) {
    console.error(`Error: Scenes directory not found: ${scenesDir}`);
    return null;
  }

  const files = fs.readdirSync(scenesDir).filter(f => f.endsWith('.json'));

  if (files.length === 0) {
    console.error(`Error: No scene files found in ${scenesDir}`);
    return null;
  }

  const scenes = [];
  const errors = [];

  for (const file of files) {
    const filePath = path.join(scenesDir, file);
    const scene = loadJsonFile(filePath);

    if (!scene) {
      errors.push(`Failed to load ${file}`);
      continue;
    }

    scenes.push({ file, scene });
  }

  if (errors.length > 0) {
    console.error('\n❌ Failed to load some scene files:');
    errors.forEach(err => console.error(`  - ${err}`));
    return null;
  }

  return scenes;
}

// Cache for compiled validators to avoid re-compilation per scene (Performance fix)
const validatorCache = new Map();

/**
 * Get or create cached validator for schema
 * @param {Object} schema - JSON Schema object
 * @param {string} schemaId - Unique identifier for caching
 * @returns {Function} Compiled validator function
 */
function getValidator(schema, schemaId) {
  if (!validatorCache.has(schemaId)) {
    validatorCache.set(schemaId, ajv.compile(schema));
  }
  return validatorCache.get(schemaId);
}

/**
 * Validate scene against schema
 * Uses cached validator for performance
 */
function validateScene(scene, sceneSchema, fileName) {
  const validate = getValidator(sceneSchema, 'scene.schema.json');
  const valid = validate(scene);

  if (!valid) {
    console.error(`\n❌ Schema validation failed for ${fileName}:`);
    validate.errors.forEach(error => {
      console.error(`  - ${error.instancePath}: ${error.message}`);
    });
    return false;
  }

  return true;
}

/**
 * Detect scene_id conflicts
 */
function detectConflicts(scenes) {
  const sceneIdMap = new Map();
  const conflicts = [];

  for (const { file, scene } of scenes) {
    const sceneId = scene.scene_id;

    if (sceneIdMap.has(sceneId)) {
      conflicts.push({
        sceneId,
        files: [sceneIdMap.get(sceneId), file]
      });
    } else {
      sceneIdMap.set(sceneId, file);
    }
  }

  return conflicts;
}

/**
 * Sort scenes by section_id order and scene order
 * Tiebreaker: scene_id (lexicographic) for determinism
 */
function sortScenes(scenes, scenario) {
  // Create section order map
  const sectionOrderMap = new Map();
  if (scenario && scenario.sections) {
    scenario.sections.forEach(section => {
      sectionOrderMap.set(section.id, section.order);
    });
  }

  return scenes.sort((a, b) => {
    const sceneA = a.scene;
    const sceneB = b.scene;

    // First sort by section order
    const sectionOrderA = sectionOrderMap.get(sceneA.section_id) ?? 999;
    const sectionOrderB = sectionOrderMap.get(sceneB.section_id) ?? 999;

    if (sectionOrderA !== sectionOrderB) {
      return sectionOrderA - sectionOrderB;
    }

    // Then sort by scene order within section
    if (sceneA.order !== sceneB.order) {
      return sceneA.order - sceneB.order;
    }

    // Tiebreaker: scene_id (lexicographic order) for determinism
    return sceneA.scene_id.localeCompare(sceneB.scene_id);
  });
}

/**
 * Detect missing scenes (sections with no scenes)
 */
function detectMissingScenes(scenes, scenario) {
  if (!scenario || !scenario.sections) {
    return [];
  }

  const sectionsWithScenes = new Set(scenes.map(s => s.scene.section_id));
  const missingSections = scenario.sections
    .filter(section => !sectionsWithScenes.has(section.id))
    .map(section => section.id);

  return missingSections;
}

/**
 * Detect duplicate orders within the same section
 */
function detectDuplicateOrders(scenes) {
  const duplicates = [];
  const orderMap = new Map(); // section_id -> Map<order, scene_ids[]>

  for (const { file, scene } of scenes) {
    const sectionId = scene.section_id;
    const order = scene.order;

    if (!orderMap.has(sectionId)) {
      orderMap.set(sectionId, new Map());
    }

    const sectionOrders = orderMap.get(sectionId);
    if (!sectionOrders.has(order)) {
      sectionOrders.set(order, []);
    }

    sectionOrders.get(order).push({ scene_id: scene.scene_id, file });
  }

  // Find duplicates
  for (const [sectionId, sectionOrders] of orderMap.entries()) {
    for (const [order, sceneInfos] of sectionOrders.entries()) {
      if (sceneInfos.length > 1) {
        duplicates.push({
          section_id: sectionId,
          order,
          scenes: sceneInfos
        });
      }
    }
  }

  return duplicates;
}

/**
 * Detect unknown sections (scenes referencing section_id not in scenario)
 */
function detectUnknownSections(scenes, scenario) {
  if (!scenario || !scenario.sections) {
    return []; // Can't validate without scenario
  }

  const knownSections = new Set(scenario.sections.map(s => s.id));
  const unknownSections = [];

  for (const { file, scene } of scenes) {
    if (!knownSections.has(scene.section_id)) {
      unknownSections.push({
        section_id: scene.section_id,
        scene_id: scene.scene_id,
        file
      });
    }
  }

  return unknownSections;
}

/**
 * Calculate total duration
 */
function calculateTotalDuration(scenes) {
  return scenes.reduce((total, { scene }) => {
    return total + (scene.content?.duration_ms || 0);
  }, 0);
}

/**
 * Generate video-script.json metadata (compliant with video-script.schema.json)
 */
function generateMetadata(scenario) {
  const metadata = {
    title: scenario?.title || 'Generated Video',
    description: scenario?.description || '',
    version: '1.0.0',
    // Use scenario's timestamp for determinism, fallback to current time
    created_at: scenario?.metadata?.generated_at || new Date().toISOString(),
    author: 'merge-scenes.js',
    video_type: scenario?.metadata?.video_type || 'custom'
  };
  // Only include scenario_id if it's a valid string
  if (scenario?.id && typeof scenario.id === 'string') {
    metadata.scenario_id = scenario.id;
  }
  return metadata;
}

/**
 * Generate default output settings
 */
function generateOutputSettings() {
  return {
    width: 1920,
    height: 1080,
    fps: 30,
    codec: 'h264',
    format: 'mp4'
  };
}

/**
 * Main merge function
 */
function mergeScenes(outputDir, options = {}) {
  console.log('🎬 Scene Merger\n');
  console.log(`Output directory: ${outputDir}\n`);

  // Load scenario (optional)
  const scenarioPath = path.join(outputDir, 'scenario.json');
  let scenario = null;
  if (fs.existsSync(scenarioPath)) {
    scenario = loadJsonFile(scenarioPath);
    if (scenario) {
      console.log('✅ Loaded scenario.json\n');

      // Validate scenario.json unless --skip-validation is specified
      if (!options.skipValidation) {
        console.log('🔍 Validating scenario.json...');
        const { validateScenario } = require('./validate-scenario.js');
        const scenarioSchemaPath = path.join(__dirname, '../schemas/scenario.schema.json');
        const validationResult = validateScenario(scenario, scenarioSchemaPath);

        if (!validationResult.valid) {
          console.error('\n❌ Scenario validation failed:');
          validationResult.errors.forEach((error, index) => {
            console.error(`  ${index + 1}. ${error.details || error.message}`);
          });
          console.error('\nRun with --skip-validation to bypass validation (not recommended).\n');
          process.exit(1);
        }

        console.log('✅ Scenario validation passed\n');
      } else {
        console.log('⚠️  Skipping scenario validation (--skip-validation)\n');
      }
    }
  }

  // Load scene schema
  const sceneSchema = loadSceneSchema();

  // Load all scene files
  const scenesDir = path.join(outputDir, 'scenes');
  const sceneFiles = loadSceneFiles(scenesDir);

  if (!sceneFiles) {
    process.exit(2);
  }

  console.log(`📁 Found ${sceneFiles.length} scene files\n`);

  // Validate all scenes
  console.log('🔍 Validating scenes...');
  let validationErrors = 0;

  for (const { file, scene } of sceneFiles) {
    if (!validateScene(scene, sceneSchema, file)) {
      validationErrors++;
    }
  }

  if (validationErrors > 0) {
    console.error(`\n❌ ${validationErrors} scene(s) failed validation`);
    process.exit(1);
  }

  console.log('✅ All scenes passed validation\n');

  // Detect conflicts
  console.log('🔍 Checking for conflicts...');
  const conflicts = detectConflicts(sceneFiles);

  if (conflicts.length > 0) {
    console.error('\n❌ CRITICAL: Scene ID conflicts detected:');
    conflicts.forEach(conflict => {
      console.error(`  - scene_id "${conflict.sceneId}" exists in multiple files:`);
      conflict.files.forEach(file => console.error(`    - ${file}`));
    });
    console.error('\nEach scene must have a unique scene_id.');
    process.exit(1);
  }

  console.log('✅ No conflicts detected\n');

  // Check for unknown sections (CRITICAL error)
  if (scenario) {
    console.log('🔍 Checking for unknown sections...');
    const unknownSections = detectUnknownSections(sceneFiles, scenario);

    if (unknownSections.length > 0) {
      console.error('\n❌ CRITICAL: Scenes reference section_id not in scenario.json:');
      unknownSections.forEach(({ section_id, scene_id, file }) => {
        console.error(`  - ${file}:`);
        console.error(`    scene_id: ${scene_id}`);
        console.error(`    section_id: ${section_id} (not found in scenario)`);
      });
      console.error('\nAll section_id values must exist in scenario.json.');
      process.exit(1);
    }

    console.log('✅ All sections are valid\n');
  }

  // Check for duplicate orders (WARNING only)
  console.log('🔍 Checking for duplicate orders...');
  const duplicateOrders = detectDuplicateOrders(sceneFiles);

  if (duplicateOrders.length > 0) {
    console.log('\n⚠️  WARNING: Duplicate orders detected within sections:');
    duplicateOrders.forEach(({ section_id, order, scenes }) => {
      console.log(`  - section_id: ${section_id}, order: ${order}`);
      scenes.forEach(({ scene_id, file }) => {
        console.log(`    - ${scene_id} (${file})`);
      });
    });
    console.log('\n  Scenes will be ordered by scene_id (lexicographic) as tiebreaker.\n');
  } else {
    console.log('✅ No duplicate orders detected\n');
  }

  // Check for missing scenes
  if (scenario) {
    console.log('🔍 Checking for missing scenes...');
    const missingSections = detectMissingScenes(sceneFiles, scenario);

    if (missingSections.length > 0) {
      console.error('\n❌ CRITICAL: Sections with no scenes:');
      missingSections.forEach(sectionId => {
        const section = scenario.sections.find(s => s.id === sectionId);
        console.error(`  - ${sectionId}: ${section?.title || 'Unknown'}`);
      });
      console.error('\nEach section must have at least one scene.');
      process.exit(1);
    }

    console.log('✅ All sections have scenes\n');
  }

  // Sort scenes
  console.log('📊 Sorting scenes...');
  const sortedScenes = sortScenes(sceneFiles, scenario);
  console.log('✅ Scenes sorted by section_id and order\n');

  // Calculate total duration
  const totalDuration = calculateTotalDuration(sortedScenes);
  console.log(`⏱️  Total duration: ${totalDuration}ms (${(totalDuration / 1000).toFixed(1)}s)\n`);

  // Generate video script (compliant with video-script.schema.json)
  const videoScript = {
    metadata: generateMetadata(scenario),
    scenes: sortedScenes.map(s => s.scene),
    total_duration_ms: totalDuration,
    output_settings: generateOutputSettings()
  };

  // Write video-script.json
  const outputPath = path.join(outputDir, 'video-script.json');
  try {
    fs.writeFileSync(outputPath, JSON.stringify(videoScript, null, 2), 'utf-8');
    console.log(`✅ Generated: ${outputPath}\n`);
  } catch (error) {
    console.error(`Error writing video-script.json: ${error.message}`);
    process.exit(2);
  }

  // Summary
  console.log('📋 Scene order:');
  sortedScenes.forEach((s, index) => {
    const scene = s.scene;
    const duration = (scene.content?.duration_ms || 0) / 1000;
    console.log(`  ${index + 1}. [${scene.section_id}] ${scene.scene_id} (${duration.toFixed(1)}s)`);
  });

  console.log('\n✅ Merge completed successfully!');
  process.exit(0);
}

// Export for testing
module.exports = {
  sortScenes,
  loadJsonFile,
  detectConflicts,
  detectDuplicateOrders,
  detectUnknownSections,
  detectMissingScenes
};

// Run as CLI (only when executed directly)
if (require.main === module) {
  // Parse arguments
  const args = process.argv.slice(2);

  if (args.length === 0 || args[0] === '--help' || args[0] === '-h') {
    console.log(`
Usage: node scripts/merge-scenes.js <output-dir> [options]

Arguments:
  <output-dir>         Path to output directory containing scenes/ and scenario.json

Options:
  --skip-validation    Skip scenario.json validation (not recommended)
  --help, -h           Show this help message

Example:
  node scripts/merge-scenes.js out/video-20260202-001/
  node scripts/merge-scenes.js out/video-20260202-001/ --skip-validation
  `);
    process.exit(0);
  }

  const outputDir = path.resolve(args[0]);
  const options = {
    skipValidation: args.includes('--skip-validation')
  };

  if (!fs.existsSync(outputDir)) {
    console.error(`Error: Output directory not found: ${outputDir}`);
    process.exit(2);
  }

  // Run merger
  mergeScenes(outputDir, options);
}
