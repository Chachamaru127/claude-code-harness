import { describe, it, expect } from 'vitest';
import {
  capitalize,
  camelCase,
  kebabCase,
  snakeCase,
  truncate,
  countWords,
  reverse,
  isPalindrome,
  padStart,
  padEnd,
  repeat,
  contains,
  slugify,
  escapeHtml,
  unescapeHtml,
  extractEmails,
  extractUrls,
  wordWrap,
  removeExtraSpaces,
  isValidEmail,
} from '../string-utils';

describe('string-utils', () => {
  describe('capitalize', () => {
    it('should capitalize first letter', () => {
      expect(capitalize('hello')).toBe('Hello');
    });

    it('should handle empty string', () => {
      expect(capitalize('')).toBe('');
    });

    it('should handle single character', () => {
      expect(capitalize('a')).toBe('A');
    });
  });

  describe('camelCase', () => {
    it('should convert kebab-case to camelCase', () => {
      expect(camelCase('hello-world')).toBe('helloWorld');
    });

    it('should convert snake_case to camelCase', () => {
      expect(camelCase('hello_world')).toBe('helloWorld');
    });

    it('should handle spaces', () => {
      expect(camelCase('hello world')).toBe('helloWorld');
    });
  });

  describe('kebabCase', () => {
    it('should convert camelCase to kebab-case', () => {
      expect(kebabCase('helloWorld')).toBe('hello-world');
    });

    it('should handle spaces', () => {
      expect(kebabCase('hello world')).toBe('hello-world');
    });
  });

  describe('snakeCase', () => {
    it('should convert camelCase to snake_case', () => {
      expect(snakeCase('helloWorld')).toBe('hello_world');
    });

    it('should handle spaces', () => {
      expect(snakeCase('hello world')).toBe('hello_world');
    });
  });

  describe('truncate', () => {
    it('should truncate long string', () => {
      expect(truncate('Hello World', 8)).toBe('Hello...');
    });

    it('should not truncate short string', () => {
      expect(truncate('Hi', 10)).toBe('Hi');
    });

    it('should use custom suffix', () => {
      expect(truncate('Hello World', 8, '---')).toBe('Hello---');
    });
  });

  describe('countWords', () => {
    it('should count words', () => {
      expect(countWords('hello world')).toBe(2);
    });

    it('should handle extra spaces', () => {
      expect(countWords('  hello   world  ')).toBe(2);
    });

    it('should handle empty string', () => {
      expect(countWords('')).toBe(0);
    });
  });

  describe('reverse', () => {
    it('should reverse string', () => {
      expect(reverse('hello')).toBe('olleh');
    });

    it('should handle Unicode', () => {
      expect(reverse('héllo')).toBe('ollèh');
    });
  });

  describe('isPalindrome', () => {
    it('should detect palindrome', () => {
      expect(isPalindrome('racecar')).toBe(true);
    });

    it('should ignore case and special characters', () => {
      expect(isPalindrome('A man, a plan, a canal: Panama')).toBe(true);
    });

    it('should detect non-palindrome', () => {
      expect(isPalindrome('hello')).toBe(false);
    });
  });

  describe('padStart', () => {
    it('should pad start with spaces', () => {
      expect(padStart('5', 3)).toBe('  5');
    });

    it('should pad with custom character', () => {
      expect(padStart('5', 3, '0')).toBe('005');
    });
  });

  describe('padEnd', () => {
    it('should pad end with spaces', () => {
      expect(padEnd('5', 3)).toBe('5  ');
    });

    it('should pad with custom character', () => {
      expect(padEnd('5', 3, '0')).toBe('500');
    });
  });

  describe('repeat', () => {
    it('should repeat string', () => {
      expect(repeat('ab', 3)).toBe('ababab');
    });

    it('should handle zero count', () => {
      expect(repeat('ab', 0)).toBe('');
    });

    it('should throw on negative count', () => {
      expect(() => repeat('ab', -1)).toThrow('count must be non-negative');
    });
  });

  describe('contains', () => {
    it('should find substring (case sensitive)', () => {
      expect(contains('Hello World', 'World')).toBe(true);
    });

    it('should be case sensitive by default', () => {
      expect(contains('Hello World', 'world')).toBe(false);
    });

    it('should support case insensitive search', () => {
      expect(contains('Hello World', 'world', false)).toBe(true);
    });
  });

  describe('slugify', () => {
    it('should create URL-friendly slug', () => {
      expect(slugify('Hello World!')).toBe('hello-world');
    });

    it('should handle special characters', () => {
      expect(slugify('Hello, World! @#$')).toBe('hello-world');
    });

    it('should remove leading/trailing dashes', () => {
      expect(slugify('  -hello-  ')).toBe('hello');
    });
  });

  describe('escapeHtml', () => {
    it('should escape HTML special characters', () => {
      expect(escapeHtml('<div>Hello & "World"</div>')).toBe('&lt;div&gt;Hello &amp; &quot;World&quot;&lt;/div&gt;');
    });

    it('should escape single quotes', () => {
      expect(escapeHtml("It's")).toBe('It&#039;s');
    });
  });

  describe('unescapeHtml', () => {
    it('should unescape HTML entities', () => {
      expect(unescapeHtml('&lt;div&gt;Hello &amp; &quot;World&quot;&lt;/div&gt;')).toBe('<div>Hello & "World"</div>');
    });

    it('should unescape single quotes', () => {
      expect(unescapeHtml('It&#039;s')).toBe("It's");
    });
  });

  describe('extractEmails', () => {
    it('should extract email addresses', () => {
      const result = extractEmails('Contact us at hello@example.com or support@test.org');
      expect(result).toEqual(['hello@example.com', 'support@test.org']);
    });

    it('should return empty array when no emails', () => {
      expect(extractEmails('No emails here')).toEqual([]);
    });
  });

  describe('extractUrls', () => {
    it('should extract URLs', () => {
      const result = extractUrls('Visit https://example.com and http://test.org');
      expect(result).toEqual(['https://example.com', 'http://test.org']);
    });

    it('should return empty array when no URLs', () => {
      expect(extractUrls('No URLs here')).toEqual([]);
    });
  });

  describe('wordWrap', () => {
    it('should wrap long lines', () => {
      const result = wordWrap('hello world test', 10);
      expect(result).toBe('hello\nworld test');
    });

    it('should not wrap short lines', () => {
      expect(wordWrap('hello', 10)).toBe('hello');
    });
  });

  describe('removeExtraSpaces', () => {
    it('should remove extra spaces', () => {
      expect(removeExtraSpaces('  hello   world  ')).toBe('hello world');
    });

    it('should handle tabs and newlines', () => {
      expect(removeExtraSpaces('hello\t\n  world')).toBe('hello world');
    });
  });

  describe('isValidEmail', () => {
    it('should validate correct email', () => {
      expect(isValidEmail('test@example.com')).toBe(true);
    });

    it('should reject invalid email', () => {
      expect(isValidEmail('invalid.email')).toBe(false);
      expect(isValidEmail('@example.com')).toBe(false);
      expect(isValidEmail('test@')).toBe(false);
    });
  });
});
