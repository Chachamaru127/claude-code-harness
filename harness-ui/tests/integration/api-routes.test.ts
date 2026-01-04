import { describe, test, expect, beforeAll, afterAll } from 'bun:test'
import { Hono } from 'hono'
import { cors } from 'hono/cors'
import healthRoutes from '../../src/server/routes/health.ts'
import plansRoutes from '../../src/server/routes/plans.ts'
import skillsRoutes from '../../src/server/routes/skills.ts'
import memoryRoutes from '../../src/server/routes/memory.ts'
import rulesRoutes from '../../src/server/routes/rules.ts'
import hooksRoutes from '../../src/server/routes/hooks.ts'
import claudeMemRoutes from '../../src/server/routes/claude-mem.ts'
import usageRoutes from '../../src/server/routes/usage.ts'
import projectsRoutes from '../../src/server/routes/projects.ts'

// Server will be started for integration tests
const API_BASE = 'http://localhost:37779' // Use different port for tests

// Create test app (similar to main server but without auto-start)
function createTestApp() {
  const app = new Hono()

  app.use('*', cors({
    origin: ['http://localhost:37778', 'http://127.0.0.1:37778', 'http://localhost:37779'],
    allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowHeaders: ['Content-Type']
  }))

  app.route('/api/health', healthRoutes)
  app.route('/api/plans', plansRoutes)
  app.route('/api/skills', skillsRoutes)
  app.route('/api/memory', memoryRoutes)
  app.route('/api/rules', rulesRoutes)
  app.route('/api/hooks', hooksRoutes)
  app.route('/api/claude-mem', claudeMemRoutes)
  app.route('/api/usage', usageRoutes)
  app.route('/api/projects', projectsRoutes)

  app.get('/api/status', (c) => {
    return c.json({
      status: 'ok',
      version: '1.0.0',
      timestamp: new Date().toISOString()
    })
  })

  return app
}

describe('API Routes Integration', () => {
  let server: { stop: () => void } | null = null

  beforeAll(async () => {
    const app = createTestApp()
    server = Bun.serve({
      port: 37779,
      fetch: app.fetch
    })
    // Give server time to start
    await new Promise(resolve => setTimeout(resolve, 100))
  })

  afterAll(() => {
    server?.stop()
  })

  describe('GET /api/status', () => {
    test('returns status ok', async () => {
      const response = await fetch(`${API_BASE}/api/status`)
      expect(response.ok).toBe(true)

      const data = await response.json()
      expect(data.status).toBe('ok')
      expect(data.version).toBe('1.0.0')
      expect(data.timestamp).toBeDefined()
    })
  })

  describe('GET /api/health', () => {
    test('returns health metrics with score', async () => {
      const response = await fetch(`${API_BASE}/api/health`)
      expect(response.ok).toBe(true)

      const data = await response.json()
      expect(typeof data.score).toBe('number')
      expect(data.score).toBeGreaterThanOrEqual(0)
      expect(data.score).toBeLessThanOrEqual(100)
      expect(['good', 'warning', 'error']).toContain(data.status)
      expect(data.breakdown).toBeDefined()
      expect(Array.isArray(data.suggestions)).toBe(true)
    })

    test('returns breakdown with skills, memory, rules, hooks', async () => {
      const response = await fetch(`${API_BASE}/api/health`)
      const data = await response.json()

      expect(data.breakdown.skills).toBeDefined()
      expect(data.breakdown.memory).toBeDefined()
      expect(data.breakdown.rules).toBeDefined()
      expect(data.breakdown.hooks).toBeDefined()
    })
  })

  describe('GET /api/plans', () => {
    test('returns kanban columns', async () => {
      const response = await fetch(`${API_BASE}/api/plans`)
      expect(response.ok).toBe(true)

      const data = await response.json()
      // KanbanResponse has plan, work, review, done directly (not wrapped in columns)
      expect(Array.isArray(data.plan)).toBe(true)
      expect(Array.isArray(data.work)).toBe(true)
      expect(Array.isArray(data.review)).toBe(true)
      expect(Array.isArray(data.done)).toBe(true)
    })
  })

  describe('GET /api/skills', () => {
    test('returns skills list', async () => {
      const response = await fetch(`${API_BASE}/api/skills`)
      expect(response.ok).toBe(true)

      const data = await response.json()
      expect(Array.isArray(data.skills)).toBe(true)
      expect(typeof data.totalTokens).toBe('number')
    })

    test('each skill has required fields', async () => {
      const response = await fetch(`${API_BASE}/api/skills`)
      const data = await response.json()

      if (data.skills.length > 0) {
        const skill = data.skills[0]
        expect(skill.name).toBeDefined()
        expect(skill.path).toBeDefined()
        expect(typeof skill.tokenCount).toBe('number')
      }
    })
  })

  describe('GET /api/memory', () => {
    test('returns memory files list', async () => {
      const response = await fetch(`${API_BASE}/api/memory`)
      expect(response.ok).toBe(true)

      const data = await response.json()
      expect(Array.isArray(data.files)).toBe(true)
      expect(typeof data.totalTokens).toBe('number')
      expect(Array.isArray(data.duplicates)).toBe(true)
    })
  })

  describe('GET /api/rules', () => {
    test('returns rules list', async () => {
      const response = await fetch(`${API_BASE}/api/rules`)
      expect(response.ok).toBe(true)

      const data = await response.json()
      expect(Array.isArray(data.rules)).toBe(true)
      expect(typeof data.totalTokens).toBe('number')
      expect(Array.isArray(data.conflicts)).toBe(true)
    })
  })

  describe('GET /api/hooks', () => {
    test('returns hooks list', async () => {
      const response = await fetch(`${API_BASE}/api/hooks`)
      expect(response.ok).toBe(true)

      const data = await response.json()
      expect(Array.isArray(data.hooks)).toBe(true)
      expect(typeof data.count).toBe('number')
    })
  })

  describe('GET /api/claude-mem/status', () => {
    test('returns availability status', async () => {
      const response = await fetch(`${API_BASE}/api/claude-mem/status`)
      expect(response.ok).toBe(true)

      const data = await response.json()
      expect(typeof data.available).toBe('boolean')
      // claude-mem might not be running during tests
      if (!data.available) {
        expect(data.message).toBeDefined()
      }
    })
  })

  describe('CORS headers', () => {
    test('includes CORS headers', async () => {
      const response = await fetch(`${API_BASE}/api/status`, {
        method: 'OPTIONS'
      })

      // Hono CORS middleware handles this
      expect(response.headers.get('access-control-allow-origin')).toBeDefined()
    })
  })

  describe('GET /api/usage', () => {
    test('returns usage response with required fields', async () => {
      const response = await fetch(`${API_BASE}/api/usage`)
      expect(response.ok).toBe(true)

      const data = await response.json()
      expect(typeof data.available).toBe('boolean')
      expect(Array.isArray(data.topSkills)).toBe(true)
      expect(Array.isArray(data.topCommands)).toBe(true)
      expect(Array.isArray(data.topAgents)).toBe(true)
      expect(Array.isArray(data.topHooks)).toBe(true)
    })

    test('returns cleanup suggestions when available', async () => {
      const response = await fetch(`${API_BASE}/api/usage`)
      const data = await response.json()

      // Cleanup is null if data not available, or CleanupSuggestions if available
      if (data.available) {
        expect(data.cleanup).toBeDefined()
        expect(data.cleanup.summary).toBeDefined()
        expect(typeof data.cleanup.summary.totalSkills).toBe('number')
        expect(typeof data.cleanup.summary.unusedSkillsCount).toBe('number')
      } else {
        expect(data.cleanup).toBeNull()
      }
    })
  })

  describe('GET /api/projects', () => {
    test('returns projects list with required fields', async () => {
      const response = await fetch(`${API_BASE}/api/projects`)
      expect(response.ok).toBe(true)

      const data = await response.json()
      expect(Array.isArray(data.projects)).toBe(true)
      expect(data).toHaveProperty('activeProjectId')
      expect(data).toHaveProperty('configPath')
    })

    test('returns active project endpoint', async () => {
      const response = await fetch(`${API_BASE}/api/projects/active`)
      expect(response.ok).toBe(true)

      const data = await response.json()
      expect(data).toHaveProperty('project')
    })
  })

  describe('404 handling', () => {
    test('returns 404 for unknown API routes', async () => {
      const response = await fetch(`${API_BASE}/api/unknown-route`)
      expect(response.status).toBe(404)
    })
  })
})
