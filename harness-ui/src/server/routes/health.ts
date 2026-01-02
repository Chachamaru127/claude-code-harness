import { Hono } from 'hono'
import { analyzeHealth, getProjectRoot } from '../services/analyzer.ts'
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

    const health = await analyzeHealth(projectRoot)
    return c.json(health)
  } catch (error) {
    console.error('Health analysis failed:', error)
    return c.json(
      {
        score: 0,
        status: 'error',
        breakdown: {
          skills: { count: 0, totalTokens: 0, status: 'error' },
          memory: { totalTokens: 0, duplicateCount: 0, status: 'error' },
          rules: { count: 0, conflictCount: 0, status: 'error' },
          hooks: { count: 0, status: 'error' }
        },
        suggestions: ['健康スコアの計算に失敗しました。プロジェクト設定を確認してください。']
      },
      500
    )
  }
})

export default app
