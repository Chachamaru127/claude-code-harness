import type {
  HealthResponse,
  KanbanResponse,
  SkillsResponse,
  CommandsResponse,
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

/**
 * プロジェクトパスを含むクエリパラメータを構築
 */
function buildProjectQuery(projectPath?: string, additionalParams?: Record<string, string>): string {
  const params = new URLSearchParams()
  if (projectPath) params.set('project', projectPath)
  if (additionalParams) {
    for (const [key, value] of Object.entries(additionalParams)) {
      params.set(key, value)
    }
  }
  const query = params.toString()
  return query ? `?${query}` : ''
}

export async function fetchHealth(projectPath?: string): Promise<HealthResponse> {
  return fetchAPI<HealthResponse>(`/health${buildProjectQuery(projectPath)}`)
}

export async function fetchPlans(mode: WorkflowMode = 'solo', projectPath?: string): Promise<KanbanResponse> {
  return fetchAPI<KanbanResponse>(`/plans${buildProjectQuery(projectPath, { mode })}`)
}

export async function fetchSkills(projectPath?: string): Promise<SkillsResponse> {
  return fetchAPI<SkillsResponse>(`/skills${buildProjectQuery(projectPath)}`)
}

export async function fetchCommands(): Promise<CommandsResponse> {
  return fetchAPI<CommandsResponse>('/commands')
}

export async function fetchMemory(projectPath?: string): Promise<MemoryResponse> {
  return fetchAPI<MemoryResponse>(`/memory${buildProjectQuery(projectPath)}`)
}

export async function fetchRules(projectPath?: string): Promise<RulesResponse> {
  return fetchAPI<RulesResponse>(`/rules${buildProjectQuery(projectPath)}`)
}

export async function fetchHooks(projectPath?: string): Promise<HooksResponse> {
  return fetchAPI<HooksResponse>(`/hooks${buildProjectQuery(projectPath)}`)
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

export async function fetchUsage(projectPath?: string): Promise<UsageResponse> {
  return fetchAPI<UsageResponse>(`/usage${buildProjectQuery(projectPath)}`)
}

// ========== Projects API ==========

export interface Project {
  id: string
  name: string
  path: string
  addedAt: string
  lastAccessedAt?: string
}

export interface ProjectsResponse {
  projects: Project[]
  activeProjectId: string | null
  configPath: string
}

export async function fetchProjects(): Promise<ProjectsResponse> {
  return fetchAPI<ProjectsResponse>('/projects')
}

export async function fetchActiveProject(): Promise<{ project: Project | null }> {
  return fetchAPI<{ project: Project | null }>('/projects/active')
}

export async function addProject(name: string, path: string): Promise<{ project: Project }> {
  const response = await fetch(`${API_BASE}/projects`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ name, path }),
  })
  if (!response.ok) {
    const error = await response.json()
    throw new Error(error.error || `API error: ${response.status}`)
  }
  return response.json()
}

export async function removeProject(id: string): Promise<{ success: boolean }> {
  const response = await fetch(`${API_BASE}/projects/${id}`, {
    method: 'DELETE',
  })
  if (!response.ok) {
    const error = await response.json()
    throw new Error(error.error || `API error: ${response.status}`)
  }
  return response.json()
}

export async function activateProject(id: string): Promise<{ project: Project }> {
  const response = await fetch(`${API_BASE}/projects/${id}/activate`, {
    method: 'PUT',
  })
  if (!response.ok) {
    const error = await response.json()
    throw new Error(error.error || `API error: ${response.status}`)
  }
  return response.json()
}
