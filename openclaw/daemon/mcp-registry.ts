import type { OpenClawConfig } from "./types";
import { log } from "./logger";

type McpServerConfig = {
  command: string;
  args: string[];
  env: Record<string, string>;
};

interface EnvRequirement {
  key: string;
  envVar: string;
}

const SERVICE_ENV_REQUIREMENTS: Record<string, EnvRequirement[]> = {
  gmail: [
    { key: "GOOGLE_CLIENT_ID", envVar: "GOOGLE_CLIENT_ID" },
    { key: "GOOGLE_CLIENT_SECRET", envVar: "GOOGLE_CLIENT_SECRET" },
    { key: "GOOGLE_REFRESH_TOKEN", envVar: "GOOGLE_REFRESH_TOKEN" },
  ],
  calendar: [
    { key: "GOOGLE_CLIENT_ID", envVar: "GOOGLE_CLIENT_ID" },
    { key: "GOOGLE_CLIENT_SECRET", envVar: "GOOGLE_CLIENT_SECRET" },
    { key: "GOOGLE_REFRESH_TOKEN", envVar: "GOOGLE_REFRESH_TOKEN" },
  ],
  line: [
    { key: "LINE_CHANNEL_ACCESS_TOKEN", envVar: "LINE_CHANNEL_ACCESS_TOKEN" },
    { key: "LINE_DESTINATION_USER_ID", envVar: "LINE_DESTINATION_USER_ID" },
  ],
  slack: [
    { key: "SLACK_BOT_TOKEN", envVar: "SLACK_BOT_TOKEN" },
    { key: "SLACK_TEAM_ID", envVar: "SLACK_TEAM_ID" },
  ],
  discord: [{ key: "DISCORD_TOKEN", envVar: "DISCORD_TOKEN" }],
};

export function validateServiceEnv(service: string): string[] {
  const reqs = SERVICE_ENV_REQUIREMENTS[service];
  if (!reqs) return [];

  return reqs
    .filter((r) => !process.env[r.envVar])
    .map((r) => r.envVar);
}

export function buildMcpServers(
  config: OpenClawConfig,
): Record<string, McpServerConfig> {
  const servers: Record<string, McpServerConfig> = {};
  const svc = config.openclaw.services;

  // Gmail + Calendar (combined MCP)
  if (svc.gmail?.enabled || svc.calendar?.enabled) {
    const missing = validateServiceEnv("gmail");
    if (missing.length > 0) {
      log.warn("mcp-env-missing", {
        server: "google-workspace",
        missing,
      });
    }
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
    const missing = validateServiceEnv("line");
    if (missing.length > 0) {
      log.warn("mcp-env-missing", { server: "line-bot", missing });
    }
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
    const missing = validateServiceEnv("slack");
    if (missing.length > 0) {
      log.warn("mcp-env-missing", { server: "slack", missing });
    }
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
    const missing = validateServiceEnv("discord");
    if (missing.length > 0) {
      log.warn("mcp-env-missing", { server: "discord", missing });
    }
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

/** Get MCP servers required for a specific service */
export function buildMcpServersForService(
  service: string,
  config: OpenClawConfig,
): Record<string, McpServerConfig> {
  const servers: Record<string, McpServerConfig> = {};

  if (service === "gmail" || service === "calendar") {
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

  if (service === "line") {
    servers["line-bot"] = {
      command: "npx",
      args: ["-y", "@line/line-bot-mcp-server"],
      env: {
        CHANNEL_ACCESS_TOKEN: process.env.LINE_CHANNEL_ACCESS_TOKEN ?? "",
        DESTINATION_USER_ID: process.env.LINE_DESTINATION_USER_ID ?? "",
      },
    };
  }

  if (service === "slack") {
    servers["slack"] = {
      command: "npx",
      args: ["-y", "@anthropic-ai/mcp-server-slack"],
      env: {
        SLACK_BOT_TOKEN: process.env.SLACK_BOT_TOKEN ?? "",
        SLACK_TEAM_ID: process.env.SLACK_TEAM_ID ?? "",
      },
    };
  }

  if (service === "discord") {
    servers["discord"] = {
      command: "npx",
      args: ["-y", "mcp-discord"],
      env: {
        DISCORD_TOKEN: process.env.DISCORD_TOKEN ?? "",
      },
    };
  }

  // For delivery, resolve the delivery channel's MCP server
  if (service === "__delivery__") {
    const channel = config.openclaw.delivery?.channel;
    if (channel) {
      const deliveryServers = buildMcpServersForService(channel, config);
      if (Object.keys(deliveryServers).length === 0) {
        log.warn("mcp-env-missing", {
          server: "delivery",
          channel,
          reason: `Unknown delivery channel "${channel}" — no MCP server available`,
        });
      }
      return deliveryServers;
    }
  }

  return servers;
}
