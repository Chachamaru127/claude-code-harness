#!/usr/bin/env node

/**
 * Scene Validator
 *
 * Validates a scene.json file against scene.schema.json
 *
 * Usage:
 *   node scripts/validate-scene.js <scene-file.json>
 *
 * Exit codes:
 *   0 - Validation successful
 *   1 - Validation failed
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
function formatErrors(errors) {
  if (!errors || errors.length === 0) {
    return [];
  }

  return errors.map((error) => {
    const path = error.instancePath || 'root';
    const message = error.message || 'Unknown error';
    const params = error.params ? JSON.stringify(error.params) : '';

    return {
      path: path,
      message: message,
      keyword: error.keyword,
      params: params,
      details: `${path}: ${message}${params ? ` (${params})` : ''}`,
    };
  });
}

/**
 * Validate scene data against schema
 */
function validateScene(sceneData, schemaPath) {
  // Load scene schema
  const schema = loadJsonFile(schemaPath);
  if (!schema) {
    return {
      valid: false,
      errors: [{ message: 'Failed to load scene schema', path: 'schema' }],
    };
  }

  // Compile schema
  let validate;
  try {
    validate = ajv.compile(schema);
  } catch (error) {
    return {
      valid: false,
      errors: [
        {
          message: `Schema compilation error: ${error.message}`,
          path: 'schema',
        },
      ],
    };
  }

  // Validate data
  const valid = validate(sceneData);

  if (!valid) {
    return {
      valid: false,
      errors: formatErrors(validate.errors),
    };
  }

  return { valid: true, errors: [] };
}

/**
 * Main validation function
 */
function main() {
  const args = process.argv.slice(2);

  if (args.length === 0) {
    console.error('Usage: node scripts/validate-scene.js <scene-file.json>');
    console.error('');
    console.error('Example:');
    console.error('  node scripts/validate-scene.js examples/scene-example.json');
    process.exit(2);
  }

  const sceneFile = args[0];
  const schemaPath = path.join(__dirname, '../schemas/scene.schema.json');

  console.log('Scene Validator');
  console.log('================');
  console.log(`Input: ${sceneFile}`);
  console.log(`Schema: ${schemaPath}`);
  console.log('');

  // Load scene file
  const sceneData = loadJsonFile(sceneFile);
  if (!sceneData) {
    process.exit(2);
  }

  // Validate
  const result = validateScene(sceneData, schemaPath);

  // Output results
  if (result.valid) {
    console.log('✅ Validation successful');
    console.log('');
    console.log('Scene details:');
    console.log(`  ID: ${sceneData.scene_id}`);
    console.log(`  Type: ${sceneData.type}`);
    console.log(`  Section: ${sceneData.section_id}`);
    console.log(`  Duration: ${sceneData.content.duration_ms}ms`);
    if (sceneData.content.title) {
      console.log(`  Title: ${sceneData.content.title}`);
    }
    console.log('');
    console.log(JSON.stringify({ valid: true, errors: [] }, null, 2));
    process.exit(0);
  } else {
    console.error('❌ Validation failed');
    console.error('');
    console.error(`Found ${result.errors.length} error(s):`);
    console.error('');

    result.errors.forEach((error, index) => {
      console.error(`${index + 1}. ${error.details}`);
    });

    console.error('');
    console.error(JSON.stringify({ valid: false, errors: result.errors }, null, 2));
    process.exit(1);
  }
}

// Run if executed directly
if (require.main === module) {
  main();
}

// Export for testing
module.exports = { validateScene, formatErrors };
