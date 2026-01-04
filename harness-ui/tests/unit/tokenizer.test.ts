import { describe, test, expect } from 'bun:test'
import { countTokens, countFileTokens } from '../../src/server/services/tokenizer.ts'

describe('countTokens', () => {
  test('counts tokens using Anthropic tokenizer', () => {
    const text = 'Hello, world! This is a test.'
    const counted = countTokens(text)
    // Should return a reasonable token count
    expect(counted).toBeGreaterThan(0)
    expect(counted).toBeLessThan(20)
  })

  test('handles empty string', () => {
    expect(countTokens('')).toBe(0)
  })

  test('counts whitespace-only string as 0', () => {
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

  test('handles English text', () => {
    const text = 'This is a simple English sentence for testing.'
    const tokens = countTokens(text)
    expect(tokens).toBeGreaterThan(5)
    expect(tokens).toBeLessThan(20)
  })

  test('handles Japanese text', () => {
    const text = 'これは日本語のテスト文です。'
    const tokens = countTokens(text)
    expect(tokens).toBeGreaterThan(0)
  })

  test('handles mixed language text', () => {
    const text = 'This is English and これは日本語です'
    const tokens = countTokens(text)
    expect(tokens).toBeGreaterThan(5)
  })

  test('handles code blocks', () => {
    const code = `
function hello() {
  console.log("Hello, World!");
  return true;
}
    `
    const tokens = countTokens(code)
    expect(tokens).toBeGreaterThan(10)
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
    const tokens = countTokens(markdown)
    expect(tokens).toBeGreaterThan(15)
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
    expect(tokens).toBeGreaterThan(10)
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
    expect(Math.abs(tokensWithFM - tokensWithoutFM)).toBeLessThan(tokensWithoutFM * 0.5)
  })
})
