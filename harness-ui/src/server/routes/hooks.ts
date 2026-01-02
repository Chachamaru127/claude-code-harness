import { Hono } from 'hono'
import { analyzeHooks, getProjectRoot } from '../services/analyzer.ts'
import { validateProjectPath } from '../services/file-reader.ts'

const app = new Hono()

app.get('/', async (c) => {
  try {
    const userProject = c.req.query('project')
    const defaultRoot = getProjectRoot()

    // Validate project path to prevent path traversal attacks
    const projectRoot = userProject
      ? validateProjectPath(userProject, defaultRoot) ?? defaultRoot
      : defaultRoot

    const hooks = await analyzeHooks(projectRoot)
    return c.json(hooks)
  } catch (error) {
    console.error('Hooks analysis failed:', error)
    return c.json(
      {
        hooks: [],
        count: 0
      },
      500
    )
  }
})

export default app
