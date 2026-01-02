import { Hono } from 'hono'
import { fetchObservations, fetchSessions, searchObservations, isClaudeMemAvailable } from '../services/claude-mem.ts'
import { parsePositiveInt } from '../services/file-reader.ts'

const app = new Hono()

// Allowed observation types
const ALLOWED_TYPES = ['decision', 'pattern', 'learning', 'workflow', 'error', 'insight']

// Check if claude-mem is available
app.get('/status', async (c) => {
  const available = await isClaudeMemAvailable()
  return c.json({ available })
})

// Get observations with fallback
app.get('/observations', async (c) => {
  const limitParam = c.req.query('limit')
  const type = c.req.query('type')

  // Validate limit parameter (default: 50, max: 500)
  const limit = parsePositiveInt(limitParam, 50, 500)

  // Validate type parameter against allowlist
  const validatedType = type && ALLOWED_TYPES.includes(type) ? type : undefined

  const result = await fetchObservations({
    limit,
    type: validatedType
  })

  return c.json(result)
})

// Get sessions
app.get('/sessions', async (c) => {
  const limitParam = c.req.query('limit')

  // Validate limit parameter (default: 10, max: 100)
  const limit = parsePositiveInt(limitParam, 10, 100)

  const result = await fetchSessions(limit)
  return c.json(result)
})

// Search observations
app.get('/search', async (c) => {
  const query = c.req.query('q')

  // Validate query parameter
  if (!query) {
    return c.json({
      available: false,
      data: [],
      message: '検索クエリが必要です（クエリパラメータ "q" を指定してください）'
    }, 400)
  }

  // Check query length (max 500 characters)
  if (query.length > 500) {
    return c.json({
      available: false,
      data: [],
      message: 'クエリが長すぎます（最大500文字）'
    }, 400)
  }

  const result = await searchObservations(query)
  return c.json(result)
})

export default app
