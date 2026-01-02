import { describe, test, expect } from 'bun:test'
import { countTokens, estimateTokens, countFileTokens } from '../../src/server/services/tokenizer.ts'

describe('estimateTokens', () => {
  test('estimates ~4 chars per token for English text', () => {
    const text = 'This is a simple English sentence for testing.'
    const tokens = estimateTokens(text)
    // ~47 chars / 4 ≈ 12 tokens (rough estimate)
    expect(tokens).toBeGreaterThan(8)
    expect(tokens).toBeLessThan(20)
  })

  test('estimates tokens for Japanese text', () => {
    const text = 'これは日本語のテスト文です。'
    const tokens = estimateTokens(text)
    // Japanese CJK chars: 14 chars * 0.5 ≈ 7 tokens
    expect(tokens).toBeGreaterThan(5)
    expect(tokens).toBeLessThan(15)
  })

  test('handles mixed language text', () => {
    const text = 'This is English and これは日本語です'
    const tokens = estimateTokens(text)
    // Mixed: ~20 English chars / 4 + ~8 CJK chars * 0.5 ≈ 5 + 4 = 9
    expect(tokens).toBeGreaterThan(5)
    expect(tokens).toBeLessThan(20)
  })

  test('returns 0 for empty string', () => {
    expect(estimateTokens('')).toBe(0)
  })

  test('handles code blocks', () => {
    const code = `
function hello() {
  console.log("Hello, World!");
  return true;
}
    `
    const tokens = estimateTokens(code)
    expect(tokens).toBeGreaterThan(15)
  })

  test('handles markdown content', () => {
    const markdown = `
# Heading

## Subheading

- List item 1
- List item 2

\`\`\`javascript
const x = 1;
\`\`\`
    `
    const tokens = estimateTokens(markdown)
    expect(tokens).toBeGreaterThan(20)
  })
})

describe('countTokens', () => {
  test('counts tokens more accurately than estimate', () => {
    const text = 'Hello, world! This is a test.'
    const estimated = estimateTokens(text)
    const counted = countTokens(text)
    // Both should be in similar range
    expect(Math.abs(estimated - counted)).toBeLessThan(counted * 0.5)
  })

  test('handles empty string', () => {
    expect(countTokens('')).toBe(0)
  })

  test('counts whitespace-only string', () => {
    expect(countTokens('   \n\t  ')).toBe(0)
  })

  test('handles special characters', () => {
    const text = '!@#$%^&*()_+-=[]{}|;:,.<>?'
    const tokens = countTokens(text)
    expect(tokens).toBeGreaterThan(0)
  })

  test('handles URLs', () => {
    const url = 'https://github.com/user/repo/blob/main/file.ts'
    const tokens = countTokens(url)
    expect(tokens).toBeGreaterThan(5)
  })
})

describe('countFileTokens', () => {
  test('counts tokens from file content string', () => {
    const fileContent = `
# My Document

This is some content in the document.

## Section 1

- Item 1
- Item 2
    `
    const tokens = countFileTokens(fileContent)
    expect(tokens).toBeGreaterThan(15)
  })

  test('handles empty file content', () => {
    expect(countFileTokens('')).toBe(0)
  })

  test('strips frontmatter before counting', () => {
    const contentWithFrontmatter = `---
title: My Doc
description: A test document
---

# Actual Content

This is the body.
    `
    const contentWithoutFrontmatter = `
# Actual Content

This is the body.
    `
    const tokensWithFM = countFileTokens(contentWithFrontmatter)
    const tokensWithoutFM = countFileTokens(contentWithoutFrontmatter)
    // Should strip frontmatter, so counts should be similar
    // (allowing some variance for implementation details)
    expect(Math.abs(tokensWithFM - tokensWithoutFM)).toBeLessThan(tokensWithoutFM * 0.3)
  })
})
