import { describe, test, expect } from 'bun:test'
import { parsePlansMarkdown, extractTasks, parseTaskLine } from '../../src/server/services/plans-parser.ts'
import type { Task, KanbanResponse } from '../../src/shared/types.ts'

describe('parseTaskLine', () => {
  test('parses checkbox task line with title', () => {
    const result = parseTaskLine('- [ ] Implement login feature')
    expect(result).toEqual({
      title: 'Implement login feature',
      completed: false,
      priority: undefined
    })
  })

  test('parses completed checkbox task', () => {
    const result = parseTaskLine('- [x] Setup database')
    expect(result).toEqual({
      title: 'Setup database',
      completed: true,
      priority: undefined
    })
  })

  test('parses task with high priority marker', () => {
    const result = parseTaskLine('- [ ] 🔴 Critical bug fix')
    expect(result).toEqual({
      title: 'Critical bug fix',
      completed: false,
      priority: 'high'
    })
  })

  test('parses task with medium priority marker', () => {
    const result = parseTaskLine('- [ ] 🟡 Performance improvement')
    expect(result).toEqual({
      title: 'Performance improvement',
      completed: false,
      priority: 'medium'
    })
  })

  test('parses task with low priority marker', () => {
    const result = parseTaskLine('- [ ] 🟢 Documentation update')
    expect(result).toEqual({
      title: 'Documentation update',
      completed: false,
      priority: 'low'
    })
  })

  test('returns null for non-task lines', () => {
    expect(parseTaskLine('## Plan')).toBeNull()
    expect(parseTaskLine('Some random text')).toBeNull()
    expect(parseTaskLine('')).toBeNull()
  })

  test('handles nested task indentation', () => {
    const result = parseTaskLine('  - [ ] Subtask item')
    expect(result).toEqual({
      title: 'Subtask item',
      completed: false,
      priority: undefined
    })
  })
})

describe('extractTasks', () => {
  test('extracts tasks from section content', () => {
    const content = `
- [ ] First task
- [x] Second task
- [ ] Third task
    `
    const tasks = extractTasks(content, 'plan')
    expect(tasks).toHaveLength(3)
    expect(tasks[0]?.title).toBe('First task')
    expect(tasks[0]?.status).toBe('plan')
    expect(tasks[1]?.title).toBe('Second task')
  })

  test('ignores non-task lines in content', () => {
    const content = `
Some description text

- [ ] Actual task

More text
    `
    const tasks = extractTasks(content, 'work')
    expect(tasks).toHaveLength(1)
    expect(tasks[0]?.title).toBe('Actual task')
    expect(tasks[0]?.status).toBe('work')
  })

  test('generates unique IDs for each task', () => {
    const content = `
- [ ] Task A
- [ ] Task B
    `
    const tasks = extractTasks(content, 'plan')
    expect(tasks[0]?.id).toBeDefined()
    expect(tasks[1]?.id).toBeDefined()
    expect(tasks[0]?.id).not.toBe(tasks[1]?.id)
  })
})

describe('parsePlansMarkdown', () => {
  test('parses complete Plans.md with all sections', () => {
    const markdown = `
# Plans

## Plan

- [ ] Plan task 1
- [ ] Plan task 2

## Work

- [ ] Work task 1

## Review

- [ ] Review task 1

## Done

- [x] Done task 1
- [x] Done task 2
    `
    const result = parsePlansMarkdown(markdown)
    expect(result.error).toBeUndefined()
    expect(result.plan).toHaveLength(2)
    expect(result.work).toHaveLength(1)
    expect(result.review).toHaveLength(1)
    expect(result.done).toHaveLength(2)
  })

  test('handles missing sections gracefully', () => {
    const markdown = `
# Plans

## Plan

- [ ] Only plan tasks

## Done

- [x] Completed
    `
    const result = parsePlansMarkdown(markdown)
    expect(result.error).toBeUndefined()
    expect(result.plan).toHaveLength(1)
    expect(result.work).toHaveLength(0)
    expect(result.review).toHaveLength(0)
    expect(result.done).toHaveLength(1)
  })

  test('returns error for empty content', () => {
    const result = parsePlansMarkdown('')
    expect(result.error).toBeDefined()
    expect(result.plan).toHaveLength(0)
    expect(result.work).toHaveLength(0)
    expect(result.review).toHaveLength(0)
    expect(result.done).toHaveLength(0)
  })

  test('returns error for invalid format (no sections)', () => {
    const markdown = `
Just some text without proper sections
No ## Plan or ## Work headers
    `
    const result = parsePlansMarkdown(markdown)
    expect(result.error).toBeDefined()
  })

  test('handles Japanese section headers', () => {
    const markdown = `
# Plans

## Plan
## 計画

- [ ] 日本語タスク

## Work
## 作業中

- [ ] Working on this

## Review
## レビュー

## Done
## 完了

- [x] 完了したタスク
    `
    const result = parsePlansMarkdown(markdown)
    expect(result.error).toBeUndefined()
    expect(result.plan.length + result.work.length + result.done.length).toBeGreaterThan(0)
  })

  test('preserves task order within sections', () => {
    const markdown = `
## Plan

- [ ] First
- [ ] Second
- [ ] Third
    `
    const result = parsePlansMarkdown(markdown)
    expect(result.plan[0]?.title).toBe('First')
    expect(result.plan[1]?.title).toBe('Second')
    expect(result.plan[2]?.title).toBe('Third')
  })

  test('handles tasks with special characters', () => {
    const markdown = `
## Plan

- [ ] Fix bug in \`calculateScore()\` function
- [ ] Update README.md with new instructions
- [ ] Handle edge-case: empty input []
    `
    const result = parsePlansMarkdown(markdown)
    expect(result.plan).toHaveLength(3)
    expect(result.plan[0]?.title).toContain('calculateScore()')
    expect(result.plan[1]?.title).toContain('README.md')
  })
})
