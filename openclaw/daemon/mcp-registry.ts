import type { OpenClawConfig } from "./types";

type McpServerConfig = {
  command: string;
  args: string[];
  env: Record<string, string>;
};

export function buildMcpServers(
  config: OpenClawConfig,
): Record<string, McpServerConfig> {
  const servers: Record<string, McpServerConfig> = {};
  const svc = config.openclaw.services;

  // Gmail + Calendar (combined MCP)
  if (svc.gmail?.enabled || svc.calendar?.enabled) {
    servers["google-workspace"] = {
      command: "npx",
      args: ["-y", "mcp-google-workspace"],
      env: {
        GOOGLE_CLIENT_ID: process.env.GOOGLE_CLIENT_ID ?? "",
        GOOGLE_CLIENT_SECRET: process.env.GOOGLE_CLIENT_SECRET ?? "",
        GOOGLE_REDIRECT_URI:
          process.env.GOOGLE_REDIRECT_URI ??
          "http://localhost:3000/oauth2callback",
        GOOGLE_REFRESH_TOKEN: process.env.GOOGLE_REFRESH_TOKEN ?? "",
      },
    };
  }

  // LINE
  if (svc.line?.enabled) {
    servers["line-bot"] = {
      command: "npx",
      args: ["-y", "@line/line-bot-mcp-server"],
      env: {
        CHANNEL_ACCESS_TOKEN: process.env.LINE_CHANNEL_ACCESS_TOKEN ?? "",
        DESTINATION_USER_ID: process.env.LINE_DESTINATION_USER_ID ?? "",
      },
    };
  }

  // Slack
  if (svc.slack?.enabled) {
    servers["slack"] = {
      command: "npx",
      args: ["-y", "@anthropic-ai/mcp-server-slack"],
      env: {
        SLACK_BOT_TOKEN: process.env.SLACK_BOT_TOKEN ?? "",
        SLACK_TEAM_ID: process.env.SLACK_TEAM_ID ?? "",
      },
    };
  }

  // Discord
  if (svc.discord?.enabled) {
    servers["discord"] = {
      command: "npx",
      args: ["-y", "mcp-discord"],
      env: {
        DISCORD_TOKEN: process.env.DISCORD_TOKEN ?? "",
      },
    };
  }

  return servers;
}
