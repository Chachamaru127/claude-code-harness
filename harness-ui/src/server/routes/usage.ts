import { Hono } from 'hono'
import { getProjectRoot } from '../services/analyzer.ts'
import { validateProjectPath } from '../services/file-reader.ts'
import { getUsageData } from '../services/usage.ts'

const app = new Hono()

app.get('/', async (c) => {
  try {
    const userProject = c.req.query('project')
    const defaultRoot = getProjectRoot()

    // Validate project path to prevent path traversal attacks
    const projectRoot = userProject
      ? validateProjectPath(userProject, defaultRoot) ?? defaultRoot
      : defaultRoot

    const usage = await getUsageData(projectRoot)
    return c.json(usage)
  } catch (error) {
    console.error('Usage data fetch failed:', error)
    return c.json(
      {
        available: false,
        data: null,
        cleanup: null,
        topSkills: [],
        topCommands: [],
        topAgents: [],
        topHooks: [],
        message: '使用状況データの取得に失敗しました'
      },
      500
    )
  }
})

export default app
