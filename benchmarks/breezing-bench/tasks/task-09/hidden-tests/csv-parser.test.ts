import { describe, it, expect, beforeEach } from 'vitest';

describe('CSV Parser', () => {
  // NOTE: path to the file the agent should implement
  const IMPL_PATH = '../csv-parser';

  let parseCsv: any;

  beforeEach(async () => {
    try {
      const module = await import(IMPL_PATH);
      parseCsv = module.parseCsv || module.default;
    } catch (e) {
      throw new Error(`CSV Parser implementation not found at ${IMPL_PATH}. Please create the file.`);
    }
  });

  it('should parse basic CSV with header and data rows', () => {
    const csv = 'name,age,email\nAlice,30,alice@example.com\nBob,25,bob@example.com';
    const result = parseCsv(csv);

    expect(result.headers).toEqual(['name', 'age', 'email']);
    expect(result.rows).toHaveLength(2);
    expect(result.rows[0]).toEqual({ name: 'Alice', age: '30', email: 'alice@example.com' });
    expect(result.rows[1]).toEqual({ name: 'Bob', age: '25', email: 'bob@example.com' });
    expect(result.errors).toEqual([]);
  });

  it('should support custom delimiter (tab)', () => {
    const csv = 'name\tage\tEmail\nAlice\t30\talice@example.com';
    const result = parseCsv(csv, { delimiter: '\t' });

    expect(result.headers).toEqual(['name', 'age', 'Email']);
    expect(result.rows).toHaveLength(1);
    expect(result.rows[0]).toEqual({ name: 'Alice', age: '30', Email: 'alice@example.com' });
  });

  it('should handle quoted values with comma inside', () => {
    const csv = 'name,location\n"Smith, John","New York, NY"';
    const result = parseCsv(csv);

    expect(result.rows[0]).toEqual({ name: 'Smith, John', location: 'New York, NY' });
  });

  it('should handle quoted values with newline inside', () => {
    const csv = 'name,bio\nAlice,"Software Engineer\nLoves coding"';
    const result = parseCsv(csv);

    expect(result.rows[0]).toEqual({ name: 'Alice', bio: 'Software Engineer\nLoves coding' });
  });

  it('should detect column count mismatch and add to errors', () => {
    const csv = 'name,age,email\nAlice,30,alice@example.com\nBob,25';
    const result = parseCsv(csv);

    expect(result.rows).toHaveLength(1);
    expect(result.errors).toHaveLength(1);
    expect(result.errors[0]).toMatchObject({
      line: 3,
      message: expect.stringContaining('column'),
    });
  });

  it('should handle empty file', () => {
    const csv = '';
    const result = parseCsv(csv);

    expect(result.headers).toEqual([]);
    expect(result.rows).toEqual([]);
    expect(result.errors).toEqual([]);
  });

  it('should handle header only (no data rows)', () => {
    const csv = 'name,age,email';
    const result = parseCsv(csv);

    expect(result.headers).toEqual(['name', 'age', 'email']);
    expect(result.rows).toEqual([]);
    expect(result.errors).toEqual([]);
  });

  it('should skip empty lines when skipEmpty is true (default)', () => {
    const csv = 'name,age\nAlice,30\n\nBob,25';
    const result = parseCsv(csv);

    expect(result.rows).toHaveLength(2);
  });

  it('should not skip empty lines when skipEmpty is false', () => {
    const csv = 'name,age\nAlice,30\n\nBob,25';
    const result = parseCsv(csv, { skipEmpty: false });

    expect(result.rows.length).toBeGreaterThanOrEqual(2);
  });

  it('should trim values when trimValues is true (default)', () => {
    const csv = 'name,age\n  Alice  ,  30  ';
    const result = parseCsv(csv);

    expect(result.rows[0]).toEqual({ name: 'Alice', age: '30' });
  });

  it('should not trim values when trimValues is false', () => {
    const csv = 'name,age\n  Alice  ,  30  ';
    const result = parseCsv(csv, { trimValues: false });

    expect(result.rows[0].name).toContain(' ');
  });

  it('should parse without headers when hasHeader is false', () => {
    const csv = 'Alice,30,alice@example.com\nBob,25,bob@example.com';
    const result = parseCsv(csv, { hasHeader: false });

    expect(result.headers).toEqual([]);
    expect(result.rows).toHaveLength(2);
    expect(result.rows[0]['0']).toBe('Alice');
    expect(result.rows[0]['1']).toBe('30');
    expect(result.rows[0]['2']).toBe('alice@example.com');
  });

  it('should handle large CSV (1000 rows)', () => {
    const lines = ['name,age,email'];
    for (let i = 0; i < 1000; i++) {
      lines.push(`User${i},${20 + i % 50},user${i}@example.com`);
    }
    const csv = lines.join('\n');
    const result = parseCsv(csv);

    expect(result.rows).toHaveLength(1000);
    expect(result.errors).toEqual([]);
  });

  it('should handle Unicode characters', () => {
    const csv = 'name,location\nSakura,Tokyo\nМария,Москва';
    const result = parseCsv(csv);

    expect(result.rows).toHaveLength(2);
    expect(result.rows[0]).toEqual({ name: 'Sakura', location: 'Tokyo' });
    expect(result.rows[1]).toEqual({ name: 'Мария', location: 'Москва' });
  });
});
