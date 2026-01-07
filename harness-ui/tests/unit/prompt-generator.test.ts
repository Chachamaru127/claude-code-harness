import { describe, test, expect, mock, beforeEach, afterEach } from 'bun:test'

/**
 * Prompt Generator Tests
 *
 * Tests for generating rich instruction prompts that include:
 * 1. Task information from Plans.md
 * 2. Related decisions from claude-mem
 * 3. Relevant patterns and learnings
 * 4. Execution context (markers, dependencies)
 * 5. SDK integration for intelligent prompt generation
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

interface ClaudeMemObservation {
  id: string
  type: 'decision' | 'pattern' | 'learning' | 'error' | 'insight'
  title: string
  content: string
  tags?: string[]
  createdAt: string
}

interface ProjectContext {
  projectName: string
  techStack?: string[]
  currentPhase?: number
  totalPhases?: number
}

interface PromptContext {
  task: TaskWithDependency
  relatedDecisions: ClaudeMemObservation[]
  relatedPatterns: ClaudeMemObservation[]
  relatedLearnings: ClaudeMemObservation[]
  projectContext: ProjectContext
  completedDependencies: TaskWithDependency[]
  warnings: string[]
}

interface GeneratedPrompt {
  markdown: string
  copyText: string
  sections: {
    task: string
    context?: string
    approach?: string
    warnings?: string
    command: string
  }
}

// ============================================================
// Implementation (to be moved to services/)
// ============================================================

/**
 * Search claude-mem observations for relevant content
 */
function searchRelevantObservations(
  observations: ClaudeMemObservation[],
  task: TaskWithDependency,
  type: ClaudeMemObservation['type']
): ClaudeMemObservation[] {
  const taskKeywords = extractKeywords(task.title)
  const markerKeywords = task.markers?.flatMap(m => m.split(':')) ?? []
  const allKeywords = [...taskKeywords, ...markerKeywords]

  return observations
    .filter(obs => obs.type === type)
    .filter(obs => {
      const obsText = `${obs.title} ${obs.content} ${obs.tags?.join(' ') ?? ''}`.toLowerCase()
      return allKeywords.some(keyword => obsText.includes(keyword.toLowerCase()))
    })
    .slice(0, 5) // Limit to 5 most relevant
}

/**
 * Extract keywords from task title
 * Splits compound words and filters stop words
 */
function extractKeywords(title: string): string[] {
  const stopWords = ['の', 'を', 'が', 'は', 'に', 'で', 'と', 'する', 'した', 'して', 'a', 'the', 'is', 'are', 'to', 'for', 'and', 'or']

  // Split by whitespace and common delimiters
  const words = title.split(/[\s、,・]+/)

  // Further split Japanese compound words (e.g., "コンポーネント作成" -> ["コンポーネント", "作成"])
  const expandedWords: string[] = []
  for (const word of words) {
    // Try to split by common Japanese action words
    const actionSplit = word.split(/(作成|実装|追加|修正|削除|更新|確認|設定|構築|統合)/)
    if (actionSplit.length > 1) {
      expandedWords.push(...actionSplit.filter(Boolean))
    } else {
      expandedWords.push(word)
    }
  }

  return expandedWords
    .filter(word => word.length > 1)
    .filter(word => !stopWords.includes(word.toLowerCase()))
}

/**
 * Build prompt context from all available data
 */
function buildPromptContext(
  task: TaskWithDependency,
  allTasks: TaskWithDependency[],
  observations: ClaudeMemObservation[],
  projectContext: ProjectContext,
  warnings: string[] = []
): PromptContext {
  return {
    task,
    relatedDecisions: searchRelevantObservations(observations, task, 'decision'),
    relatedPatterns: searchRelevantObservations(observations, task, 'pattern'),
    relatedLearnings: searchRelevantObservations(observations, task, 'learning'),
    projectContext,
    completedDependencies: task.depends
      ? allTasks.filter(t => task.depends!.includes(t.id) && t.status === 'done')
      : [],
    warnings
  }
}

/**
 * Generate approach suggestions based on markers
 */
function generateApproachSuggestions(task: TaskWithDependency): string[] {
  const suggestions: string[] = []

  if (task.markers?.includes('feature:tdd')) {
    suggestions.push('テストファイルを先に作成してください（TDD推奨）')
    suggestions.push('テストケース: 正常系、境界値、異常系を網羅')
  }

  if (task.markers?.includes('feature:security')) {
    suggestions.push('セキュリティチェックリストを確認してください')
    suggestions.push('入力バリデーション、認証・認可、SQLインジェクション対策')
  }

  if (task.markers?.includes('feature:a11y')) {
    suggestions.push('アクセシビリティを考慮してください')
    suggestions.push('aria-label、キーボード操作、コントラスト比')
  }

  if (task.markers?.includes('bugfix:reproduce-first')) {
    suggestions.push('まず再現テストを作成してください')
    suggestions.push('バグが再現することを確認してから修正')
  }

  return suggestions
}

/**
 * Generate the prompt markdown
 */
function generatePromptMarkdown(context: PromptContext): GeneratedPrompt {
  const { task, relatedDecisions, relatedPatterns, relatedLearnings, projectContext, completedDependencies, warnings } = context

  const sections: GeneratedPrompt['sections'] = {
    task: '',
    command: ''
  }

  // Task section
  let taskSection = `## タスク: ${task.title}\n\n`
  if (task.phase) {
    taskSection += `**フェーズ**: ${task.phase}${projectContext.totalPhases ? ` / ${projectContext.totalPhases}` : ''}\n`
  }
  if (task.markers && task.markers.length > 0) {
    taskSection += `**マーカー**: ${task.markers.map(m => `\`${m}\``).join(' ')}\n`
  }
  sections.task = taskSection

  // Context section (decisions + patterns)
  let contextSection = ''

  if (relatedDecisions.length > 0) {
    contextSection += `### 関連する決定事項\n\n`
    for (const decision of relatedDecisions) {
      contextSection += `- **${decision.title}**: ${decision.content.slice(0, 100)}${decision.content.length > 100 ? '...' : ''}\n`
    }
    contextSection += '\n'
  }

  if (relatedPatterns.length > 0) {
    contextSection += `### 参考パターン\n\n`
    for (const pattern of relatedPatterns) {
      contextSection += `- **${pattern.title}**: ${pattern.content.slice(0, 100)}${pattern.content.length > 100 ? '...' : ''}\n`
    }
    contextSection += '\n'
  }

  if (relatedLearnings.length > 0) {
    contextSection += `### 過去の学び\n\n`
    for (const learning of relatedLearnings) {
      contextSection += `- ${learning.title}\n`
    }
    contextSection += '\n'
  }

  if (completedDependencies.length > 0) {
    contextSection += `### 完了済み依存タスク\n\n`
    for (const dep of completedDependencies) {
      contextSection += `- ✅ ${dep.title}\n`
    }
    contextSection += '\n'
  }

  if (contextSection) {
    sections.context = contextSection
  }

  // Approach section
  const suggestions = generateApproachSuggestions(task)
  if (suggestions.length > 0) {
    let approachSection = `### 推奨アプローチ\n\n`
    for (const suggestion of suggestions) {
      approachSection += `- ${suggestion}\n`
    }
    sections.approach = approachSection
  }

  // Warnings section
  if (warnings.length > 0) {
    let warningsSection = `### ⚠️ 注意\n\n`
    for (const warning of warnings) {
      warningsSection += `- ${warning}\n`
    }
    sections.warnings = warningsSection
  }

  // Command section
  sections.command = `\n---\n\n\`/work\` で「${task.title}」を実行してください。`

  // Combine all sections
  const markdown = [
    sections.task,
    sections.context,
    sections.approach,
    sections.warnings,
    sections.command
  ].filter(Boolean).join('\n')

  // Generate copy-friendly text (simplified)
  const copyText = generateCopyText(context)

  return {
    markdown,
    copyText,
    sections
  }
}

/**
 * Generate simplified copy text for clipboard
 */
function generateCopyText(context: PromptContext): string {
  const { task, relatedDecisions, warnings } = context
  const lines: string[] = []

  lines.push(`タスク: ${task.title}`)

  if (task.markers && task.markers.length > 0) {
    if (task.markers.includes('feature:tdd')) {
      lines.push('→ TDD推奨: テストから書いてください')
    }
    if (task.markers.includes('feature:security')) {
      lines.push('→ セキュリティ注意: チェックリストを確認')
    }
  }

  if (relatedDecisions.length > 0) {
    lines.push('')
    lines.push('関連決定:')
    for (const d of relatedDecisions.slice(0, 3)) {
      lines.push(`- ${d.title}`)
    }
  }

  if (warnings.length > 0) {
    lines.push('')
    lines.push('警告:')
    for (const w of warnings) {
      lines.push(`- ${w}`)
    }
  }

  lines.push('')
  lines.push('/work で実行')

  return lines.join('\n')
}

// ============================================================
// Mock Data
// ============================================================

function createMockObservations(): ClaudeMemObservation[] {
  return [
    {
      id: 'dec-1',
      type: 'decision',
      title: 'UIコンポーネントはshadcn/uiを使用',
      content: 'shadcn/uiを採用。理由: カスタマイズ性が高く、Tailwindと相性が良い',
      tags: ['ui', 'component', 'frontend'],
      createdAt: '2024-01-15'
    },
    {
      id: 'dec-2',
      type: 'decision',
      title: '状態管理はZustandを使用',
      content: 'Zustandを採用。Reduxより軽量で、TypeScriptとの相性が良い',
      tags: ['state', 'frontend'],
      createdAt: '2024-01-16'
    },
    {
      id: 'dec-3',
      type: 'decision',
      title: '認証はClerkを使用',
      content: 'Clerkを採用。ソーシャルログイン、MFA対応',
      tags: ['auth', 'security'],
      createdAt: '2024-01-17'
    },
    {
      id: 'pat-1',
      type: 'pattern',
      title: 'コンポーネント構造パターン',
      content: 'src/components/{feature}/{Component}.tsx の構造を使用',
      tags: ['component', 'structure'],
      createdAt: '2024-01-15'
    },
    {
      id: 'pat-2',
      type: 'pattern',
      title: 'APIエンドポイントパターン',
      content: 'tRPCを使用。型安全なAPI呼び出し',
      tags: ['api', 'backend'],
      createdAt: '2024-01-16'
    },
    {
      id: 'learn-1',
      type: 'learning',
      title: 'Headerでのナビゲーションエラー',
      content: 'Next.js AppRouterではLinkコンポーネントを使う必要がある',
      tags: ['header', 'navigation', 'nextjs'],
      createdAt: '2024-01-18'
    },
    {
      id: 'learn-2',
      type: 'learning',
      title: '認証トークンの扱い',
      content: 'httpOnly cookieを使用。localStorageは避ける',
      tags: ['auth', 'security', 'token'],
      createdAt: '2024-01-19'
    }
  ]
}

function createMockProjectContext(): ProjectContext {
  return {
    projectName: 'my-app',
    techStack: ['Next.js', 'TypeScript', 'Tailwind', 'Prisma'],
    currentPhase: 2,
    totalPhases: 4
  }
}

// ============================================================
// Tests: Keyword Extraction
// ============================================================

describe('extractKeywords', () => {
  test('extracts meaningful keywords from Japanese title', () => {
    const keywords = extractKeywords('Header コンポーネント作成')
    expect(keywords).toContain('Header')
    expect(keywords).toContain('コンポーネント') // Split from compound word
    expect(keywords).toContain('作成')
  })

  test('extracts keywords from English title', () => {
    const keywords = extractKeywords('Implement user authentication')
    expect(keywords).toContain('Implement')
    expect(keywords).toContain('user')
    expect(keywords).toContain('authentication')
  })

  test('filters out stop words', () => {
    const keywords = extractKeywords('Create a new component for the header')
    expect(keywords).not.toContain('a')
    expect(keywords).not.toContain('the')
    expect(keywords).not.toContain('for')
  })

  test('handles mixed language', () => {
    const keywords = extractKeywords('認証機能 authentication')
    expect(keywords).toContain('認証機能')
    expect(keywords).toContain('authentication')
  })
})

// ============================================================
// Tests: Observation Search
// ============================================================

describe('searchRelevantObservations', () => {
  const observations = createMockObservations()

  test('finds decisions related to UI task', () => {
    const task: TaskWithDependency = {
      id: 'header',
      title: 'Header コンポーネント作成',
      status: 'plan',
      markers: ['feature:a11y']
    }

    const results = searchRelevantObservations(observations, task, 'decision')

    expect(results.length).toBeGreaterThan(0)
    expect(results.some(r => r.title.includes('UI'))).toBe(true)
  })

  test('finds decisions related to auth task', () => {
    const task: TaskWithDependency = {
      id: 'auth',
      title: '認証機能実装',
      status: 'plan',
      markers: ['feature:security']
    }

    const results = searchRelevantObservations(observations, task, 'decision')

    expect(results.some(r => r.title.includes('認証') || r.tags?.includes('auth'))).toBe(true)
  })

  test('finds patterns related to component task', () => {
    const task: TaskWithDependency = {
      id: 'sidebar',
      title: 'Sidebar component',
      status: 'plan'
    }

    const results = searchRelevantObservations(observations, task, 'pattern')

    expect(results.some(r => r.title.includes('コンポーネント'))).toBe(true)
  })

  test('finds learnings related to header task', () => {
    const task: TaskWithDependency = {
      id: 'header',
      title: 'Header ナビゲーション',
      status: 'plan'
    }

    const results = searchRelevantObservations(observations, task, 'learning')

    expect(results.some(r => r.title.includes('Header'))).toBe(true)
  })

  test('limits results to 5', () => {
    // Create many matching observations
    const manyObs = Array.from({ length: 20 }, (_, i) => ({
      id: `dec-${i}`,
      type: 'decision' as const,
      title: `UIに関する決定 ${i}`,
      content: 'コンポーネントの構造について',
      createdAt: '2024-01-01'
    }))

    const task: TaskWithDependency = {
      id: 'ui',
      title: 'UI コンポーネント',
      status: 'plan'
    }

    const results = searchRelevantObservations(manyObs, task, 'decision')

    expect(results).toHaveLength(5)
  })

  test('returns empty array when no matches', () => {
    const task: TaskWithDependency = {
      id: 'unrelated',
      title: 'Completely unrelated task xyz123',
      status: 'plan'
    }

    const results = searchRelevantObservations(observations, task, 'decision')

    expect(results).toHaveLength(0)
  })

  test('searches by marker keywords', () => {
    const task: TaskWithDependency = {
      id: 'security-task',
      title: 'Some task',
      status: 'plan',
      markers: ['feature:security']
    }

    const results = searchRelevantObservations(observations, task, 'decision')

    // Should find auth-related decisions due to 'security' marker
    expect(results.some(r => r.tags?.includes('security') || r.tags?.includes('auth'))).toBe(true)
  })
})

// ============================================================
// Tests: Prompt Context Building
// ============================================================

describe('buildPromptContext', () => {
  const observations = createMockObservations()
  const projectContext = createMockProjectContext()

  test('builds complete context for task with dependencies', () => {
    const tasks: TaskWithDependency[] = [
      { id: 'header', title: 'Header作成', status: 'done' },
      { id: 'footer', title: 'Footer作成', status: 'done' },
      { id: 'layout', title: 'Layout作成', status: 'plan', depends: ['header', 'footer'] }
    ]

    const context = buildPromptContext(
      tasks[2],
      tasks,
      observations,
      projectContext
    )

    expect(context.task.id).toBe('layout')
    expect(context.completedDependencies).toHaveLength(2)
    expect(context.projectContext.projectName).toBe('my-app')
  })

  test('includes warnings when provided', () => {
    const task: TaskWithDependency = {
      id: 'task1',
      title: 'Test task',
      status: 'plan'
    }

    const context = buildPromptContext(
      task,
      [task],
      observations,
      projectContext,
      ['未コミットの変更があります', 'テストが未実行です']
    )

    expect(context.warnings).toHaveLength(2)
  })

  test('finds related observations', () => {
    const task: TaskWithDependency = {
      id: 'ui-task',
      title: 'UI コンポーネント実装',
      status: 'plan',
      markers: ['feature:a11y']
    }

    const context = buildPromptContext(
      task,
      [task],
      observations,
      projectContext
    )

    expect(context.relatedDecisions.length + context.relatedPatterns.length).toBeGreaterThan(0)
  })
})

// ============================================================
// Tests: Approach Suggestions
// ============================================================

describe('generateApproachSuggestions', () => {
  test('generates TDD suggestions', () => {
    const task: TaskWithDependency = {
      id: 'task1',
      title: 'Feature implementation',
      status: 'plan',
      markers: ['feature:tdd']
    }

    const suggestions = generateApproachSuggestions(task)

    expect(suggestions.some(s => s.includes('テスト'))).toBe(true)
    expect(suggestions.some(s => s.includes('TDD'))).toBe(true)
  })

  test('generates security suggestions', () => {
    const task: TaskWithDependency = {
      id: 'auth',
      title: 'Auth implementation',
      status: 'plan',
      markers: ['feature:security']
    }

    const suggestions = generateApproachSuggestions(task)

    expect(suggestions.some(s => s.includes('セキュリティ'))).toBe(true)
  })

  test('generates a11y suggestions', () => {
    const task: TaskWithDependency = {
      id: 'ui',
      title: 'UI component',
      status: 'plan',
      markers: ['feature:a11y']
    }

    const suggestions = generateApproachSuggestions(task)

    expect(suggestions.some(s => s.includes('アクセシビリティ'))).toBe(true)
  })

  test('generates bugfix suggestions', () => {
    const task: TaskWithDependency = {
      id: 'fix',
      title: 'Bug fix',
      status: 'plan',
      markers: ['bugfix:reproduce-first']
    }

    const suggestions = generateApproachSuggestions(task)

    expect(suggestions.some(s => s.includes('再現'))).toBe(true)
  })

  test('returns empty for no markers', () => {
    const task: TaskWithDependency = {
      id: 'task1',
      title: 'Simple task',
      status: 'plan'
    }

    const suggestions = generateApproachSuggestions(task)

    expect(suggestions).toHaveLength(0)
  })

  test('combines multiple marker suggestions', () => {
    const task: TaskWithDependency = {
      id: 'complex',
      title: 'Complex feature',
      status: 'plan',
      markers: ['feature:tdd', 'feature:security']
    }

    const suggestions = generateApproachSuggestions(task)

    expect(suggestions.some(s => s.includes('TDD'))).toBe(true)
    expect(suggestions.some(s => s.includes('セキュリティ'))).toBe(true)
  })
})

// ============================================================
// Tests: Prompt Generation
// ============================================================

describe('generatePromptMarkdown', () => {
  const observations = createMockObservations()
  const projectContext = createMockProjectContext()

  test('generates basic prompt with task info', () => {
    const task: TaskWithDependency = {
      id: 'header',
      title: 'Header コンポーネント作成',
      status: 'plan',
      phase: 2
    }

    const context = buildPromptContext(task, [task], [], projectContext)
    const result = generatePromptMarkdown(context)

    expect(result.markdown).toContain('## タスク: Header コンポーネント作成')
    expect(result.markdown).toContain('フェーズ')
    expect(result.markdown).toContain('/work')
  })

  test('includes related decisions', () => {
    const task: TaskWithDependency = {
      id: 'ui',
      title: 'UI コンポーネント',
      status: 'plan'
    }

    const context = buildPromptContext(task, [task], observations, projectContext)
    const result = generatePromptMarkdown(context)

    if (context.relatedDecisions.length > 0) {
      expect(result.markdown).toContain('関連する決定事項')
    }
  })

  test('includes approach suggestions for TDD task', () => {
    const task: TaskWithDependency = {
      id: 'feature',
      title: 'New feature',
      status: 'plan',
      markers: ['feature:tdd']
    }

    const context = buildPromptContext(task, [task], [], projectContext)
    const result = generatePromptMarkdown(context)

    expect(result.markdown).toContain('推奨アプローチ')
    expect(result.markdown).toContain('TDD')
  })

  test('includes warnings when present', () => {
    const task: TaskWithDependency = {
      id: 'task1',
      title: 'Task with warnings',
      status: 'plan'
    }

    const context = buildPromptContext(
      task,
      [task],
      [],
      projectContext,
      ['未コミットの変更があります']
    )
    const result = generatePromptMarkdown(context)

    expect(result.markdown).toContain('⚠️ 注意')
    expect(result.markdown).toContain('未コミット')
  })

  test('includes completed dependencies', () => {
    const tasks: TaskWithDependency[] = [
      { id: 'dep1', title: 'Dependency 1', status: 'done' },
      { id: 'dep2', title: 'Dependency 2', status: 'done' },
      { id: 'main', title: 'Main task', status: 'plan', depends: ['dep1', 'dep2'] }
    ]

    const context = buildPromptContext(tasks[2], tasks, [], projectContext)
    const result = generatePromptMarkdown(context)

    expect(result.markdown).toContain('完了済み依存タスク')
    expect(result.markdown).toContain('✅')
  })

  test('generates copy text with simplified format', () => {
    const task: TaskWithDependency = {
      id: 'header',
      title: 'Header作成',
      status: 'plan',
      markers: ['feature:tdd']
    }

    const context = buildPromptContext(task, [task], observations, projectContext)
    const result = generatePromptMarkdown(context)

    expect(result.copyText).toContain('タスク: Header作成')
    expect(result.copyText).toContain('/work で実行')
    expect(result.copyText).toContain('TDD')
  })

  test('has separate sections for modularity', () => {
    const task: TaskWithDependency = {
      id: 'complex',
      title: 'Complex task',
      status: 'plan',
      phase: 2,
      markers: ['feature:security']
    }

    const context = buildPromptContext(
      task,
      [task],
      observations,
      projectContext,
      ['Warning 1']
    )
    const result = generatePromptMarkdown(context)

    expect(result.sections.task).toContain('Complex task')
    expect(result.sections.approach).toContain('セキュリティ')
    expect(result.sections.warnings).toContain('Warning 1')
    expect(result.sections.command).toContain('/work')
  })
})

// ============================================================
// Tests: Realistic Scenarios
// ============================================================

describe('Realistic prompt generation scenarios', () => {
  const observations = createMockObservations()
  const projectContext = createMockProjectContext()

  test('Scenario: UI component with related decisions', () => {
    const tasks: TaskWithDependency[] = [
      { id: 'setup', title: 'プロジェクトセットアップ', status: 'done', phase: 1 },
      { id: 'header', title: 'Header コンポーネント作成', status: 'plan', phase: 2, markers: ['feature:a11y'] }
    ]

    const context = buildPromptContext(tasks[1], tasks, observations, projectContext)
    const result = generatePromptMarkdown(context)

    // Should find UI-related decision
    expect(result.markdown).toContain('shadcn') // From mock decision

    // Should have a11y suggestions
    expect(result.markdown).toContain('アクセシビリティ')

    // Should have command
    expect(result.markdown).toContain('/work')
  })

  test('Scenario: Security task with strict requirements', () => {
    const task: TaskWithDependency = {
      id: 'auth-impl',
      title: '認証機能実装',
      status: 'plan',
      phase: 2,
      markers: ['feature:security', 'feature:tdd']
    }

    const context = buildPromptContext(
      task,
      [task],
      observations,
      projectContext,
      ['未コミットの変更があります（セキュリティタスクには推奨されません）']
    )
    const result = generatePromptMarkdown(context)

    // Should find auth-related decisions
    expect(result.markdown).toContain('認証') // Should match auth decision

    // Should have security and TDD suggestions
    expect(result.markdown).toContain('セキュリティ')
    expect(result.markdown).toContain('TDD')

    // Should show warning
    expect(result.markdown).toContain('⚠️')
  })

  test('Scenario: Task with multiple completed dependencies', () => {
    const tasks: TaskWithDependency[] = [
      { id: 'header', title: 'Header作成', status: 'done', phase: 2 },
      { id: 'footer', title: 'Footer作成', status: 'done', phase: 2 },
      { id: 'sidebar', title: 'Sidebar作成', status: 'done', phase: 2 },
      {
        id: 'layout',
        title: 'Layout統合',
        status: 'plan',
        phase: 2,
        depends: ['header', 'footer', 'sidebar']
      }
    ]

    const context = buildPromptContext(tasks[3], tasks, observations, projectContext)
    const result = generatePromptMarkdown(context)

    expect(result.markdown).toContain('完了済み依存タスク')
    expect(result.markdown).toContain('Header')
    expect(result.markdown).toContain('Footer')
    expect(result.markdown).toContain('Sidebar')
  })

  test('Scenario: Bugfix with reproduce-first marker', () => {
    const task: TaskWithDependency = {
      id: 'bugfix',
      title: 'ログイン時のエラー修正',
      status: 'plan',
      markers: ['bugfix:reproduce-first']
    }

    const context = buildPromptContext(task, [task], observations, projectContext)
    const result = generatePromptMarkdown(context)

    expect(result.markdown).toContain('再現テスト')
    expect(result.copyText).toContain('/work')
  })
})

// ============================================================
// Tests: Edge Cases
// ============================================================

describe('Edge cases', () => {
  test('handles task with no context', () => {
    const task: TaskWithDependency = {
      id: 'minimal',
      title: 'Minimal task',
      status: 'plan'
    }

    const context = buildPromptContext(
      task,
      [task],
      [],
      { projectName: 'test' }
    )
    const result = generatePromptMarkdown(context)

    // Should still generate valid prompt
    expect(result.markdown).toContain('Minimal task')
    expect(result.markdown).toContain('/work')
    expect(result.copyText.length).toBeGreaterThan(0)
  })

  test('handles very long task title', () => {
    const longTitle = 'A'.repeat(200) + ' タスク'
    const task: TaskWithDependency = {
      id: 'long',
      title: longTitle,
      status: 'plan'
    }

    const context = buildPromptContext(task, [task], [], { projectName: 'test' })
    const result = generatePromptMarkdown(context)

    expect(result.markdown).toContain(longTitle)
  })

  test('handles special characters in task title', () => {
    const task: TaskWithDependency = {
      id: 'special',
      title: 'Fix `calculateScore()` & <Component>',
      status: 'plan'
    }

    const context = buildPromptContext(task, [task], [], { projectName: 'test' })
    const result = generatePromptMarkdown(context)

    expect(result.markdown).toContain('calculateScore()')
  })

  test('handles empty observations array', () => {
    const task: TaskWithDependency = {
      id: 'task',
      title: 'Task',
      status: 'plan'
    }

    const context = buildPromptContext(task, [task], [], { projectName: 'test' })

    expect(context.relatedDecisions).toHaveLength(0)
    expect(context.relatedPatterns).toHaveLength(0)
    expect(context.relatedLearnings).toHaveLength(0)
  })

  test('truncates long observation content', () => {
    const longObs: ClaudeMemObservation[] = [{
      id: 'long',
      type: 'decision',
      title: 'Long decision タスク',
      content: 'A'.repeat(500),
      createdAt: '2024-01-01'
    }]

    const task: TaskWithDependency = {
      id: 'task',
      title: 'タスク',
      status: 'plan'
    }

    const context = buildPromptContext(task, [task], longObs, { projectName: 'test' })
    const result = generatePromptMarkdown(context)

    // Content should be truncated with ellipsis
    expect(result.markdown).toContain('...')
  })
})
