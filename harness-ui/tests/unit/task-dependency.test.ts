import { describe, test, expect } from 'bun:test'

/**
 * Task Dependency & Execution Control Tests
 *
 * These tests verify the core logic for:
 * 1. Parsing task IDs and dependencies from Plans.md
 * 2. Checking if a task can be executed (dependency resolution)
 * 3. Blocking execution when prerequisites are not met
 *
 * Format:
 * - [ ] TaskName `cc:TODO` `id:task-id` `depends:dep1,dep2`
 */

// ============================================================
// Type Definitions (to be moved to shared/types.ts)
// ============================================================

interface TaskWithDependency {
  id: string
  title: string
  status: 'plan' | 'work' | 'review' | 'done'
  phase?: number
  depends?: string[]
  markers?: string[]
}

interface ExecutionCheckResult {
  executable: boolean
  reason?: string
  blockedBy?: string[]
}

// ============================================================
// Parser Functions (to be implemented in services/)
// ============================================================

/**
 * Parse task ID from line
 * Format: `id:task-id`
 */
function parseTaskId(line: string): string | undefined {
  const match = line.match(/`id:([a-zA-Z0-9_-]+)`/)
  return match?.[1]
}

/**
 * Parse dependencies from line
 * Format: `depends:dep1,dep2,dep3`
 */
function parseTaskDependencies(line: string): string[] {
  const match = line.match(/`depends:([a-zA-Z0-9_,\-]+)`/)
  if (!match?.[1]) return []
  return match[1].split(',').map(d => d.trim()).filter(Boolean)
}

/**
 * Parse phase number from section header or task
 * Format: ## フェーズ1: ... or `phase:1`
 */
function parsePhase(line: string, currentPhase?: number): number | undefined {
  // Check inline phase marker
  const inlineMatch = line.match(/`phase:(\d+)`/)
  if (inlineMatch) return parseInt(inlineMatch[1], 10)

  // Check section header
  const headerMatch = line.match(/^##\s*(?:フェーズ|Phase)\s*(\d+)/i)
  if (headerMatch) return parseInt(headerMatch[1], 10)

  return currentPhase
}

/**
 * Parse feature markers (tdd, security, a11y, etc.)
 * Format: `[feature:tdd]` or `[bugfix:reproduce-first]`
 */
function parseMarkers(line: string): string[] {
  const matches = line.matchAll(/\[(\w+):([a-zA-Z0-9_-]+)\]/g)
  return Array.from(matches).map(m => `${m[1]}:${m[2]}`)
}

/**
 * Full task line parser with all metadata
 */
function parseTaskWithDependency(line: string, currentPhase?: number): TaskWithDependency | null {
  // Must be a checkbox task
  const taskMatch = line.match(/^\s*-\s*\[([ xX])\]\s*(.+)$/)
  if (!taskMatch) return null

  const completed = taskMatch[1]?.toLowerCase() === 'x'
  const content = taskMatch[2] ?? ''

  // Extract ID (required for dependency tracking)
  const id = parseTaskId(content)
  if (!id) return null // Tasks without ID cannot participate in dependency graph

  // Extract status from marker
  let status: TaskWithDependency['status'] = completed ? 'done' : 'plan'
  if (content.includes('`cc:WIP`') || content.includes('`cc:作業中`')) {
    status = 'work'
  } else if (content.includes('`cc:完了`')) {
    status = 'done'
  } else if (content.includes('`cc:TODO`') || content.includes('`cc:依頼中`')) {
    status = 'plan'
  }

  // Extract title (remove all markers)
  const title = content
    .replace(/`[^`]+`/g, '')
    .replace(/\[[^\]]+\]/g, '')
    .trim()

  return {
    id,
    title,
    status,
    phase: parsePhase(content, currentPhase),
    depends: parseTaskDependencies(content),
    markers: parseMarkers(content)
  }
}

/**
 * Check if a task can be executed based on dependencies
 */
function canExecuteTask(
  task: TaskWithDependency,
  allTasks: TaskWithDependency[]
): ExecutionCheckResult {
  const blockedBy: string[] = []

  // Check direct dependencies
  if (task.depends && task.depends.length > 0) {
    for (const depId of task.depends) {
      const depTask = allTasks.find(t => t.id === depId)

      if (!depTask) {
        // Dependency not found - this is a configuration error
        return {
          executable: false,
          reason: `依存タスク「${depId}」が見つかりません`,
          blockedBy: [depId]
        }
      }

      if (depTask.status !== 'done') {
        blockedBy.push(depId)
      }
    }
  }

  if (blockedBy.length > 0) {
    const depTitles = blockedBy
      .map(id => allTasks.find(t => t.id === id)?.title ?? id)
      .join(', ')
    return {
      executable: false,
      reason: `依存タスクが未完了: ${depTitles}`,
      blockedBy
    }
  }

  return { executable: true }
}

/**
 * Check phase-based execution (all tasks in previous phases must be done)
 */
function canExecuteInPhase(
  task: TaskWithDependency,
  allTasks: TaskWithDependency[]
): ExecutionCheckResult {
  if (!task.phase || task.phase <= 1) {
    return { executable: true }
  }

  const previousPhaseTasks = allTasks.filter(
    t => t.phase !== undefined && t.phase < task.phase!
  )

  const incomplete = previousPhaseTasks.filter(t => t.status !== 'done')

  if (incomplete.length > 0) {
    return {
      executable: false,
      reason: `フェーズ${task.phase - 1}に未完了タスクが${incomplete.length}件あります`,
      blockedBy: incomplete.map(t => t.id)
    }
  }

  return { executable: true }
}

// ============================================================
// Tests
// ============================================================

describe('parseTaskId', () => {
  test('extracts simple ID', () => {
    expect(parseTaskId('- [ ] Header作成 `cc:TODO` `id:header`')).toBe('header')
  })

  test('extracts ID with hyphens', () => {
    expect(parseTaskId('- [ ] API実装 `id:api-endpoint-v2`')).toBe('api-endpoint-v2')
  })

  test('extracts ID with underscores', () => {
    expect(parseTaskId('- [ ] Test `id:unit_test_auth`')).toBe('unit_test_auth')
  })

  test('returns undefined for missing ID', () => {
    expect(parseTaskId('- [ ] Header作成 `cc:TODO`')).toBeUndefined()
  })

  test('handles multiple backtick sections', () => {
    expect(parseTaskId('- [ ] `feature` task `id:my-task` `cc:TODO`')).toBe('my-task')
  })
})

describe('parseTaskDependencies', () => {
  test('extracts single dependency', () => {
    expect(parseTaskDependencies('`depends:header`')).toEqual(['header'])
  })

  test('extracts multiple dependencies', () => {
    expect(parseTaskDependencies('`depends:header,footer,sidebar`')).toEqual([
      'header',
      'footer',
      'sidebar'
    ])
  })

  test('handles dependencies with hyphens', () => {
    expect(parseTaskDependencies('`depends:api-v2,auth-module`')).toEqual([
      'api-v2',
      'auth-module'
    ])
  })

  test('returns empty array for no dependencies', () => {
    expect(parseTaskDependencies('- [ ] Task without deps')).toEqual([])
  })

  test('handles whitespace in dependency list', () => {
    // Note: Our format doesn't allow spaces, but should be robust
    expect(parseTaskDependencies('`depends:a,b,c`')).toEqual(['a', 'b', 'c'])
  })
})

describe('parsePhase', () => {
  test('extracts phase from Japanese header', () => {
    expect(parsePhase('## フェーズ1: 基盤構築')).toBe(1)
  })

  test('extracts phase from English header', () => {
    expect(parsePhase('## Phase 2: Core Features')).toBe(2)
  })

  test('extracts inline phase marker', () => {
    expect(parsePhase('- [ ] Task `phase:3`')).toBe(3)
  })

  test('uses current phase as fallback', () => {
    expect(parsePhase('- [ ] Regular task', 2)).toBe(2)
  })

  test('returns undefined when no phase info', () => {
    expect(parsePhase('- [ ] Task without phase')).toBeUndefined()
  })
})

describe('parseMarkers', () => {
  test('extracts TDD marker', () => {
    expect(parseMarkers('[feature:tdd]')).toEqual(['feature:tdd'])
  })

  test('extracts multiple markers', () => {
    expect(parseMarkers('[feature:tdd] [feature:security]')).toEqual([
      'feature:tdd',
      'feature:security'
    ])
  })

  test('extracts bugfix marker', () => {
    expect(parseMarkers('[bugfix:reproduce-first]')).toEqual(['bugfix:reproduce-first'])
  })

  test('returns empty for no markers', () => {
    expect(parseMarkers('Regular text')).toEqual([])
  })
})

describe('parseTaskWithDependency', () => {
  test('parses complete task with all metadata', () => {
    const line = '- [ ] Layout作成 `cc:TODO` `id:layout` `depends:header,footer` [feature:tdd]'
    const task = parseTaskWithDependency(line)

    expect(task).toEqual({
      id: 'layout',
      title: 'Layout作成',
      status: 'plan',
      phase: undefined,
      depends: ['header', 'footer'],
      markers: ['feature:tdd']
    })
  })

  test('parses completed task', () => {
    const line = '- [x] Header完了 `cc:完了` `id:header`'
    const task = parseTaskWithDependency(line)

    expect(task?.status).toBe('done')
    expect(task?.id).toBe('header')
  })

  test('parses WIP task', () => {
    const line = '- [x] 作業中タスク `cc:WIP` `id:wip-task`'
    const task = parseTaskWithDependency(line)

    expect(task?.status).toBe('work')
  })

  test('returns null for task without ID', () => {
    const line = '- [ ] Task without ID `cc:TODO`'
    expect(parseTaskWithDependency(line)).toBeNull()
  })

  test('returns null for non-task lines', () => {
    expect(parseTaskWithDependency('## Section Header')).toBeNull()
    expect(parseTaskWithDependency('Regular text')).toBeNull()
  })

  test('inherits phase from context', () => {
    const line = '- [ ] Task `id:task1`'
    const task = parseTaskWithDependency(line, 2)

    expect(task?.phase).toBe(2)
  })
})

describe('canExecuteTask', () => {
  const createTask = (
    id: string,
    status: TaskWithDependency['status'],
    depends?: string[]
  ): TaskWithDependency => ({
    id,
    title: `Task ${id}`,
    status,
    depends
  })

  test('allows execution when no dependencies', () => {
    const task = createTask('task1', 'plan')
    const result = canExecuteTask(task, [task])

    expect(result.executable).toBe(true)
  })

  test('allows execution when all dependencies are done', () => {
    const tasks = [
      createTask('header', 'done'),
      createTask('footer', 'done'),
      createTask('layout', 'plan', ['header', 'footer'])
    ]

    const result = canExecuteTask(tasks[2], tasks)

    expect(result.executable).toBe(true)
  })

  test('blocks execution when dependency is not done', () => {
    const tasks = [
      createTask('header', 'done'),
      createTask('footer', 'work'), // Not done!
      createTask('layout', 'plan', ['header', 'footer'])
    ]

    const result = canExecuteTask(tasks[2], tasks)

    expect(result.executable).toBe(false)
    expect(result.blockedBy).toContain('footer')
    expect(result.reason).toContain('未完了')
  })

  test('blocks execution when dependency is in plan', () => {
    const tasks = [
      createTask('header', 'plan'), // Not started!
      createTask('layout', 'plan', ['header'])
    ]

    const result = canExecuteTask(tasks[1], tasks)

    expect(result.executable).toBe(false)
    expect(result.blockedBy).toEqual(['header'])
  })

  test('reports all blocking dependencies', () => {
    const tasks = [
      createTask('a', 'plan'),
      createTask('b', 'work'),
      createTask('c', 'plan'),
      createTask('final', 'plan', ['a', 'b', 'c'])
    ]

    const result = canExecuteTask(tasks[3], tasks)

    expect(result.executable).toBe(false)
    expect(result.blockedBy).toHaveLength(3)
    expect(result.blockedBy).toContain('a')
    expect(result.blockedBy).toContain('b')
    expect(result.blockedBy).toContain('c')
  })

  test('fails when dependency does not exist', () => {
    const tasks = [
      createTask('layout', 'plan', ['nonexistent'])
    ]

    const result = canExecuteTask(tasks[0], tasks)

    expect(result.executable).toBe(false)
    expect(result.reason).toContain('見つかりません')
  })

  test('handles circular dependency gracefully', () => {
    // This shouldn't happen in practice, but parser should not crash
    const tasks = [
      createTask('a', 'plan', ['b']),
      createTask('b', 'plan', ['a'])
    ]

    const resultA = canExecuteTask(tasks[0], tasks)
    const resultB = canExecuteTask(tasks[1], tasks)

    // Both should be blocked (neither is done)
    expect(resultA.executable).toBe(false)
    expect(resultB.executable).toBe(false)
  })

  test('handles deep dependency chains', () => {
    const tasks = [
      createTask('step1', 'done'),
      createTask('step2', 'done', ['step1']),
      createTask('step3', 'done', ['step2']),
      createTask('step4', 'plan', ['step3']) // Only checks direct dependency
    ]

    const result = canExecuteTask(tasks[3], tasks)

    expect(result.executable).toBe(true)
  })
})

describe('canExecuteInPhase', () => {
  const createTaskWithPhase = (
    id: string,
    phase: number,
    status: TaskWithDependency['status']
  ): TaskWithDependency => ({
    id,
    title: `Task ${id}`,
    status,
    phase
  })

  test('allows phase 1 tasks regardless of other tasks', () => {
    const tasks = [
      createTaskWithPhase('task1', 1, 'plan')
    ]

    const result = canExecuteInPhase(tasks[0], tasks)

    expect(result.executable).toBe(true)
  })

  test('allows phase 2 when phase 1 is complete', () => {
    const tasks = [
      createTaskWithPhase('p1-1', 1, 'done'),
      createTaskWithPhase('p1-2', 1, 'done'),
      createTaskWithPhase('p2-1', 2, 'plan')
    ]

    const result = canExecuteInPhase(tasks[2], tasks)

    expect(result.executable).toBe(true)
  })

  test('blocks phase 2 when phase 1 has incomplete tasks', () => {
    const tasks = [
      createTaskWithPhase('p1-1', 1, 'done'),
      createTaskWithPhase('p1-2', 1, 'work'), // Not done!
      createTaskWithPhase('p2-1', 2, 'plan')
    ]

    const result = canExecuteInPhase(tasks[2], tasks)

    expect(result.executable).toBe(false)
    expect(result.reason).toContain('フェーズ1')
    expect(result.reason).toContain('未完了')
  })

  test('blocks phase 3 when phase 2 is incomplete', () => {
    const tasks = [
      createTaskWithPhase('p1-1', 1, 'done'),
      createTaskWithPhase('p2-1', 2, 'done'),
      createTaskWithPhase('p2-2', 2, 'plan'), // Not done!
      createTaskWithPhase('p3-1', 3, 'plan')
    ]

    const result = canExecuteInPhase(tasks[3], tasks)

    expect(result.executable).toBe(false)
    expect(result.blockedBy).toContain('p2-2')
  })

  test('allows tasks without phase regardless of others', () => {
    const tasks: TaskWithDependency[] = [
      createTaskWithPhase('p1-1', 1, 'plan'),
      { id: 'no-phase', title: 'No phase', status: 'plan' }
    ]

    const result = canExecuteInPhase(tasks[1], tasks)

    expect(result.executable).toBe(true)
  })
})

describe('Integration: Full Plans.md parsing with dependencies', () => {
  /**
   * Parse a full Plans.md content and extract all tasks with dependencies
   */
  function parsePlansWithDependencies(markdown: string): TaskWithDependency[] {
    const lines = markdown.split('\n')
    const tasks: TaskWithDependency[] = []
    let currentPhase: number | undefined

    for (const line of lines) {
      // Check for phase header
      const phaseFromHeader = parsePhase(line)
      if (phaseFromHeader !== undefined) {
        currentPhase = phaseFromHeader
        continue
      }

      // Try to parse as task
      const task = parseTaskWithDependency(line, currentPhase)
      if (task) {
        tasks.push(task)
      }
    }

    return tasks
  }

  test('parses realistic Plans.md with phases and dependencies', () => {
    const markdown = `
# Plans.md

## フェーズ1: 基盤構築

- [x] プロジェクト初期化 \`cc:完了\` \`id:init\`
- [x] 環境設定 \`cc:完了\` \`id:env\` \`depends:init\`

## フェーズ2: コア機能

- [ ] Header作成 \`cc:TODO\` \`id:header\` [feature:a11y]
- [ ] Footer作成 \`cc:TODO\` \`id:footer\` [feature:a11y]
- [ ] Layout作成 \`cc:TODO\` \`id:layout\` \`depends:header,footer\`
- [ ] Page実装 \`cc:TODO\` \`id:page\` \`depends:layout\` [feature:tdd]

## フェーズ3: 仕上げ

- [ ] テスト追加 \`cc:TODO\` \`id:tests\` \`depends:page\`
- [ ] デプロイ \`cc:TODO\` \`id:deploy\` \`depends:tests\`
`
    const tasks = parsePlansWithDependencies(markdown)

    expect(tasks).toHaveLength(8)

    // Phase 1 tasks
    const init = tasks.find(t => t.id === 'init')
    expect(init?.phase).toBe(1)
    expect(init?.status).toBe('done')

    // Phase 2 with dependencies
    const layout = tasks.find(t => t.id === 'layout')
    expect(layout?.phase).toBe(2)
    expect(layout?.depends).toEqual(['header', 'footer'])

    // Markers
    const page = tasks.find(t => t.id === 'page')
    expect(page?.markers).toContain('feature:tdd')

    // Check execution status
    const header = tasks.find(t => t.id === 'header')!
    const headerCanExecute = canExecuteTask(header, tasks)
    expect(headerCanExecute.executable).toBe(true) // No deps, phase 1 done

    const layoutCanExecute = canExecuteTask(layout!, tasks)
    expect(layoutCanExecute.executable).toBe(false) // header/footer not done
    expect(layoutCanExecute.blockedBy).toContain('header')
    expect(layoutCanExecute.blockedBy).toContain('footer')
  })

  test('handles complex dependency graph', () => {
    const markdown = `
## Phase 1

- [x] A \`cc:完了\` \`id:a\`
- [x] B \`cc:完了\` \`id:b\`

## Phase 2

- [x] C \`cc:完了\` \`id:c\` \`depends:a\`
- [ ] D \`cc:TODO\` \`id:d\` \`depends:a,b\`
- [ ] E \`cc:TODO\` \`id:e\` \`depends:c,d\`
`
    const tasks = parsePlansWithDependencies(markdown)

    // D can execute (a and b are done)
    const d = tasks.find(t => t.id === 'd')!
    expect(canExecuteTask(d, tasks).executable).toBe(true)

    // E cannot execute (d is not done)
    const e = tasks.find(t => t.id === 'e')!
    const eResult = canExecuteTask(e, tasks)
    expect(eResult.executable).toBe(false)
    expect(eResult.blockedBy).toContain('d')
    expect(eResult.blockedBy).not.toContain('c') // c is done
  })

  test('validates real harness-style Plans.md', () => {
    const markdown = `
# Plans.md - プロンプト生成機能

> **運用モード**: Solo

---

## フェーズ1: パーサー拡張 \`cc:完了\`

- [x] 依存関係パース実装 \`cc:完了\` \`id:parse-deps\`
- [x] タスクIDパース実装 \`cc:完了\` \`id:parse-id\` \`depends:parse-deps\`

## フェーズ2: 実行制御 \`cc:WIP\`

- [x] 依存関係チェッカー \`cc:完了\` \`id:dep-checker\` \`depends:parse-id\`
- [ ] フェーズチェッカー \`cc:TODO\` \`id:phase-checker\` \`depends:dep-checker\`
- [ ] 現状取得 \`cc:TODO\` \`id:current-state\` [feature:tdd]

## フェーズ3: プロンプト生成 \`cc:TODO\`

- [ ] テンプレートエンジン \`cc:TODO\` \`id:template\` \`depends:phase-checker,current-state\`
- [ ] SDK統合 \`cc:TODO\` \`id:sdk\` \`depends:template\` [feature:security]
- [ ] APIエンドポイント \`cc:TODO\` \`id:api\` \`depends:sdk\`
`
    const tasks = parsePlansWithDependencies(markdown)

    expect(tasks).toHaveLength(8)

    // Current state: phase-checker can execute
    const phaseChecker = tasks.find(t => t.id === 'phase-checker')!
    expect(canExecuteTask(phaseChecker, tasks).executable).toBe(true)

    // Current state: current-state can execute (no deps)
    const currentState = tasks.find(t => t.id === 'current-state')!
    expect(canExecuteTask(currentState, tasks).executable).toBe(true)

    // Template blocked by both phase-checker and current-state
    const template = tasks.find(t => t.id === 'template')!
    const templateResult = canExecuteTask(template, tasks)
    expect(templateResult.executable).toBe(false)
    expect(templateResult.blockedBy).toHaveLength(2)

    // SDK blocked by template
    const sdk = tasks.find(t => t.id === 'sdk')!
    expect(canExecuteTask(sdk, tasks).executable).toBe(false)

    // Check security marker on SDK task
    expect(sdk.markers).toContain('feature:security')
  })
})

describe('Edge cases and error handling', () => {
  test('handles empty Plans.md', () => {
    const tasks: TaskWithDependency[] = []
    // Should not crash
    expect(tasks).toHaveLength(0)
  })

  test('handles task with empty depends', () => {
    const line = '- [ ] Task `id:t1` `depends:`'
    const deps = parseTaskDependencies(line)
    expect(deps).toEqual([])
  })

  test('handles malformed markers gracefully', () => {
    // Missing closing backtick
    expect(parseTaskId('- [ ] Task `id:test')).toBeUndefined()

    // Wrong format
    expect(parseTaskId('- [ ] Task id:test')).toBeUndefined()
  })

  test('handles Unicode in task titles', () => {
    const line = '- [ ] 🚀 ログイン機能 `id:login` `cc:TODO`'
    const task = parseTaskWithDependency(line)

    expect(task?.id).toBe('login')
    expect(task?.title).toContain('ログイン機能')
  })

  test('handles very long dependency lists', () => {
    const deps = 'a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p'
    const line = `- [ ] Task \`id:final\` \`depends:${deps}\``
    const parsed = parseTaskDependencies(line)

    expect(parsed).toHaveLength(16)
  })
})
