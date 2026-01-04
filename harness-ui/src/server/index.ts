import { Hono } from 'hono'
import { cors } from 'hono/cors'
import { logger } from 'hono/logger'

// Import routes
import healthRoutes from './routes/health.ts'
import plansRoutes from './routes/plans.ts'
import skillsRoutes from './routes/skills.ts'
import commandsRoutes from './routes/commands.ts'
import memoryRoutes from './routes/memory.ts'
import rulesRoutes from './routes/rules.ts'
import hooksRoutes from './routes/hooks.ts'
import claudeMemRoutes from './routes/claude-mem.ts'
import insightsRoutes from './routes/insights.ts'
import usageRoutes from './routes/usage.ts'
import projectsRoutes from './routes/projects.ts'
import { initializeSession } from './services/projects.ts'

// Import HTML for Bun's HTML imports feature
import indexHtml from '../../public/index.html'

const app = new Hono()

// Middleware for API routes
app.use('*', logger())
app.use('*', cors({
  origin: ['http://localhost:37778', 'http://127.0.0.1:37778'],
  allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowHeaders: ['Content-Type']
}))

// API Routes - mounted at /api prefix
app.route('/api/health', healthRoutes)
app.route('/api/plans', plansRoutes)
app.route('/api/skills', skillsRoutes)
app.route('/api/commands', commandsRoutes)
app.route('/api/memory', memoryRoutes)
app.route('/api/rules', rulesRoutes)
app.route('/api/hooks', hooksRoutes)
app.route('/api/claude-mem', claudeMemRoutes)
app.route('/api/insights', insightsRoutes)
app.route('/api/usage', usageRoutes)
app.route('/api/projects', projectsRoutes)

// API status endpoint
app.get('/api/status', (c) => {
  return c.json({
    status: 'ok',
    version: '1.0.0',
    timestamp: new Date().toISOString()
  })
})

// Start server
const port = parseInt(process.env['PORT'] ?? '37778', 10)

// Auto-register current project on startup (like claude-mem)
const currentProject = initializeSession()
if (currentProject) {
  console.log(`[harness-ui] Auto-registered project: ${currentProject.name} (${currentProject.path})`)
}

console.log(`
╔═══════════════════════════════════════════════╗
║         Harness UI Server v1.0.0              ║
╠═══════════════════════════════════════════════╣
║  Local:  http://localhost:${port}                ║
║  API:    http://localhost:${port}/api            ║
╚═══════════════════════════════════════════════╝
`)

// Use Bun.serve with routes for HTML (Bun handles bundling)
// API routes use Hono app.fetch
const server = Bun.serve({
  port,
  routes: {
    // Frontend (Bun bundles HTML imports automatically)
    '/': indexHtml,

    // API Routes - delegate to Hono for middleware (logger, cors)
    '/api/*': {
      GET: (req: Request) => app.fetch(req),
      POST: (req: Request) => app.fetch(req),
      PUT: (req: Request) => app.fetch(req),
      DELETE: (req: Request) => app.fetch(req),
      OPTIONS: (req: Request) => app.fetch(req),
    },

    // SPA catch-all - serve the same HTML for client-side routing
    '/*': indexHtml,
  },
  development: {
    hmr: true,
    console: true,
  }
})

console.log(`Server running at ${server.url}`)

// Export for testing (don't export fetch directly to avoid Bun auto-serve)
export { app, port }
export const apiRouter = app
