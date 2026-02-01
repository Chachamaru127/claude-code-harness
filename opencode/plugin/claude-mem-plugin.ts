/**
 * Claude-mem Plugin for OpenCode
 *
 * This plugin integrates Claude-mem persistent memory system with OpenCode.
 * It provides cross-session memory capabilities similar to Claude Code integration.
 *
 * Features:
 * - Auto-injects previous session context on session start
 * - Records observations from tool executions (OpenCode native tools only)
 * - Generates session summaries on session end
 *
 * IMPORTANT LIMITATION:
 * - MCP tool calls do NOT trigger plugin hooks in OpenCode
 * - Only native OpenCode tools (Edit, Write, Bash, etc.) are captured
 * - For full integration, also configure claude-mem MCP server in opencode.json
 *
 * Requirements:
 * - Claude-mem worker must be running on port 37777
 * - Run: npx -y claude-mem-mcp worker start
 *
 * @see https://github.com/thedotmack/claude-mem
 * @see /opencode-mem command for setup instructions
 */

import type { Plugin } from "@opencode-ai/plugin";

const WORKER_URL = "http://127.0.0.1:37777";
const WORKER_HEALTH_TIMEOUT = 5000;

interface SessionState {
  sessionId: string;
  project: string;
  startTime: Date;
  observations: Observation[];
  injectedContext: string | null;
  healthy: boolean;
}

interface Observation {
  type: string;
  concepts: string[];
  text: string;
  files?: string[];
  timestamp: Date;
}

interface ContextResponse {
  context: string;
  sources: number;
}

// Session-keyed state management (supports concurrent sessions)
const sessions = new Map<string, SessionState>();

/**
 * Check if Claude-mem worker is running
 */
async function isWorkerHealthy(): Promise<boolean> {
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(
      () => controller.abort(),
      WORKER_HEALTH_TIMEOUT
    );

    const response = await fetch(`${WORKER_URL}/health`, {
      signal: controller.signal,
    });

    clearTimeout(timeoutId);
    return response.ok;
  } catch {
    return false;
  }
}

/**
 * Get project name from working directory
 */
function getProjectName(directory: string): string {
  const parts = directory.split("/");
  return parts[parts.length - 1] || "unknown";
}

/**
 * Generate a unique session ID for claude-mem
 */
function generateMemSessionId(): string {
  return `opencode-${Date.now()}-${Math.random().toString(36).substring(2, 11)}`;
}

/**
 * Inject context from previous sessions
 */
async function injectContext(project: string): Promise<string | null> {
  try {
    const response = await fetch(
      `${WORKER_URL}/api/context/inject?projects=${encodeURIComponent(project)}`,
      {
        method: "GET",
        headers: { "Content-Type": "application/json" },
      }
    );

    if (!response.ok) {
      console.error(
        `[claude-mem] Context injection failed: ${response.status}`
      );
      return null;
    }

    const data = (await response.json()) as ContextResponse;
    if (data.context && data.sources > 0) {
      console.log(
        `[claude-mem] Injected context from ${data.sources} previous sessions`
      );
      return data.context;
    }

    return null;
  } catch (error) {
    console.error("[claude-mem] Context injection error:", error);
    return null;
  }
}

/**
 * Record an observation to Claude-mem
 */
async function recordObservation(
  session: SessionState,
  observation: Observation
): Promise<boolean> {
  try {
    const response = await fetch(`${WORKER_URL}/api/sessions/observations`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        session_id: session.sessionId,
        project: session.project,
        type: observation.type,
        concepts: observation.concepts,
        text: observation.text,
        files: observation.files || [],
        timestamp: observation.timestamp.toISOString(),
      }),
    });

    return response.ok;
  } catch (error) {
    console.error("[claude-mem] Observation recording error:", error);
    return false;
  }
}

/**
 * Generate and save session summary
 */
async function summarizeSession(session: SessionState): Promise<void> {
  try {
    const response = await fetch(`${WORKER_URL}/api/sessions/summarize`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        session_id: session.sessionId,
        project: session.project,
        observations: session.observations,
        start_time: session.startTime.toISOString(),
        end_time: new Date().toISOString(),
      }),
    });

    if (response.ok) {
      console.log("[claude-mem] Session summary saved");
    }
  } catch (error) {
    console.error("[claude-mem] Session summarization error:", error);
  }
}

/**
 * Determine observation type from tool execution
 */
function determineObservationType(
  toolName: string,
  input: unknown
): string | null {
  const inputStr = JSON.stringify(input || {}).toLowerCase();

  // Skip routine/read-only operations
  const skipTools = ["glob", "grep", "read", "ls", "webfetch", "websearch"];
  if (skipTools.includes(toolName.toLowerCase())) {
    return null;
  }

  // Determine type based on tool and input
  if (toolName === "Edit" || toolName === "Write") {
    if (inputStr.includes("test") || inputStr.includes("spec")) {
      return "feature";
    }
    if (inputStr.includes("fix") || inputStr.includes("bug")) {
      return "bugfix";
    }
    if (inputStr.includes("refactor")) {
      return "refactor";
    }
    return "change";
  }

  if (toolName === "Bash") {
    if (inputStr.includes("git commit")) {
      return "change";
    }
    // Skip package/install operations
    if (
      inputStr.includes("npm install") ||
      inputStr.includes("bun install") ||
      inputStr.includes("yarn add")
    ) {
      return null;
    }
    // Skip status checks
    if (inputStr.includes("git status") || inputStr.includes("git diff")) {
      return null;
    }
  }

  if (toolName === "NotebookEdit") {
    return "change";
  }

  return null;
}

/**
 * Extract files from tool input
 */
function extractFiles(toolName: string, input: unknown): string[] {
  const files: string[] = [];
  if (!input || typeof input !== "object") return files;

  const inputObj = input as Record<string, unknown>;

  if (toolName === "Edit" || toolName === "Write" || toolName === "Read") {
    if (inputObj.file_path && typeof inputObj.file_path === "string") {
      files.push(inputObj.file_path);
    }
  }

  if (toolName === "NotebookEdit") {
    if (inputObj.notebook_path && typeof inputObj.notebook_path === "string") {
      files.push(inputObj.notebook_path);
    }
  }

  return files;
}

/**
 * Main plugin export - OpenCode Plugin API
 *
 * @see https://opencode.ai/docs/plugins/
 */
export const claudeMemPlugin: Plugin = async (context) => {
  const { directory } = context;
  const projectName = getProjectName(directory);

  return {
    /**
     * Called when a new session is created
     */
    "session.created": async ({
      sessionId,
    }: {
      sessionId: string;
    }): Promise<void> => {
      // Check worker health first
      const healthy = await isWorkerHealthy();
      if (!healthy) {
        console.log(
          "[claude-mem] Worker not running. Memory features disabled."
        );
        console.log("[claude-mem] Run: npx -y claude-mem-mcp worker start");

        // Still create session state but mark as unhealthy
        sessions.set(sessionId, {
          sessionId: generateMemSessionId(),
          project: projectName,
          startTime: new Date(),
          observations: [],
          injectedContext: null,
          healthy: false,
        });
        return;
      }

      const memSessionId = generateMemSessionId();

      // Inject context from previous sessions
      const injectedContext = await injectContext(projectName);
      if (injectedContext) {
        console.log(`[claude-mem] Previous session context available.`);
      }

      // Initialize session state
      sessions.set(sessionId, {
        sessionId: memSessionId,
        project: projectName,
        startTime: new Date(),
        observations: [],
        injectedContext,
        healthy: true,
      });

      console.log(`[claude-mem] Session started: ${memSessionId}`);
    },

    /**
     * Called after a tool execution completes
     *
     * NOTE: MCP tool calls do NOT trigger this hook.
     * Only native OpenCode tools are captured.
     */
    "tool.execute.after": async ({
      toolName,
      input,
      output,
      sessionId,
    }: {
      toolName: string;
      input: unknown;
      output: unknown;
      sessionId: string;
    }): Promise<void> => {
      const session = sessions.get(sessionId);
      if (!session || !session.healthy) return;

      const observationType = determineObservationType(toolName, input);
      if (!observationType) return;

      const files = extractFiles(toolName, input);
      const outputStr =
        typeof output === "string"
          ? output
          : JSON.stringify(output || "").substring(0, 500);

      // Create observation
      const observation: Observation = {
        type: observationType,
        concepts: ["what-changed"],
        text: `${toolName}: ${outputStr.substring(0, 500)}`,
        files,
        timestamp: new Date(),
      };

      // Store locally and send to worker
      session.observations.push(observation);
      await recordObservation(session, observation);
    },

    /**
     * Called when a session is deleted/ended
     */
    "session.deleted": async ({
      sessionId,
    }: {
      sessionId: string;
    }): Promise<void> => {
      const session = sessions.get(sessionId);
      if (!session) return;

      if (session.healthy) {
        await summarizeSession(session);
        console.log(
          `[claude-mem] Session ended. ${session.observations.length} observations recorded.`
        );
      }

      sessions.delete(sessionId);
    },

    /**
     * Transform system prompt to inject previous session context
     *
     * This experimental hook allows injecting context into the system prompt.
     */
    "experimental.chat.system.transform": async ({
      system,
      sessionId,
    }: {
      system: string;
      sessionId: string;
    }): Promise<string> => {
      const session = sessions.get(sessionId);
      if (!session?.injectedContext) {
        return system;
      }

      // Inject previous session context at the end of system prompt
      return `${system}

<previous-session-context>
${session.injectedContext}
</previous-session-context>`;
    },
  };
};

// Default export for compatibility
export default claudeMemPlugin;
