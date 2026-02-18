import { Cron } from "croner";
import { query } from "@anthropic-ai/claude-agent-sdk";
import { loadConfig } from "./config";
import { buildMcpServers } from "./mcp-registry";
import { SessionManager } from "./session-manager";
import { buildCronPrompt } from "./prompt-builder";
import { log } from "./logger";
import { writeFileSync } from "node:fs";

const config = loadConfig();

if (!config.openclaw.enabled) {
  console.error(
    "[openclaw] Daemon is disabled. Set openclaw.enabled: true in .claude-code-harness.config.yaml",
  );
  process.exit(1);
}

const sessions = new SessionManager(config.openclaw.project_cwd);

// Graceful shutdown
const abort = new AbortController();
let isRunning = false;

function shutdown() {
  if (abort.signal.aborted) return;
  log.info("daemon-shutdown");
  abort.abort();
  sessions.save();
  process.exit(0);
}
process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);

// Single cron run
async function executeCronRun() {
  if (abort.signal.aborted) return;
  if (isRunning) {
    log.warn("cron-skip", { reason: "previous run still active" });
    return;
  }

  isRunning = true;
  const runId = crypto.randomUUID();
  log.info("cron-tick", { runId, interval: config.openclaw.cron_interval });

  const mcpServers = buildMcpServers(config);
  const sessionId = sessions.getLastSessionId();
  const prompt = buildCronPrompt(config);

  try {
    for await (const message of query({
      prompt,
      options: {
        cwd: config.openclaw.project_cwd,
        systemPrompt: { type: "preset", preset: "claude_code" },
        settingSources: ["project"],
        plugins: [{ type: "local", path: config.openclaw.harness_path }],
        mcpServers,
        executable: "bun",
        maxTurns: config.openclaw.max_turns,
        maxBudgetUsd: config.openclaw.max_budget_usd,
        allowDangerouslySkipPermissions: true,
        permissionMode: "bypassPermissions",
        abortController: abort,
        ...(sessionId ? { resume: sessionId } : {}),
        env: {
          ...process.env,
          OPENCLAW_MODE: "daemon",
          OPENCLAW_RUN_ID: runId,
        },
      },
    })) {
      // Capture session ID from init message
      if (
        message.type === "system" &&
        "subtype" in message &&
        message.subtype === "init" &&
        "session_id" in message
      ) {
        sessions.setLastSessionId(message.session_id as string);
      }

      // Log result
      if (message.type === "result") {
        const result = message as Record<string, unknown>;
        log.info("run-complete", {
          runId,
          subtype: result.subtype as string,
          turns: result.num_turns as number,
          cost: result.total_cost_usd as number,
          duration_ms: result.duration_ms as number,
        });
      }
    }
  } catch (err) {
    log.error("run-failed", { runId, error: String(err) });
    sessions.clearLastSessionId();
  } finally {
    isRunning = false;
  }
}

// Start cron
const job = new Cron(config.openclaw.cron_interval, executeCronRun);

const enabledServices = Object.entries(config.openclaw.services)
  .filter(([, v]) => v.enabled)
  .map(([k]) => k);

log.info("daemon-started", {
  interval: config.openclaw.cron_interval,
  services: enabledServices,
  maxTurns: config.openclaw.max_turns,
  maxBudgetUsd: config.openclaw.max_budget_usd,
  pid: process.pid,
});

// Write PID file
writeFileSync(config.openclaw.pid_file, String(process.pid));

// Run immediately on start, then cron takes over
executeCronRun();
