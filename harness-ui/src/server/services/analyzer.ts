import { join } from 'node:path'
import { listFiles, readFileContent, parseFrontmatter, getFileMetadata } from './file-reader.ts'
import { countTokens, countFileTokens } from './tokenizer.ts'
import { calculateHealthScore, getHealthStatus, generateSuggestions } from './health.ts'
import { parsePlansMarkdown } from './plans-parser.ts'
import type {
  HealthResponse,
  HealthMetrics,
  KanbanResponse,
  Skill,
  SkillsResponse,
  MemoryFile,
  MemoryResponse,
  Rule,
  RulesResponse,
  Hook,
  HooksResponse
} from '../../shared/types.ts'

/**
 * Get the project root (assumes harness-ui is inside claude-code-harness)
 */
export function getProjectRoot(): string {
  // Priority: 1) env var, 2) parent of cwd (harness-ui -> claude-code-harness)
  if (process.env['PROJECT_ROOT']) {
    return process.env['PROJECT_ROOT']
  }
  // harness-ui is a subdirectory of claude-code-harness
  const cwd = process.cwd()
  if (cwd.endsWith('harness-ui')) {
    return join(cwd, '..')
  }
  // Fallback: use import.meta.dir path
  return join(import.meta.dir, '../../../../')
}

/**
 * Analyze project health
 */
export async function analyzeHealth(projectRoot?: string): Promise<HealthResponse> {
  const root = projectRoot ?? getProjectRoot()

  // Gather metrics
  const [skills, memory, rules, hooks] = await Promise.all([
    analyzeSkills(root),
    analyzeMemory(root),
    analyzeRules(root),
    analyzeHooks(root)
  ])

  // Calculate total initial load tokens (Skills descriptions + Rules)
  const totalInitialLoadTokens = skills.totalTokens + rules.initialLoadTokens

  const metrics: HealthMetrics = {
    skills: {
      count: skills.skills.length,
      totalTokens: skills.totalTokens, // Already description-only
      unusedCount: skills.unusedSkills.length
    },
    memory: {
      storageTokens: memory.totalTokens, // Storage only, not initial load
      duplicateCount: memory.duplicates.length
    },
    rules: {
      count: rules.rules.filter(r => r.category !== 'template').length,
      initialLoadTokens: rules.initialLoadTokens,
      conflictCount: rules.conflicts.length
    },
    hooks: {
      count: hooks.count
    },
    totalInitialLoadTokens
  }

  const score = calculateHealthScore(metrics)
  const status = getHealthStatus(score)
  const suggestions = generateSuggestions(metrics)

  return {
    score,
    status,
    totalInitialLoadTokens,
    breakdown: {
      skills: {
        count: metrics.skills.count,
        totalTokens: metrics.skills.totalTokens,
        status: getHealthStatus(metrics.skills.count === 0 ? 50 : metrics.skills.totalTokens > 10000 ? 60 : 100)
      },
      memory: {
        storageTokens: metrics.memory.storageTokens,
        duplicateCount: metrics.memory.duplicateCount,
        status: getHealthStatus(metrics.memory.storageTokens === 0 ? 50 : metrics.memory.duplicateCount > 0 ? 60 : 100)
      },
      rules: {
        count: metrics.rules.count,
        initialLoadTokens: metrics.rules.initialLoadTokens,
        conflictCount: metrics.rules.conflictCount,
        status: getHealthStatus(metrics.rules.conflictCount > 0 ? 40 : metrics.rules.count === 0 ? 60 : 100)
      },
      hooks: {
        count: metrics.hooks.count,
        status: getHealthStatus(metrics.hooks.count > 10 ? 60 : 100)
      }
    },
    suggestions
  }
}

/**
 * Check if claude-mem is available via HTTP API
 */
async function isClaudeMemAvailable(): Promise<boolean> {
  try {
    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), 2000)
    const response = await fetch('http://127.0.0.1:37777/api/health', {
      signal: controller.signal
    })
    clearTimeout(timeoutId)
    return response.ok
  } catch {
    return false
  }
}

/**
 * Fetch observations from claude-mem HTTP API
 */
async function fetchClaudeMemObservations(limit = 200): Promise<{ title: string; narrative?: string; text?: string }[]> {
  try {
    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), 5000)
    const response = await fetch(`http://127.0.0.1:37777/api/observations?limit=${limit}`, {
      signal: controller.signal
    })
    clearTimeout(timeoutId)
    if (!response.ok) return []
    const data = await response.json() as { items?: { title: string; narrative?: string; text?: string }[] }
    return data.items ?? []
  } catch {
    return []
  }
}

/**
 * Check if claude-mem MCP is available and get skill usage data
 *
 * Strategy:
 * 1. claude-mem HTTP API (port 37777) - most accurate, searches observation titles/narratives
 * 2. File modification times - fallback heuristic
 * 3. Session-log parsing - additional heuristic
 */
async function getSkillUsageFromClaudeMem(skillNames: string[]): Promise<{
  available: boolean
  usageCounts: Map<string, number>
  message?: string
}> {
  try {
    const root = getProjectRoot()
    const usageCounts = new Map<string, number>()
    const now = Date.now()
    const thirtyDaysAgo = now - (30 * 24 * 60 * 60 * 1000)

    // Strategy 1: Query claude-mem HTTP API for observations mentioning skills
    const claudeMemAvailable = await isClaudeMemAvailable()
    let usedClaudeMem = false

    if (claudeMemAvailable) {
      const observations = await fetchClaudeMemObservations(300)
      if (observations.length > 0) {
        usedClaudeMem = true
        for (const skillName of skillNames) {
          // Extract base name (e.g., "impl" from "impl/work/doc")
          const baseName = skillName.split('/')[0]
          let count = 0

          for (const obs of observations) {
            const searchText = `${obs.title ?? ''} ${obs.narrative ?? ''} ${obs.text ?? ''}`.toLowerCase()
            // Look for skill references in observations
            if (searchText.includes(`skill(${baseName})`) ||
                searchText.includes(`skills/${baseName}`) ||
                searchText.includes(`/${baseName}`) && searchText.includes('skill')) {
              count++
            }
          }
          if (count > 0) {
            usageCounts.set(skillName, count * 5) // Weight claude-mem data higher
          }
        }
      }
    }

    // Strategy 2: Check skill file modification times (fallback)
    for (const skillName of skillNames) {
      const skillPath = join(root, 'skills', skillName + '.md')
      const metadata = await getFileMetadata(skillPath)

      if (metadata?.lastModified) {
        const modTime = new Date(metadata.lastModified).getTime()
        if (modTime > thirtyDaysAgo) {
          const daysAgo = Math.floor((now - modTime) / (24 * 60 * 60 * 1000))
          const existing = usageCounts.get(skillName) || 0
          usageCounts.set(skillName, existing + Math.max(1, 30 - daysAgo))
        }
      }
    }

    // Strategy 3: Check session-log for explicit skill references
    const sessionLogPath = join(root, '.claude', 'memory', 'session-log.md')
    const sessionLog = await readFileContent(sessionLogPath)

    if (sessionLog) {
      for (const skillName of skillNames) {
        const pathPattern = new RegExp(`skills/${skillName.replace(/\//g, '\\/')}`, 'gi')
        const matches = sessionLog.match(pathPattern)
        if (matches && matches.length > 0) {
          const existing = usageCounts.get(skillName) || 0
          usageCounts.set(skillName, existing + matches.length * 2)
        }
      }
    }

    const sources: string[] = []
    if (usedClaudeMem) sources.push('claude-mem API')
    sources.push('ファイル更新日時')
    if (sessionLog) sources.push('session-log')

    return {
      available: true,
      usageCounts,
      message: sources.join(' + ') + ' ベース'
    }
  } catch {
    return {
      available: false,
      usageCounts: new Map(),
      message: '利用履歴の取得に失敗しました'
    }
  }
}

/**
 * Analyze skills
 * Note: Only description is loaded into Claude's initial context,
 * so we count description tokens only (not full file content)
 */
export async function analyzeSkills(projectRoot?: string): Promise<SkillsResponse> {
  const root = projectRoot ?? getProjectRoot()
  const skillsDir = join(root, 'skills')

  const skillFiles = await listFiles(skillsDir, { extension: '.md', recursive: true })
  const skills: Skill[] = []
  let totalTokens = 0

  for (const filePath of skillFiles) {
    const content = await readFileContent(filePath)
    const { frontmatter } = parseFrontmatter(content)
    const metadata = await getFileMetadata(filePath)

    // Only count description tokens (that's what Claude loads initially)
    const description = frontmatter['description'] ?? ''
    const descriptionEn = frontmatter['description-en'] ?? ''
    const descriptionTokens = countTokens(description + ' ' + descriptionEn)

    totalTokens += descriptionTokens

    skills.push({
      name: filePath.replace(skillsDir + '/', '').replace(/\.md$/, ''),
      path: filePath,
      description,
      descriptionEn,
      tokenCount: descriptionTokens,
      lastUsed: metadata?.lastModified
    })
  }

  // Try to get usage data from claude-mem or session logs
  const skillNames = skills.map(s => s.name)
  const usageData = await getSkillUsageFromClaudeMem(skillNames)

  // Update skills with usage counts
  for (const skill of skills) {
    skill.usageCount = usageData.usageCounts.get(skill.name) ?? 0
  }

  // Mark skills with 0 usage as unused (only if tracking is available)
  let unusedSkills: string[] = []
  if (usageData.available) {
    unusedSkills = skills
      .filter(s => !s.usageCount || s.usageCount === 0)
      .map(s => s.name)
      .slice(0, 5) // Only report first 5
  }

  return {
    skills,
    totalTokens,
    unusedSkills,
    usageTrackingAvailable: usageData.available,
    usageTrackingMessage: usageData.message
  }
}

/**
 * Analyze memory files
 */
export async function analyzeMemory(projectRoot?: string): Promise<MemoryResponse> {
  const root = projectRoot ?? getProjectRoot()
  const memoryDir = join(root, '.claude', 'memory')

  const memoryFiles = await listFiles(memoryDir, { extension: '.md' })
  const files: MemoryFile[] = []
  let totalTokens = 0
  const contentHashes: Map<string, string[]> = new Map()

  for (const filePath of memoryFiles) {
    const content = await readFileContent(filePath)
    const tokenCount = countFileTokens(content)
    const metadata = await getFileMetadata(filePath)

    totalTokens += tokenCount

    files.push({
      name: filePath.replace(memoryDir + '/', ''),
      path: filePath,
      tokenCount,
      lastModified: metadata?.lastModified ?? ''
    })

    // Simple duplicate detection based on content similarity
    const hash = simpleHash(content)
    const existing = contentHashes.get(hash)
    if (existing) {
      existing.push(filePath)
    } else {
      contentHashes.set(hash, [filePath])
    }
  }

  // Find duplicates
  const duplicates: string[] = []
  for (const [, paths] of contentHashes) {
    if (paths.length > 1) {
      duplicates.push(...paths.slice(1))
    }
  }

  return {
    files,
    totalTokens,
    initialLoadTokens: 0, // Memory is loaded on-demand, not at session start
    duplicates
  }
}

/**
 * Analyze rules from multiple sources:
 * - .claude/rules/ - Active Claude Code rules (loaded initially)
 * - .cursor/rules/ - Cursor rules for 2-agent mode (loaded initially)
 * - templates/rules/ - Available rule templates (NOT loaded)
 */
export async function analyzeRules(projectRoot?: string): Promise<RulesResponse> {
  const root = projectRoot ?? getProjectRoot()

  // Multiple rule directories to check
  const rulesDirs = [
    { path: join(root, '.claude', 'rules'), category: 'active', initialLoad: true },
    { path: join(root, '.cursor', 'rules'), category: 'cursor', initialLoad: true },
    { path: join(root, 'templates', 'rules'), category: 'template', initialLoad: false }
  ]

  const rules: Rule[] = []
  let totalTokens = 0
  let initialLoadTokens = 0

  for (const { path: rulesDir, category, initialLoad } of rulesDirs) {
    // List both .md and .md.template files
    const mdFiles = await listFiles(rulesDir, { extension: '.md' })
    const templateFiles = await listFiles(rulesDir, { extension: '.template' })
    const allFiles = [...mdFiles, ...templateFiles]

    for (const filePath of allFiles) {
      const content = await readFileContent(filePath)
      if (!content) continue

      const tokenCount = countFileTokens(content)
      totalTokens += tokenCount

      // Only count active and cursor rules for initial load
      if (initialLoad) {
        initialLoadTokens += tokenCount
      }

      // Clean up name
      let name = filePath.replace(rulesDir + '/', '')
        .replace(/\.md\.template$/, '')
        .replace(/\.md$/, '')
        .replace(/\.template$/, '')

      // Add category prefix for clarity
      if (category === 'template') {
        name = `[テンプレート] ${name}`
      } else if (category === 'cursor') {
        name = `[Cursor] ${name}`
      }

      rules.push({
        name,
        path: filePath,
        content,
        tokenCount,
        category: category as 'active' | 'cursor' | 'template'
      })
    }
  }

  // Simple conflict detection (would need more sophisticated analysis)
  const conflicts: string[] = []

  return {
    rules,
    totalTokens,
    initialLoadTokens,
    conflicts
  }
}

/**
 * Analyze hooks
 */
export async function analyzeHooks(projectRoot?: string): Promise<HooksResponse> {
  const root = projectRoot ?? getProjectRoot()
  const hooksFile = join(root, 'hooks', 'hooks.json')

  const parseHooksFile = (content: string): HooksResponse => {
    if (!content) return { hooks: [], count: 0 }

    try {
      const hooksData = JSON.parse(content)

      // Handle new structure: { hooks: { PreToolUse: [...], SessionStart: [...], ... } }
      if (hooksData.hooks && typeof hooksData.hooks === 'object' && !Array.isArray(hooksData.hooks)) {
        const flatHooks: Hook[] = []

        for (const [hookType, hookGroups] of Object.entries(hooksData.hooks)) {
          if (Array.isArray(hookGroups)) {
            for (const group of hookGroups as { matcher?: string; hooks?: { type: string; command?: string; prompt?: string }[] }[]) {
              if (group.hooks && Array.isArray(group.hooks)) {
                for (const hook of group.hooks) {
                  // Handle both command and prompt type hooks
                  const hookCommand = hook.command ?? hook.prompt ?? ''
                  const hookName = hook.command
                    ? hook.command.split('/').pop()?.replace('.sh', '') ?? 'unknown'
                    : hook.type === 'prompt' ? 'prompt-hook' : 'unknown'

                  flatHooks.push({
                    name: hookName,
                    type: hookType as Hook['type'],
                    matcher: group.matcher,
                    command: hookCommand
                  })
                }
              }
            }
          }
        }

        return { hooks: flatHooks, count: flatHooks.length }
      }

      // Handle legacy structure: { hooks: Hook[] }
      if (Array.isArray(hooksData.hooks)) {
        return {
          hooks: hooksData.hooks,
          count: hooksData.hooks.length
        }
      }

      return { hooks: [], count: 0 }
    } catch {
      return { hooks: [], count: 0 }
    }
  }

  const content = await readFileContent(hooksFile)
  if (content) {
    return parseHooksFile(content)
  }

  // Try alternative path
  const altHooksFile = join(root, '.claude', 'hooks.json')
  const altContent = await readFileContent(altHooksFile)
  return parseHooksFile(altContent)
}

/**
 * Parse Plans.md
 * @param projectRoot - Optional project root path
 * @param mode - Workflow mode: 'solo' (default) or '2agent'
 */
export async function parsePlans(projectRoot?: string, mode?: 'solo' | '2agent'): Promise<KanbanResponse> {
  const root = projectRoot ?? getProjectRoot()
  const workflowMode = mode ?? 'solo'

  // Try multiple possible locations
  const possiblePaths = [
    join(root, '.claude', 'Plans.md'),
    join(root, 'Plans.md'),
    join(root, '.claude', 'plans.md')
  ]

  for (const plansPath of possiblePaths) {
    const content = await readFileContent(plansPath)
    if (content) {
      return parsePlansMarkdown(content, workflowMode)
    }
  }

  return {
    plan: [],
    work: [],
    review: [],
    done: [],
    error: 'Plans.md が見つかりません'
  }
}

/**
 * Simple hash function for content comparison
 */
function simpleHash(content: string): string {
  // Normalize content and take first 500 chars for comparison
  const normalized = content.trim().toLowerCase().slice(0, 500)
  let hash = 0
  for (let i = 0; i < normalized.length; i++) {
    const char = normalized.charCodeAt(i)
    hash = ((hash << 5) - hash) + char
    hash = hash & hash // Convert to 32bit integer
  }
  return hash.toString(16)
}
