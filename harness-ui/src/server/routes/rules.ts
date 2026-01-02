import { Hono } from 'hono'
import { analyzeRules, getProjectRoot } from '../services/analyzer.ts'
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

    const rules = await analyzeRules(projectRoot)
    return c.json(rules)
  } catch (error) {
    console.error('Rules analysis failed:', error)
    return c.json(
      {
        rules: [],
        totalTokens: 0,
        conflicts: []
      },
      500
    )
  }
})

export default app
