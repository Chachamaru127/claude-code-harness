import type { Task, KanbanResponse } from '../../shared/types.ts'

/**
 * Workflow mode configuration
 * - solo: Single agent mode (cc:完了 = done)
 * - 2agent: PM + Implementation mode (cc:完了 = review, pm:確認済 = done)
 */
export type WorkflowMode = 'solo' | '2agent'

interface ParsedTask {
  title: string
  completed: boolean
  priority?: 'high' | 'medium' | 'low'
  marker?: string
}

/**
 * Parse a single task line from markdown
 */
export function parseTaskLine(line: string): ParsedTask | null {
  // Match checkbox task pattern: - [ ] or - [x]
  const taskMatch = line.match(/^\s*-\s*\[([ xX])\]\s*(.+)$/)
  if (!taskMatch) return null

  const completed = taskMatch[1]?.toLowerCase() === 'x'
  let title = taskMatch[2]?.trim() ?? ''

  // Check for priority markers
  let priority: 'high' | 'medium' | 'low' | undefined

  if (title.includes('🔴')) {
    priority = 'high'
    title = title.replace('🔴', '').trim()
  } else if (title.includes('🟡')) {
    priority = 'medium'
    title = title.replace('🟡', '').trim()
  } else if (title.includes('🟢')) {
    priority = 'low'
    title = title.replace('🟢', '').trim()
  }

  // Extract marker (cc:TODO, cc:WIP, cc:完了, etc.)
  const markerMatch = title.match(/`(cc:|pm:|cursor:)(\S+)`/)
  const marker = markerMatch ? `${markerMatch[1]}${markerMatch[2]}` : undefined

  // Clean up marker from title
  if (marker) {
    title = title.replace(/`(cc:|pm:|cursor:)\S+`/g, '').trim()
  }

  return { title, completed, priority, marker }
}

/**
 * Extract tasks from a section's content
 */
export function extractTasks(content: string, status: Task['status']): Task[] {
  const lines = content.split('\n')
  const tasks: Task[] = []

  for (const line of lines) {
    const parsed = parseTaskLine(line)
    if (parsed) {
      tasks.push({
        id: generateId(),
        title: parsed.title,
        status,
        priority: parsed.priority
      })
    }
  }

  return tasks
}

/**
 * Extract tasks from marker-based format
 *
 * Marker mapping by mode:
 * - solo mode: cc:TODO -> plan, cc:WIP -> work, cc:完了 -> done
 * - 2agent mode: cc:TODO -> plan, cc:WIP -> work, cc:完了 -> review, pm:確認済 -> done
 */
export function extractMarkerTasks(markdown: string, mode: WorkflowMode = 'solo'): KanbanResponse {
  const result: KanbanResponse = {
    plan: [],
    work: [],
    review: [],
    done: []
  }

  const lines = markdown.split('\n')

  for (const line of lines) {
    const parsed = parseTaskLine(line)
    if (parsed && parsed.marker) {
      let status: Task['status']

      // Map markers to status based on workflow mode
      // Support both new format (cc:, pm:) and old format (cursor:)
      if (parsed.marker.includes('TODO') || parsed.marker.includes('依頼中')) {
        status = 'plan'
      } else if (parsed.marker.includes('WIP') || parsed.marker.includes('作業中') || parsed.marker.includes('WORK') || parsed.marker.includes('IN_PROGRESS')) {
        status = 'work'
      } else if (parsed.marker.includes('完了') || parsed.marker.includes('DONE')) {
        // In solo mode, cc:完了 means done (no PM review needed)
        // In 2agent mode, cc:完了 means review (waiting for PM confirmation)
        // Note: cursor:完了 (old format) is treated the same as pm:確認済 (PM approved)
        if (parsed.marker.startsWith('cursor:')) {
          // Old cursor:完了 means PM approved = done
          status = 'done'
        } else {
          status = mode === 'solo' ? 'done' : 'review'
        }
      } else if (parsed.marker.includes('確認済') || parsed.marker.includes('承認')) {
        status = 'done'
      } else {
        // Default based on checkbox state
        status = parsed.completed ? 'done' : 'plan'
      }

      result[status].push({
        id: generateId(),
        title: parsed.title,
        status,
        priority: parsed.priority
      })
    }
  }

  return result
}

/**
 * Parse Plans.md markdown content into KanbanResponse
 * @param markdown - The markdown content to parse
 * @param mode - Workflow mode: 'solo' (default) or '2agent'
 */
export function parsePlansMarkdown(markdown: string, mode: WorkflowMode = 'solo'): KanbanResponse {
  const result: KanbanResponse = {
    plan: [],
    work: [],
    review: [],
    done: []
  }

  if (!markdown || markdown.trim() === '') {
    return {
      ...result,
      error: 'Plans.md が空です'
    }
  }

  // Define section patterns (English and Japanese, including legacy formats)
  const sectionPatterns: Record<Task['status'], RegExp[]> = {
    plan: [
      /^##\s*Plan/i,
      /^##\s*計画/,
      /^##\s*未着手/,
      /^##\s*🟡\s*未着手/,
      /^##\s*次に着手/,
      /^##\s*TODO/i
    ],
    work: [
      /^##\s*Work/i,
      /^##\s*作業中/,
      /^##\s*In\s*Progress/i,
      /^##\s*進行中/,
      /^##\s*🔴\s*進行中/
    ],
    review: [
      /^##\s*Review/i,
      /^##\s*レビュー/,
      /^##\s*確認待ち/
    ],
    done: [
      /^##\s*Done/i,
      /^##\s*完了/,
      /^##\s*Completed/i,
      /^##\s*直近完了/,
      /^##\s*🟢\s*完了/
    ]
  }

  // Split content by section headers
  const lines = markdown.split('\n')
  let currentSection: Task['status'] | null = null
  let sectionContent: string[] = []
  let foundAnySection = false

  const processSection = () => {
    if (currentSection && sectionContent.length > 0) {
      const tasks = extractTasks(sectionContent.join('\n'), currentSection)
      result[currentSection].push(...tasks)
    }
  }

  for (const line of lines) {
    // Check if this line is a section header
    let matchedSection: Task['status'] | null = null

    for (const [section, patterns] of Object.entries(sectionPatterns)) {
      for (const pattern of patterns) {
        if (pattern.test(line)) {
          matchedSection = section as Task['status']
          foundAnySection = true
          break
        }
      }
      if (matchedSection) break
    }

    if (matchedSection) {
      // Process previous section before starting new one
      processSection()
      currentSection = matchedSection
      sectionContent = []
    } else if (currentSection) {
      sectionContent.push(line)
    }
  }

  // Process the last section
  processSection()

  // Check if section-based parsing yielded any tasks
  const sectionTaskCount = result.plan.length + result.work.length + result.review.length + result.done.length

  // If section-based parsing yielded no tasks, try marker-based parsing
  if (sectionTaskCount === 0) {
    const markerResult = extractMarkerTasks(markdown, mode)
    const markerTaskCount = markerResult.plan.length +
      markerResult.work.length +
      markerResult.review.length +
      markerResult.done.length

    if (markerTaskCount > 0) {
      return markerResult
    }

    // Only show error if we found no tasks at all
    if (!foundAnySection) {
      return {
        ...result,
        error: 'Plans.md のフォーマットが不正です。## Plan または ## Work セクション、またはマーカー（cc:TODO等）が必要です。'
      }
    }
  }

  return result
}

/**
 * Generate a unique ID for a task
 */
let idCounter = 0
function generateId(): string {
  idCounter++
  return `task-${Date.now()}-${idCounter}`
}

/**
 * Reset ID counter (useful for testing)
 */
export function resetIdCounter(): void {
  idCounter = 0
}
