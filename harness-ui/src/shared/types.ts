// Health Score Types
export interface HealthMetrics {
  skills: {
    count: number
    /** Description tokens only (loaded initially) */
    totalTokens: number
    unusedCount: number
  }
  memory: {
    /** Storage tokens (NOT loaded initially) */
    storageTokens: number
    duplicateCount: number
  }
  rules: {
    count: number
    /** Active + Cursor rules tokens (loaded initially) */
    initialLoadTokens: number
    conflictCount: number
  }
  hooks: {
    count: number
  }
  /** Total tokens loaded at session start */
  totalInitialLoadTokens: number
}

export type HealthStatus = 'good' | 'warning' | 'error'

export interface HealthResponse {
  score: number
  status: HealthStatus
  /** Total tokens loaded at session start (Skills + Rules) */
  totalInitialLoadTokens: number
  breakdown: {
    skills: { count: number; totalTokens: number; status: HealthStatus }
    memory: { storageTokens: number; duplicateCount: number; status: HealthStatus }
    rules: { count: number; initialLoadTokens: number; conflictCount: number; status: HealthStatus }
    hooks: { count: number; status: HealthStatus }
  }
  suggestions: string[]
}

// Kanban Types
export interface Task {
  id: string
  title: string
  description?: string
  status: 'plan' | 'work' | 'review' | 'done'
  priority?: 'high' | 'medium' | 'low'
  createdAt?: string
}

export type WorkflowMode = 'solo' | '2agent'

export interface KanbanResponse {
  plan: Task[]
  work: Task[]
  review: Task[]
  done: Task[]
  mode?: WorkflowMode
  error?: string
}

// Skills Types
export interface Skill {
  name: string
  path: string
  description: string
  descriptionEn?: string
  tokenCount: number
  lastUsed?: string
  usageCount?: number
}

export interface SkillsResponse {
  skills: Skill[]
  totalTokens: number
  unusedSkills: string[]
  /** Whether usage tracking is available (requires claude-mem) */
  usageTrackingAvailable: boolean
  /** Message about usage tracking status */
  usageTrackingMessage?: string
}

// Memory Types
export interface MemoryFile {
  name: string
  path: string
  /** Storage size in tokens (NOT loaded initially) */
  tokenCount: number
  lastModified: string
}

export interface MemoryResponse {
  files: MemoryFile[]
  /** Total storage tokens (NOT loaded initially - memory is on-demand) */
  totalTokens: number
  /** Memory files are loaded on-demand, not at session start */
  initialLoadTokens: 0
  duplicates: string[]
}

// Rules Types
export interface Rule {
  name: string
  path: string
  content: string
  tokenCount: number
  category?: 'active' | 'cursor' | 'template'
}

export interface RulesResponse {
  rules: Rule[]
  totalTokens: number
  /** Tokens loaded into Claude's initial context (active + cursor only) */
  initialLoadTokens: number
  conflicts: string[]
}

// Hooks Types
export interface Hook {
  name: string
  type: 'PreToolUse' | 'PostToolUse' | 'Notification' | 'Stop' | 'SessionStart' | 'UserPromptSubmit' | 'PermissionRequest' | string
  matcher?: string
  command: string
}

export interface HooksResponse {
  hooks: Hook[]
  count: number
}

// claude-mem Types
export interface Observation {
  id: number
  content: string
  timestamp: string
  type: string
}

export interface ClaudeMemResponse {
  available: boolean
  data: Observation[]
  message?: string
}

// Usage Tracking Types
export interface UsageEntry {
  count: number
  lastUsed: string | null
}

export interface HookUsageEntry {
  triggered: number
  blocked: number
  lastTriggered: string | null
}

export interface UsageData {
  version: string
  updatedAt: string
  skills: Record<string, UsageEntry>
  commands: Record<string, UsageEntry>
  agents: Record<string, UsageEntry>
  hooks: Record<string, HookUsageEntry>
}

export interface CleanupSuggestions {
  unusedSkills: Array<{ name: string } & UsageEntry>
  unusedCommands: Array<{ name: string } & UsageEntry>
  unusedAgents: Array<{ name: string } & UsageEntry>
  inactiveHooks: Array<{ name: string } & HookUsageEntry>
  summary: {
    totalSkills: number
    totalCommands: number
    totalAgents: number
    totalHooks: number
    unusedSkillsCount: number
    unusedCommandsCount: number
    unusedAgentsCount: number
    inactiveHooksCount: number
  }
}

export interface UsageResponse {
  available: boolean
  data: UsageData | null
  cleanup: CleanupSuggestions | null
  topSkills: Array<[string, UsageEntry]>
  topCommands: Array<[string, UsageEntry]>
  topAgents: Array<[string, UsageEntry]>
  topHooks: Array<[string, HookUsageEntry]>
  message?: string
}

// AI Insights Types
export interface Insight {
  type: 'optimization' | 'warning' | 'suggestion'
  title: string
  description: string
  impact: 'high' | 'medium' | 'low'
  effort: 'high' | 'medium' | 'low'
  cliCommand: string
}

export interface InsightsResponse {
  insights: Insight[]
  generatedAt: string
}
