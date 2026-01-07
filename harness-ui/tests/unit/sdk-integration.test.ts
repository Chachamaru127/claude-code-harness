import { describe, test, expect, mock, beforeEach, afterEach } from 'bun:test'

/**
 * SDK Integration Tests
 *
 * Tests for the Claude Agent SDK integration for intelligent prompt generation.
 * Uses mocks to avoid actual API calls.
 *
 * This tests:
 * 1. SDK client initialization
 * 2. Prompt enhancement via SDK
 * 3. Error handling
 * 4. Rate limiting and retries
 * 5. Response parsing
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

interface PromptContext {
  task: TaskWithDependency
  relatedDecisions: { title: string; content: string }[]
  relatedPatterns: { title: string; content: string }[]
  relatedLearnings: { title: string }[]
  projectContext: { projectName: string; techStack?: string[] }
  completedDependencies: TaskWithDependency[]
  warnings: string[]
}

interface SDKMessage {
  role: 'user' | 'assistant'
  content: string
}

interface SDKResponse {
  content: Array<{ type: 'text'; text: string }>
  usage?: {
    input_tokens: number
    output_tokens: number
  }
}

interface SDKError extends Error {
  status?: number
  error?: { type: string; message: string }
}

// ============================================================
// Mock SDK Client
// ============================================================

class MockAnthropicClient {
  private mockResponses: Map<string, SDKResponse> = new Map()
  private callHistory: Array<{ model: string; messages: SDKMessage[] }> = []
  private shouldFail: boolean = false
  private failureError: SDKError | null = null

  setMockResponse(promptContains: string, response: SDKResponse) {
    this.mockResponses.set(promptContains, response)
  }

  setFailure(error: SDKError) {
    this.shouldFail = true
    this.failureError = error
  }

  clearFailure() {
    this.shouldFail = false
    this.failureError = null
  }

  getCallHistory() {
    return this.callHistory
  }

  clearHistory() {
    this.callHistory = []
  }

  messages = {
    create: async (params: {
      model: string
      max_tokens: number
      system?: string
      messages: SDKMessage[]
    }): Promise<SDKResponse> => {
      // Record the call
      this.callHistory.push({
        model: params.model,
        messages: params.messages
      })

      // Simulate failure if configured
      if (this.shouldFail && this.failureError) {
        throw this.failureError
      }

      // Find matching mock response
      const userMessage = params.messages.find(m => m.role === 'user')?.content ?? ''

      for (const [key, response] of this.mockResponses) {
        if (userMessage.includes(key)) {
          return response
        }
      }

      // Default response
      return {
        content: [{
          type: 'text',
          text: `## タスク分析

このタスクを実行するための推奨アプローチ:

1. 既存のコードパターンを確認
2. テストを先に書く
3. 実装を進める

/work で実行してください。`
        }],
        usage: {
          input_tokens: 500,
          output_tokens: 100
        }
      }
    }
  }
}

// ============================================================
// Prompt Enhancement Service (to be implemented)
// ============================================================

interface EnhancedPrompt {
  original: string
  enhanced: string
  aiAnalysis: string
  suggestions: string[]
  estimatedComplexity: 'low' | 'medium' | 'high'
  usage?: { input_tokens: number; output_tokens: number }
}

class PromptEnhancementService {
  private client: MockAnthropicClient
  private model: string = 'claude-sonnet-4-20250514'
  private maxRetries: number = 3
  private retryDelayMs: number = 1000

  constructor(client: MockAnthropicClient) {
    this.client = client
  }

  /**
   * Enhance a prompt using the SDK
   */
  async enhancePrompt(
    basePrompt: string,
    context: PromptContext
  ): Promise<EnhancedPrompt> {
    const systemPrompt = this.buildSystemPrompt()
    const userPrompt = this.buildUserPrompt(basePrompt, context)

    let lastError: Error | null = null

    for (let attempt = 0; attempt < this.maxRetries; attempt++) {
      try {
        const response = await this.client.messages.create({
          model: this.model,
          max_tokens: 2048,
          system: systemPrompt,
          messages: [{ role: 'user', content: userPrompt }]
        })

        return this.parseResponse(basePrompt, response)
      } catch (error) {
        lastError = error as Error

        // Don't retry on non-retryable errors
        if (this.isNonRetryableError(error as SDKError)) {
          throw error
        }

        // Wait before retry (exponential backoff in real implementation)
        if (attempt < this.maxRetries - 1) {
          await this.delay(this.retryDelayMs * Math.pow(2, attempt))
        }
      }
    }

    throw lastError ?? new Error('Unknown error during prompt enhancement')
  }

  /**
   * Build the system prompt for the SDK
   */
  private buildSystemPrompt(): string {
    return `あなたはclaude-code-harnessの指示プロンプト生成アシスタントです。

タスクとコンテキストを分析し、Claude Codeに渡す最適な指示プロンプトを生成してください。

出力形式:
1. タスクの分析（複雑さ、注意点）
2. 推奨アプローチ（ステップバイステップ）
3. 関連する過去の決定・パターンの活用方法
4. 潜在的なリスクと対策
5. 実行コマンド

必ず日本語で回答してください。`
  }

  /**
   * Build the user prompt with context
   */
  private buildUserPrompt(basePrompt: string, context: PromptContext): string {
    const parts: string[] = []

    parts.push(`## タスク\n${context.task.title}`)

    if (context.task.markers && context.task.markers.length > 0) {
      parts.push(`\n## マーカー\n${context.task.markers.join(', ')}`)
    }

    if (context.relatedDecisions.length > 0) {
      parts.push(`\n## 関連する決定事項`)
      for (const d of context.relatedDecisions) {
        parts.push(`- ${d.title}: ${d.content}`)
      }
    }

    if (context.relatedPatterns.length > 0) {
      parts.push(`\n## 参考パターン`)
      for (const p of context.relatedPatterns) {
        parts.push(`- ${p.title}: ${p.content}`)
      }
    }

    if (context.projectContext.techStack) {
      parts.push(`\n## 技術スタック\n${context.projectContext.techStack.join(', ')}`)
    }

    if (context.warnings.length > 0) {
      parts.push(`\n## 警告\n${context.warnings.join('\n')}`)
    }

    parts.push(`\n## ベースプロンプト\n${basePrompt}`)

    parts.push(`\n上記を踏まえて、最適な指示プロンプトを生成してください。`)

    return parts.join('\n')
  }

  /**
   * Parse the SDK response into EnhancedPrompt
   */
  private parseResponse(basePrompt: string, response: SDKResponse): EnhancedPrompt {
    const text = response.content[0]?.text ?? ''

    // Extract suggestions (lines starting with numbers or bullets)
    const suggestions = text
      .split('\n')
      .filter(line => /^[\d\-\*]/.test(line.trim()))
      .map(line => line.replace(/^[\d\.\-\*\s]+/, '').trim())
      .filter(Boolean)
      .slice(0, 5)

    // Estimate complexity based on response content
    let estimatedComplexity: 'low' | 'medium' | 'high' = 'medium'
    const lowerText = text.toLowerCase()
    if (lowerText.includes('複雑') || lowerText.includes('注意') || lowerText.includes('リスク')) {
      estimatedComplexity = 'high'
    } else if (lowerText.includes('シンプル') || lowerText.includes('簡単')) {
      estimatedComplexity = 'low'
    }

    return {
      original: basePrompt,
      enhanced: text,
      aiAnalysis: text.split('\n').slice(0, 3).join('\n'),
      suggestions,
      estimatedComplexity,
      usage: response.usage
    }
  }

  /**
   * Check if error is non-retryable
   */
  private isNonRetryableError(error: SDKError): boolean {
    // 4xx errors (except 429) are not retryable
    if (error.status && error.status >= 400 && error.status < 500 && error.status !== 429) {
      return true
    }
    // Invalid API key
    if (error.error?.type === 'authentication_error') {
      return true
    }
    return false
  }

  /**
   * Delay helper
   */
  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms))
  }
}

// ============================================================
// Test Helpers
// ============================================================

function createMockContext(overrides: Partial<PromptContext> = {}): PromptContext {
  return {
    task: {
      id: 'test-task',
      title: 'Test task',
      status: 'plan',
      ...overrides.task
    },
    relatedDecisions: overrides.relatedDecisions ?? [],
    relatedPatterns: overrides.relatedPatterns ?? [],
    relatedLearnings: overrides.relatedLearnings ?? [],
    projectContext: {
      projectName: 'test-project',
      ...overrides.projectContext
    },
    completedDependencies: overrides.completedDependencies ?? [],
    warnings: overrides.warnings ?? []
  }
}

function createSDKError(status: number, type: string, message: string): SDKError {
  const error = new Error(message) as SDKError
  error.status = status
  error.error = { type, message }
  return error
}

// ============================================================
// Tests: SDK Client Initialization
// ============================================================

describe('PromptEnhancementService initialization', () => {
  test('creates service with mock client', () => {
    const client = new MockAnthropicClient()
    const service = new PromptEnhancementService(client)

    expect(service).toBeDefined()
  })
})

// ============================================================
// Tests: Prompt Enhancement
// ============================================================

describe('enhancePrompt', () => {
  let client: MockAnthropicClient
  let service: PromptEnhancementService

  beforeEach(() => {
    client = new MockAnthropicClient()
    service = new PromptEnhancementService(client)
  })

  test('enhances basic prompt', async () => {
    const context = createMockContext({
      task: { id: 'header', title: 'Header作成', status: 'plan' }
    })

    const result = await service.enhancePrompt('Header作成', context)

    expect(result.original).toBe('Header作成')
    expect(result.enhanced).toBeDefined()
    expect(result.enhanced.length).toBeGreaterThan(0)
  })

  test('includes context in SDK call', async () => {
    const context = createMockContext({
      task: {
        id: 'auth',
        title: '認証機能実装',
        status: 'plan',
        markers: ['feature:security']
      },
      relatedDecisions: [
        { title: 'Clerk使用', content: '認証にはClerkを採用' }
      ],
      projectContext: {
        projectName: 'my-app',
        techStack: ['Next.js', 'TypeScript']
      }
    })

    await service.enhancePrompt('認証機能実装', context)

    const calls = client.getCallHistory()
    expect(calls).toHaveLength(1)

    const userMessage = calls[0].messages.find(m => m.role === 'user')?.content ?? ''
    expect(userMessage).toContain('認証機能実装')
    expect(userMessage).toContain('feature:security')
    expect(userMessage).toContain('Clerk')
    expect(userMessage).toContain('Next.js')
  })

  test('extracts suggestions from response', async () => {
    client.setMockResponse('Header', {
      content: [{
        type: 'text',
        text: `## 分析

このタスクの推奨アプローチ:

1. shadcn/ui の Button, Navigation を使用
2. レスポンシブデザインを考慮
3. アクセシビリティ属性を追加
4. テストを書く

/work で実行`
      }]
    })

    const context = createMockContext({
      task: { id: 'header', title: 'Header作成', status: 'plan' }
    })

    const result = await service.enhancePrompt('Header', context)

    expect(result.suggestions.length).toBeGreaterThan(0)
    expect(result.suggestions.some(s => s.includes('shadcn'))).toBe(true)
  })

  test('estimates complexity from response', async () => {
    client.setMockResponse('複雑なタスク', {
      content: [{
        type: 'text',
        text: `## 分析

このタスクは複雑です。注意が必要です。
リスクが高いため慎重に進めてください。`
      }]
    })

    const context = createMockContext({
      task: { id: 'complex', title: '複雑なタスク', status: 'plan' }
    })

    const result = await service.enhancePrompt('複雑なタスク', context)

    expect(result.estimatedComplexity).toBe('high')
  })

  test('includes usage information', async () => {
    const context = createMockContext()

    const result = await service.enhancePrompt('Test', context)

    expect(result.usage).toBeDefined()
    expect(result.usage?.input_tokens).toBeGreaterThan(0)
    expect(result.usage?.output_tokens).toBeGreaterThan(0)
  })

  test('includes warnings in prompt', async () => {
    const context = createMockContext({
      warnings: ['未コミットの変更があります', 'テストが失敗しています']
    })

    await service.enhancePrompt('Test', context)

    const calls = client.getCallHistory()
    const userMessage = calls[0].messages.find(m => m.role === 'user')?.content ?? ''

    expect(userMessage).toContain('警告')
    expect(userMessage).toContain('未コミット')
    expect(userMessage).toContain('テストが失敗')
  })
})

// ============================================================
// Tests: Error Handling
// ============================================================

describe('error handling', () => {
  let client: MockAnthropicClient
  let service: PromptEnhancementService

  beforeEach(() => {
    client = new MockAnthropicClient()
    service = new PromptEnhancementService(client)
  })

  afterEach(() => {
    client.clearFailure()
  })

  test('throws on authentication error (no retry)', async () => {
    client.setFailure(createSDKError(401, 'authentication_error', 'Invalid API key'))

    const context = createMockContext()

    await expect(service.enhancePrompt('Test', context)).rejects.toThrow('Invalid API key')

    // Should only try once (no retry for auth errors)
    expect(client.getCallHistory()).toHaveLength(1)
  })

  test('throws on bad request error (no retry)', async () => {
    client.setFailure(createSDKError(400, 'invalid_request_error', 'Bad request'))

    const context = createMockContext()

    await expect(service.enhancePrompt('Test', context)).rejects.toThrow('Bad request')
    expect(client.getCallHistory()).toHaveLength(1)
  })

  test('retries on server error', async () => {
    // Fail twice, then succeed
    let callCount = 0
    const originalCreate = client.messages.create.bind(client.messages)

    client.messages.create = async (params: any) => {
      callCount++
      if (callCount < 3) {
        throw createSDKError(500, 'server_error', 'Internal server error')
      }
      return originalCreate(params)
    }

    const context = createMockContext()

    // Should eventually succeed after retries
    const result = await service.enhancePrompt('Test', context)

    expect(result.enhanced).toBeDefined()
    expect(callCount).toBe(3)
  })

  test('throws after max retries exceeded', async () => {
    client.setFailure(createSDKError(500, 'server_error', 'Internal server error'))

    const context = createMockContext()

    await expect(service.enhancePrompt('Test', context)).rejects.toThrow('Internal server error')

    // Should try maxRetries times
    expect(client.getCallHistory()).toHaveLength(3)
  })

  test('retries on rate limit error', async () => {
    // Fail with rate limit twice, then succeed
    let callCount = 0
    const originalCreate = client.messages.create.bind(client.messages)

    client.messages.create = async (params: any) => {
      callCount++
      if (callCount < 3) {
        throw createSDKError(429, 'rate_limit_error', 'Rate limited')
      }
      return originalCreate(params)
    }

    const context = createMockContext()

    const result = await service.enhancePrompt('Test', context)

    expect(result.enhanced).toBeDefined()
    expect(callCount).toBe(3)
  })
})

// ============================================================
// Tests: Response Parsing
// ============================================================

describe('response parsing', () => {
  let client: MockAnthropicClient
  let service: PromptEnhancementService

  beforeEach(() => {
    client = new MockAnthropicClient()
    service = new PromptEnhancementService(client)
  })

  test('handles empty response', async () => {
    client.setMockResponse('empty', {
      content: [{ type: 'text', text: '' }]
    })

    const context = createMockContext({
      task: { id: 'empty', title: 'empty', status: 'plan' }
    })

    const result = await service.enhancePrompt('empty', context)

    expect(result.enhanced).toBe('')
    expect(result.suggestions).toHaveLength(0)
  })

  test('handles response with no suggestions', async () => {
    client.setMockResponse('no-suggestions', {
      content: [{
        type: 'text',
        text: 'Just a plain text response without any numbered items.'
      }]
    })

    const context = createMockContext({
      task: { id: 'no-suggestions', title: 'no-suggestions', status: 'plan' }
    })

    const result = await service.enhancePrompt('no-suggestions', context)

    expect(result.suggestions).toHaveLength(0)
  })

  test('limits suggestions to 5', async () => {
    client.setMockResponse('many', {
      content: [{
        type: 'text',
        text: `Steps:
1. First
2. Second
3. Third
4. Fourth
5. Fifth
6. Sixth
7. Seventh`
      }]
    })

    const context = createMockContext({
      task: { id: 'many', title: 'many', status: 'plan' }
    })

    const result = await service.enhancePrompt('many', context)

    expect(result.suggestions).toHaveLength(5)
  })

  test('handles Japanese bullet points', async () => {
    client.setMockResponse('japanese', {
      content: [{
        type: 'text',
        text: `推奨事項:
- テストを先に書く
- 型安全を確保
- エラーハンドリングを追加`
      }]
    })

    const context = createMockContext({
      task: { id: 'japanese', title: 'japanese', status: 'plan' }
    })

    const result = await service.enhancePrompt('japanese', context)

    expect(result.suggestions.some(s => s.includes('テスト'))).toBe(true)
  })
})

// ============================================================
// Tests: Integration Scenarios
// ============================================================

describe('integration scenarios', () => {
  let client: MockAnthropicClient
  let service: PromptEnhancementService

  beforeEach(() => {
    client = new MockAnthropicClient()
    service = new PromptEnhancementService(client)
  })

  test('Scenario: Security task with full context', async () => {
    client.setMockResponse('認証', {
      content: [{
        type: 'text',
        text: `## セキュリティ分析

このタスクはセキュリティに関連するため、注意が必要です。

推奨事項:
1. Clerkの設定を確認
2. 環境変数でシークレットを管理
3. CSRFトークンを実装
4. セッション管理を確認

リスク:
- 認証バイパスの可能性
- トークン漏洩のリスク

/work で実行してください。`
      }]
    })

    const context = createMockContext({
      task: {
        id: 'auth',
        title: '認証機能実装',
        status: 'plan',
        markers: ['feature:security', 'feature:tdd']
      },
      relatedDecisions: [
        { title: 'Clerk使用', content: '認証にはClerkを採用。ソーシャルログイン対応' }
      ],
      projectContext: {
        projectName: 'my-app',
        techStack: ['Next.js', 'TypeScript', 'Clerk']
      }
    })

    const result = await service.enhancePrompt('認証機能実装', context)

    expect(result.estimatedComplexity).toBe('high')
    expect(result.suggestions.some(s => s.includes('Clerk'))).toBe(true)
    expect(result.enhanced).toContain('セキュリティ')
  })

  test('Scenario: Simple UI component', async () => {
    client.setMockResponse('Header', {
      content: [{
        type: 'text',
        text: `## シンプルなUIコンポーネント

このタスクは比較的簡単です。

1. shadcn/uiのコンポーネントを使用
2. Tailwindでスタイリング

/work で実行`
      }]
    })

    const context = createMockContext({
      task: {
        id: 'header',
        title: 'Header作成',
        status: 'plan'
      }
    })

    const result = await service.enhancePrompt('Header', context)

    expect(result.estimatedComplexity).toBe('low')
  })

  test('Scenario: Task with warnings', async () => {
    const context = createMockContext({
      task: { id: 'task', title: 'Feature実装', status: 'plan' },
      warnings: [
        '未コミットの変更が5ファイルあります',
        '前回のテストが失敗しています'
      ]
    })

    const result = await service.enhancePrompt('Feature実装', context)

    // Check that warnings were sent to SDK
    const calls = client.getCallHistory()
    const userMessage = calls[0].messages.find(m => m.role === 'user')?.content ?? ''

    expect(userMessage).toContain('未コミット')
    expect(userMessage).toContain('テストが失敗')
  })
})

// ============================================================
// Tests: Model Selection (future feature)
// ============================================================

describe('model usage', () => {
  test('uses claude-sonnet-4-20250514 by default', async () => {
    const client = new MockAnthropicClient()
    const service = new PromptEnhancementService(client)
    const context = createMockContext()

    await service.enhancePrompt('Test', context)

    const calls = client.getCallHistory()
    expect(calls[0].model).toBe('claude-sonnet-4-20250514')
  })
})
