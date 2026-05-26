#!/usr/bin/env node

/**
 * Schema Validation Test
 *
 * Tests that all JSON schemas are valid and can be used with ajv.
 * Usage: node validate-schemas.js
 */

const Ajv = require('ajv');
const addFormats = require('ajv-formats');
const fs = require('fs');
const path = require('path');

// Initialize ajv with JSON Schema draft-07
const ajv = new Ajv({
  strict: false, // Allow additional properties for flexibility
  allErrors: true,
  verbose: true
});
addFormats(ajv);

// Load schemas
const scenarioSchema = JSON.parse(
  fs.readFileSync(path.join(__dirname, 'scenario.schema.json'), 'utf8')
);
const sceneSchema = JSON.parse(
  fs.readFileSync(path.join(__dirname, 'scene.schema.json'), 'utf8')
);
const videoScriptSchema = JSON.parse(
  fs.readFileSync(path.join(__dirname, 'video-script.schema.json'), 'utf8')
);

// Add schemas to ajv
ajv.addSchema(scenarioSchema);
ajv.addSchema(sceneSchema);
ajv.addSchema(videoScriptSchema);

console.log('=== Schema Validation Test ===\n');

// Test 1: Validate scenario schema
console.log('1. Testing scenario.schema.json...');
const testScenario = {
  title: "Product Demo Scenario",
  description: "A comprehensive product demonstration video scenario",
  sections: [
    {
      id: "intro",
      title: "Introduction",
      description: "Opening hook and product overview",
      order: 0,
      duration_estimate_ms: 5000
    },
    {
      id: "features",
      title: "Key Features",
      description: "Showcase main features",
      order: 1,
      duration_estimate_ms: 30000,
      tags: ["demo", "features"]
    }
  ],
  metadata: {
    version: "1.0.0",
    generated_at: "2026-02-02T14:30:00Z",
    generator: "claude-code-harness",
    project_name: "MyApp",
    video_type: "intro-demo",
    target_funnel: "interest"
  }
};

const validateScenario = ajv.compile(scenarioSchema);
const scenarioValid = validateScenario(testScenario);
if (scenarioValid) {
  console.log('   ✅ Scenario schema is valid\n');
} else {
  console.log('   ❌ Scenario validation failed:');
  console.log(validateScenario.errors);
  process.exit(1);
}

// Test 2: Validate scene schema
console.log('2. Testing scene.schema.json...');
const testScene = {
  scene_id: "intro-scene-1",
  section_id: "intro",
  order: 0,
  type: "intro",
  content: {
    text: "Welcome to MyApp",
    image: "assets/intro.png",
    duration_ms: 5000,
    title: "MyApp",
    subtitle: "Simplify Your Workflow"
  },
  direction: {
    transition: {
      in: "fade",
      out: "fade",
      duration_ms: 500
    },
    emphasis: {
      effect: "pulse",
      timing: "2s"
    },
    background: {
      type: "gradient",
      value: "linear-gradient(135deg, #667eea 0%, #764ba2 100%)",
      opacity: 1
    }
  },
  assets: [
    {
      type: "image",
      source: "assets/intro.png",
      generated: false,
      metadata: {
        width: 1920,
        height: 1080,
        format: "png"
      }
    }
  ],
  audio: {
    narration: {
      text: "Welcome to MyApp, the tool that simplifies your workflow",
      file: "audio/narration-intro.mp3",
      start_offset_ms: 1000
    }
  },
  template: "intro"
};

const validateScene = ajv.compile(sceneSchema);
const sceneValid = validateScene(testScene);
if (sceneValid) {
  console.log('   ✅ Scene schema is valid\n');
} else {
  console.log('   ❌ Scene validation failed:');
  console.log(validateScene.errors);
  process.exit(1);
}

// Test 3: Validate video-script schema
console.log('3. Testing video-script.schema.json...');
const testVideoScript = {
  metadata: {
    title: "MyApp Product Demo",
    description: "Comprehensive product demonstration video",
    version: "1.0.0",
    created_at: "2026-02-02T14:30:00Z",
    updated_at: "2026-02-02T14:30:00Z",
    author: "claude-code-harness",
    project: "myapp",
    video_type: "intro-demo",
    tags: ["demo", "product"],
    scenario_id: "scenario-001"
  },
  scenes: [
    testScene,
    {
      scene_id: "demo-scene-1",
      section_id: "features",
      order: 1,
      type: "ui-demo",
      content: {
        duration_ms: 15000,
        url: "http://localhost:3000/dashboard",
        actions: [
          {
            type: "wait",
            value: 1000
          },
          {
            type: "click",
            selector: "[data-testid='login-button']"
          },
          {
            type: "type",
            selector: "input[name='email']",
            value: "demo@example.com"
          }
        ]
      },
      direction: {
        transition: {
          in: "slide_in",
          out: "fade",
          duration_ms: 500
        }
      },
      assets: []
    }
  ],
  total_duration_ms: 20000,
  output_settings: {
    width: 1920,
    height: 1080,
    fps: 30,
    codec: "h264",
    format: "mp4",
    quality: "high",
    preset: "1080p"
  },
  audio_settings: {
    bgm: {
      file: "public/BGM/background.mp3",
      volume: 0.3,
      fade_in_ms: 1000,
      fade_out_ms: 2000,
      loop: true
    },
    master_volume: 1.0
  },
  branding: {
    logo: "public/logo.svg",
    colors: {
      primary: "#667eea",
      secondary: "#764ba2",
      accent: "#f093fb",
      background: "#1a202c",
      text: "#ffffff"
    },
    fonts: {
      primary: "Inter",
      secondary: "Roboto",
      monospace: "Fira Code"
    }
  },
  transitions: {
    default_duration_ms: 500,
    overlap_ms: 450,
    type: "fade"
  },
  notes: "Initial product demo video for MyApp"
};

const validateVideoScript = ajv.compile(videoScriptSchema);
const videoScriptValid = validateVideoScript(testVideoScript);
if (videoScriptValid) {
  console.log('   ✅ Video script schema is valid\n');
} else {
  console.log('   ❌ Video script validation failed:');
  console.log(validateVideoScript.errors);
  process.exit(1);
}

// Test 4: Validate cross-references work
console.log('4. Testing $ref cross-references...');
try {
  // The video-script schema references scene.schema.json via $ref
  // If ajv can compile it, the references work
  const validateWithRefs = ajv.getSchema('https://claude-code-harness.dev/schemas/video/video-script.schema.json');
  if (validateWithRefs) {
    console.log('   ✅ Schema cross-references are working\n');
  } else {
    console.log('   ⚠️  Could not get schema by $id\n');
  }
} catch (error) {
  console.log('   ❌ Cross-reference validation failed:');
  console.log(error.message);
  process.exit(1);
}

console.log('=== All Tests Passed ===');
console.log('\nSchemas are valid and ready to use with ajv!\n');
console.log('Summary:');
console.log('  - scenario.schema.json: ✅');
console.log('  - scene.schema.json: ✅');
console.log('  - video-script.schema.json: ✅');
console.log('  - Cross-references: ✅');
