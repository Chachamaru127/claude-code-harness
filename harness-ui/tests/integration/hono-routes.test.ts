import { describe, test, expect } from 'bun:test'
import { Hono } from 'hono'
import healthRoutes from '../../src/server/routes/health.ts'
import plansRoutes from '../../src/server/routes/plans.ts'
import skillsRoutes from '../../src/server/routes/skills.ts'
import memoryRoutes from '../../src/server/routes/memory.ts'
import rulesRoutes from '../../src/server/routes/rules.ts'
import hooksRoutes from '../../src/server/routes/hooks.ts'

// Helper to create test app
function createTestApp() {
  const app = new Hono()
  app.route('/api/health', healthRoutes)
  app.route('/api/plans', plansRoutes)
  app.route('/api/skills', skillsRoutes)
  app.route('/api/memory', memoryRoutes)
  app.route('/api/rules', rulesRoutes)
  app.route('/api/hooks', hooksRoutes)
  return app
}

describe('Hono Routes Unit Tests', () => {
  describe('Health Routes', () => {
    test('GET / returns health response', async () => {
      const app = createTestApp()
      const res = await app.request('/api/health')

      expect(res.status).toBe(200)
      const data = await res.json()

      expect(typeof data.score).toBe('number')
      expect(['good', 'warning', 'error']).toContain(data.status)
      expect(data.breakdown).toBeDefined()
    })
  })

  describe('Plans Routes', () => {
    test('GET / returns kanban response', async () => {
      const app = createTestApp()
      const res = await app.request('/api/plans')

      expect(res.status).toBe(200)
      const data = await res.json()

      // KanbanResponse has plan, work, review, done directly (not wrapped in columns)
      expect(Array.isArray(data.plan)).toBe(true)
      expect(Array.isArray(data.work)).toBe(true)
      expect(Array.isArray(data.review)).toBe(true)
      expect(Array.isArray(data.done)).toBe(true)
    })
  })

  describe('Skills Routes', () => {
    test('GET / returns skills response', async () => {
      const app = createTestApp()
      const res = await app.request('/api/skills')

      expect(res.status).toBe(200)
      const data = await res.json()

      expect(Array.isArray(data.skills)).toBe(true)
      expect(typeof data.totalTokens).toBe('number')
    })
  })

  describe('Memory Routes', () => {
    test('GET / returns memory response', async () => {
      const app = createTestApp()
      const res = await app.request('/api/memory')

      expect(res.status).toBe(200)
      const data = await res.json()

      expect(Array.isArray(data.files)).toBe(true)
      expect(typeof data.totalTokens).toBe('number')
      expect(Array.isArray(data.duplicates)).toBe(true)
    })
  })

  describe('Rules Routes', () => {
    test('GET / returns rules response', async () => {
      const app = createTestApp()
      const res = await app.request('/api/rules')

      expect(res.status).toBe(200)
      const data = await res.json()

      expect(Array.isArray(data.rules)).toBe(true)
      expect(typeof data.totalTokens).toBe('number')
      expect(Array.isArray(data.conflicts)).toBe(true)
    })
  })

  describe('Hooks Routes', () => {
    test('GET / returns hooks response', async () => {
      const app = createTestApp()
      const res = await app.request('/api/hooks')

      expect(res.status).toBe(200)
      const data = await res.json()

      expect(Array.isArray(data.hooks)).toBe(true)
      expect(typeof data.count).toBe('number')
    })
  })
})

describe('Response Structure Validation', () => {
  test('health breakdown has all required sections', async () => {
    const app = createTestApp()
    const res = await app.request('/api/health')
    const data = await res.json()

    // Skills breakdown
    expect(data.breakdown.skills).toHaveProperty('count')
    expect(data.breakdown.skills).toHaveProperty('totalTokens')

    // Memory breakdown
    expect(data.breakdown.memory).toHaveProperty('storageTokens')

    // Rules breakdown
    expect(data.breakdown.rules).toHaveProperty('count')

    // Hooks breakdown
    expect(data.breakdown.hooks).toHaveProperty('count')
  })

  test('skills have required fields', async () => {
    const app = createTestApp()
    const res = await app.request('/api/skills')
    const data = await res.json()

    // Even if empty, structure should be correct
    if (data.skills.length > 0) {
      const skill = data.skills[0]
      expect(skill).toHaveProperty('name')
      expect(skill).toHaveProperty('path')
      expect(skill).toHaveProperty('tokenCount')
    }
  })

  test('memory files have required fields', async () => {
    const app = createTestApp()
    const res = await app.request('/api/memory')
    const data = await res.json()

    if (data.files.length > 0) {
      const file = data.files[0]
      expect(file).toHaveProperty('name')
      expect(file).toHaveProperty('path')
      expect(file).toHaveProperty('tokenCount')
    }
  })

  test('rules have required fields', async () => {
    const app = createTestApp()
    const res = await app.request('/api/rules')
    const data = await res.json()

    if (data.rules.length > 0) {
      const rule = data.rules[0]
      expect(rule).toHaveProperty('name')
      expect(rule).toHaveProperty('path')
      expect(rule).toHaveProperty('tokenCount')
    }
  })
})
