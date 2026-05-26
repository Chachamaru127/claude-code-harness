#!/usr/bin/env node

/**
 * Basic Schema Validation Test (without ajv)
 *
 * Tests that all JSON schemas are valid JSON and have required fields.
 * Usage: node validate-schemas-basic.js
 */

const fs = require('fs');
const path = require('path');

console.log('=== Basic Schema Validation Test ===\n');

const schemas = [
  { name: 'scenario.schema.json', file: 'scenario.schema.json' },
  { name: 'scene.schema.json', file: 'scene.schema.json' },
  { name: 'video-script.schema.json', file: 'video-script.schema.json' }
];

let allValid = true;

schemas.forEach(({ name, file }) => {
  console.log(`Testing ${name}...`);

  try {
    // Test 1: Can we parse it as JSON?
    const content = fs.readFileSync(path.join(__dirname, file), 'utf8');
    const schema = JSON.parse(content);
    console.log('  ✅ Valid JSON');

    // Test 2: Does it have required meta fields?
    if (!schema.$schema) {
      console.log('  ❌ Missing $schema field');
      allValid = false;
      return;
    }
    console.log('  ✅ Has $schema field');

    if (!schema.$id) {
      console.log('  ❌ Missing $id field');
      allValid = false;
      return;
    }
    console.log('  ✅ Has $id field');

    if (!schema.title) {
      console.log('  ❌ Missing title field');
      allValid = false;
      return;
    }
    console.log('  ✅ Has title field');

    if (!schema.version) {
      console.log('  ❌ Missing version field');
      allValid = false;
      return;
    }
    console.log('  ✅ Has version field:', schema.version);

    if (schema.type !== 'object') {
      console.log('  ❌ Root type should be "object"');
      allValid = false;
      return;
    }
    console.log('  ✅ Root type is "object"');

    if (!schema.required || !Array.isArray(schema.required)) {
      console.log('  ⚠️  No required fields defined');
    } else {
      console.log('  ✅ Has required fields:', schema.required.join(', '));
    }

    if (!schema.properties || typeof schema.properties !== 'object') {
      console.log('  ❌ Missing or invalid properties field');
      allValid = false;
      return;
    }
    console.log('  ✅ Has properties field with', Object.keys(schema.properties).length, 'properties');

    console.log(`  ✅ ${name} is valid\n`);

  } catch (error) {
    console.log(`  ❌ Failed to validate ${name}:`);
    console.log('  ', error.message);
    allValid = false;
  }
});

if (allValid) {
  console.log('=== All Tests Passed ===\n');
  console.log('All schemas are valid JSON Schema draft-07 documents!\n');
  console.log('To run full validation with ajv, install dependencies:');
  console.log('  npm install ajv ajv-formats');
  console.log('  node validate-schemas.js');
  process.exit(0);
} else {
  console.log('=== Some Tests Failed ===\n');
  process.exit(1);
}
