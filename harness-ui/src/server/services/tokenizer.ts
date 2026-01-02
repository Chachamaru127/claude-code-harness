import { countTokens as anthropicCountTokens } from '@anthropic-ai/tokenizer'

/**
 * Count tokens using official Anthropic tokenizer
 * This matches Claude's actual token counting
 */
export function countTokens(text: string): number {
  if (!text || text.trim() === '') return 0
  return anthropicCountTokens(text)
}

/**
 * Count tokens from file content, stripping frontmatter
 */
export function countFileTokens(content: string): number {
  if (!content || content.trim() === '') return 0

  // Strip YAML frontmatter if present
  const strippedContent = stripFrontmatter(content)

  return countTokens(strippedContent)
}

/**
 * Strip YAML frontmatter from markdown content
 */
function stripFrontmatter(content: string): string {
  // Match frontmatter: starts with ---, ends with ---
  const frontmatterPattern = /^---\s*\n[\s\S]*?\n---\s*\n?/

  return content.replace(frontmatterPattern, '').trim()
}

/**
 * Count tokens in multiple files and return total
 */
export function countTotalTokens(files: { content: string }[]): number {
  return files.reduce((total, file) => total + countFileTokens(file.content), 0)
}

/**
 * Analyze token distribution across files
 */
export interface TokenAnalysis {
  total: number
  files: { name: string; tokens: number; percentage: number }[]
}

export function analyzeTokens(files: { name: string; content: string }[]): TokenAnalysis {
  const fileTokens = files.map(f => ({
    name: f.name,
    tokens: countFileTokens(f.content)
  }))

  const total = fileTokens.reduce((sum, f) => sum + f.tokens, 0)

  return {
    total,
    files: fileTokens.map(f => ({
      ...f,
      percentage: total > 0 ? Math.round((f.tokens / total) * 100) : 0
    }))
  }
}
