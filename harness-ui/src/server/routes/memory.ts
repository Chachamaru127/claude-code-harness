import { Hono } from 'hono'
import { analyzeMemory, getProjectRoot } from '../services/analyzer.ts'
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

    const memory = await analyzeMemory(projectRoot)
    return c.json(memory)
  } catch (error) {
    console.error('Memory analysis failed:', error)
    return c.json(
      {
        files: [],
        totalTokens: 0,
        duplicates: []
      },
      500
    )
  }
})

export default app
