import { Hono } from 'hono'
import { analyzeCommands } from '../services/analyzer.ts'

const app = new Hono()

app.get('/', async (c) => {
  try {
    const commands = await analyzeCommands()
    return c.json(commands)
  } catch (error) {
    console.error('Commands analysis failed:', error)
    return c.json({ commands: [] }, 500)
  }
})

export default app
