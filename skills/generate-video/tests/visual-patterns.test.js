/**
 * Visual Patterns Schema Validation Tests
 * Phase 6: Task 6.1
 */

const Ajv = require('ajv');
const addFormats = require('ajv-formats');
const fs = require('fs');
const path = require('path');

describe('Visual Patterns Schema', () => {
  let ajv;
  let schema;

  beforeAll(() => {
    // Initialize AJV with strict mode disabled for custom keywords
    ajv = new Ajv({ strict: false });
    addFormats(ajv);

    // Load schema
    const schemaPath = path.join(__dirname, '../schemas/visual-patterns.schema.json');
    schema = JSON.parse(fs.readFileSync(schemaPath, 'utf-8'));
  });

  describe('Schema Structure', () => {
    test('schema is valid JSON Schema', () => {
      expect(() => ajv.compile(schema)).not.toThrow();
    });

    test('has required metadata fields', () => {
      expect(schema).toHaveProperty('$schema');
      expect(schema).toHaveProperty('$id');
      expect(schema).toHaveProperty('title');
      expect(schema).toHaveProperty('description');
      expect(schema).toHaveProperty('version');
    });

    test('defines all four pattern types', () => {
      expect(schema.properties.type.enum).toEqual([
        'comparison',
        'concept',
        'flow',
        'highlight'
      ]);
    });
  });

  describe('Comparison Pattern', () => {
    test('validates valid comparison pattern', () => {
      const validate = ajv.compile(schema);
      const validComparison = {
        type: 'comparison',
        topic: 'Task Management Improvement',
        style: 'modern',
        comparison: {
          leftSide: {
            label: 'Before',
            items: ['Manual spreadsheet updates', 'Frequent missed updates', '30 minutes to check status'],
            icon: 'x',
            sentiment: 'negative'
          },
          rightSide: {
            label: 'After',
            items: ['Automatic dashboard updates', 'Real-time sync', 'Status at a glance'],
            icon: 'check',
            sentiment: 'positive'
          },
          divider: 'arrow'
        }
      };

      const result = validate(validComparison);
      if (!result) {
        console.error('Validation errors:', validate.errors);
      }
      expect(result).toBe(true);
    });

    test('rejects comparison without leftSide', () => {
      const validate = ajv.compile(schema);
      const invalid = {
        type: 'comparison',
        topic: 'Test',
        comparison: {
          rightSide: {
            label: 'After',
            items: ['Item 1']
          }
        }
      };

      expect(validate(invalid)).toBe(false);
    });

    test('rejects comparison without rightSide', () => {
      const validate = ajv.compile(schema);
      const invalid = {
        type: 'comparison',
        topic: 'Test',
        comparison: {
          leftSide: {
            label: 'Before',
            items: ['Item 1']
          }
        }
      };

      expect(validate(invalid)).toBe(false);
    });
  });

  describe('Concept Pattern', () => {
    test('validates valid concept pattern', () => {
      const validate = ajv.compile(schema);
      const validConcept = {
        type: 'concept',
        topic: 'Microservices Architecture',
        style: 'technical',
        concept: {
          elements: [
            {
              id: 'api-gateway',
              label: 'API Gateway',
              description: 'Entry point for all requests',
              level: 0,
              icon: 'cloud',
              emphasis: 'high'
            },
            {
              id: 'auth-service',
              label: 'Auth Service',
              level: 1,
              parentId: 'api-gateway',
              icon: 'server',
              emphasis: 'medium'
            }
          ],
          relationships: [
            {
              from: 'api-gateway',
              to: 'auth-service',
              label: 'Authenticate',
              type: 'flow'
            }
          ],
          layout: 'hierarchy'
        }
      };

      const result = validate(validConcept);
      if (!result) {
        console.error('Validation errors:', validate.errors);
      }
      expect(result).toBe(true);
    });

    test('rejects concept with less than 2 elements', () => {
      const validate = ajv.compile(schema);
      const invalid = {
        type: 'concept',
        topic: 'Test',
        concept: {
          elements: [
            {
              id: 'single',
              label: 'Single Element'
            }
          ],
          layout: 'hierarchy'
        }
      };

      expect(validate(invalid)).toBe(false);
    });

    test('validates concept with relationships', () => {
      const validate = ajv.compile(schema);
      const valid = {
        type: 'concept',
        topic: 'Test',
        concept: {
          elements: [
            { id: 'a', label: 'A' },
            { id: 'b', label: 'B' }
          ],
          relationships: [
            { from: 'a', to: 'b', type: 'dependency' }
          ]
        }
      };

      expect(validate(valid)).toBe(true);
    });
  });

  describe('Flow Pattern', () => {
    test('validates valid flow pattern', () => {
      const validate = ajv.compile(schema);
      const validFlow = {
        type: 'flow',
        topic: 'Video Generation Flow',
        style: 'modern',
        flow: {
          steps: [
            {
              id: 'analyze',
              label: 'Analyze Codebase',
              description: 'Detect project structure',
              order: 1,
              type: 'start',
              icon: 'circle',
              duration: '10 seconds'
            },
            {
              id: 'plan',
              label: 'Generate Scenario',
              order: 2,
              type: 'process',
              icon: 'square',
              duration: '20 seconds'
            },
            {
              id: 'render',
              label: 'Render Video',
              order: 3,
              type: 'end',
              icon: 'hexagon',
              duration: '30 seconds'
            }
          ],
          direction: 'horizontal',
          arrowStyle: 'solid',
          showNumbers: true
        }
      };

      const result = validate(validFlow);
      if (!result) {
        console.error('Validation errors:', validate.errors);
      }
      expect(result).toBe(true);
    });

    test('rejects flow with less than 2 steps', () => {
      const validate = ajv.compile(schema);
      const invalid = {
        type: 'flow',
        topic: 'Test',
        flow: {
          steps: [
            { id: 'single', label: 'Single Step', order: 1 }
          ]
        }
      };

      expect(validate(invalid)).toBe(false);
    });

    test('validates different flow directions', () => {
      const validate = ajv.compile(schema);

      ['horizontal', 'vertical', 'zigzag'].forEach(direction => {
        const valid = {
          type: 'flow',
          topic: 'Test',
          flow: {
            steps: [
              { id: 'a', label: 'A', order: 1 },
              { id: 'b', label: 'B', order: 2 }
            ],
            direction
          }
        };

        expect(validate(valid)).toBe(true);
      });
    });
  });

  describe('Highlight Pattern', () => {
    test('validates valid highlight pattern', () => {
      const validate = ajv.compile(schema);
      const validHighlight = {
        type: 'highlight',
        topic: 'Product Value',
        style: 'gradient',
        highlight: {
          mainText: '95% Time Saved',
          subText: 'Development teams freed from manual tasks',
          icon: 'rocket',
          position: 'center',
          effect: 'glow',
          fontSize: 'xlarge',
          emphasis: 'high'
        }
      };

      const result = validate(validHighlight);
      if (!result) {
        console.error('Validation errors:', validate.errors);
      }
      expect(result).toBe(true);
    });

    test('rejects highlight without mainText', () => {
      const validate = ajv.compile(schema);
      const invalid = {
        type: 'highlight',
        topic: 'Test',
        highlight: {
          subText: 'Only subtitle'
        }
      };

      expect(validate(invalid)).toBe(false);
    });

    test('validates different icon types', () => {
      const validate = ajv.compile(schema);
      const icons = ['star', 'check', 'alert', 'trophy', 'rocket', 'fire', 'bolt', 'none'];

      icons.forEach(icon => {
        const valid = {
          type: 'highlight',
          topic: 'Test',
          highlight: {
            mainText: 'Test Message',
            icon
          }
        };

        expect(validate(valid)).toBe(true);
      });
    });
  });

  describe('Color Scheme', () => {
    test('validates valid hex color codes', () => {
      const validate = ajv.compile(schema);
      const valid = {
        type: 'highlight',
        topic: 'Test',
        colorScheme: {
          primary: '#3B82F6',
          secondary: '#10B981',
          accent: '#F59E0B',
          background: '#1F2937'
        },
        highlight: {
          mainText: 'Test'
        }
      };

      expect(validate(valid)).toBe(true);
    });

    test('rejects invalid hex color codes', () => {
      const validate = ajv.compile(schema);
      const invalid = {
        type: 'highlight',
        topic: 'Test',
        colorScheme: {
          primary: 'blue' // Invalid: not hex format
        },
        highlight: {
          mainText: 'Test'
        }
      };

      expect(validate(invalid)).toBe(false);
    });
  });

  describe('Dimensions', () => {
    test('validates custom dimensions', () => {
      const validate = ajv.compile(schema);
      const valid = {
        type: 'highlight',
        topic: 'Test',
        dimensions: {
          width: 1920,
          height: 1080,
          aspectRatio: '16:9'
        },
        highlight: {
          mainText: 'Test'
        }
      };

      expect(validate(valid)).toBe(true);
    });

    test('rejects dimensions outside valid range', () => {
      const validate = ajv.compile(schema);
      const invalid = {
        type: 'highlight',
        topic: 'Test',
        dimensions: {
          width: 100, // Too small (min: 256)
          height: 1080
        },
        highlight: {
          mainText: 'Test'
        }
      };

      expect(validate(invalid)).toBe(false);
    });
  });

  describe('Generation Settings', () => {
    test('validates generation settings', () => {
      const validate = ajv.compile(schema);
      const valid = {
        type: 'highlight',
        topic: 'Test',
        generation: {
          seed: 42,
          quality: 'high',
          retries: 3
        },
        highlight: {
          mainText: 'Test'
        }
      };

      expect(validate(valid)).toBe(true);
    });

    test('validates different quality levels', () => {
      const validate = ajv.compile(schema);
      const qualities = ['draft', 'standard', 'high'];

      qualities.forEach(quality => {
        const valid = {
          type: 'highlight',
          topic: 'Test',
          generation: { quality },
          highlight: { mainText: 'Test' }
        };

        expect(validate(valid)).toBe(true);
      });
    });
  });

  describe('oneOf Pattern Enforcement', () => {
    test('rejects comparison type without comparison field', () => {
      const validate = ajv.compile(schema);
      const invalid = {
        type: 'comparison',
        topic: 'Test'
        // Missing comparison field
      };

      expect(validate(invalid)).toBe(false);
    });

    test('rejects concept type without concept field', () => {
      const validate = ajv.compile(schema);
      const invalid = {
        type: 'concept',
        topic: 'Test'
        // Missing concept field
      };

      expect(validate(invalid)).toBe(false);
    });

    test('rejects flow type without flow field', () => {
      const validate = ajv.compile(schema);
      const invalid = {
        type: 'flow',
        topic: 'Test'
        // Missing flow field
      };

      expect(validate(invalid)).toBe(false);
    });

    test('rejects highlight type without highlight field', () => {
      const validate = ajv.compile(schema);
      const invalid = {
        type: 'highlight',
        topic: 'Test'
        // Missing highlight field
      };

      expect(validate(invalid)).toBe(false);
    });
  });
});
