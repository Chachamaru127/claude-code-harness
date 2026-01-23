#!/usr/bin/env node
/**
 * Harness MCP Server
 *
 * Enables cross-client session communication for Claude Code Harness.
 * Supports Claude Code, Codex, and other MCP-compatible clients.
 *
 * Usage:
 *   npx harness-mcp-server
 *   node dist/index.js
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  type Tool,
} from "@modelcontextprotocol/sdk/types.js";

import { sessionTools, handleSessionTool } from "./tools/session.js";
import { workflowTools, handleWorkflowTool } from "./tools/workflow.js";
import { statusTools, handleStatusTool } from "./tools/status.js";

// Server instance
const server = new Server(
  {
    name: "harness-mcp-server",
    version: "1.0.0",
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// Combine all tools
const allTools: Tool[] = [...sessionTools, ...workflowTools, ...statusTools];

// List available tools
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return { tools: allTools };
});

// Handle tool calls
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    // Route to appropriate handler
    if (name.startsWith("harness_session_")) {
      return await handleSessionTool(name, args);
    }

    if (name.startsWith("harness_workflow_")) {
      return await handleWorkflowTool(name, args);
    }

    if (name.startsWith("harness_status")) {
      return await handleStatusTool(name, args);
    }

    return {
      content: [
        {
          type: "text",
          text: `Unknown tool: ${name}`,
        },
      ],
      isError: true,
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return {
      content: [
        {
          type: "text",
          text: `Error executing ${name}: ${message}`,
        },
      ],
      isError: true,
    };
  }
});

// Start server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Harness MCP Server started");
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
