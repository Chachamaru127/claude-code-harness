import { Hono } from 'hono'
import { analyzeSkills, getProjectRoot } from '../services/analyzer.ts'
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

    const skills = await analyzeSkills(projectRoot)
    return c.json(skills)
  } catch (error) {
    console.error('Skills analysis failed:', error)
    return c.json(
      {
        skills: [],
        totalTokens: 0,
        unusedSkills: [],
        usageTrackingAvailable: false,
        usageTrackingMessage: 'スキル分析に失敗しました'
      },
      500
    )
  }
})

export default app
