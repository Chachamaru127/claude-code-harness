/**
 * Session Communication Tools
 *
 * Enables inter-session messaging across different AI clients.
 * Works with Claude Code, Codex, and other MCP-compatible clients.
 */

import { type Tool } from "@modelcontextprotocol/sdk/types.js";
import {
  SESSIONS_DIR,
  ACTIVE_SESSIONS_FILE,
  BROADCAST_FILE,
  STALE_THRESHOLD_SECONDS,
  MAX_BROADCAST_MESSAGES,
  ensureDir,
  safeReadJSON,
  safeWriteJSON,
  formatTimeAgo,
} from "../utils.js";

// Session state storage
interface Session {
  id: string;
  client: string;
  lastSeen: number;
  pid?: string;
}

interface BroadcastMessage {
  timestamp: string;
  sessionId: string;
  client: string;
  message: string;
}

// Tool definitions
export const sessionTools: Tool[] = [
  {
    name: "harness_session_list",
    description:
      "List all active Harness sessions across different AI clients (Claude Code, Codex, etc.)",
    inputSchema: {
      type: "object",
      properties: {},
      required: [],
    },
  },
  {
    name: "harness_session_broadcast",
    description:
      "Broadcast a message to all active sessions. Use this to notify other sessions about important changes (API modifications, schema updates, etc.)",
    inputSchema: {
      type: "object",
      properties: {
        message: {
          type: "string",
          description: "The message to broadcast to all sessions",
        },
      },
      required: ["message"],
    },
  },
  {
    name: "harness_session_inbox",
    description:
      "Check inbox for messages from other sessions. Returns unread messages since last check.",
    inputSchema: {
      type: "object",
      properties: {
        since: {
          type: "string",
          description: "ISO timestamp to get messages since (optional)",
        },
      },
      required: [],
    },
  },
  {
    name: "harness_session_register",
    description:
      "Register current session with the Harness MCP server. Call this when starting a new session.",
    inputSchema: {
      type: "object",
      properties: {
        client: {
          type: "string",
          description: "Client name (e.g., 'claude-code', 'codex', 'cursor')",
        },
        sessionId: {
          type: "string",
          description: "Unique session identifier",
        },
      },
      required: ["client", "sessionId"],
    },
  },
];

// Helper functions using shared utilities
function loadSessions(): Record<string, Session> {
  ensureDir(SESSIONS_DIR);
  return safeReadJSON<Record<string, Session>>(ACTIVE_SESSIONS_FILE, {});
}

function saveSessions(sessions: Record<string, Session>): void {
  ensureDir(SESSIONS_DIR);
  safeWriteJSON(ACTIVE_SESSIONS_FILE, sessions);
}

function loadBroadcasts(): BroadcastMessage[] {
  ensureDir(SESSIONS_DIR);
  return safeReadJSON<BroadcastMessage[]>(BROADCAST_FILE, []);
}

function saveBroadcasts(messages: BroadcastMessage[]): void {
  ensureDir(SESSIONS_DIR);
  // Keep only last N messages
  const trimmed = messages.slice(-MAX_BROADCAST_MESSAGES);
  safeWriteJSON(BROADCAST_FILE, trimmed);
}

// Tool handlers
export async function handleSessionTool(
  name: string,
  args: Record<string, unknown> | undefined
): Promise<{ content: Array<{ type: string; text: string }>; isError?: boolean }> {
  switch (name) {
    case "harness_session_list":
      return handleListSessions();

    case "harness_session_broadcast":
      return handleBroadcast(args as { message: string });

    case "harness_session_inbox":
      return handleInbox(args as { since?: string });

    case "harness_session_register":
      return handleRegister(args as { client: string; sessionId: string });

    default:
      return {
        content: [{ type: "text", text: `Unknown session tool: ${name}` }],
        isError: true,
      };
  }
}

function handleListSessions(): {
  content: Array<{ type: string; text: string }>;
} {
  const sessions = loadSessions();
  const now = Date.now() / 1000;

  const activeSessions = Object.entries(sessions)
    .filter(([_, session]) => now - session.lastSeen < STALE_THRESHOLD_SECONDS)
    .map(([_id, session]) => {
      const age = Math.floor(now - session.lastSeen);
      return `- ${session.id.slice(0, 12)} (${session.client}) - ${formatTimeAgo(age)}`;
    });

  const text =
    activeSessions.length > 0
      ? `📋 Active Sessions:\n${activeSessions.join("\n")}`
      : "📋 No active sessions found";

  return { content: [{ type: "text", text }] };
}

function handleBroadcast(args: { message: string }): {
  content: Array<{ type: string; text: string }>;
} {
  const { message } = args;

  if (!message) {
    return {
      content: [{ type: "text", text: "Error: message is required" }],
      isError: true,
    } as { content: Array<{ type: string; text: string }>; isError: boolean };
  }

  const broadcasts = loadBroadcasts();
  const newMessage: BroadcastMessage = {
    timestamp: new Date().toISOString(),
    sessionId: process.env.HARNESS_SESSION_ID || "unknown",
    client: process.env.HARNESS_CLIENT || "unknown",
    message,
  };

  broadcasts.push(newMessage);
  saveBroadcasts(broadcasts);

  return {
    content: [
      {
        type: "text",
        text: `📤 Broadcast sent: "${message}"`,
      },
    ],
  };
}

/** Default inbox window: 1 hour in milliseconds */
const DEFAULT_INBOX_WINDOW_MS = 3600000;

function handleInbox(args: { since?: string }): {
  content: Array<{ type: string; text: string }>;
} {
  const broadcasts = loadBroadcasts();
  const since = args.since
    ? new Date(args.since).getTime()
    : Date.now() - DEFAULT_INBOX_WINDOW_MS;

  const unread = broadcasts.filter(
    (msg) => new Date(msg.timestamp).getTime() > since
  );

  if (unread.length === 0) {
    return { content: [{ type: "text", text: "📨 No new messages" }] };
  }

  const formatted = unread
    .map((msg) => {
      const time = new Date(msg.timestamp).toLocaleTimeString();
      return `[${time}] ${msg.client}: ${msg.message}`;
    })
    .join("\n");

  return {
    content: [
      {
        type: "text",
        text: `📨 ${unread.length} message(s):\n${formatted}`,
      },
    ],
  };
}

function handleRegister(args: { client: string; sessionId: string }): {
  content: Array<{ type: string; text: string }>;
} {
  const { client, sessionId } = args;

  if (!client || !sessionId) {
    return {
      content: [
        { type: "text", text: "Error: client and sessionId are required" },
      ],
      isError: true,
    } as { content: Array<{ type: string; text: string }>; isError: boolean };
  }

  const sessions = loadSessions();
  sessions[sessionId] = {
    id: sessionId,
    client,
    lastSeen: Date.now() / 1000,
    pid: process.pid.toString(),
  };
  saveSessions(sessions);

  // Set environment for this process
  process.env.HARNESS_SESSION_ID = sessionId;
  process.env.HARNESS_CLIENT = client;

  return {
    content: [
      {
        type: "text",
        text: `✅ Session registered: ${sessionId} (${client})`,
      },
    ],
  };
}
