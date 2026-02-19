import { Cron } from "croner";
import { query } from "@anthropic-ai/claude-agent-sdk";
import { loadConfig } from "./config";
import { buildMcpServersForService } from "./mcp-registry";
import { buildServicePrompt } from "./prompt-builder";
import { buildDeliveryPrompt } from "./delivery";
import { checkHeartbeat } from "./heartbeat";
import { RunHistoryManager } from "./run-history";
import { cronRunResultJsonSchema, CronRunResultSchema } from "./schemas";
import { log } from "./logger";
import { unlinkSync, writeFileSync } from "node:fs";
import type { CronRunResult, ContextSnapshot, RunHistoryEntry } from "./types";

const MODEL_MAP: Record<string, string> = {
  opus: "claude-opus-4-6",
  sonnet: "claude-sonnet-4-5-20250929",
  haiku: "claude-haiku-4-5-20251001",
};

const config = loadConfig();

if (!config.openclaw.enabled) {
  console.error(
    "[openclaw] Daemon is disabled. Set openclaw.enabled: true in .claude-code-harness.config.yaml",
  );
  process.exit(1);
}

const history = new RunHistoryManager(config.openclaw.project_cwd);

// Graceful shutdown
const abort = new AbortController();
let isRunning = false;

function shutdown() {
  if (abort.signal.aborted) return;
  log.info("daemon-shutdown");
  abort.abort();
  try {
    unlinkSync(config.openclaw.pid_file);
  } catch {
    /* PID file may already be gone */
  }
  // Allow in-flight async operations to observe abort and clean up
  setTimeout(() => process.exit(0), 3000);
}
process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);

function getEnabledServices(): string[] {
  return Object.entries(config.openclaw.services)
    .filter(([, v]) => v.enabled)
    .sort((a, b) => {
      const priorityOrder = { high: 0, medium: 1, low: 2 };
      const pa = priorityOrder[a[1].priority ?? "medium"];
      const pb = priorityOrder[b[1].priority ?? "medium"];
      return pa - pb;
    })
    .map(([k]) => k);
}

function parseCronIntervalMinutes(cronExpr: string): number {
  // Use croner to compute actual interval from any valid cron expression
  try {
    const cron = new Cron(cronExpr);
    const runs = cron.nextRuns(2);
    if (runs.length === 2) {
      return Math.round((runs[1].getTime() - runs[0].getTime()) / 60000);
    }
  } catch {
    /* invalid cron expression — fall through to default */
  }
  // Fallback: assume 30 minutes
  return 30;
}

function resolveModel(service: string): string | undefined {
  const svcConfig = config.openclaw.services[service];
  const modelKey = svcConfig?.model;
  if (!modelKey) return undefined;
  return MODEL_MAP[modelKey] ?? undefined;
}

interface ServiceRunResult {
  service: string;
  result: CronRunResult | null;
  cost: number;
  turns: number;
  durationMs: number;
  status: "success" | "error" | "skipped";
  error?: string;
}

async function executeServiceQuery(
  service: string,
  heartbeatTasks: string[],
  runId: string,
): Promise<ServiceRunResult> {
  const svcConfig = config.openclaw.services[service];
  const maxTurns = svcConfig?.max_turns ?? config.openclaw.max_turns;
  const maxBudget =
    svcConfig?.max_budget_usd ?? config.openclaw.max_budget_usd;
  const model = resolveModel(service);

  // Get previous context for memory injection
  const previousContext = history.getRecentContext(service, 3);

  const prompt = buildServicePrompt(
    service,
    config,
    heartbeatTasks,
    previousContext,
  );
  const mcpServers = buildMcpServersForService(service, config);

  log.info("service-start", { runId, service, model: model ?? "default" });

  const startTime = Date.now();
  let resultCost = 0;
  let resultTurns = 0;
  let parsedResult: CronRunResult | null = null;

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
        maxTurns,
        maxBudgetUsd: maxBudget,
        allowDangerouslySkipPermissions: true,
        permissionMode: "bypassPermissions",
        abortController: abort,
        ...(model ? { model } : {}),
        outputFormat: {
          type: "json_schema",
          schema: cronRunResultJsonSchema,
        },
        env: {
          ...process.env,
          OPENCLAW_MODE: "daemon",
          OPENCLAW_RUN_ID: runId,
          OPENCLAW_SERVICE: service,
        },
      },
    })) {
      if (message.type === "result") {
        const result = message as Record<string, unknown>;
        resultCost = (result.total_cost_usd as number) ?? 0;
        resultTurns = (result.num_turns as number) ?? 0;

        // Try to parse and validate the structured JSON output
        const resultText =
          typeof result.result === "string" ? result.result : "";
        try {
          const rawJson = JSON.parse(resultText);
          const validated = CronRunResultSchema.safeParse(rawJson);
          if (validated.success) {
            parsedResult = validated.data as CronRunResult;
          } else {
            log.warn("service-validation-error", {
              runId,
              service,
              errors: validated.error.issues.map((i) => i.message),
              preview: resultText.slice(0, 200),
            });
          }
        } catch {
          log.warn("service-parse-error", {
            runId,
            service,
            preview: resultText.slice(0, 200),
          });
        }
      }
    }

    const durationMs = Date.now() - startTime;

    log.info("service-complete", {
      runId,
      service,
      turns: resultTurns,
      cost: resultCost,
      duration_ms: durationMs,
    });

    // Save to run history (Memory)
    const contextSnapshot: ContextSnapshot | undefined = parsedResult
      ? {
          service,
          timestamp: new Date().toISOString(),
          summary: parsedResult.context_snapshot?.summary ?? parsedResult.summary,
          key_facts: parsedResult.context_snapshot?.key_facts ?? [],
          actions_taken: parsedResult.context_snapshot?.actions_taken ?? [],
        }
      : undefined;

    const entry: RunHistoryEntry = {
      runId,
      timestamp: new Date().toISOString(),
      service,
      costUsd: resultCost,
      turns: resultTurns,
      durationMs,
      status: parsedResult ? "success" : "error",
      context: contextSnapshot,
    };
    history.append(entry);

    return {
      service,
      result: parsedResult,
      cost: resultCost,
      turns: resultTurns,
      durationMs,
      status: parsedResult ? "success" : "error",
      error: parsedResult ? undefined : "Failed to parse structured output",
    };
  } catch (err) {
    const durationMs = Date.now() - startTime;
    log.error("service-error", {
      runId,
      service,
      error: String(err),
      duration_ms: durationMs,
    });

    history.append({
      runId,
      timestamp: new Date().toISOString(),
      service,
      costUsd: resultCost,
      turns: resultTurns,
      durationMs,
      status: "error",
    });

    return {
      service,
      result: null,
      cost: resultCost,
      turns: resultTurns,
      durationMs,
      status: "error",
      error: String(err),
    };
  }
}

function mergeResults(serviceResults: ServiceRunResult[]): CronRunResult {
  const allActions = serviceResults.flatMap(
    (r) => r.result?.actions_taken ?? [],
  );
  const allPending = serviceResults.flatMap(
    (r) => r.result?.pending_human_review ?? [],
  );
  const allServices = serviceResults.map((r) => r.service);

  const summaries = serviceResults
    .filter((r) => r.result?.summary)
    .map((r) => `[${r.service}] ${r.result!.summary}`);

  return {
    timestamp: new Date().toISOString(),
    services_checked: allServices,
    actions_taken: allActions,
    pending_human_review: allPending,
    context_snapshot: {
      service: "all",
      timestamp: new Date().toISOString(),
      summary: summaries.join(" | ") || "全サービス確認完了。特筆事項なし。",
      key_facts: serviceResults.flatMap(
        (r) => r.result?.context_snapshot?.key_facts ?? [],
      ),
      actions_taken: serviceResults.flatMap(
        (r) => r.result?.context_snapshot?.actions_taken ?? [],
      ),
    },
    summary: summaries.join(" | ") || "全サービス確認完了。特筆事項なし。",
  };
}

async function executeDelivery(
  report: CronRunResult,
  runId: string,
): Promise<void> {
  const deliveryPrompt = buildDeliveryPrompt(report, config);
  if (!deliveryPrompt) {
    log.info("delivery-skip", { runId, reason: "no delivery configured or no actions" });
    return;
  }

  const mcpServers = buildMcpServersForService("__delivery__", config);

  try {
    for await (const message of query({
      prompt: deliveryPrompt,
      options: {
        cwd: config.openclaw.project_cwd,
        systemPrompt: { type: "preset", preset: "claude_code" },
        mcpServers,
        executable: "bun",
        maxTurns: 5,
        maxBudgetUsd: 0.10,
        allowDangerouslySkipPermissions: true,
        permissionMode: "bypassPermissions",
        abortController: abort,
        env: {
          ...process.env,
          OPENCLAW_MODE: "delivery",
          OPENCLAW_RUN_ID: runId,
        },
      },
    })) {
      if (message.type === "result") {
        const result = message as Record<string, unknown>;
        log.info("delivery-sent", {
          runId,
          channel: config.openclaw.delivery.channel,
          cost: result.total_cost_usd as number,
          actions: report.actions_taken.length,
        });
      }
    }
  } catch (err) {
    log.error("delivery-error", { runId, error: String(err) });
  }
}

// Single cron run — the heart of v2
async function executeCronRun() {
  if (abort.signal.aborted) return;
  if (isRunning) {
    log.warn("cron-skip", { reason: "previous run still active" });
    return;
  }

  isRunning = true;
  const runId = crypto.randomUUID();
  log.info("cron-tick", { runId, interval: config.openclaw.cron_interval });

  try {
    // Step 1: Heartbeat check
    const heartbeat = checkHeartbeat(
      config.openclaw.project_cwd,
      config.openclaw.heartbeat.file,
    );

    log.info("heartbeat-check", {
      runId,
      hasWork: heartbeat.hasWork,
      tasks: heartbeat.tasks,
    });

    if (
      config.openclaw.heartbeat.enabled &&
      config.openclaw.heartbeat.skip_when_empty &&
      !heartbeat.hasWork
    ) {
      log.info("heartbeat-skip", { runId, reason: "HEARTBEAT.md is empty" });

      // Record skip in history
      history.append({
        runId,
        timestamp: new Date().toISOString(),
        service: "heartbeat",
        costUsd: 0,
        turns: 0,
        durationMs: 0,
        status: "skipped",
      });

      return;
    }

    // Step 2: Check enabled services
    const enabledServices = getEnabledServices();
    if (enabledServices.length === 0) {
      log.warn("cron-skip", { runId, reason: "no services enabled" });
      return;
    }

    // Step 3: Budget check — sum all per-service budgets as daily safety limit
    const todayCost = history.getTodayCost();
    const perRunBudget = enabledServices.reduce((sum, svc) => {
      const svcCfg = config.openclaw.services[svc];
      return sum + (svcCfg?.max_budget_usd ?? config.openclaw.max_budget_usd);
    }, 0);
    // Daily safety: per-run budget × estimated max runs/day (cron-aware)
    const cronMinutes = parseCronIntervalMinutes(config.openclaw.cron_interval);
    const maxRunsPerDay = Math.ceil((24 * 60) / cronMinutes);
    const dailyBudget = perRunBudget * maxRunsPerDay;
    if (dailyBudget > 0 && todayCost >= dailyBudget) {
      log.warn("budget-exceeded", {
        runId,
        todayCost,
        dailyBudget,
        maxRunsPerDay,
      });
      return;
    }

    // Step 4: Execute each service in isolated sessions
    const serviceResults: ServiceRunResult[] = [];

    for (const service of enabledServices) {
      if (abort.signal.aborted) break;

      const result = await executeServiceQuery(
        service,
        heartbeat.tasks,
        runId,
      );
      serviceResults.push(result);
    }

    // Step 5: Merge results
    const report = mergeResults(serviceResults);

    // Step 6: Delivery
    if (config.openclaw.delivery.enabled) {
      await executeDelivery(report, runId);
    }

    // Step 7: Log summary
    const totalCost = serviceResults.reduce((sum, r) => sum + r.cost, 0);
    const totalTurns = serviceResults.reduce((sum, r) => sum + r.turns, 0);
    const totalDuration = serviceResults.reduce(
      (sum, r) => sum + r.durationMs,
      0,
    );

    log.info("run-complete", {
      runId,
      services: enabledServices,
      totalCost,
      totalTurns,
      totalDuration_ms: totalDuration,
      actionsCount: report.actions_taken.length,
      pendingCount: report.pending_human_review.length,
    });
  } catch (err) {
    log.error("run-failed", { runId, error: String(err) });
  } finally {
    isRunning = false;
  }
}

// Start cron
const _job = new Cron(config.openclaw.cron_interval, executeCronRun);

const enabledServices = getEnabledServices();

log.info("daemon-started", {
  interval: config.openclaw.cron_interval,
  services: enabledServices,
  heartbeat: config.openclaw.heartbeat,
  delivery: config.openclaw.delivery,
  maxTurns: config.openclaw.max_turns,
  maxBudgetUsd: config.openclaw.max_budget_usd,
  pid: process.pid,
});

// Write PID file
try {
  writeFileSync(config.openclaw.pid_file, String(process.pid));
} catch (err) {
  log.error("pid-file-write-failed", { error: String(err) });
  process.exit(1);
}

// Run immediately on start, then cron takes over
executeCronRun().catch((err) => {
  log.error("initial-run-failed", { error: String(err) });
});
