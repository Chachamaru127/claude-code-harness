/**
 * Claude-mem Plugin for OpenCode
 *
 * This plugin integrates Claude-mem persistent memory system with OpenCode.
 * It provides cross-session memory capabilities similar to Claude Code integration.
 *
 * Features:
 * - Auto-injects previous session context on session start
 * - Records observations from tool executions
 * - Generates session summaries on session end
 *
 * Requirements:
 * - Claude-mem worker must be running on port 37777
 * - Claude-mem plugin must be installed (~/.claude/plugins/marketplaces/thedotmack/)
 *
 * @see https://github.com/thedotmack/claude-mem
 * @see /opencode-mem command for setup instructions
 */

import type { PluginContext } from "@opencode-ai/plugin";

const WORKER_URL = "http://127.0.0.1:37777";
const WORKER_HEALTH_TIMEOUT = 5000;

interface SessionState {
  sessionId: string;
  project: string;
  startTime: Date;
  observations: Observation[];
  injectedContext: string | null;
}

interface Observation {
  type: string;
  concept: string[];
  text: string;
  files?: string[];
  timestamp: Date;
}

interface ContextResponse {
  context: string;
  sources: number;
}

let currentSession: SessionState | null = null;

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
function getProjectName(cwd: string): string {
  const parts = cwd.split("/");
  return parts[parts.length - 1] || "unknown";
}

/**
 * Generate a unique session ID
 */
function generateSessionId(): string {
  return `opencode-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
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
async function recordObservation(observation: Observation): Promise<boolean> {
  try {
    const response = await fetch(`${WORKER_URL}/api/sessions/observations`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        session_id: currentSession?.sessionId,
        project: currentSession?.project,
        type: observation.type,
        concepts: observation.concept,
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
async function summarizeSession(): Promise<void> {
  if (!currentSession) return;

  try {
    const response = await fetch(`${WORKER_URL}/api/sessions/summarize`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        session_id: currentSession.sessionId,
        project: currentSession.project,
        observations: currentSession.observations,
        start_time: currentSession.startTime.toISOString(),
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
  const inputStr = JSON.stringify(input).toLowerCase();

  // Skip routine operations
  const skipPatterns = [
    /^(glob|grep|read|ls)$/i,
    /status.*check/i,
    /empty/i,
  ];

  for (const pattern of skipPatterns) {
    if (pattern.test(toolName)) {
      return null;
    }
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
    if (inputStr.includes("npm") || inputStr.includes("bun")) {
      return null; // Skip package operations
    }
  }

  return null;
}

/**
 * Extract files from tool input
 */
function extractFiles(toolName: string, input: unknown): string[] {
  const files: string[] = [];
  const inputObj = input as Record<string, unknown>;

  if (toolName === "Edit" || toolName === "Write" || toolName === "Read") {
    if (inputObj.file_path && typeof inputObj.file_path === "string") {
      files.push(inputObj.file_path);
    }
  }

  return files;
}

/**
 * Main plugin export
 */
export default function claudeMemPlugin(context: PluginContext) {
  const { app } = context;
  const cwd = process.cwd();

  return {
    /**
     * Called when a new session starts
     */
    async onSessionStart() {
      // Check worker health first
      const healthy = await isWorkerHealthy();
      if (!healthy) {
        console.log(
          "[claude-mem] Worker not running. Memory features disabled."
        );
        console.log("[claude-mem] Run `/opencode-mem` to set up Claude-mem.");
        return;
      }

      const project = getProjectName(cwd);
      const sessionId = generateSessionId();

      // Initialize session state
      currentSession = {
        sessionId,
        project,
        startTime: new Date(),
        observations: [],
        injectedContext: null,
      };

      // Inject context from previous sessions
      const context = await injectContext(project);
      if (context) {
        currentSession.injectedContext = context;
        console.log(`[claude-mem] Previous session context available.`);
      }

      console.log(`[claude-mem] Session started: ${sessionId}`);
    },

    /**
     * Called before a tool is executed (can modify args or block)
     */
    async onToolCall(toolName: string, input: unknown) {
      // We don't modify tool calls, just pass through
      return { toolName, input };
    },

    /**
     * Called after a tool execution completes
     */
    async onToolResult(toolName: string, input: unknown, output: unknown) {
      if (!currentSession) return;

      const observationType = determineObservationType(toolName, input);
      if (!observationType) return;

      const files = extractFiles(toolName, input);
      const outputStr =
        typeof output === "string" ? output : JSON.stringify(output);

      // Create observation
      const observation: Observation = {
        type: observationType,
        concept: ["what-changed"],
        text: `${toolName}: ${outputStr.substring(0, 500)}`,
        files,
        timestamp: new Date(),
      };

      // Store locally and send to worker
      currentSession.observations.push(observation);
      await recordObservation(observation);
    },

    /**
     * Called when the session ends
     */
    async onSessionEnd() {
      if (!currentSession) return;

      await summarizeSession();
      console.log(
        `[claude-mem] Session ended. ${currentSession.observations.length} observations recorded.`
      );

      currentSession = null;
    },

    /**
     * Get injected context for system prompt
     * This can be used to add previous session context to the agent's prompt
     */
    getInjectedContext(): string | null {
      return currentSession?.injectedContext ?? null;
    },
  };
}

// Also export named for flexibility
export { claudeMemPlugin };
