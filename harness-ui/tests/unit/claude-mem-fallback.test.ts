import { describe, test, expect, mock, afterEach } from 'bun:test'
import { fetchObservations, isClaudeMemAvailable, CLAUDE_MEM_API_URL } from '../../src/server/services/claude-mem.ts'
import type { ClaudeMemResponse } from '../../src/shared/types.ts'

describe('CLAUDE_MEM_API_URL', () => {
  test('uses correct default port', () => {
    expect(CLAUDE_MEM_API_URL).toBe('http://localhost:37777')
  })
})

describe('isClaudeMemAvailable', () => {
  const originalFetch = globalThis.fetch

  afterEach(() => {
    globalThis.fetch = originalFetch
  })

  test('returns true when claude-mem responds with 200', async () => {
    globalThis.fetch = mock(() =>
      Promise.resolve(new Response(JSON.stringify({ status: 'ok' }), { status: 200 }))
    ) as typeof fetch

    const result = await isClaudeMemAvailable()
    expect(result).toBe(true)
  })

  test('returns false when claude-mem returns non-200', async () => {
    globalThis.fetch = mock(() =>
      Promise.resolve(new Response('Not Found', { status: 404 }))
    ) as typeof fetch

    const result = await isClaudeMemAvailable()
    expect(result).toBe(false)
  })

  test('returns false when fetch throws (connection refused)', async () => {
    globalThis.fetch = mock(() =>
      Promise.reject(new Error('ECONNREFUSED'))
    ) as typeof fetch

    const result = await isClaudeMemAvailable()
    expect(result).toBe(false)
  })

  test('returns false on timeout', async () => {
    globalThis.fetch = mock(() =>
      new Promise((_, reject) => setTimeout(() => reject(new Error('Timeout')), 100))
    ) as typeof fetch

    const result = await isClaudeMemAvailable()
    expect(result).toBe(false)
  })
})

describe('fetchObservations', () => {
  const originalFetch = globalThis.fetch

  afterEach(() => {
    globalThis.fetch = originalFetch
  })

  test('returns observations when claude-mem is running', async () => {
    const mockObservations = [
      { id: 1, content: 'Test observation', timestamp: '2024-01-01T00:00:00Z', type: 'discovery' },
      { id: 2, content: 'Another observation', timestamp: '2024-01-01T01:00:00Z', type: 'decision' }
    ]

    // claude-mem returns paginated response: { items: [...], hasMore, limit, offset }
    globalThis.fetch = mock(() =>
      Promise.resolve(new Response(JSON.stringify({ items: mockObservations, hasMore: false }), { status: 200 }))
    ) as typeof fetch

    const result = await fetchObservations()
    expect(result.available).toBe(true)
    expect(result.data).toHaveLength(2)
    expect(result.data[0]?.id).toBe(1)
    expect(result.message).toBeUndefined()
  })

  test('returns fallback when claude-mem is not running', async () => {
    globalThis.fetch = mock(() =>
      Promise.reject(new Error('ECONNREFUSED'))
    ) as typeof fetch

    const result = await fetchObservations()
    expect(result.available).toBe(false)
    expect(result.data).toHaveLength(0)
    expect(result.message).toBeDefined()
    expect(result.message).toContain('claude-mem')
  })

  test('returns fallback when claude-mem returns error status', async () => {
    globalThis.fetch = mock(() =>
      Promise.resolve(new Response('Internal Server Error', { status: 500 }))
    ) as typeof fetch

    const result = await fetchObservations()
    expect(result.available).toBe(false)
    expect(result.data).toHaveLength(0)
    expect(result.message).toBeDefined()
  })

  test('returns fallback when response is not valid JSON', async () => {
    globalThis.fetch = mock(() =>
      Promise.resolve(new Response('Not JSON', { status: 200 }))
    ) as typeof fetch

    const result = await fetchObservations()
    expect(result.available).toBe(false)
    expect(result.data).toHaveLength(0)
  })

  test('handles empty observations array', async () => {
    // claude-mem returns paginated response: { items: [...], hasMore, limit, offset }
    globalThis.fetch = mock(() =>
      Promise.resolve(new Response(JSON.stringify({ items: [], hasMore: false }), { status: 200 }))
    ) as typeof fetch

    const result = await fetchObservations()
    expect(result.available).toBe(true)
    expect(result.data).toHaveLength(0)
    expect(result.message).toBeUndefined()
  })

  test('accepts optional limit parameter', async () => {
    const mockObservations = Array.from({ length: 10 }, (_, i) => ({
      id: i + 1,
      content: `Observation ${i + 1}`,
      timestamp: new Date().toISOString(),
      type: 'discovery'
    }))

    let capturedUrl = ''
    // claude-mem returns paginated response: { items: [...], hasMore, limit, offset }
    globalThis.fetch = mock((url: string | URL | Request) => {
      capturedUrl = url.toString()
      return Promise.resolve(new Response(JSON.stringify({ items: mockObservations, hasMore: false }), { status: 200 }))
    }) as typeof fetch

    await fetchObservations({ limit: 5 })
    expect(capturedUrl).toContain('limit=5')
  })

  test('accepts optional type filter parameter', async () => {
    let capturedUrl = ''
    // claude-mem returns paginated response: { items: [...], hasMore, limit, offset }
    globalThis.fetch = mock((url: string | URL | Request) => {
      capturedUrl = url.toString()
      return Promise.resolve(new Response(JSON.stringify({ items: [], hasMore: false }), { status: 200 }))
    }) as typeof fetch

    await fetchObservations({ type: 'decision' })
    expect(capturedUrl).toContain('type=decision')
  })
})

describe('Fallback UI behavior', () => {
  test('fallback response has correct structure', async () => {
    const originalFetch = globalThis.fetch
    globalThis.fetch = mock(() => Promise.reject(new Error('ECONNREFUSED'))) as typeof fetch

    const result: ClaudeMemResponse = await fetchObservations()

    expect(result).toHaveProperty('available')
    expect(result).toHaveProperty('data')
    expect(result).toHaveProperty('message')
    expect(typeof result.available).toBe('boolean')
    expect(Array.isArray(result.data)).toBe(true)

    globalThis.fetch = originalFetch
  })

  test('fallback message is user-friendly', async () => {
    const originalFetch = globalThis.fetch
    globalThis.fetch = mock(() => Promise.reject(new Error('ECONNREFUSED'))) as typeof fetch

    const result = await fetchObservations()

    // Message should be understandable to users
    expect(result.message?.length).toBeGreaterThan(10)
    expect(result.message).not.toContain('ECONNREFUSED') // Technical error should be hidden

    globalThis.fetch = originalFetch
  })
})
