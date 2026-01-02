import type { ClaudeMemResponse, Observation } from '../../shared/types.ts'

/**
 * claude-mem API base URL
 */
export const CLAUDE_MEM_API_URL = 'http://localhost:37777'

/**
 * Check if claude-mem is available
 */
export async function isClaudeMemAvailable(): Promise<boolean> {
  try {
    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), 3000)

    const response = await fetch(`${CLAUDE_MEM_API_URL}/api/health`, {
      signal: controller.signal
    })

    clearTimeout(timeoutId)
    return response.ok
  } catch {
    return false
  }
}

interface FetchOptions {
  limit?: number
  type?: string
}

/**
 * Fetch observations from claude-mem with fallback
 */
export async function fetchObservations(options?: FetchOptions): Promise<ClaudeMemResponse> {
  try {
    // Build URL with query params
    const url = new URL(`${CLAUDE_MEM_API_URL}/api/observations`)
    if (options?.limit) {
      url.searchParams.set('limit', String(options.limit))
    }
    if (options?.type) {
      url.searchParams.set('type', options.type)
    }

    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), 5000)

    const response = await fetch(url.toString(), {
      signal: controller.signal
    })

    clearTimeout(timeoutId)

    if (!response.ok) {
      return createFallbackResponse()
    }

    // claude-mem returns paginated response: { items: [...], hasMore, limit, offset }
    const data = await response.json() as { items?: Observation[], hasMore?: boolean }

    return {
      available: true,
      data: Array.isArray(data.items) ? data.items : []
    }
  } catch {
    return createFallbackResponse()
  }
}

/**
 * Create fallback response when claude-mem is unavailable
 */
function createFallbackResponse(): ClaudeMemResponse {
  return {
    available: false,
    data: [],
    message: 'claude-mem が起動していません。最新の作業履歴は表示されません。'
  }
}

/**
 * Fetch sessions from claude-mem
 */
export async function fetchSessions(limit = 10): Promise<{ available: boolean; data: unknown[]; message?: string }> {
  try {
    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), 5000)

    const response = await fetch(`${CLAUDE_MEM_API_URL}/api/sessions?limit=${limit}`, {
      signal: controller.signal
    })

    clearTimeout(timeoutId)

    if (!response.ok) {
      return { available: false, data: [], message: 'claude-mem にアクセスできません' }
    }

    const data = await response.json()

    return {
      available: true,
      data: Array.isArray(data) ? data : []
    }
  } catch {
    return {
      available: false,
      data: [],
      message: 'claude-mem が起動していません'
    }
  }
}

/**
 * Search observations in claude-mem
 */
export async function searchObservations(query: string): Promise<ClaudeMemResponse> {
  try {
    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), 10000)

    const response = await fetch(`${CLAUDE_MEM_API_URL}/api/search?q=${encodeURIComponent(query)}`, {
      signal: controller.signal
    })

    clearTimeout(timeoutId)

    if (!response.ok) {
      return createFallbackResponse()
    }

    const data = await response.json() as Observation[]

    return {
      available: true,
      data: Array.isArray(data) ? data : []
    }
  } catch {
    return createFallbackResponse()
  }
}
