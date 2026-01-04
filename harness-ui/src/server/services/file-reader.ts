import { readdir, stat } from 'node:fs/promises'
import { join, extname, basename, resolve, normalize, isAbsolute, sep } from 'node:path'
import { existsSync, statSync } from 'node:fs'

/**
 * Validate and sanitize project root path to prevent path traversal attacks
 * @param userInput - User-provided path (from query parameter)
 * @param allowedBase - The base directory that paths must be within
 * @returns Validated path or null if invalid
 */
export function validateProjectPath(
  userInput: string | undefined,
  allowedBase: string
): string | null {
  if (!userInput) {
    return null
  }

  // Security check: reject null bytes (path truncation attack)
  if (userInput.includes('\0')) {
    console.warn('[Security] Null byte detected in path')
    return null
  }

  // Security check: reject overly long paths
  if (userInput.length > 500) {
    console.warn('[Security] Path too long')
    return null
  }

  // For absolute paths, validate they exist and are directories
  // This allows users to specify project paths like "/Users/user/myproject"
  if (isAbsolute(userInput)) {
    // Validate the path exists and is a directory
    try {
      if (!existsSync(userInput)) {
        console.warn(`[Security] Absolute path does not exist: ${userInput}`)
        return null
      }
      const stats = statSync(userInput)
      if (!stats.isDirectory()) {
        console.warn(`[Security] Absolute path is not a directory: ${userInput}`)
        return null
      }
      return userInput
    } catch {
      console.warn(`[Security] Failed to validate absolute path: ${userInput}`)
      return null
    }
  }

  // For relative paths, resolve against the allowed base
  const normalized = normalize(userInput)
  const resolved = resolve(allowedBase, normalized)

  // Check if resolved path starts with allowed base (prevents traversal)
  const resolvedBase = resolve(allowedBase)
  // Use sep to ensure exact directory match (not just string prefix)
  if (!resolved.startsWith(resolvedBase + sep) && resolved !== resolvedBase) {
    console.warn(`[Security] Path traversal attempt detected: ${userInput}`)
    return null
  }

  return resolved
}

/**
 * Parse positive integer with validation
 * @param value - String value to parse
 * @param defaultValue - Default value if parsing fails
 * @param max - Maximum allowed value
 * @returns Parsed integer within bounds
 */
export function parsePositiveInt(
  value: string | undefined,
  defaultValue: number,
  max: number = 1000
): number {
  if (!value) return defaultValue

  const parsed = parseInt(value, 10)

  if (isNaN(parsed) || parsed < 1 || parsed > max) {
    return defaultValue
  }

  return parsed
}

/**
 * Read a file and return its content
 */
export async function readFileContent(filePath: string): Promise<string> {
  try {
    const file = Bun.file(filePath)
    return await file.text()
  } catch (error) {
    console.error(`Failed to read file: ${filePath}`, error)
    return ''
  }
}

/**
 * Check if a file exists
 */
export async function fileExists(filePath: string): Promise<boolean> {
  try {
    const file = Bun.file(filePath)
    return await file.exists()
  } catch {
    return false
  }
}

/**
 * List files in a directory with optional extension filter
 */
export async function listFiles(
  dirPath: string,
  options?: { extension?: string; recursive?: boolean }
): Promise<string[]> {
  const files: string[] = []

  try {
    const entries = await readdir(dirPath, { withFileTypes: true })

    for (const entry of entries) {
      const fullPath = join(dirPath, entry.name)

      if (entry.isDirectory() && options?.recursive) {
        const subFiles = await listFiles(fullPath, options)
        files.push(...subFiles)
      } else if (entry.isFile()) {
        if (!options?.extension || extname(entry.name) === options.extension) {
          files.push(fullPath)
        }
      }
    }
  } catch (error) {
    console.error(`Failed to list directory: ${dirPath}`, error)
  }

  return files
}

/**
 * Get file metadata
 */
export async function getFileMetadata(filePath: string): Promise<{
  name: string
  path: string
  size: number
  lastModified: string
} | null> {
  try {
    const stats = await stat(filePath)
    return {
      name: basename(filePath),
      path: filePath,
      size: stats.size,
      lastModified: stats.mtime.toISOString()
    }
  } catch {
    return null
  }
}

/**
 * Read multiple files and return their contents
 */
export async function readMultipleFiles(
  filePaths: string[]
): Promise<{ path: string; content: string }[]> {
  const results = await Promise.all(
    filePaths.map(async (path) => ({
      path,
      content: await readFileContent(path)
    }))
  )
  return results.filter((r) => r.content !== '')
}

/**
 * Parse YAML frontmatter from markdown content
 */
export function parseFrontmatter(content: string): {
  frontmatter: Record<string, string>
  body: string
} {
  const frontmatterMatch = content.match(/^---\s*\n([\s\S]*?)\n---\s*\n?/)

  if (!frontmatterMatch) {
    return { frontmatter: {}, body: content }
  }

  const frontmatterStr = frontmatterMatch[1] ?? ''
  const body = content.slice(frontmatterMatch[0].length)

  const frontmatter: Record<string, string> = {}
  const lines = frontmatterStr.split('\n')

  for (const line of lines) {
    const match = line.match(/^(\w+[\w-]*):\s*(.+)$/)
    if (match) {
      const key = match[1]
      const value = match[2]
      if (key && value) {
        frontmatter[key] = value.trim()
      }
    }
  }

  return { frontmatter, body }
}
