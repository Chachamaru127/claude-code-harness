import { describe, test, expect, beforeEach, mock } from 'bun:test'

/**
 * Execution Checker Tests
 *
 * Tests for determining if a task can be executed based on:
 * 1. Dependency completion status
 * 2. Phase ordering
 * 3. Current project state (git, tests, build)
 * 4. Combined checks
 */

// ============================================================
// Type Definitions
// ============================================================

interface TaskWithDependency {
  id: string
  title: string
  status: 'plan' | 'work' | 'review' | 'done'
  phase?: number
  depends?: string[]
  markers?: string[]
}

interface ProjectState {
  git: {
    hasUncommittedChanges: boolean
    uncommittedFiles?: string[]
    currentBranch?: string
  }
  tests: {
    lastRunSuccess: boolean | null
    failedTests?: string[]
    lastRunAt?: string
  }
  build: {
    lastRunSuccess: boolean | null
    errors?: string[]
    lastRunAt?: string
  }
}

interface ExecutionCheckResult {
  executable: boolean
  reason?: string
  blockedBy?: string[]
  warnings?: string[]
}

interface FullExecutionCheck {
  canExecute: boolean
  dependencyCheck: ExecutionCheckResult
  phaseCheck: ExecutionCheckResult
  stateCheck: ExecutionCheckResult
  summary: string
}

// ============================================================
// Implementation (to be moved to services/)
// ============================================================

/**
 * Check dependencies
 */
function checkDependencies(
  task: TaskWithDependency,
  allTasks: TaskWithDependency[]
): ExecutionCheckResult {
  if (!task.depends || task.depends.length === 0) {
    return { executable: true }
  }

  const blockedBy: string[] = []

  for (const depId of task.depends) {
    const depTask = allTasks.find(t => t.id === depId)

    if (!depTask) {
      return {
        executable: false,
        reason: `依存タスク「${depId}」が見つかりません（Plans.mdの設定を確認してください）`,
        blockedBy: [depId]
      }
    }

    if (depTask.status !== 'done') {
      blockedBy.push(depId)
    }
  }

  if (blockedBy.length > 0) {
    const names = blockedBy.map(id => {
      const t = allTasks.find(x => x.id === id)
      return t ? `${t.title}(${id})` : id
    })
    return {
      executable: false,
      reason: `依存タスクが未完了: ${names.join(', ')}`,
      blockedBy
    }
  }

  return { executable: true }
}

/**
 * Check phase ordering
 */
function checkPhase(
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
      reason: `フェーズ${task.phase - 1}以前に未完了タスクが${incomplete.length}件あります`,
      blockedBy: incomplete.map(t => t.id)
    }
  }

  return { executable: true }
}

/**
 * Check project state (git, tests, build)
 */
function checkProjectState(
  task: TaskWithDependency,
  state: ProjectState
): ExecutionCheckResult {
  const warnings: string[] = []
  let executable = true
  let reason: string | undefined

  // Critical: Tests failing blocks execution
  if (state.tests.lastRunSuccess === false) {
    executable = false
    reason = `テストが失敗しています: ${state.tests.failedTests?.join(', ') || '詳細不明'}`
  }

  // Critical: Build failing blocks execution
  if (state.build.lastRunSuccess === false) {
    executable = false
    const buildReason = `ビルドが失敗しています: ${state.build.errors?.join(', ') || '詳細不明'}`
    reason = reason ? `${reason}; ${buildReason}` : buildReason
  }

  // Warning: Uncommitted changes (doesn't block, but warns)
  if (state.git.hasUncommittedChanges) {
    warnings.push(`未コミットの変更があります: ${state.git.uncommittedFiles?.length || '?'}ファイル`)
  }

  // Warning: Tests haven't been run
  if (state.tests.lastRunSuccess === null) {
    warnings.push('テストが未実行です。実行後に再確認を推奨します')
  }

  // Security tasks require clean state
  if (task.markers?.includes('feature:security')) {
    if (state.git.hasUncommittedChanges) {
      executable = false
      reason = 'セキュリティ関連タスクは未コミット変更がない状態で実行してください'
    }
  }

  return {
    executable,
    reason,
    warnings: warnings.length > 0 ? warnings : undefined
  }
}

/**
 * Full execution check combining all conditions
 */
function checkCanExecute(
  task: TaskWithDependency,
  allTasks: TaskWithDependency[],
  state: ProjectState
): FullExecutionCheck {
  const dependencyCheck = checkDependencies(task, allTasks)
  const phaseCheck = checkPhase(task, allTasks)
  const stateCheck = checkProjectState(task, state)

  const canExecute =
    dependencyCheck.executable &&
    phaseCheck.executable &&
    stateCheck.executable

  // Build summary message
  let summary: string
  if (canExecute) {
    if (stateCheck.warnings && stateCheck.warnings.length > 0) {
      summary = `実行可能（警告あり: ${stateCheck.warnings.join(', ')}）`
    } else {
      summary = '実行可能'
    }
  } else {
    const reasons: string[] = []
    if (!dependencyCheck.executable) reasons.push(dependencyCheck.reason!)
    if (!phaseCheck.executable) reasons.push(phaseCheck.reason!)
    if (!stateCheck.executable) reasons.push(stateCheck.reason!)
    summary = `実行不可: ${reasons.join('; ')}`
  }

  return {
    canExecute,
    dependencyCheck,
    phaseCheck,
    stateCheck,
    summary
  }
}

// ============================================================
// Mock helpers
// ============================================================

function createTask(
  id: string,
  status: TaskWithDependency['status'],
  options: {
    depends?: string[]
    phase?: number
    markers?: string[]
    title?: string
  } = {}
): TaskWithDependency {
  return {
    id,
    title: options.title ?? `Task ${id}`,
    status,
    depends: options.depends,
    phase: options.phase,
    markers: options.markers
  }
}

function createCleanState(): ProjectState {
  return {
    git: { hasUncommittedChanges: false },
    tests: { lastRunSuccess: true },
    build: { lastRunSuccess: true }
  }
}

function createDirtyState(options: {
  uncommittedFiles?: string[]
  failedTests?: string[]
  buildErrors?: string[]
  testsNotRun?: boolean
} = {}): ProjectState {
  return {
    git: {
      hasUncommittedChanges: (options.uncommittedFiles?.length ?? 0) > 0,
      uncommittedFiles: options.uncommittedFiles
    },
    tests: {
      lastRunSuccess: options.testsNotRun ? null : (options.failedTests?.length ?? 0) === 0,
      failedTests: options.failedTests
    },
    build: {
      lastRunSuccess: (options.buildErrors?.length ?? 0) === 0,
      errors: options.buildErrors
    }
  }
}

// ============================================================
// Tests: Dependency Check
// ============================================================

describe('checkDependencies', () => {
  test('allows task with no dependencies', () => {
    const task = createTask('task1', 'plan')
    const result = checkDependencies(task, [task])

    expect(result.executable).toBe(true)
  })

  test('allows task when all dependencies are done', () => {
    const tasks = [
      createTask('dep1', 'done'),
      createTask('dep2', 'done'),
      createTask('main', 'plan', { depends: ['dep1', 'dep2'] })
    ]

    const result = checkDependencies(tasks[2], tasks)
    expect(result.executable).toBe(true)
  })

  test('blocks when any dependency is not done', () => {
    const tasks = [
      createTask('dep1', 'done'),
      createTask('dep2', 'work'),
      createTask('main', 'plan', { depends: ['dep1', 'dep2'] })
    ]

    const result = checkDependencies(tasks[2], tasks)

    expect(result.executable).toBe(false)
    expect(result.blockedBy).toEqual(['dep2'])
    expect(result.reason).toContain('dep2')
  })

  test('reports missing dependency', () => {
    const task = createTask('main', 'plan', { depends: ['nonexistent'] })

    const result = checkDependencies(task, [task])

    expect(result.executable).toBe(false)
    expect(result.reason).toContain('見つかりません')
    expect(result.reason).toContain('Plans.md')
  })

  test('blocks when dependency is in review (not done)', () => {
    const tasks = [
      createTask('dep1', 'review'),
      createTask('main', 'plan', { depends: ['dep1'] })
    ]

    const result = checkDependencies(tasks[1], tasks)

    expect(result.executable).toBe(false)
    expect(result.blockedBy).toContain('dep1')
  })

  test('includes task titles in error message', () => {
    const tasks = [
      createTask('header', 'work', { title: 'Header コンポーネント' }),
      createTask('layout', 'plan', { depends: ['header'], title: 'Layout' })
    ]

    const result = checkDependencies(tasks[1], tasks)

    expect(result.reason).toContain('Header コンポーネント')
  })
})

// ============================================================
// Tests: Phase Check
// ============================================================

describe('checkPhase', () => {
  test('allows phase 1 tasks unconditionally', () => {
    const tasks = [
      createTask('other', 'plan', { phase: 1 }),
      createTask('task1', 'plan', { phase: 1 })
    ]

    const result = checkPhase(tasks[1], tasks)
    expect(result.executable).toBe(true)
  })

  test('allows phase 2 when phase 1 is complete', () => {
    const tasks = [
      createTask('p1-task', 'done', { phase: 1 }),
      createTask('p2-task', 'plan', { phase: 2 })
    ]

    const result = checkPhase(tasks[1], tasks)
    expect(result.executable).toBe(true)
  })

  test('blocks phase 2 when phase 1 is incomplete', () => {
    const tasks = [
      createTask('p1-done', 'done', { phase: 1 }),
      createTask('p1-wip', 'work', { phase: 1 }),
      createTask('p2-task', 'plan', { phase: 2 })
    ]

    const result = checkPhase(tasks[2], tasks)

    expect(result.executable).toBe(false)
    expect(result.reason).toContain('フェーズ1')
    expect(result.blockedBy).toContain('p1-wip')
  })

  test('blocks phase 3 when any earlier phase is incomplete', () => {
    const tasks = [
      createTask('p1-task', 'done', { phase: 1 }),
      createTask('p2-task', 'plan', { phase: 2 }),
      createTask('p3-task', 'plan', { phase: 3 })
    ]

    const result = checkPhase(tasks[2], tasks)

    expect(result.executable).toBe(false)
    expect(result.blockedBy).toContain('p2-task')
  })

  test('allows tasks without phase', () => {
    const tasks = [
      createTask('phased', 'plan', { phase: 1 }),
      createTask('unphased', 'plan')
    ]

    const result = checkPhase(tasks[1], tasks)
    expect(result.executable).toBe(true)
  })

  test('handles multiple incomplete tasks in previous phase', () => {
    const tasks = [
      createTask('p1-a', 'plan', { phase: 1 }),
      createTask('p1-b', 'work', { phase: 1 }),
      createTask('p1-c', 'review', { phase: 1 }),
      createTask('p2-task', 'plan', { phase: 2 })
    ]

    const result = checkPhase(tasks[3], tasks)

    expect(result.executable).toBe(false)
    expect(result.blockedBy).toHaveLength(3)
  })
})

// ============================================================
// Tests: Project State Check
// ============================================================

describe('checkProjectState', () => {
  test('allows execution with clean state', () => {
    const task = createTask('task1', 'plan')
    const state = createCleanState()

    const result = checkProjectState(task, state)

    expect(result.executable).toBe(true)
    expect(result.warnings).toBeUndefined()
  })

  test('blocks execution when tests are failing', () => {
    const task = createTask('task1', 'plan')
    const state = createDirtyState({
      failedTests: ['auth.test.ts', 'user.test.ts']
    })

    const result = checkProjectState(task, state)

    expect(result.executable).toBe(false)
    expect(result.reason).toContain('テストが失敗')
    expect(result.reason).toContain('auth.test.ts')
  })

  test('blocks execution when build is failing', () => {
    const task = createTask('task1', 'plan')
    const state = createDirtyState({
      buildErrors: ['Type error in api.ts']
    })

    const result = checkProjectState(task, state)

    expect(result.executable).toBe(false)
    expect(result.reason).toContain('ビルドが失敗')
  })

  test('warns on uncommitted changes but allows execution', () => {
    const task = createTask('task1', 'plan')
    const state = createDirtyState({
      uncommittedFiles: ['src/api.ts', 'src/utils.ts']
    })

    const result = checkProjectState(task, state)

    expect(result.executable).toBe(true)
    expect(result.warnings).toBeDefined()
    expect(result.warnings![0]).toContain('未コミット')
  })

  test('warns when tests have not been run', () => {
    const task = createTask('task1', 'plan')
    const state = createDirtyState({ testsNotRun: true })

    const result = checkProjectState(task, state)

    expect(result.executable).toBe(true)
    expect(result.warnings).toBeDefined()
    expect(result.warnings![0]).toContain('テストが未実行')
  })

  test('blocks security tasks with uncommitted changes', () => {
    const task = createTask('auth', 'plan', {
      markers: ['feature:security']
    })
    const state = createDirtyState({
      uncommittedFiles: ['src/auth.ts']
    })

    const result = checkProjectState(task, state)

    expect(result.executable).toBe(false)
    expect(result.reason).toContain('セキュリティ')
    expect(result.reason).toContain('未コミット')
  })

  test('allows security tasks with clean state', () => {
    const task = createTask('auth', 'plan', {
      markers: ['feature:security']
    })
    const state = createCleanState()

    const result = checkProjectState(task, state)

    expect(result.executable).toBe(true)
  })

  test('combines multiple failure reasons', () => {
    const task = createTask('task1', 'plan')
    const state = createDirtyState({
      failedTests: ['test1.ts'],
      buildErrors: ['error in file.ts']
    })

    const result = checkProjectState(task, state)

    expect(result.executable).toBe(false)
    expect(result.reason).toContain('テスト')
    expect(result.reason).toContain('ビルド')
  })
})

// ============================================================
// Tests: Full Execution Check
// ============================================================

describe('checkCanExecute (integration)', () => {
  test('returns full check result for executable task', () => {
    const tasks = [
      createTask('dep1', 'done', { phase: 1 }),
      createTask('main', 'plan', { phase: 2, depends: ['dep1'] })
    ]
    const state = createCleanState()

    const result = checkCanExecute(tasks[1], tasks, state)

    expect(result.canExecute).toBe(true)
    expect(result.dependencyCheck.executable).toBe(true)
    expect(result.phaseCheck.executable).toBe(true)
    expect(result.stateCheck.executable).toBe(true)
    expect(result.summary).toBe('実行可能')
  })

  test('returns full check result for blocked task', () => {
    const tasks = [
      createTask('dep1', 'work', { phase: 1 }),
      createTask('main', 'plan', { phase: 2, depends: ['dep1'] })
    ]
    const state = createCleanState()

    const result = checkCanExecute(tasks[1], tasks, state)

    expect(result.canExecute).toBe(false)
    expect(result.dependencyCheck.executable).toBe(false)
    expect(result.phaseCheck.executable).toBe(false) // Phase 1 incomplete
    expect(result.summary).toContain('実行不可')
  })

  test('includes warnings in summary', () => {
    const tasks = [
      createTask('main', 'plan')
    ]
    const state = createDirtyState({
      uncommittedFiles: ['file.ts']
    })

    const result = checkCanExecute(tasks[0], tasks, state)

    expect(result.canExecute).toBe(true)
    expect(result.summary).toContain('警告あり')
  })

  test('blocks on state even if deps and phase are OK', () => {
    const tasks = [
      createTask('dep1', 'done', { phase: 1 }),
      createTask('main', 'plan', { phase: 2, depends: ['dep1'] })
    ]
    const state = createDirtyState({
      failedTests: ['failing.test.ts']
    })

    const result = checkCanExecute(tasks[1], tasks, state)

    expect(result.canExecute).toBe(false)
    expect(result.dependencyCheck.executable).toBe(true)
    expect(result.phaseCheck.executable).toBe(true)
    expect(result.stateCheck.executable).toBe(false)
  })

  test('combines all failure reasons in summary', () => {
    const tasks = [
      createTask('dep1', 'work', { phase: 1 }),
      createTask('main', 'plan', { phase: 2, depends: ['dep1'] })
    ]
    const state = createDirtyState({
      failedTests: ['test.ts']
    })

    const result = checkCanExecute(tasks[1], tasks, state)

    expect(result.canExecute).toBe(false)
    expect(result.summary).toContain('依存タスク')
    expect(result.summary).toContain('フェーズ')
    expect(result.summary).toContain('テスト')
  })
})

// ============================================================
// Tests: Realistic Scenarios
// ============================================================

describe('Realistic scenarios', () => {
  test('Scenario: Starting a new feature after setup', () => {
    const tasks = [
      createTask('init', 'done', { phase: 1, title: 'プロジェクト初期化' }),
      createTask('env', 'done', { phase: 1, title: '環境設定', depends: ['init'] }),
      createTask('header', 'plan', { phase: 2, title: 'Header作成' }),
      createTask('footer', 'plan', { phase: 2, title: 'Footer作成' }),
      createTask('layout', 'plan', { phase: 2, title: 'Layout作成', depends: ['header', 'footer'] })
    ]
    const state = createCleanState()

    // header can execute
    expect(checkCanExecute(tasks[2], tasks, state).canExecute).toBe(true)

    // footer can execute
    expect(checkCanExecute(tasks[3], tasks, state).canExecute).toBe(true)

    // layout cannot (deps not done)
    expect(checkCanExecute(tasks[4], tasks, state).canExecute).toBe(false)
  })

  test('Scenario: Progressing through phases', () => {
    const tasks = [
      createTask('p1-1', 'done', { phase: 1 }),
      createTask('p1-2', 'done', { phase: 1 }),
      createTask('p2-1', 'done', { phase: 2 }),
      createTask('p2-2', 'work', { phase: 2 }), // Still in progress
      createTask('p3-1', 'plan', { phase: 3 })
    ]
    const state = createCleanState()

    // Phase 3 blocked because phase 2 incomplete
    const result = checkCanExecute(tasks[4], tasks, state)
    expect(result.canExecute).toBe(false)
    expect(result.phaseCheck.blockedBy).toContain('p2-2')
  })

  test('Scenario: Test failure blocks all new work', () => {
    const tasks = [
      createTask('feature-a', 'done', { phase: 1 }),
      createTask('feature-b', 'plan', { phase: 1 })
    ]
    const state = createDirtyState({
      failedTests: ['feature-a.test.ts']
    })

    // Even though deps and phase are OK, test failure blocks
    const result = checkCanExecute(tasks[1], tasks, state)
    expect(result.canExecute).toBe(false)
    expect(result.summary).toContain('テストが失敗')
  })

  test('Scenario: Security audit with clean state required', () => {
    const tasks = [
      createTask('implement', 'done', { phase: 1 }),
      createTask('security-audit', 'plan', {
        phase: 2,
        depends: ['implement'],
        markers: ['feature:security']
      })
    ]

    // With uncommitted changes - blocked
    const dirtyState = createDirtyState({ uncommittedFiles: ['src/auth.ts'] })
    const dirtyResult = checkCanExecute(tasks[1], tasks, dirtyState)
    expect(dirtyResult.canExecute).toBe(false)

    // With clean state - allowed
    const cleanState = createCleanState()
    const cleanResult = checkCanExecute(tasks[1], tasks, cleanState)
    expect(cleanResult.canExecute).toBe(true)
  })

  test('Scenario: Complex dependency graph', () => {
    // Diamond dependency pattern
    //     A
    //    / \
    //   B   C
    //    \ /
    //     D
    const tasks = [
      createTask('a', 'done'),
      createTask('b', 'done', { depends: ['a'] }),
      createTask('c', 'work', { depends: ['a'] }), // Not done!
      createTask('d', 'plan', { depends: ['b', 'c'] })
    ]
    const state = createCleanState()

    const result = checkCanExecute(tasks[3], tasks, state)

    expect(result.canExecute).toBe(false)
    expect(result.dependencyCheck.blockedBy).toEqual(['c'])
    expect(result.dependencyCheck.blockedBy).not.toContain('b')
  })

  test('Scenario: Multiple warnings but still executable', () => {
    const tasks = [
      createTask('task', 'plan')
    ]
    const state: ProjectState = {
      git: {
        hasUncommittedChanges: true,
        uncommittedFiles: ['file1.ts', 'file2.ts']
      },
      tests: {
        lastRunSuccess: null // Not run
      },
      build: {
        lastRunSuccess: true
      }
    }

    const result = checkCanExecute(tasks[0], tasks, state)

    expect(result.canExecute).toBe(true)
    expect(result.stateCheck.warnings).toHaveLength(2)
    expect(result.summary).toContain('警告あり')
  })
})

// ============================================================
// Tests: Edge Cases
// ============================================================

describe('Edge cases', () => {
  test('handles empty task list', () => {
    const task = createTask('solo', 'plan')
    const state = createCleanState()

    // Task is not in allTasks - should still work for self-contained task
    const result = checkCanExecute(task, [task], state)
    expect(result.canExecute).toBe(true)
  })

  test('handles task depending on itself (invalid but should not crash)', () => {
    const task = createTask('self', 'plan', { depends: ['self'] })
    const state = createCleanState()

    const result = checkCanExecute(task, [task], state)

    // Self-dependency means task is never done, so blocked
    expect(result.canExecute).toBe(false)
  })

  test('handles very long dependency chain', () => {
    const tasks: TaskWithDependency[] = []
    for (let i = 0; i < 20; i++) {
      tasks.push(createTask(
        `task-${i}`,
        i < 19 ? 'done' : 'plan',
        { depends: i > 0 ? [`task-${i - 1}`] : undefined }
      ))
    }
    const state = createCleanState()

    // Last task can execute (all deps done)
    const result = checkCanExecute(tasks[19], tasks, state)
    expect(result.canExecute).toBe(true)
  })

  test('handles task with many dependencies', () => {
    const deps: TaskWithDependency[] = []
    for (let i = 0; i < 10; i++) {
      deps.push(createTask(`dep-${i}`, i < 9 ? 'done' : 'work'))
    }
    const main = createTask('main', 'plan', {
      depends: deps.map(d => d.id)
    })
    const state = createCleanState()

    const result = checkCanExecute(main, [...deps, main], state)

    expect(result.canExecute).toBe(false)
    expect(result.dependencyCheck.blockedBy).toContain('dep-9')
  })

  test('handles null/undefined in state gracefully', () => {
    const task = createTask('task', 'plan')
    const state: ProjectState = {
      git: { hasUncommittedChanges: false },
      tests: { lastRunSuccess: null },
      build: { lastRunSuccess: null }
    }

    // Should not crash
    const result = checkCanExecute(task, [task], state)
    expect(result.canExecute).toBe(true)
  })
})
