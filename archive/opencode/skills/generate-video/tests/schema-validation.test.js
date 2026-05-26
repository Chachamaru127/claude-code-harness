/**
 * @file schema-validation.test.js
 * @description Test to verify asset manifest schema is valid
 */

const Ajv = require('ajv');
const addFormats = require('ajv-formats');
const fs = require('fs');
const path = require('path');

describe('Asset Manifest Schema', () => {
  let ajv;
  let schema;

  beforeAll(() => {
    // Initialize AJV validator
    ajv = new Ajv({ allErrors: true, strict: true });
    addFormats(ajv);

    // Load schema
    const schemaPath = path.join(__dirname, '../schemas/assets.manifest.schema.json');
    schema = JSON.parse(fs.readFileSync(schemaPath, 'utf-8'));
  });

  test('schema is valid JSON Schema', () => {
    expect(() => ajv.compile(schema)).not.toThrow();
  });

  test('validates correct manifest', () => {
    const validate = ajv.compile(schema);
    const validManifest = {
      version: '1.0.0',
      generated_at: '2026-02-02T14:30:00Z',
      project: {
        name: 'Test Project',
        video_id: 'video-20260202-abc12345',
      },
      assets: [
        {
          id: 'test-asset',
          path: 'assets/test.webp',
          type: 'image',
          hash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          size: 1024,
        },
      ],
    };

    const valid = validate(validManifest);
    if (!valid) {
      console.error('Validation errors:', validate.errors);
    }
    expect(valid).toBe(true);
  });

  test('rejects manifest without required fields', () => {
    const validate = ajv.compile(schema);
    const invalidManifest = {
      version: '1.0.0',
      // missing generated_at and assets
    };

    const valid = validate(invalidManifest);
    expect(valid).toBe(false);
    expect(validate.errors).toBeDefined();
  });

  test('rejects asset with invalid hash format', () => {
    const validate = ajv.compile(schema);
    const invalidManifest = {
      version: '1.0.0',
      generated_at: '2026-02-02T14:30:00Z',
      assets: [
        {
          id: 'test-asset',
          path: 'assets/test.webp',
          type: 'image',
          hash: 'invalid-hash', // Not SHA-256 format
          size: 1024,
        },
      ],
    };

    const valid = validate(invalidManifest);
    expect(valid).toBe(false);
    expect(validate.errors.some(err => err.instancePath.includes('hash'))).toBe(true);
  });

  test('validates asset with optional fields', () => {
    const validate = ajv.compile(schema);
    const manifestWithOptionals = {
      version: '1.0.0',
      generated_at: '2026-02-02T14:30:00Z',
      assets: [
        {
          id: 'test-asset',
          path: 'assets/test.webp',
          type: 'image',
          hash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          size: 1024,
          mime_type: 'image/webp',
          dimensions: {
            width: 1920,
            height: 1080,
          },
          source: {
            type: 'generated',
            generator: 'nano-banana-pro',
            seed: 42,
          },
          created_at: '2026-02-02T14:25:00Z',
          verified_at: '2026-02-02T14:30:00Z',
        },
      ],
    };

    const valid = validate(manifestWithOptionals);
    if (!valid) {
      console.error('Validation errors:', validate.errors);
    }
    expect(valid).toBe(true);
  });

  test('rejects invalid asset type', () => {
    const validate = ajv.compile(schema);
    const invalidManifest = {
      version: '1.0.0',
      generated_at: '2026-02-02T14:30:00Z',
      assets: [
        {
          id: 'test-asset',
          path: 'assets/test.webp',
          type: 'invalid-type', // Not in enum
          hash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          size: 1024,
        },
      ],
    };

    const valid = validate(invalidManifest);
    expect(valid).toBe(false);
  });
});
