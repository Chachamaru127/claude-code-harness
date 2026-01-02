#!/usr/bin/env bun
/**
 * harness-ui MCP Server
 *
 * Provides MCP tools for accessing harness data while also running
 * the HTTP server for browser-based UI access.
 */

import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js'
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js'
import { z } from 'zod'

import { startHttpServer, DEFAULT_PORT } from '../server/http-server.ts'
import { analyzeHealth, analyzeSkills, getProjectRoot } from '../server/services/analyzer.ts'
import { getUsageData } from '../server/services/usage.ts'
import { validateBetaAccess, showBetaAccessDenied } from './beta-gate.ts'

const SERVER_NAME = 'harness-ui'
const SERVER_VERSION = '1.0.0'

async function main() {
  // Redirect console.log to stderr to avoid interfering with MCP stdio
  console.log = (...args) => {
    process.stderr.write(args.map(a => String(a)).join(' ') + '\n')
  }

  // === Beta Gate Check ===
  const betaResult = await validateBetaAccess()
  if (!betaResult.valid) {
    showBetaAccessDenied(betaResult)
    process.exit(0)
  }
  console.log(`[harness-ui] Beta access granted: ${betaResult.reason}`)

  // Start HTTP server for browser UI (in background, silent mode)
  const port = parseInt(process.env['PORT'] ?? String(DEFAULT_PORT), 10)

  let httpServerRunning = false
  try {
    startHttpServer(port, true)
    httpServerRunning = true
    console.log(`[harness-ui] HTTP server started on port ${port}`)
  } catch (error: unknown) {
    // Check if port is already in use (another harness-ui instance running)
    const isPortInUse = error instanceof Error && 'code' in error && error.code === 'EADDRINUSE'
    if (isPortInUse) {
      console.log(`[harness-ui] Port ${port} already in use, using existing server`)
      httpServerRunning = true
    } else {
      console.error('[harness-ui] Failed to start HTTP server:', error)
    }
  }

  // Create MCP server
  const mcpServer = new McpServer(
    {
      name: SERVER_NAME,
      version: SERVER_VERSION
    },
    {
      capabilities: {
        tools: {},
        resources: {}
      }
    }
  )

  // Get project root for all tool calls
  const projectRoot = getProjectRoot()

  // === Register Tools ===

  // harness_health - Get health score and breakdown
  mcpServer.registerTool(
    'harness_health',
    {
      title: 'Harness Health',
      description: 'プロジェクトのヘルススコアと詳細な内訳を取得します。Skills、Memory、Rules、Hooks の状態を分析し、改善提案を提供します。',
      inputSchema: z.object({
        project: z.string().optional().describe('対象プロジェクトのパス（省略時はデフォルト）')
      })
    },
    async (args) => {
      try {
        const targetProject = args.project ?? projectRoot
        const health = await analyzeHealth(targetProject)
        return {
          content: [{
            type: 'text' as const,
            text: JSON.stringify(health, null, 2)
          }]
        }
      } catch (error) {
        return {
          content: [{
            type: 'text' as const,
            text: `Error: ${error instanceof Error ? error.message : 'Unknown error'}`
          }],
          isError: true
        }
      }
    }
  )

  // harness_usage - Get usage statistics
  mcpServer.registerTool(
    'harness_usage',
    {
      title: 'Harness Usage',
      description: 'Skills、Commands、Agents の使用状況統計を取得します。最も使用されているアイテムと未使用のアイテムを表示します。',
      inputSchema: z.object({
        project: z.string().optional().describe('対象プロジェクトのパス（省略時はデフォルト）')
      })
    },
    async (args) => {
      try {
        const targetProject = args.project ?? projectRoot
        const usage = await getUsageData(targetProject)
        return {
          content: [{
            type: 'text' as const,
            text: JSON.stringify(usage, null, 2)
          }]
        }
      } catch (error) {
        return {
          content: [{
            type: 'text' as const,
            text: `Error: ${error instanceof Error ? error.message : 'Unknown error'}`
          }],
          isError: true
        }
      }
    }
  )

  // harness_skills - Get skills list
  mcpServer.registerTool(
    'harness_skills',
    {
      title: 'Harness Skills',
      description: '利用可能なスキルの一覧とトークン数を取得します。未使用スキルの情報も含まれます。',
      inputSchema: z.object({
        project: z.string().optional().describe('対象プロジェクトのパス（省略時はデフォルト）')
      })
    },
    async (args) => {
      try {
        const targetProject = args.project ?? projectRoot
        const skills = await analyzeSkills(targetProject)
        return {
          content: [{
            type: 'text' as const,
            text: JSON.stringify(skills, null, 2)
          }]
        }
      } catch (error) {
        return {
          content: [{
            type: 'text' as const,
            text: `Error: ${error instanceof Error ? error.message : 'Unknown error'}`
          }],
          isError: true
        }
      }
    }
  )

  // harness_ui_url - Get the UI URL
  mcpServer.registerTool(
    'harness_ui_url',
    {
      title: 'Harness UI URL',
      description: 'ブラウザでアクセスできる Harness UI の URL を取得します。'
    },
    async () => {
      const status = httpServerRunning ? 'running' : 'not available'
      return {
        content: [{
          type: 'text' as const,
          text: `Harness UI (${status}): http://localhost:${port}`
        }]
      }
    }
  )

  // Connect to stdio transport
  const transport = new StdioServerTransport()
  await mcpServer.connect(transport)

  console.log(`[harness-ui] MCP server started (stdio transport)`)

  // Handle graceful shutdown
  process.on('SIGINT', async () => {
    console.log('[harness-ui] Shutting down...')
    await mcpServer.close()
    process.exit(0)
  })

  process.on('SIGTERM', async () => {
    console.log('[harness-ui] Shutting down...')
    await mcpServer.close()
    process.exit(0)
  })
}

main().catch((error) => {
  console.error('[harness-ui] Fatal error:', error)
  process.exit(1)
})
