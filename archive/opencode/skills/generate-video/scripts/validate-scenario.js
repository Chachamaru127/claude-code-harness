#!/usr/bin/env node

/**
 * Scenario Validator
 *
 * Validates a scenario.json file against scenario.schema.json
 * Also performs semantic validation:
 * - Section ID uniqueness
 * - Section order correctness
 * - Duration estimates consistency
 *
 * Usage:
 *   node scripts/validate-scenario.js <scenario-file.json>
 *
 * Exit codes:
 *   0 - Validation successful
 *   1 - Validation failed (schema or semantic errors)
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
    const path = error.instancePath || error.path || 'root';
    const message = error.message || 'Unknown error';
    const params = error.params ? JSON.stringify(error.params) : '';

    return {
      path: path,
      message: message,
      keyword: error.keyword || 'semantic',
      params: params,
      details: `${path}: ${message}${params ? ` (${params})` : ''}`,
    };
  });
}

/**
 * Perform semantic validation on scenario sections
 */
function validateSemantics(scenarioData) {
  const errors = [];
  const sections = scenarioData.sections || [];

  // Check section ID uniqueness
  const sectionIds = new Set();
  const duplicateIds = new Set();

  sections.forEach((section, index) => {
    if (sectionIds.has(section.id)) {
      duplicateIds.add(section.id);
      errors.push({
        path: `/sections/${index}/id`,
        message: `Duplicate section ID: "${section.id}"`,
        keyword: 'uniqueness',
      });
    } else {
      sectionIds.add(section.id);
    }
  });

  // Check section order sequence
  const orders = sections.map((s) => s.order).sort((a, b) => a - b);
  for (let i = 0; i < orders.length; i++) {
    if (orders[i] !== i) {
      errors.push({
        path: '/sections',
        message: `Section order sequence is broken: expected ${i}, found ${orders[i]}`,
        keyword: 'order-sequence',
      });
      break;
    }
  }

  // Check for order duplicates
  const orderSet = new Set();
  sections.forEach((section, index) => {
    if (orderSet.has(section.order)) {
      errors.push({
        path: `/sections/${index}/order`,
        message: `Duplicate order value: ${section.order}`,
        keyword: 'order-duplicate',
      });
    } else {
      orderSet.add(section.order);
    }
  });

  // Check duration estimates are reasonable
  sections.forEach((section, index) => {
    if (section.duration_estimate_ms !== undefined) {
      if (section.duration_estimate_ms < 0) {
        errors.push({
          path: `/sections/${index}/duration_estimate_ms`,
          message: 'Duration cannot be negative',
          keyword: 'duration-negative',
        });
      }
      if (section.duration_estimate_ms > 3600000) {
        // 1 hour
        errors.push({
          path: `/sections/${index}/duration_estimate_ms`,
          message: 'Duration exceeds 1 hour (likely an error)',
          keyword: 'duration-excessive',
        });
      }
    }
  });

  return errors;
}

/**
 * Validate scenario data against schema
 */
function validateScenario(scenarioData, schemaPath) {
  // Load scenario schema
  const schema = loadJsonFile(schemaPath);
  if (!schema) {
    return {
      valid: false,
      errors: [{ message: 'Failed to load scenario schema', path: 'schema' }],
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

  // Validate data against schema
  const valid = validate(scenarioData);
  let schemaErrors = [];

  if (!valid) {
    schemaErrors = formatErrors(validate.errors);
  }

  // Perform semantic validation
  const semanticErrors = validateSemantics(scenarioData);

  // Combine errors
  const allErrors = [...schemaErrors, ...semanticErrors];

  if (allErrors.length > 0) {
    return {
      valid: false,
      errors: allErrors,
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
    console.error('Usage: node scripts/validate-scenario.js <scenario-file.json>');
    console.error('');
    console.error('Example:');
    console.error('  node scripts/validate-scenario.js examples/scenario-example.json');
    process.exit(2);
  }

  const scenarioFile = args[0];
  const schemaPath = path.join(__dirname, '../schemas/scenario.schema.json');

  console.log('Scenario Validator');
  console.log('==================');
  console.log(`Input: ${scenarioFile}`);
  console.log(`Schema: ${schemaPath}`);
  console.log('');

  // Load scenario file
  const scenarioData = loadJsonFile(scenarioFile);
  if (!scenarioData) {
    process.exit(2);
  }

  // Validate
  const result = validateScenario(scenarioData, schemaPath);

  // Output results
  if (result.valid) {
    console.log('✅ Validation successful');
    console.log('');
    console.log('Scenario details:');
    console.log(`  Title: ${scenarioData.title}`);
    console.log(`  Sections: ${scenarioData.sections.length}`);
    if (scenarioData.metadata.video_type) {
      console.log(`  Type: ${scenarioData.metadata.video_type}`);
    }
    if (scenarioData.metadata.target_funnel) {
      console.log(`  Funnel: ${scenarioData.metadata.target_funnel}`);
    }

    // Display section breakdown
    console.log('');
    console.log('Sections:');
    scenarioData.sections.forEach((section) => {
      const duration = section.duration_estimate_ms
        ? ` (${(section.duration_estimate_ms / 1000).toFixed(1)}s)`
        : '';
      console.log(`  ${section.order}. ${section.title}${duration}`);
    });

    console.log('');
    console.log(JSON.stringify({ valid: true, errors: [] }, null, 2));
    process.exit(0);
  } else {
    console.error('❌ Validation failed');
    console.error('');
    console.error(`Found ${result.errors.length} error(s):`);
    console.error('');

    // Group errors by type
    // Semantic keywords from validateSemantics: 'uniqueness', 'order-sequence', 'order-duplicate', 'duration-negative', 'duration-excessive'
    const SEMANTIC_KEYWORDS = ['uniqueness', 'order-sequence', 'order-duplicate', 'duration-negative', 'duration-excessive'];
    const schemaErrors = result.errors.filter((e) => !SEMANTIC_KEYWORDS.includes(e.keyword));
    const semanticErrors = result.errors.filter((e) => SEMANTIC_KEYWORDS.includes(e.keyword));

    if (schemaErrors.length > 0) {
      console.error('Schema Errors:');
      schemaErrors.forEach((error, index) => {
        console.error(`  ${index + 1}. ${error.details}`);
      });
      console.error('');
    }

    if (semanticErrors.length > 0) {
      console.error('Semantic Errors:');
      semanticErrors.forEach((error, index) => {
        console.error(`  ${index + 1}. ${error.details}`);
      });
      console.error('');
    }

    console.error(JSON.stringify({ valid: false, errors: result.errors }, null, 2));
    process.exit(1);
  }
}

// Run if executed directly
if (require.main === module) {
  main();
}

// Export for testing
module.exports = { validateScenario, validateSemantics, formatErrors };
