/**
 * @file character-schema.test.js
 * @description Phase 10: Test character schema validation (future extension)
 */

const Ajv = require('ajv');
const addFormats = require('ajv-formats');
const fs = require('fs');
const path = require('path');

describe('Character Schema (Phase 10)', () => {
  let ajv;
  let schema;

  beforeAll(() => {
    ajv = new Ajv({ allErrors: true, strict: true });
    addFormats(ajv);

    const schemaPath = path.join(__dirname, '../schemas/character.schema.json');
    schema = JSON.parse(fs.readFileSync(schemaPath, 'utf-8'));
  });

  test('schema is valid JSON Schema', () => {
    expect(() => ajv.compile(schema)).not.toThrow();
  });

  test('validates minimal character definition', () => {
    const validate = ajv.compile(schema);
    const minimalCharacter = {
      character_id: 'narrator',
      name: 'Narrator',
      voice: {
        provider: 'google-cloud-tts',
      },
      appearance: {
        type: 'icon',
      },
    };

    const valid = validate(minimalCharacter);
    if (!valid) {
      console.error('Validation errors:', validate.errors);
    }
    expect(valid).toBe(true);
  });

  test('validates complete character with all optional fields', () => {
    const validate = ajv.compile(schema);
    const completeCharacter = {
      character_id: 'expert-reviewer',
      name: 'Expert Reviewer',
      role: 'expert',
      voice: {
        provider: 'elevenlabs',
        voice_id: 'elevenlabs:josh',
        language: 'en-US',
        gender: 'male',
        pitch: 0,
        speed: 1.0,
        volume: 0,
        style: 'professional',
        emotion: 'neutral',
      },
      appearance: {
        type: 'avatar',
        avatar: {
          style: 'minimalist',
          base_image: 'assets/avatars/expert.png',
          expressions: {
            neutral: 'assets/avatars/expert_neutral.png',
            happy: 'assets/avatars/expert_happy.png',
            thinking: 'assets/avatars/expert_thinking.png',
          },
          color_scheme: {
            primary: '#10b981',
            secondary: '#065f46',
            background: '#f0fdf4',
          },
        },
        position: 'right',
        size_preset: 'medium',
      },
      dialogue_style: {
        text_box: {
          style: 'bubble',
          background_color: 'rgba(0, 0, 0, 0.8)',
          text_color: '#FFFFFF',
          font_size: 24,
          font_family: 'sans-serif',
          padding: 16,
          border_radius: 8,
        },
        animation: {
          enter: 'fade',
          exit: 'fade',
          speaking_indicator: true,
          pulse_on_speak: true,
        },
      },
      personality: {
        traits: ['professional', 'technical', 'calm'],
        speaking_pattern: 'Uses technical jargon with clear explanations',
        expertise_level: 'expert',
      },
      metadata: {
        created_at: '2026-02-02T00:00:00Z',
        updated_at: '2026-02-02T12:00:00Z',
        author: 'Claude Code Harness',
        version: '1.0.0',
        tags: ['expert', 'reviewer', 'technical'],
        notes: 'Character for architecture explanation videos',
      },
    };

    const valid = validate(completeCharacter);
    if (!valid) {
      console.error('Validation errors:', validate.errors);
    }
    expect(valid).toBe(true);
  });

  test('rejects character without required fields', () => {
    const validate = ajv.compile(schema);
    const invalidCharacter = {
      character_id: 'test',
      // missing: name, voice, appearance
    };

    const valid = validate(invalidCharacter);
    expect(valid).toBe(false);
    expect(validate.errors).toBeDefined();
  });

  test('rejects invalid character_id pattern', () => {
    const validate = ajv.compile(schema);
    const invalidCharacter = {
      character_id: 'Invalid ID!', // Has space and special char
      name: 'Test',
      voice: { provider: 'google-cloud-tts' },
      appearance: { type: 'icon' },
    };

    const valid = validate(invalidCharacter);
    expect(valid).toBe(false);
  });

  test('rejects invalid TTS provider', () => {
    const validate = ajv.compile(schema);
    const invalidCharacter = {
      character_id: 'test',
      name: 'Test',
      voice: {
        provider: 'invalid-provider', // Not in enum
      },
      appearance: { type: 'icon' },
    };

    const valid = validate(invalidCharacter);
    expect(valid).toBe(false);
  });

  test('validates voice pitch range', () => {
    const validate = ajv.compile(schema);

    // Valid pitch
    const validCharacter = {
      character_id: 'test',
      name: 'Test',
      voice: {
        provider: 'google-cloud-tts',
        pitch: 10, // Within -20 to 20
      },
      appearance: { type: 'icon' },
    };

    expect(validate(validCharacter)).toBe(true);

    // Invalid pitch (too high)
    const invalidCharacter = {
      character_id: 'test2',
      name: 'Test2',
      voice: {
        provider: 'google-cloud-tts',
        pitch: 25, // Exceeds max 20
      },
      appearance: { type: 'icon' },
    };

    expect(validate(invalidCharacter)).toBe(false);
  });

  test('validates voice speed range', () => {
    const validate = ajv.compile(schema);

    // Valid speed
    const validCharacter = {
      character_id: 'test',
      name: 'Test',
      voice: {
        provider: 'google-cloud-tts',
        speed: 1.5, // Within 0.25 to 4.0
      },
      appearance: { type: 'icon' },
    };

    expect(validate(validCharacter)).toBe(true);

    // Invalid speed (too slow)
    const invalidCharacter = {
      character_id: 'test2',
      name: 'Test2',
      voice: {
        provider: 'google-cloud-tts',
        speed: 0.1, // Below min 0.25
      },
      appearance: { type: 'icon' },
    };

    expect(validate(invalidCharacter)).toBe(false);
  });

  test('validates appearance type enum', () => {
    const validate = ajv.compile(schema);

    // Valid types
    const validTypes = ['avatar', 'icon', 'image', 'video', 'none'];

    validTypes.forEach((type) => {
      const character = {
        character_id: `test-${type}`,
        name: 'Test',
        voice: { provider: 'google-cloud-tts' },
        appearance: { type: type },
      };

      expect(validate(character)).toBe(true);
    });

    // Invalid type
    const invalidCharacter = {
      character_id: 'test',
      name: 'Test',
      voice: { provider: 'google-cloud-tts' },
      appearance: { type: 'invalid-type' },
    };

    expect(validate(invalidCharacter)).toBe(false);
  });

  test('validates language code pattern', () => {
    const validate = ajv.compile(schema);

    const validLanguages = [
      { lang: 'ja', id: 'test-ja' },
      { lang: 'en', id: 'test-en' },
      { lang: 'es', id: 'test-es' },
      { lang: 'en-US', id: 'test-enus' },
      { lang: 'en-GB', id: 'test-engb' },
      { lang: 'ja-JP', id: 'test-jajp' },
    ];

    validLanguages.forEach(({ lang, id }) => {
      const character = {
        character_id: id,
        name: 'Test',
        voice: {
          provider: 'google-cloud-tts',
          language: lang,
        },
        appearance: { type: 'icon' },
      };

      const valid = validate(character);
      if (!valid) {
        console.log(`Language ${lang} failed:`, validate.errors);
      }
      expect(valid).toBe(true);
    });

    // Invalid language
    const invalidCharacter = {
      character_id: 'test',
      name: 'Test',
      voice: {
        provider: 'google-cloud-tts',
        language: 'INVALID',
      },
      appearance: { type: 'icon' },
    };

    expect(validate(invalidCharacter)).toBe(false);
  });

  test('validates schema examples', () => {
    const validate = ajv.compile(schema);

    // Test both examples in the schema
    expect(schema.examples).toBeDefined();
    expect(schema.examples.length).toBeGreaterThan(0);

    schema.examples.forEach((example, index) => {
      const valid = validate(example);
      if (!valid) {
        console.error(`Example ${index} validation errors:`, validate.errors);
      }
      expect(valid).toBe(true);
    });
  });
});
