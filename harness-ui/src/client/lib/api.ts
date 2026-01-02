import type {
  HealthResponse,
  KanbanResponse,
  SkillsResponse,
  MemoryResponse,
  RulesResponse,
  HooksResponse,
  ClaudeMemResponse,
  UsageResponse,
  WorkflowMode
} from '../../shared/types.ts'

const API_BASE = '/api'

async function fetchAPI<T>(endpoint: string): Promise<T> {
  const response = await fetch(`${API_BASE}${endpoint}`)
  if (!response.ok) {
    throw new Error(`API error: ${response.status}`)
  }
  return response.json() as Promise<T>
}

export async function fetchHealth(): Promise<HealthResponse> {
  return fetchAPI<HealthResponse>('/health')
}

export async function fetchPlans(mode: WorkflowMode = 'solo'): Promise<KanbanResponse> {
  return fetchAPI<KanbanResponse>(`/plans?mode=${mode}`)
}

export async function fetchSkills(): Promise<SkillsResponse> {
  return fetchAPI<SkillsResponse>('/skills')
}

export async function fetchMemory(): Promise<MemoryResponse> {
  return fetchAPI<MemoryResponse>('/memory')
}

export async function fetchRules(): Promise<RulesResponse> {
  return fetchAPI<RulesResponse>('/rules')
}

export async function fetchHooks(): Promise<HooksResponse> {
  return fetchAPI<HooksResponse>('/hooks')
}

export async function fetchClaudeMemStatus(): Promise<{ available: boolean }> {
  return fetchAPI<{ available: boolean }>('/claude-mem/status')
}

export async function fetchObservations(options?: {
  limit?: number
  type?: string
}): Promise<ClaudeMemResponse> {
  const params = new URLSearchParams()
  if (options?.limit) params.set('limit', String(options.limit))
  if (options?.type) params.set('type', options.type)

  const query = params.toString()
  return fetchAPI<ClaudeMemResponse>(`/claude-mem/observations${query ? `?${query}` : ''}`)
}

export async function searchObservations(query: string): Promise<ClaudeMemResponse> {
  return fetchAPI<ClaudeMemResponse>(`/claude-mem/search?q=${encodeURIComponent(query)}`)
}

export async function fetchUsage(): Promise<UsageResponse> {
  return fetchAPI<UsageResponse>('/usage')
}
