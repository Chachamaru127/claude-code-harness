import { Hono } from 'hono'
import { cors } from 'hono/cors'
import { logger } from 'hono/logger'

// Import routes
import healthRoutes from './routes/health.ts'
import plansRoutes from './routes/plans.ts'
import skillsRoutes from './routes/skills.ts'
import memoryRoutes from './routes/memory.ts'
import rulesRoutes from './routes/rules.ts'
import hooksRoutes from './routes/hooks.ts'
import claudeMemRoutes from './routes/claude-mem.ts'
import insightsRoutes from './routes/insights.ts'
import usageRoutes from './routes/usage.ts'

// Import HTML for Bun's HTML imports feature
import indexHtml from '../../public/index.html'

export const app = new Hono()

// Middleware for API routes
app.use('*', logger())
app.use('*', cors({
  origin: ['http://localhost:37778', 'http://127.0.0.1:37778'],
  allowMethods: ['GET', 'POST', 'OPTIONS'],
  allowHeaders: ['Content-Type']
}))

// API Routes - mounted at /api prefix
app.route('/api/health', healthRoutes)
app.route('/api/plans', plansRoutes)
app.route('/api/skills', skillsRoutes)
app.route('/api/memory', memoryRoutes)
app.route('/api/rules', rulesRoutes)
app.route('/api/hooks', hooksRoutes)
app.route('/api/claude-mem', claudeMemRoutes)
app.route('/api/insights', insightsRoutes)
app.route('/api/usage', usageRoutes)

// API status endpoint
app.get('/api/status', (c) => {
  return c.json({
    status: 'ok',
    version: '1.0.0',
    timestamp: new Date().toISOString()
  })
})

export const DEFAULT_PORT = 37778

/**
 * Start the HTTP server
 * @param port - Port to listen on (default: 37778)
 * @param silent - If true, suppress startup messages
 * @returns The Bun server instance
 */
export function startHttpServer(port: number = DEFAULT_PORT, silent: boolean = false): ReturnType<typeof Bun.serve> {
  if (!silent) {
    console.log(`
╔═══════════════════════════════════════════════╗
║         Harness UI Server v1.0.0              ║
╠═══════════════════════════════════════════════╣
║  Local:  http://localhost:${port}                ║
║  API:    http://localhost:${port}/api            ║
╚═══════════════════════════════════════════════╝
`)
  }

  const server = Bun.serve({
    port,
    routes: {
      // Frontend (Bun bundles HTML imports automatically)
      '/': indexHtml,

      // API Routes - delegate to Hono for middleware (logger, cors)
      '/api/*': {
        GET: (req: Request) => app.fetch(req),
        POST: (req: Request) => app.fetch(req),
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

  if (!silent) {
    console.log(`Server running at ${server.url}`)
  }

  return server
}

export const apiRouter = app
