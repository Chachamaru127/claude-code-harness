import { join } from 'path'
import type { UsageData, UsageEntry, HookUsageEntry, UsageResponse, CleanupSuggestions } from '../../shared/types.ts'

const USAGE_FILE = '.claude/state/harness-usage.json'

/**
 * Read usage data from project
 */
export async function getUsageData(projectRoot: string): Promise<UsageResponse> {
  const usagePath = join(projectRoot, USAGE_FILE)

  try {
    const file = Bun.file(usagePath)
    if (!(await file.exists())) {
      return {
        available: false,
        data: null,
        cleanup: null,
        topSkills: [],
        topCommands: [],
        topAgents: [],
        topHooks: [],
        message: '使用状況データがまだありません。Skills/Commands/Agents を使用すると自動的に記録されます。'
      }
    }

    const data = await file.json() as UsageData

    // Calculate top items (sorted by usage count, descending)
    const sortByCount = (a: [string, UsageEntry], b: [string, UsageEntry]) =>
      (b[1].count || 0) - (a[1].count || 0)

    const sortByTriggered = (a: [string, HookUsageEntry], b: [string, HookUsageEntry]) =>
      (b[1].triggered || 0) - (a[1].triggered || 0)

    const topSkills = Object.entries(data.skills || {})
      .sort(sortByCount)
      .slice(0, 10) as Array<[string, UsageEntry]>

    const topCommands = Object.entries(data.commands || {})
      .sort(sortByCount)
      .slice(0, 10) as Array<[string, UsageEntry]>

    const topAgents = Object.entries(data.agents || {})
      .sort(sortByCount)
      .slice(0, 10) as Array<[string, UsageEntry]>

    const topHooks = Object.entries(data.hooks || {})
      .sort(sortByTriggered)
      .slice(0, 10) as Array<[string, HookUsageEntry]>

    // Calculate cleanup suggestions
    const cleanup = getCleanupSuggestions(data)

    return {
      available: true,
      data,
      cleanup,
      topSkills,
      topCommands,
      topAgents,
      topHooks
    }
  } catch (error) {
    console.error('Failed to read usage data:', error)
    return {
      available: false,
      data: null,
      cleanup: null,
      topSkills: [],
      topCommands: [],
      topAgents: [],
      topHooks: [],
      message: `使用状況データの読み込みに失敗しました: ${error instanceof Error ? error.message : 'Unknown error'}`
    }
  }
}

/**
 * Calculate cleanup suggestions based on usage data
 */
function getCleanupSuggestions(data: UsageData): CleanupSuggestions {
  const thirtyDaysAgo = new Date()
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30)

  const unusedSkills: Array<{ name: string } & UsageEntry> = []
  const unusedCommands: Array<{ name: string } & UsageEntry> = []
  const unusedAgents: Array<{ name: string } & UsageEntry> = []
  const inactiveHooks: Array<{ name: string } & HookUsageEntry> = []

  // Check skills
  for (const [name, entry] of Object.entries(data.skills || {})) {
    if (entry.count === 0 || (entry.lastUsed && new Date(entry.lastUsed) < thirtyDaysAgo)) {
      unusedSkills.push({ name, ...entry })
    }
  }

  // Check commands
  for (const [name, entry] of Object.entries(data.commands || {})) {
    if (entry.count === 0 || (entry.lastUsed && new Date(entry.lastUsed) < thirtyDaysAgo)) {
      unusedCommands.push({ name, ...entry })
    }
  }

  // Check agents
  for (const [name, entry] of Object.entries(data.agents || {})) {
    if (entry.count === 0 || (entry.lastUsed && new Date(entry.lastUsed) < thirtyDaysAgo)) {
      unusedAgents.push({ name, ...entry })
    }
  }

  // Check hooks
  for (const [name, entry] of Object.entries(data.hooks || {})) {
    if (entry.triggered === 0 || (entry.lastTriggered && new Date(entry.lastTriggered) < thirtyDaysAgo)) {
      inactiveHooks.push({ name, ...entry })
    }
  }

  return {
    unusedSkills,
    unusedCommands,
    unusedAgents,
    inactiveHooks,
    summary: {
      totalSkills: Object.keys(data.skills || {}).length,
      totalCommands: Object.keys(data.commands || {}).length,
      totalAgents: Object.keys(data.agents || {}).length,
      totalHooks: Object.keys(data.hooks || {}).length,
      unusedSkillsCount: unusedSkills.length,
      unusedCommandsCount: unusedCommands.length,
      unusedAgentsCount: unusedAgents.length,
      inactiveHooksCount: inactiveHooks.length
    }
  }
}
