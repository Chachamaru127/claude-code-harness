import { appendFileSync, mkdirSync } from "node:fs";
import { dirname } from "node:path";

const LOG_FILE =
  process.env.OPENCLAW_LOG_FILE ?? ".claude/logs/openclaw-daemon.log";

function ensureDir(path: string) {
  try {
    mkdirSync(dirname(path), { recursive: true });
  } catch {
    /* already exists */
  }
}

function write(
  level: string,
  event: string,
  data?: Record<string, unknown>,
) {
  const entry = JSON.stringify({
    ts: new Date().toISOString(),
    level,
    event,
    ...data,
  });
  console.error(`[openclaw] ${entry}`);
  ensureDir(LOG_FILE);
  appendFileSync(LOG_FILE, entry + "\n");
}

export const log = {
  info: (event: string, data?: Record<string, unknown>) =>
    write("info", event, data),
  error: (event: string, data?: Record<string, unknown>) =>
    write("error", event, data),
  warn: (event: string, data?: Record<string, unknown>) =>
    write("warn", event, data),
};
