import { Hono } from 'hono'
import { parsePlans, getProjectRoot } from '../services/analyzer.ts'
import { validateProjectPath } from '../services/file-reader.ts'
import type { WorkflowMode } from '../services/plans-parser.ts'

const app = new Hono()

app.get('/', async (c) => {
  try {
    const userProject = c.req.query('project')
    const defaultRoot = getProjectRoot()

    // Validate project path to prevent path traversal attacks
    const projectRoot = userProject
      ? validateProjectPath(userProject, defaultRoot) ?? defaultRoot
      : defaultRoot

    // Get workflow mode (default: solo for single-agent operation)
    const modeParam = c.req.query('mode')
    const mode: WorkflowMode = modeParam === '2agent' ? '2agent' : 'solo'

    const plans = await parsePlans(projectRoot, mode)
    return c.json({ ...plans, mode })
  } catch (error) {
    console.error('Plans parsing failed:', error)
    return c.json(
      {
        plan: [],
        work: [],
        review: [],
        done: [],
        mode: 'solo',
        error: 'Plans.md の読み取りに失敗しました'
      },
      500
    )
  }
})

export default app
