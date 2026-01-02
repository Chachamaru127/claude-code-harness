import { describe, test, expect, beforeEach, afterEach } from 'bun:test'
import { getUsageData } from '../../src/server/services/usage.ts'
import type { UsageData } from '../../src/shared/types.ts'
import { mkdtemp, rm, mkdir } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

describe('getUsageData', () => {
  let tempDir: string

  beforeEach(async () => {
    tempDir = await mkdtemp(join(tmpdir(), 'usage-test-'))
    await mkdir(join(tempDir, '.claude', 'state'), { recursive: true })
  })

  afterEach(async () => {
    await rm(tempDir, { recursive: true, force: true })
  })

  test('returns unavailable when file does not exist', async () => {
    const result = await getUsageData(tempDir)

    expect(result.available).toBe(false)
    expect(result.data).toBeNull()
    expect(result.cleanup).toBeNull()
    expect(result.topSkills).toEqual([])
    expect(result.topCommands).toEqual([])
    expect(result.topAgents).toEqual([])
    expect(result.topHooks).toEqual([])
    expect(result.message).toContain('使用状況データがまだありません')
  })

  test('parses valid usage data correctly', async () => {
    const usageData: UsageData = {
      version: '1.0.0',
      updatedAt: '2024-01-01T00:00:00.000Z',
      skills: {
        'impl': { count: 10, lastUsed: '2024-01-01T00:00:00.000Z' },
        'review': { count: 5, lastUsed: '2024-01-01T00:00:00.000Z' }
      },
      commands: {
        'harness-init': { count: 3, lastUsed: '2024-01-01T00:00:00.000Z' }
      },
      agents: {
        'project-analyzer': { count: 2, lastUsed: '2024-01-01T00:00:00.000Z' }
      },
      hooks: {
        'session-init': { triggered: 15, blocked: 0, lastTriggered: '2024-01-01T00:00:00.000Z' }
      }
    }

    await Bun.write(
      join(tempDir, '.claude', 'state', 'harness-usage.json'),
      JSON.stringify(usageData)
    )

    const result = await getUsageData(tempDir)

    expect(result.available).toBe(true)
    expect(result.data).not.toBeNull()
    expect(result.data?.version).toBe('1.0.0')
    expect(Object.keys(result.data?.skills ?? {})).toHaveLength(2)
    expect(Object.keys(result.data?.commands ?? {})).toHaveLength(1)
    expect(Object.keys(result.data?.agents ?? {})).toHaveLength(1)
    expect(Object.keys(result.data?.hooks ?? {})).toHaveLength(1)
  })

  test('sorts topSkills by count descending', async () => {
    const usageData: UsageData = {
      version: '1.0.0',
      updatedAt: '2024-01-01T00:00:00.000Z',
      skills: {
        'impl': { count: 5, lastUsed: '2024-01-01T00:00:00.000Z' },
        'review': { count: 20, lastUsed: '2024-01-01T00:00:00.000Z' },
        'verify': { count: 10, lastUsed: '2024-01-01T00:00:00.000Z' }
      },
      commands: {},
      agents: {},
      hooks: {}
    }

    await Bun.write(
      join(tempDir, '.claude', 'state', 'harness-usage.json'),
      JSON.stringify(usageData)
    )

    const result = await getUsageData(tempDir)

    expect(result.topSkills.length).toBeGreaterThanOrEqual(3)
    expect(result.topSkills[0]![0]).toBe('review')
    expect(result.topSkills[0]![1].count).toBe(20)
    expect(result.topSkills[1]![0]).toBe('verify')
    expect(result.topSkills[1]![1].count).toBe(10)
    expect(result.topSkills[2]![0]).toBe('impl')
    expect(result.topSkills[2]![1].count).toBe(5)
  })

  test('sorts topHooks by triggered count descending', async () => {
    const usageData: UsageData = {
      version: '1.0.0',
      updatedAt: '2024-01-01T00:00:00.000Z',
      skills: {},
      commands: {},
      agents: {},
      hooks: {
        'hook-a': { triggered: 5, blocked: 0, lastTriggered: '2024-01-01T00:00:00.000Z' },
        'hook-b': { triggered: 30, blocked: 5, lastTriggered: '2024-01-01T00:00:00.000Z' },
        'hook-c': { triggered: 15, blocked: 2, lastTriggered: '2024-01-01T00:00:00.000Z' }
      }
    }

    await Bun.write(
      join(tempDir, '.claude', 'state', 'harness-usage.json'),
      JSON.stringify(usageData)
    )

    const result = await getUsageData(tempDir)

    expect(result.topHooks.length).toBeGreaterThanOrEqual(3)
    expect(result.topHooks[0]![0]).toBe('hook-b')
    expect(result.topHooks[0]![1].triggered).toBe(30)
    expect(result.topHooks[1]![0]).toBe('hook-c')
    expect(result.topHooks[1]![1].triggered).toBe(15)
    expect(result.topHooks[2]![0]).toBe('hook-a')
    expect(result.topHooks[2]![1].triggered).toBe(5)
  })

  test('limits top items to 10', async () => {
    const skills: UsageData['skills'] = {}
    for (let i = 0; i < 20; i++) {
      skills[`skill-${i}`] = { count: i, lastUsed: '2024-01-01T00:00:00.000Z' }
    }

    const usageData: UsageData = {
      version: '1.0.0',
      updatedAt: '2024-01-01T00:00:00.000Z',
      skills,
      commands: {},
      agents: {},
      hooks: {}
    }

    await Bun.write(
      join(tempDir, '.claude', 'state', 'harness-usage.json'),
      JSON.stringify(usageData)
    )

    const result = await getUsageData(tempDir)

    expect(result.topSkills).toHaveLength(10)
    // The top skill should be skill-19 (count: 19)
    expect(result.topSkills[0]![0]).toBe('skill-19')
  })

  test('handles malformed JSON gracefully', async () => {
    await Bun.write(
      join(tempDir, '.claude', 'state', 'harness-usage.json'),
      '{ invalid json }'
    )

    const result = await getUsageData(tempDir)

    expect(result.available).toBe(false)
    expect(result.message).toContain('読み込みに失敗')
  })
})

describe('cleanup suggestions', () => {
  let tempDir: string

  beforeEach(async () => {
    tempDir = await mkdtemp(join(tmpdir(), 'usage-test-'))
    await mkdir(join(tempDir, '.claude', 'state'), { recursive: true })
  })

  afterEach(async () => {
    await rm(tempDir, { recursive: true, force: true })
  })

  test('identifies unused skills (count = 0)', async () => {
    const usageData: UsageData = {
      version: '1.0.0',
      updatedAt: new Date().toISOString(),
      skills: {
        'used-skill': { count: 5, lastUsed: new Date().toISOString() },
        'unused-skill': { count: 0, lastUsed: null }
      },
      commands: {},
      agents: {},
      hooks: {}
    }

    await Bun.write(
      join(tempDir, '.claude', 'state', 'harness-usage.json'),
      JSON.stringify(usageData)
    )

    const result = await getUsageData(tempDir)

    expect(result.cleanup).not.toBeNull()
    expect(result.cleanup?.unusedSkills).toHaveLength(1)
    expect(result.cleanup!.unusedSkills[0]!.name).toBe('unused-skill')
    expect(result.cleanup?.summary.unusedSkillsCount).toBe(1)
  })

  test('identifies skills unused for 30+ days', async () => {
    const thirtyOneDaysAgo = new Date()
    thirtyOneDaysAgo.setDate(thirtyOneDaysAgo.getDate() - 31)

    const usageData: UsageData = {
      version: '1.0.0',
      updatedAt: new Date().toISOString(),
      skills: {
        'recent-skill': { count: 5, lastUsed: new Date().toISOString() },
        'old-skill': { count: 10, lastUsed: thirtyOneDaysAgo.toISOString() }
      },
      commands: {},
      agents: {},
      hooks: {}
    }

    await Bun.write(
      join(tempDir, '.claude', 'state', 'harness-usage.json'),
      JSON.stringify(usageData)
    )

    const result = await getUsageData(tempDir)

    expect(result.cleanup?.unusedSkills).toHaveLength(1)
    expect(result.cleanup!.unusedSkills[0]!.name).toBe('old-skill')
  })

  test('identifies inactive hooks (triggered = 0)', async () => {
    const usageData: UsageData = {
      version: '1.0.0',
      updatedAt: new Date().toISOString(),
      skills: {},
      commands: {},
      agents: {},
      hooks: {
        'active-hook': { triggered: 10, blocked: 0, lastTriggered: new Date().toISOString() },
        'inactive-hook': { triggered: 0, blocked: 0, lastTriggered: null }
      }
    }

    await Bun.write(
      join(tempDir, '.claude', 'state', 'harness-usage.json'),
      JSON.stringify(usageData)
    )

    const result = await getUsageData(tempDir)

    expect(result.cleanup?.inactiveHooks).toHaveLength(1)
    expect(result.cleanup!.inactiveHooks[0]!.name).toBe('inactive-hook')
    expect(result.cleanup?.summary.inactiveHooksCount).toBe(1)
  })

  test('provides correct summary counts', async () => {
    const thirtyOneDaysAgo = new Date()
    thirtyOneDaysAgo.setDate(thirtyOneDaysAgo.getDate() - 31)

    const usageData: UsageData = {
      version: '1.0.0',
      updatedAt: new Date().toISOString(),
      skills: {
        'skill-1': { count: 5, lastUsed: new Date().toISOString() },
        'skill-2': { count: 0, lastUsed: null },
        'skill-3': { count: 3, lastUsed: thirtyOneDaysAgo.toISOString() }
      },
      commands: {
        'cmd-1': { count: 2, lastUsed: new Date().toISOString() },
        'cmd-2': { count: 0, lastUsed: null }
      },
      agents: {
        'agent-1': { count: 1, lastUsed: new Date().toISOString() }
      },
      hooks: {
        'hook-1': { triggered: 5, blocked: 0, lastTriggered: new Date().toISOString() },
        'hook-2': { triggered: 0, blocked: 0, lastTriggered: null },
        'hook-3': { triggered: 2, blocked: 1, lastTriggered: thirtyOneDaysAgo.toISOString() }
      }
    }

    await Bun.write(
      join(tempDir, '.claude', 'state', 'harness-usage.json'),
      JSON.stringify(usageData)
    )

    const result = await getUsageData(tempDir)
    const summary = result.cleanup?.summary

    expect(summary?.totalSkills).toBe(3)
    expect(summary?.totalCommands).toBe(2)
    expect(summary?.totalAgents).toBe(1)
    expect(summary?.totalHooks).toBe(3)
    expect(summary?.unusedSkillsCount).toBe(2) // skill-2 (count=0) + skill-3 (old)
    expect(summary?.unusedCommandsCount).toBe(1) // cmd-2 (count=0)
    expect(summary?.unusedAgentsCount).toBe(0)
    expect(summary?.inactiveHooksCount).toBe(2) // hook-2 (triggered=0) + hook-3 (old)
  })
})

describe('edge cases', () => {
  let tempDir: string

  beforeEach(async () => {
    tempDir = await mkdtemp(join(tmpdir(), 'usage-test-'))
    await mkdir(join(tempDir, '.claude', 'state'), { recursive: true })
  })

  afterEach(async () => {
    await rm(tempDir, { recursive: true, force: true })
  })

  test('handles empty sections gracefully', async () => {
    const usageData: UsageData = {
      version: '1.0.0',
      updatedAt: new Date().toISOString(),
      skills: {},
      commands: {},
      agents: {},
      hooks: {}
    }

    await Bun.write(
      join(tempDir, '.claude', 'state', 'harness-usage.json'),
      JSON.stringify(usageData)
    )

    const result = await getUsageData(tempDir)

    expect(result.available).toBe(true)
    expect(result.topSkills).toEqual([])
    expect(result.topCommands).toEqual([])
    expect(result.topAgents).toEqual([])
    expect(result.topHooks).toEqual([])
    expect(result.cleanup?.summary.totalSkills).toBe(0)
    expect(result.cleanup?.summary.unusedSkillsCount).toBe(0)
  })

  test('handles null lastUsed dates', async () => {
    const usageData: UsageData = {
      version: '1.0.0',
      updatedAt: new Date().toISOString(),
      skills: {
        'skill-null-date': { count: 5, lastUsed: null }
      },
      commands: {},
      agents: {},
      hooks: {}
    }

    await Bun.write(
      join(tempDir, '.claude', 'state', 'harness-usage.json'),
      JSON.stringify(usageData)
    )

    const result = await getUsageData(tempDir)

    expect(result.available).toBe(true)
    expect(result.topSkills).toHaveLength(1)
    // Skills with null lastUsed but count > 0 are not considered "unused"
    // They're active but just missing a date
    expect(result.cleanup?.unusedSkills).toHaveLength(0)
  })
})
